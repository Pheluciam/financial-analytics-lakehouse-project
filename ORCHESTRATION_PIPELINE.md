# Orchestration Pipeline — Phase 3 walkthrough

> AWS Step Functions state machine orchestrating dbt-athena builds on AWS
> Glue Python Shell, with complementary Athena native-integration verify
> tasks. Lives at the Phase 2 Silver Data Vault output, drives Phase 4 Gold
> mart refresh on every execution.
>
> Created: 2026-05-29 (Phase 3 session 12 close). Companion to
> `DBT_PIPELINE.md` (Phase 2 transformation surface) and
> `EXTRACT_PIPELINE.md` (Phase 1 Bronze landing).

---

## 1. What this pipeline does

End-to-end orchestrated daily refresh of the financial-analytics lakehouse:
trigger Step Functions → Glue Python Shell job runs `dbtRunner().invoke(["deps", ...])` then `dbtRunner().invoke(["build", ...])` against the dbt project synced to S3 → Athena native-integration verify query confirms downstream-facing Silver tables populated. Sequential state machine, on-demand trigger only (per demo durability principle 2 — no EventBridge cron rule).

Tools: AWS Step Functions (orchestrator), AWS Glue Python Shell (dbt host runtime), AWS Athena (query engine for both dbt-athena materializations and Step Functions native verify tasks), AWS Glue Data Catalog (metastore), Amazon S3 (object storage + dbt project deploy target), AWS IAM (Customer Managed Policies for both runtime roles).

## 2. Architecture

```
                                                  ┌────────────────────────────┐
                                                  │ Step Functions state       │
                                                  │ machine: financial-        │
[ engineer triggers via Console / SDK / CLI ]  →  │ analytics-orchestrator     │
                                                  │ (Standard, JSONPath)       │
                                                  └────────────┬───────────────┘
                                                               │
                              ┌────────────────────────────────┴───────────────┐
                              ▼                                                │
        ┌─────────────────────────────────────────┐                            │
        │ State 1: RunDbtBuildOnGlue              │                            │
        │ Integration: glue:startJobRun.sync      │                            │
        │ Polls glue:GetJobRun until terminal     │                            │
        └─────────────────────┬───────────────────┘                            │
                              │                                                │
                              ▼                                                │
        ┌─────────────────────────────────────────┐                            │
        │ Glue Python Shell job:                  │                            │
        │ financial-analytics-dbt-build           │                            │
        │ Python 3.9 / 0.0625 DPU / 30 min cap    │                            │
        │ --additional-python-modules:            │                            │
        │   dbt-core==1.9.10,dbt-athena-          │                            │
        │   community==1.9.5                      │                            │
        └─────────────────────┬───────────────────┘                            │
                              │                                                │
                              ▼                                                │
        ┌─────────────────────────────────────────┐                            │
        │ scripts/run_dbt_in_glue.py              │                            │
        │ 1. boto3 sync dbt-project/latest/ → /tmp│                            │
        │ 2. dbtRunner.invoke(["deps", ...])      │                            │
        │ 3. dbtRunner.invoke(["build",           │                            │
        │      "--target", "glue"])               │                            │
        │ 4. sys.exit(0 if success else 1)        │                            │
        └─────────────────────┬───────────────────┘                            │
                              │                                                │
                              ▼                                                │
        ┌─────────────────────────────────────────┐                            │
        │ Athena queries against                  │                            │
        │ financial_analytics_silver (read Bronze │                            │
        │ via sources, write Silver via Iceberg   │                            │
        │ merge)                                  │                            │
        └─────────────────────┬───────────────────┘                            │
                              │                                                │
                              ▼                                                │
                            (Glue task terminal: Succeeded / Failed)           │
                              │                                                │
                              ▼                                                │
        ┌─────────────────────────────────────────┐                            │
        │ State 2: VerifyHubCompanyRowCount       │                            │
        │ Integration: athena:                    │                            │
        │   startQueryExecution.sync              │                            │
        │ Raw SQL: SELECT COUNT(*) FROM           │                            │
        │   financial_analytics_silver.hub_company│                            │
        └─────────────────────┬───────────────────┘                            │
                              │                                                │
                              ▼                                                ▼
                            (End)                                       (CloudWatch
                                                                         execution
                                                                         history)
```

Risk 29 complementary pattern at a glance: the Glue task hosts dbt (transformation + tests); the Athena task runs a raw verify query directly via Step Functions native integration (no compute host). Session 13 fans the verify side out to all 10 sql/verify/03-12 queries via a Parallel state.

## 3. Components

### 3.1 IAM execution roles

Two Customer Managed Policies + two roles, both authored as JSON artifacts under `stepfunctions/iam_policies/`. Customer Managed (not inline) because the policy bodies exceed the 2048-char inline cap (Phase 2 session 1 lesson on the phil-dbt user policy).

**Role A — `financial-analytics-glue-runtime`** (trusts `glue.amazonaws.com`):

- S3 read on the whole lakehouse bucket (Bronze raw JSON + scripts + athena-results read)
- S3 write on `zone=silver/` + `athena-results/` prefixes only (dbt-athena writes Iceberg files via Athena CTAS / INSERT on behalf of the caller)
- Athena `Start/Stop/Get/Batch*QueryExecution` on workgroup `wg_financial_analytics` + catalog `awsdatacatalog`
- Glue Catalog read+write on `financial_analytics_silver` database+tables (dbt materializes here)
- Glue Catalog read-only on `financial_analytics_bronze` database+tables (dbt sources read here — Risk 34)
- CloudWatch Logs `Create*` + `PutLogEvents` on `/aws-glue/python-jobs/*`

**Role B — `financial-analytics-stepfunctions-runtime`** (trusts `states.amazonaws.com`):

- `glue:StartJobRun + GetJobRun + GetJobRuns + BatchStopJobRun` scoped to the specific `financial-analytics-dbt-build` job ARN (Risk 29 verified against AWS docs — Glue `.sync` polls via `GetJobRun`, not EventBridge rules; no `PutTargets` / `PutRule` needed)
- Athena `Start/Stop/Get/Batch*QueryExecution + GetWorkGroup + GetDataCatalog` on workgroup + catalog (for the .sync verify task)
- S3 read on the lakehouse bucket + write on `athena-results/` only (verify queries scan Silver tables, write result files)
- Glue Catalog read on `financial_analytics_silver` (verify queries traverse the same metadata)

Authored via Custom trust policy in IAM Console (NOT the AWS service → Step Functions wizard use case — Risk 33 banked because that wizard auto-attaches `AWSLambdaRole`, which is dead weight for non-Lambda state machines and obscures the policy search box). Trust policy JSON pasted directly into the wizard.

### 3.2 Glue Python Shell job: `financial-analytics-dbt-build`

| Field | Value |
|---|---|
| Type | Python Shell |
| Python version | 3.9 (Risk 26 — Glue Python Shell 3.6 sunset 2026-03-01; 3.9 is the only supported runtime as of session 12 close) |
| Glue version | 3.0 |
| Worker capacity | 0.0625 DPU (~8x Free-Tier margin at daily cadence per Risk 27 analysis) |
| Job timeout | 30 min (cold-start dep-install + dbt build runs in ~3 min — 30 min is the safety ceiling that surfaces a hang before it eats Free-Tier budget) |
| Maximum concurrency | 1 (Risk 24 — dbt-core does not support safe parallel execution in the same process; fan-out happens at the Step Functions level via parallel branches launching separate Glue jobs, NOT inside one Python process) |
| Number of retries | 0 (first-run baseline; revisit when CI/CD is in scope) |
| Script path | `s3://phil-financial-analytics-lakehouse/glue-scripts/run_dbt_in_glue.py` |
| Script filename | `run_dbt_in_glue.py` |
| IAM Role | `financial-analytics-glue-runtime` |
| `--additional-python-modules` | `dbt-core==1.9.10,dbt-athena-community==1.9.5` (pinned per Risk 25 stability contract; downgraded from 1.11/1.10 per Risk 30 cascade) |
| Load common analytics libraries | TICKED (pyathena 2.5.3 pre-installed via this checkbox — narrows the cold-start dep-install delta per Risk 27) |
| Job parameter | `--dbt_project_s3_uri = s3://phil-financial-analytics-lakehouse/dbt-project/latest/` (consumed by the wrapper via `awsglue.utils.getResolvedOptions`) |

First-run cold-start measurement: total 55 sec (Risk 27 gate was 5 min — passed by an order of magnitude). Subsequent runs ~3 min including the full dbt build of 9 incremental + 1 seed + 5 table + 2 view models + 140 data tests (157 PASS / 0 ERROR / 0 SKIP).

### 3.3 dbt-runner wrapper: `scripts/run_dbt_in_glue.py`

The Glue Python Shell entry point. Three-layer pattern: clean professional script on disk, verbose-in-chat explanation provided at session 12 authoring, this walkthrough doc as the technical depth carrier.

Lifecycle:

1. Top-level `print(..., flush=True)` confirms script body executed (Risk 32 carry-forward — the `__name__ == "__main__"` guard is unreliable in Glue Python Shell, so we call `sys.exit(main())` unconditionally at module level).
2. `awsglue.utils.getResolvedOptions(sys.argv, ["dbt_project_s3_uri"])` resolves the Glue job arg to a local Python value.
3. `_sync_project_from_s3(uri, /tmp/dbt_project)` paginate-downloads every object under the S3 prefix to a clean local working dir (idempotent across job retries via `shutil.rmtree` before sync).
4. `dbtRunner().invoke(["deps", "--project-dir", ..., "--profiles-dir", ...])` installs dbt-utils into `/tmp/dbt_project/dbt_packages/` (Risk 35 — the deploy sync excludes `dbt_packages/` by design, so dbt deps runs at Glue runtime instead).
5. `dbtRunner().invoke(["build", "--project-dir", ..., "--profiles-dir", ..., "--target", "glue"])` runs the full transformation: staging → intermediate → warehouse (Raw Vault) → business_vault (PIT + Bridge).
6. `return 0 if result.success else 1` — Risk 25 exit-code-only success detection. dbt-core treats `result.results[*]` internals as not contracted ("liable to change"); we read only the top-level `.success` bool.

The "glue" dbt profile target omits `aws_access_key_id` + `aws_secret_access_key` so pyathena uses the boto3 default credential chain — which inside Glue resolves to the job's IAM role (`financial-analytics-glue-runtime`) via the `AWS_CONTAINER_CREDENTIALS_*` env vars Glue injects. The "dev" target (Phil's local invocation) keeps the dotenv-mounted phil-dbt static keys.

### 3.4 Deploy sync helper: `scripts/sync_phase3_artifacts_to_s3.py`

One-shot Python helper using boto3 + python-dotenv. Reads AWS creds from `.env` (phil-admin keys via `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`). Replaces the AWS CLI for this single use case to avoid the `dotenv -f run -- aws` Windows subprocess invocation issue (CreateProcess can't find pip-installed `aws` shim).

Uploads two surfaces to the lakehouse bucket per run:

- `dbt/` (minus build artifacts) → `s3://phil-financial-analytics-lakehouse/dbt-project/latest/`
- `scripts/run_dbt_in_glue.py` → `s3://phil-financial-analytics-lakehouse/glue-scripts/run_dbt_in_glue.py`

Exclusions: `target/`, `dbt_packages/`, `logs/`, `__pycache__`, `.pytest_cache`, `.user.yml`, `.env`. Manual deploy step for Phase 3; replaced by CI/CD push at Phase 6.

### 3.5 Step Functions state machine: `financial-analytics-orchestrator`

ASL JSON at `stepfunctions/state_machine.json`. Standard workflow type (not Express — durable history for auditing + supports runs > 5 min). JSONPath query language (NOT JSONata — our `ResultPath: "$.glueRun"` style references are JSONPath-shaped, and Workflow Studio's JSONata default would have broken parameter resolution).

Two states, sequential:

| State | Type | Resource | Polling |
|---|---|---|---|
| `RunDbtBuildOnGlue` | Task | `arn:aws:states:::glue:startJobRun.sync` | Step Functions polls `glue:GetJobRun` until terminal status |
| `VerifyHubCompanyRowCount` | Task | `arn:aws:states:::athena:startQueryExecution.sync` | Step Functions polls `athena:GetQueryExecution` until terminal status |

The Athena task's QueryString is inlined directly in the ASL: `SELECT COUNT(*) AS hub_company_row_count FROM financial_analytics_silver.hub_company`. Triples as: (a) demonstration of Risk 29's complementary pattern (raw SQL via Step Functions native integration, no compute host); (b) sanity-check that the Glue dbt build actually populated `hub_company`; (c) wiring proof for the IAM + workgroup + catalog stack.

Session 13 expands the verify side to a Parallel state running all 10 `sql/verify/03-12` queries — same shape, ten siblings.

## 4. End-to-end execution

First orchestrated run (Phase 3 session 12 close, 2026-05-29):

| Surface | Result |
|---|---|
| Step Functions execution status | Succeeded |
| Duration | 4 min 59 sec |
| State transitions | 4 (Start → RunDbtBuildOnGlue → VerifyHubCompanyRowCount → End) |
| Glue dbt build | PASS=157 / WARN=0 / ERROR=0 / SKIP=0 / TOTAL=157 — 9 incremental + 1 seed + 5 table + 2 view models + 140 data tests in 151.16s |
| Athena verify | hub_company COUNT(*) returned successfully against `financial_analytics_silver` |
| Risk 27 cold-start gate | 5 min — PASSED at 55s on the standalone Glue run; ~3 min inside the orchestrated execution |
| Athena Recent queries | ~50 queries timestamped at the run window, all tagged `dbt_version: 1.9.10` (the Glue-pinned version) |
| S3 zone=silver/ | Fresh Parquet objects (40.7 MB on bridge_company_concept_period alone) at the run timestamp |

## 5. Risks addressed at Phase 3 session 12

All twelve Phase 3 Risks (24-35) carried into the design. Six (24-29) banked at the kickoff forward-verify pass; six (30-35) banked at the first-run debug loop. Each Risk's full diagnosis + carry-forward principle lives in `LEARNINGS.md` under the matching subsection — this section maps Risks to where each lands in the pipeline.

| Risk | Surface in this pipeline |
|---|---|
| 24 — no parallel dbt invocations in same process | Glue job Maximum concurrency = 1; fan-out via Step Functions parallel branches launching separate Glue jobs (Phase 4+) |
| 25 — `dbtRunnerResult.result` internals not contracted | Wrapper returns `0 if result.success else 1`; never inspects `result.results[*]` |
| 26 — Glue Python Shell 3.6 EOL 2026-03-01 | Python version = 3.9 (locked at job creation) |
| 27 — cold-start dep-install timing | First-run baseline measured at 55s total (gate was 5 min) — pattern locked |
| 28 — Lambda 15-min hard cap | Glue Python Shell timeout = 30 min default; 480 min ceiling on Glue v5+; Lambda Container Image runtime rejected at the forward-verify direction-check |
| 29 — Athena `.sync` runs raw SQL, not dbt | Pattern: ONE Glue task (dbt host) + ONE Athena verify task (raw SQL via Step Functions native integration) — complementary by design |
| 30 — managed-runtime Python ceiling vs tool Python floor | Pinned dbt-core==1.9.10 + dbt-athena-community==1.9.5 (last 1.x with Python 3.9 support); requirements.txt now caps dbt-core<1.11 |
| 31 — dbt 1.10+ `arguments:` test wrapper rejected by 1.9.x | 28 instances flattened across 4 schema YAMLs via `scripts/flatten_test_arguments.py`; flags block removed from dbt_project.yml |
| 32 — Glue Python Shell stdout buffering + `__name__ == "__main__"` unreliable | `sys.exit(main())` at module level (no guard); `print(..., flush=True)` everywhere |
| 33 — IAM Role wizard "Step Functions" use case auto-attaches AWSLambdaRole | Step Functions role authored via Custom trust policy path (NOT AWS service → Step Functions) |
| 34 — Glue role's Glue Catalog scope missed the Bronze database | Policy split into `GlueCatalogSilverReadWrite` + `GlueCatalogBronzeRead` Sid blocks |
| 35 — sync helper excludes dbt_packages/ from S3 | Wrapper calls `dbtRunner.invoke(["deps", ...])` before `["build", ...]`; ~2s runtime cost preserves clean S3 deploy surface |

## 6. How to deploy + run

Pre-flight (one-time per session):

1. Local venv active. `python --version` shows 3.12+ (any 3.9+ works for local; Glue side is 3.9 only).
2. `.env` has `AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY` (phil-admin keys) + `AWS_DEFAULT_REGION=us-east-1` + `AWS_DBT_ACCESS_KEY_ID` + `AWS_DBT_SECRET_ACCESS_KEY` (phil-dbt keys for local dbt invocations).
3. dbt-core 1.9.10 + dbt-athena-community 1.9.5 + dbt-utils 1.3.3 (via `dbt deps`) installed in the venv.

Deploy (per change to dbt/ or scripts/run_dbt_in_glue.py):

```powershell
python scripts/sync_phase3_artifacts_to_s3.py
```

Trigger orchestrated run:

- AWS Console: Step Functions → State machines → `financial-analytics-orchestrator` → Execute → leave input as `{}` → Start execution.
- AWS CLI (post-installation): `aws stepfunctions start-execution --state-machine-arn arn:aws:states:us-east-1:470439680370:stateMachine:financial-analytics-orchestrator`.

Monitor:

- Step Functions execution detail page: graph view + execution status + state transitions counter.
- Glue Console → financial-analytics-dbt-build → Runs tab for the underlying Glue execution.
- CloudWatch `/aws-glue/python-jobs/output` log stream for the wrapper + dbt stdout.
- Athena Console → Recent queries to confirm dbt-1.9.10-tagged queries at the run window.

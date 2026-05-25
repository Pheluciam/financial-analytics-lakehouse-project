# Project Context — financial-analytics-lakehouse-project

> Running state record. Read at the start of every session alongside
> TEACHING_PREFERENCES.md. Captures WHERE we are in the project — what's
> shipped, what's locked, what's open, what's blocked, what's queued for
> the next session. PROJECT_PLAN.md is the static "what we're building";
> this file is the live "where we are right now."
>
> Created: 2026-05-23 (Phase 0 closeout). Updated at every session close
> per the bundled-commit cadence in TEACHING_PREFERENCES.md.

---

## Current status

| Field | Value |
|---|---|
| Active phase | **Phase 1 — Bronze landing** (mid-phase, session 3 closed) |
| Next phase | Phase 1 session 4 — 100-company full S&P 100 extract (Bronze freeze) + boto3 S3 metadata verification script + Phase 1 close-out audit |
| Last session closed | 2026-05-25 (Phase 1 session 3) |
| Last bundled commit | 2026-05-25 — Phase 1 session 3 bundle (10-company extract + Glue Crawler attempt + manual Bronze DDL + Athena workgroup + verification suite — all 6 checks PASS) |
| Active blockers | None |
| Open questions | None blocking session 4 kickoff |

---

## What's locked

All Phase 0 decisions locked 2026-05-23. Full table in PROJECT_PLAN.md
section 4. Stack summary in PROJECT_PLAN.md section 3. Full deliberation
history in LEARNING_ROADMAP.md "Notes / changes" 2026-05-23 entries.

Eight locks at a glance:

1. History depth — 10 years
2. Operational layer — direct-to-S3 (no RDS)
3. Transformation tool — dbt-athena
4. Power BI publishing — continuous + freeze at v1.0
5. Company universe — S&P 100 current roster
6. Dashboard themes — 4 (P&L trend, Peer benchmarking, Financial health/ratios, Growth/forecasting) + 1 executive overview
7. Orchestration — AWS Step Functions
8. SEC EDGAR User-Agent — `Phil <pheluciam@outlook.com>`

Two major pivots also locked this session: cloud (Azure → AWS), analytical
platform (Databricks → AWS-native lakehouse S3 + Glue + Athena + Lake
Formation). Databricks deferred to mini-project slot 2 of the mini-projects
block (see LEARNING_ROADMAP.md).

Three standing conventions baked in across the project (live in
TEACHING_PREFERENCES.md):

- AI-assistance disclosure on every README (paste-able template lives in
  TEACHING_PREFERENCES.md)
- In-session debugging discipline (Phil drives the diagnosis, not just
  accepts the fix; bank non-trivial bugs in LEARNINGS.md)
- Debugging fluency as the priority emphasis area in the 6-8 week training
  journey

---

## What's open

Deliberately deferred OUT of Phase 0, handled at Phase 1 kickoff:

- AWS account creation (12-month Free Tier clock starts at account creation
  — timing with actual build start is optimal)
- GitHub repo creation + first commit
- Python venv setup + `requirements.txt` scaffolding
- `.env.example` template authoring

Deferred to specific later phases (per PROJECT_PLAN.md section 14):

- Python forecasting library choice (Prophet vs statsmodels) → Phase 4
- dbt-athena Iceberg vs Parquet materialisation → Phase 2 dbt scaffolding
- Lake Formation governance → Phase 6 stretch

Not deferred — actively NOT in scope for Project #3:

- Databricks (deferred to mini-project slot 2)
- AWS Glue ETL Spark / PySpark (deferred to mini-project slot 5 — streaming)
- Microsoft Fabric (deferred to mini-project slot 3)
- Streaming ingestion (deferred to mini-project slot 5)
- ML beyond simple Python forecasting (deferred — no ML platform in Project #3)
- Risk + anomaly dashboard theme (10-K/A restatements — dropped at Phase 0)

---

## Session log

Append a new entry at every session close. Newest at top.

### 2026-05-25 — Phase 1 session 3 — 10-company extract + Glue Crawler attempt + manual Bronze DDL + verification suite

**Goal.** 10-company sector-diverse extract test (10 fresh CIKs across financials, tech, healthcare, energy, consumer staples) using the existing `extract_sec_edgar.py` with repeated `--cik` flags. Bronze verification suite first draft via Athena SQL. Optional Glue Crawler bootstrap. Phil opted up-front for Option A (Crawler-first → SQL-via-Athena verification) per pacing signal welcoming 30-60 min for professional-quality routes.

**What landed.**

- **10-company SEC EDGAR extract PASSED.** ~12-15 seconds wall-clock for 10 CIKs across financials (JPM 19617, BAC 70858), tech (MSFT 789019, NVDA 1045810), healthcare (JNJ 200406, UNH 731766), energy (XOM 34088, CVX 93410), consumer (WMT 104169, PG 80424). All 11 partition combos (10 from today + Apple from session 2) reachable through partition projection. Rate limiter held cleanly at moderate scale — no 429s, no SEC rejections.
- **Glue infrastructure shipped (Crawler retained as scaffolding, NOT used for Bronze).** IAM role `AWSGlueServiceRole-financial-analytics-lakehouse` created with managed AWSGlueServiceRole policy + custom inline `S3ReadAccess-financial-analytics-lakehouse` policy scoped to our bucket. Glue database `financial_analytics_bronze` created. Crawler `crawler_bronze_sec_edgar` configured (S3 source `zone=bronze/`, on-demand schedule, table prefix `sec_edgar_`). Crawler ran 49 seconds and FAILED with ValidationException on the 128 KB column-type-definition limit during NVIDIA's struct inference — 6 partial tables created before bail. Crawler infrastructure kept for future Silver/Gold Parquet layers where the schema heterogeneity won't apply.
- **Athena workgroup `wg_financial_analytics` created.** Customer-managed query results at `s3://phil-financial-analytics-lakehouse/athena-results/`, override-client-side-settings ON, IAM auth, engine v3. Per-query bytes-scanned hard cap deferred — AWS UI now surfaces only soft CloudWatch alerts at workgroup level; the historical hard cap moved to post-creation edit path. Acceptable at our 30-300 MB bucket scale; revisit in Phase 6 if data crosses GB territory.
- **Manual Bronze DDL shipped.** `sql/ddl/01_create_bronze_tables.sql` — `CREATE EXTERNAL TABLE` with `facts` column intentionally excluded (deferred to Phase 2 Silver dbt parsing), `entityname` mapped via openx JsonSerDe, partition projection on `extract_date` (type=date, range=`2026-05-24,NOW`) + `cik` (type=injected). DDL ran clean; smoke check returned 11 rows including NVIDIA (the one that broke the Crawler). 10/10 audit PASS.
- **Bronze verification suite shipped.** `sql/verify/01_phase1_bronze_verification.sql` — CTE-based PASS/FAIL pattern carried from Project #2 LEARNINGS. 6 checks: total rows = 11, distinct CIKs = 11, extract_date partitions = 2, today's row count = 10, yesterday's row count = 1, non-null entitynames = 11. All 6 PASSED on first run. Run time 1.181 sec, 241.5 KB scanned. 10/10 audit PASS.
- **LEARNINGS.md** — five new "Project #3 lessons" entries banked: (1) venv-not-active on fresh PowerShell session — Phil drove the diagnosis; (2) Glue Crawler heterogeneity / 128 KB column-type-definition limit; (3) Athena Query Editor one-statement-at-a-time constraint; (4) TYPE_MISMATCH on date BETWEEN over string partition column + four-options consolidation — Phil drove the diagnosis; (5) web-search-verify discipline before shipping unverified syntax claims.
- **EXTRACT_PIPELINE.md** — extended with section 9 (Glue Crawler attempt + pivot), section 10 (manual Bronze DDL design), section 11 (Athena workgroup + verification suite). Section 7 (step-up testing protocol) flipped: 10-company status PASSED 2026-05-25; 100-company still PENDING.

**Decisions locked this session.**

- Bronze table schema: minimal column set (entityname + partition keys), `facts` deferred to Silver.
- Glue Crawler retained as infrastructure scaffolding for Silver/Gold layers; not used for Bronze where heterogeneous JSON broke it.
- Athena workgroup `wg_financial_analytics` is the project-default workgroup for the rest of Project #3.
- Web-search-verify discipline: standing pattern for any non-trivial DDL or API claim — `allowed_domains` restricted to authoritative sources only.

**Blockers / surprises.** The Glue Crawler failure was a genuine architectural surprise — the 128 KB Catalog limit isn't prominently documented and the heterogeneous-JSON limitation wasn't anticipated at design time. Pivot was clean once the limitation was understood. The `::` cast and openx-string-serialization claims being WRONG were the meta-surprise — reinforced the web-search-verify discipline.

**NOT in this session — deferred.**

- 100-company full S&P 100 extract → next session (Phase 1 session 4, final Bronze extract; Bronze freeze).
- boto3-based S3 byte-count + sha256 fingerprint verification script → next session (the SQL verification suite covers JSON content; Python script needs to cover S3 object metadata).
- VS Code venv auto-activate config → Phase 6 polish.
- Per-query bytes-scanned hard cap on Athena workgroup → Phase 6 polish if bucket scales past GB.

**Next session.** Phase 1 session 4 — 100-company full S&P 100 extract + rate-limiter scaling validation + boto3-based S3 metadata verification script + Phase 1 close-out structural audit. Bronze freezes on this snapshot per demo-durability principle 1.

---

### 2026-05-24 — Phase 1 session 2 — smoke test + SEC EDGAR extract + Apple 1-company test

**Goal.** Ship the AWS smoke test (deferred from session 1) + first draft
SEC EDGAR extract script + validate against Apple Inc (CIK 320193) per
the step-up testing protocol. Bank session-2 lessons in
TEACHING_PREFERENCES + LEARNINGS.

**What landed.**

- `scripts/smoke_test_aws.py` — connectivity proof for the AWS auth + S3
  stack. Three-layer pattern (verbose chat walkthrough → clean on disk →
  EXTRACT_PIPELINE section 3a updated). Structured logging with specific
  exception classes, 5 distinct exit codes, dedicated `health_checks/`
  prefix on S3, sha256-style separation of concerns (lifecycle policy
  banked for Phase 6). 10-criteria audit: 10/10 PASS.
- `scripts/extract_sec_edgar.py` — SEC EDGAR companyfacts → S3 Bronze.
  argparse `--cik` (default Apple), polite ~8 req/sec rate limiter,
  `urllib3.Retry` adapter for transient failures (5 attempts, expo
  backoff), Hive-style partition key `zone=bronze/extract_date=YYYY-MM-DD/cik=XXXXXXXXXX/`,
  10-digit CIK pad, sha256 fingerprint in S3 object metadata, 8 exit
  codes. 10-criteria audit: 10/10 PASS.
- `requirements.txt` — boto3, python-dotenv, requests (minimum-version
  pinning during build; lock file deferred to Phase 6).
- `.venv/` — local virtual environment created and gitignored (already
  covered by session-1 `.gitignore`).
- `PROJECT_PLAN.md` section 10 principle #4 — Free Tier wording fixed
  (12-month Free Tier → 6-month Free Plan / $200 credits; account cliff
  23 Nov 2026 explicit).
- `EXTRACT_PIPELINE.md` — section 3a flipped from "deferred" to "shipped"
  (smoke test); sections 4-8 expanded with extract script details, rate
  limiter design, retry tuning, step-up testing protocol with Apple PASS.
- `TEACHING_PREFERENCES.md` — four pace / depth calibration bullets
  added under "Anything else Claude should know": (1) no inline code
  formatting in explanations — re-lock; (2) verbose-in-chat depth =
  block-level for Python, line-level for configs; (3) pace > teaching
  density — Project #3 ships first, deep instruction deferred to 6-8
  week training journey + interview prep; (4) standard response template
  — brief bullet summary, light explanation, one optional direction
  question, senior-DE default, Phil asks for depth.
- `LEARNINGS.md` — two new entries under "Project #3 lessons": inline-code
  formatting drift (diagnosis → fix → lesson) and process-density drift
  (diagnosis → fix → lesson).

**Apple 1-company test result.** PASSED 2026-05-24 12:26 local. ~3.6 MB
raw JSON landed to `s3://phil-financial-analytics-lakehouse/zone=bronze/extract_date=2026-05-24/cik=0000320193/companyfacts.json`.
sha256 prefix `31f9ab439840`. End-to-end ~4 seconds. AWS Console
inspection confirmed: 5 metadata fields (Content-Type + cik + extracted-at
+ sha256 + source) and 3 tags (Purpose=Extract + Component=extract_sec_edgar
+ Source=SECEDGAR) all rendered correctly. S3 versioning audited via
"Show versions" toggle — confirmed smoke test delete-marker preserved.

**Decisions locked this session.** None new at the project-level — all
session-2 decisions were within the locked Phase 0 stack. Calibrations
locked at the working-style level (4 bullets in TEACHING_PREFERENCES).

**Lessons captured in LEARNINGS.md "Project #3 lessons" section.**

Two diagnosis → fix → lesson loops banked: (1) inline-code formatting
in explanations breaks Phil's reading flow — re-locked the 2026-05-20
rule with explicit violation categories; (2) process-density drift —
session 2 drifted into Phase-0-style discussion density (multi-paragraph
design call write-ups, 6 green-light questions before building); fixed
with three coordinated TEACHING_PREFERENCES bullets locking the new
ship-tight default template.

**Blockers / surprises.** None. Smoke test ran clean first try; extract
ran clean first try; AWS Console inspection confirmed every metadata
field and tag we set.

**NOT in this session — deferred.**

- 10-company sector-diverse extract test → next session.
- Full S&P 100 extract → session after.
- Glue Crawler bootstrap → next session (or session after, depending on
  whether Phil wants to crawl after the 10-company landing or after the
  100-company freeze).
- `sql/verify/01_phase1_bronze_verification.sql` → next session.
- Pylance squiggle check on `scripts/*.py` in VS Code → flag from
  10-criteria audit item 6; non-blocking, glance next time VS Code opens.

**Next session.** Phase 1 session 3 — 10-company sector-diverse extract
+ rate-limiter scaling validation + Bronze verification suite first
draft + (optional) Glue Crawler bootstrap if 10-company landing looks
clean.

---

### 2026-05-23 — Phase 1 session 1 — AWS bootstrap + S3 landing + GitHub repo

**Goal.** Lay the AWS + git foundation that everything else hangs off.
AWS account, Admin IAM user with MFA, $5 budget alert, S3 bucket with
medallion prefix folders, GitHub repo creation. SEC EDGAR extract is
session 2 scope, not this session.

**What landed.**

- AWS account on Free Plan (~$200 credits + 6 months; Free Plan expires
  23 Nov 2026 — banked as the conversion-to-paid cliff date). Account ID
  470439680370.
- Root MFA enabled (Microsoft Authenticator, device `phil-root-msauth`);
  root signed out and shelved post-bootstrap.
- Admin IAM user `phil-admin` via Administrators user group +
  `AdministratorAccess` policy. MFA enabled (`phil-admin-msauth`).
  Programmatic access keys generated → written straight into `.env`.
- Budget alert `portfolio-monthly-5usd-tripwire` — $5/month cap, alerts
  at 85% actual / 100% actual / 100% forecasted to
  `pheluciam@outlook.com`.
- S3 bucket `phil-financial-analytics-lakehouse` in **us-east-1** (region
  locked at this step). General purpose, ACLs disabled,
  block-all-public-access ✓, versioning enabled, default SSE-S3
  encryption. Three prefix folders: `zone=bronze/`, `zone=silver/`,
  `zone=gold/`.
- `.env` populated with real credentials + locked region + locked bucket
  + locked SEC EDGAR User-Agent (gitignored). `.env.example` committed
  as the template counterpart.
- `.gitignore` committed — covers Python artifacts, venv, secrets, AWS
  local creds, linter caches, IDE scratch, OS junk, local data scratch.
- `EXTRACT_PIPELINE.md` stub authored — distinguishes session 1 vs
  session 2 scope; will expand session 2 as extract is built.
- GitHub repo `Pheluciam/financial-analytics-lakehouse-project` (public).
  Local `git init` + `origin` remote wired up + default branch `main`.

**Decisions locked this session.**

- AWS region: **us-east-1** (N. Virginia). Cheapest tier + strongest
  tutorial alignment. Cost difference at our 100-300 MB scale is ~$0.01
  per month vs Sydney; tutorial alignment is the dominant signal.

**Lessons captured in LEARNINGS.md "Project #3 lessons" section.**

Three diagnosis → fix → lesson loops banked this session: (1) build
locally first, GitHub commit at session close (no mid-session git
plumbing); (2) never screenshot AWS one-time credentials — clipboard or
password manager only; (3) AWS Console region selector doesn't take
effect on Global-service pages, only on region-bound services. Also
banked two trackable open items: Free Plan cliff (23 Nov 2026) and
phil-admin lacking IAM-access-to-billing.

**NOT in this session — deferred.**

- `scripts/smoke_test_aws.py` — boto3 → AWS auth → S3 read/write
  end-to-end value proof. Originally session 1 scope; deferred at
  mid-session scope reshape. To be built first thing in session 2
  BEFORE the extract script, since the extract script depends on the
  same boto3 + auth chain working.
- PROJECT_PLAN.md section 10 Free Tier wording update (12-month →
  6-month / $200-credits). Minor; banked.
- (Resolved in this session close) LEARNINGS.md lessons captured in
  the new "Project #3 lessons" section — workflow, credentials, Console
  UI. No longer deferred.

**Blockers / surprises.** Region dropdown click intermittently
unresponsive on Global-service pages — diagnosed in-session (only
takes effect on region-bound services). Account temp password
exposed in a screenshot — mitigated by force-change + MFA.

**Next session.** `scripts/smoke_test_aws.py` first, then
`scripts/extract_sec_edgar.py` first draft against single company
(Apple, CIK 320193) + polite rate limiter validation + step-up to 10
companies.

---

### 2026-05-23 — Phase 0 kickoff and closeout (single session)

**Goal.** Complete Phase 0 — load context, validate SEC EDGAR API live,
resolve the three non-blocking pre-Phase-0 items, drive all open Phase 0
decisions, lock the stack, author the project-specific docs, structural audit.

**What landed.**

- Live SEC EDGAR API sanity check PASSED against Apple Inc (CIK 320193) with
  User-Agent `Phil <pheluciam@outlook.com>`. ~59KB JSON, populated
  `filings.recent.accessionNumber` array.
- Three non-blocking items resolved: Databricks trial timing (defer to Bronze
  landing close); Azure SQL operational layer (locked as fresh, then
  superseded by AWS pivot); User-Agent format (confirmed).
- **PIVOT 1: Cloud vendor — Azure → AWS.** Driver: portfolio breadth for
  Australian DE job market (research showed Australia/Melbourne split closer
  to 50/50 than feared 90/10 Azure; Phil already has Azure on CV via Project
  #2). Phil prior AWS familiarity from NEC Australia.
- **PIVOT 2: Analytical platform — Databricks → AWS-native (S3 + Glue
  Catalog + Athena + Lake Formation).** Driver: cost-vs-keyword analysis
  (Databricks has 14-day trial cliff + $3-5/demo; AWS-native is pennies/demo
  forever; AWS-native S3/Glue/Athena cluster appears in roughly 2.8× more
  AWS-shop postings than Databricks).
- **Mini-projects block** earmarked at 5 slots, sequenced simpler →
  more complex: (1) dbt Cloud + CI/CD, (2) Databricks, (3) Microsoft Fabric
  end-to-end, (4) Iceberg vs Delta comparison, (5) Streaming (Kinesis + Glue
  ETL Spark Structured Streaming). 1-2 Tableau + ~3 Power BI BI-split target.
- **Mini-projects sit BEFORE the 6-8 week training journey** — journey
  consolidates lessons from 8 codebases (3 main + 5 mini), not 3.
- **AI-assistance disclosure convention** baked as standing convention
  across all 8 portfolio repos. Paste-able README template in
  TEACHING_PREFERENCES.md.
- **Debugging fluency** locked as the priority emphasis area in the training
  journey; in-session debug discipline added to TEACHING_PREFERENCES.md;
  ≥1 debug-pattern question per session locked as a standing quiz category.
- All 8 Phase 0 decisions locked (see PROJECT_PLAN.md section 4).
- **PROJECT_PLAN.md authored fresh.**
- **PROJECT_CONTEXT.md authored fresh** (this file).
- **LEARNING_ROADMAP.md** updated extensively — full table refreshed, Project
  #3 stack section rewritten, mini-projects section added, training journey
  scope expanded, debugging emphasis added, AI-disclosure convention noted,
  Notes/changes appended.
- **ENGINEERING_STANDARDS.md** light update — Project #3 context note added
  at top, date updated.
- **LEARNINGS.md** carry-forward subsection populated with Project #2 → Project
  #3 carry-forward principles.
- Phase 0 structural audit run — no findings.

**Blockers / surprises.** None. Single bash curl was blocked by sandbox
proxy allowlist for `data.sec.gov` — pivoted to `mcp__workspace__web_fetch`,
which routed correctly and returned the JSON. Lesson banked: for SEC EDGAR
API calls from the sandbox during build, route via web_fetch (or via Phil's
local Python in Phase 1 once the extract script exists).

**Next session.** Phase 1 — Bronze landing layer kickoff. First sub-steps
expected: (1) AWS account creation + IAM bootstrap + S3 bucket creation;
(2) GitHub repo creation + first commit (this Phase 0 doc set); (3)
`scripts/extract_sec_edgar.py` first draft with polite rate limiter +
single-company smoke test (Apple, CIK 320193) before any 10-company or
full-100 scale-up.

---

## Files in the project (Phase 1 session 3 close inventory)

Doc-shaped:

- `README.md` — TBD at Phase 6
- `PROJECT_PLAN.md` ✓
- `PROJECT_CONTEXT.md` ✓ (this file)
- `LEARNING_ROADMAP.md` ✓
- `TEACHING_PREFERENCES.md` ✓
- `ENGINEERING_STANDARDS.md` ✓
- `GLOSSARY.md` ✓
- `LEARNINGS.md` ✓ (5 new Project #3 entries banked session 3)
- `EXTRACT_PIPELINE.md` ✓ (Phase 1 walkthrough; sections 1-8 shipped sessions 1-2, sections 9-11 shipped session 3)

Code-shaped:

- `scripts/smoke_test_aws.py` ✓ (session 2 — AWS auth + S3 round-trip proof)
- `scripts/extract_sec_edgar.py` ✓ (session 2 — SEC EDGAR companyfacts → S3 Bronze; 10-company test PASSED session 3)
- `sql/ddl/01_create_bronze_tables.sql` ✓ (session 3 — manual Bronze table DDL with partition projection)
- `sql/verify/01_phase1_bronze_verification.sql` ✓ (session 3 — CTE-based PASS/FAIL verification suite, all 6 PASS)
- `requirements.txt` ✓ (session 2 — boto3, python-dotenv, requests)

AWS infrastructure (provisioned via Console, not yet captured as IaC):

- IAM role `AWSGlueServiceRole-financial-analytics-lakehouse` (session 3 — Glue + custom S3 read inline)
- Glue database `financial_analytics_bronze` (session 3)
- Glue Crawler `crawler_bronze_sec_edgar` (session 3 — bootstrapped; failed against Bronze JSON, retained for Silver/Gold)
- Athena workgroup `wg_financial_analytics` (session 3 — Customer managed results, override-client-settings ON)

Repo-config:

- `.env` (gitignored)
- `.env.example` ✓
- `.gitignore` ✓
- `.venv/` (gitignored, session 2)

---

## Cross-doc reading order at session start

1. **TEACHING_PREFERENCES.md** — how Phil wants to work
2. **PROJECT_CONTEXT.md** (this file) — where we are right now
3. **PROJECT_PLAN.md** sections relevant to the active phase — what we're building
4. **ENGINEERING_STANDARDS.md** if writing code — the audit bar
5. **LEARNING_ROADMAP.md** sections only if context-shifting (rare mid-project)
6. **LEARNINGS.md** as needed when a bug class is familiar

---

*Last updated: 2026-05-25 (Phase 1 session 3 close). Append a session-log
entry at every session close.*

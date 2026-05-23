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
| Active phase | **Phase 1 — Bronze landing** (mid-phase, session 1 closed) |
| Next phase | Phase 1 session 2 — `scripts/smoke_test_aws.py` (deferred from session 1) + `scripts/extract_sec_edgar.py` first draft |
| Last session closed | 2026-05-23 (Phase 1 session 1) |
| Last bundled commit | 2026-05-23 — Phase 1 session 1 bundle (AWS bootstrap + S3 + GitHub) |
| Active blockers | None |
| Open questions | None blocking session 2 kickoff |

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

**Notes / banked lessons (full LEARNINGS.md write-up at session 2 start).**

- **Workflow discipline**: "build everything locally first, THEN create
  GitHub repo + commit + push as one atomic ship moment at session
  close." Burnt during this session when GitHub repo setup pre-dinner
  left a dangling git-init-no-commit across an intended dinner break.
  Phil flagged this as unprofessional and reversed the plan to finish
  the session fully in one go.
- **Credential handling**: AWS one-time temp passwords + access keys
  must never appear in screenshots — copy via clipboard or password
  manager only. Force-change-on-first-sign-in + immediate MFA enrollment
  narrowed the exposure window when this happened with phil-admin's
  temp password.
- **AWS Console UI**: region selector on Global-service pages (IAM,
  Billing, Account) does not take visible effect — only switches when
  on a region-bound service like S3. Don't burn time trying to switch
  region from a global page.

**NOT in this session — deferred.**

- `scripts/smoke_test_aws.py` — boto3 → AWS auth → S3 read/write
  end-to-end value proof. Originally session 1 scope; deferred at
  mid-session scope reshape. To be built first thing in session 2
  BEFORE the extract script, since the extract script depends on the
  same boto3 + auth chain working.
- PROJECT_PLAN.md section 10 Free Tier wording update (12-month →
  6-month / $200-credits). Minor; banked.
- LEARNINGS.md mid-session lessons capture (workflow + credentials +
  Console UI). Banked for session 2 first-thing.

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

## Files in the project (Phase 0 close inventory)

Doc-shaped (all Phase 0):

- `README.md` — TBD at Phase 6
- `PROJECT_PLAN.md` ✓ (authored this session)
- `PROJECT_CONTEXT.md` ✓ (this file)
- `LEARNING_ROADMAP.md` ✓ (updated extensively this session)
- `TEACHING_PREFERENCES.md` ✓ (updated this session — AI-disclosure + debug discipline)
- `ENGINEERING_STANDARDS.md` ✓ (light context-note update this session)
- `GLOSSARY.md` ✓ (carried forward from Project #2; Project #3-specific terms added as they appear)
- `LEARNINGS.md` ✓ (carry-forward subsection populated this session)

Code-shaped: none yet (Phase 1 onward).

---

## Cross-doc reading order at session start

1. **TEACHING_PREFERENCES.md** — how Phil wants to work
2. **PROJECT_CONTEXT.md** (this file) — where we are right now
3. **PROJECT_PLAN.md** sections relevant to the active phase — what we're building
4. **ENGINEERING_STANDARDS.md** if writing code — the audit bar
5. **LEARNING_ROADMAP.md** sections only if context-shifting (rare mid-project)
6. **LEARNINGS.md** as needed when a bug class is familiar

---

*Last updated: 2026-05-23 (Phase 0 close — initial authoring). Append a
session-log entry at every session close.*

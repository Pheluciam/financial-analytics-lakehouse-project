# LEARNING_ROADMAP.md — Phil's data engineering pathway

> Captures the *learning trajectory* beyond the current project. Lives alongside
> the per-project plans (`PROJECT_PLAN.md`, `PROJECT_CONTEXT.md`) and gets
> updated as Phil's direction firms up.
>
> Created: 2026-05-13. Updated as plans evolve.

---

## Where we are

| Stage | Status | Notes |
|---|---|---|
| Project #1 — CDC NT Transport (dbt-first analytics project) | ✅ Done | Reference: `C:\dbt\cdc_nt_gtfs\` |
| **Project #2 — Retail Demand & Forecasting Pipeline** (this repo) | ✅ **v1.0 SHIPPED 2026-05-22** | All 6 phases complete: Azure SQL → Snowflake → dbt → Cortex ML forecast → 5-page Power BI dashboard. CI shipped (ruff F821 + dbt parse + sqlfluff). |
| Project #3 — `financial-analytics-lakehouse-project` (AWS-native lakehouse + Data Vault 2.0, SEC EDGAR corporate finance) | 📋 Planned — stack locked 2026-05-19, domain + folder name locked 2026-05-22, **cloud + analytical platform pivoted to AWS-native 2026-05-23**; pre-Phase-0 housekeeping complete; live API check passed 2026-05-23; ready for Phase 0 decision lock | See "Project #3 — locked stack" section below |
| **Mini-projects block — 4-5 portfolio gap-fillers** | 📋 Earmarked 2026-05-23; slot 5 locked as Microsoft Fabric end-to-end | Sits AFTER Project #3, BEFORE the training journey. Sequenced simpler / more-employer-friendly first → more complex. See "Mini-projects" section below |
| **Post-Project #3 mini-projects — 6-8 week DE training journey** | 📋 Planned — design locked 2026-05-19; scope expanded 2026-05-23 to consolidate lessons from all three main projects + the 4-5 mini-projects | Runs AFTER the mini-projects block, not concurrently. See below |
| Subsequent projects | 🤔 TBD | Depends on job search outcome and direction |

---

## Project #3 — locked stack

Stack locked 2026-05-19. **Domain + folder name re-opened and pre-Phase-0 principles banked 2026-05-22**. **Cloud vendor + analytical platform pivoted to AWS-native 2026-05-23** (see Notes/changes for full chronology). Builds on Project #2 muscle where useful, intentionally differentiates where portfolio variety pays off. Three projects, three distinct modeling stories.

**Repo / folder name (LOCKED 2026-05-22): `financial-analytics-lakehouse-project`.** Reasoning: "financial analytics" covers both the BA and FA personas Phil is targeting (broader than "reporting", more specific than "data"); "lakehouse" is the modern stack keyword DE/AE recruiters scan for. Original lock as `financial-markets-pipeline-project` was invalidated by the domain pivot. Folder will be created in File Explorer FIRST under `C:\Users\Phil\Documents\Claude\Projects\financial-analytics-lakehouse-project`, THEN attached at Cowork project creation — never renamed mid-project. The rename-breakage lesson from Project #2 Phase 0 still applies; following the File-Explorer-first order avoids triggering it.

**Domain (revised 2026-05-22).** **Corporate finance — SEC EDGAR public filings.** Pivoted from the original "financial markets / equity OHLCV" framing after Phil's BA / FA dashboard goal was clarified (P&L, revenue, expenses, financial ratios, peer benchmarking). SEC EDGAR's XBRL data delivers real US-GAAP income statement / balance sheet / cash flow line items — a much stronger fit than equity price bars.

**Data source — SEC EDGAR API.** Free, no API key, no published rate limit (10 req/sec is the safe community ceiling). REST, JSON responses. Hosted at `data.sec.gov`. User-Agent header with contact info required by SEC policy. Three endpoints that matter:

- `data.sec.gov/submissions/CIK##########.json` — filing history per company
- `data.sec.gov/api/xbrl/companyfacts/CIK##########.json` — all XBRL financial facts per company (income statement / balance sheet / cash flow)
- `data.sec.gov/api/xbrl/frames/...` — one fact across all companies for a period (peer benchmarking)

Bulk nightly ZIP archives also available if per-call ingestion ever becomes a bottleneck. Verified live 2026-05-22 against official SEC docs (last reviewed April 2025) — free, no key, structurally unlikely to change (US government statutory disclosure mandate).

**Pre-Phase-0 API live check (lesson from Project #1).** Before Phase 0 commits any code, run a two-minute live sanity test: GET on one company's `/submissions/CIK*.json` with a User-Agent header, confirm JSON returns and the `filings.recent` array is populated. Only after this passes does Phase 0 proceed. Banked because Project #1 burned hours after Copilot pointed at Transport Canberra without checking it required a vendor-gated key.

**Stack (AWS-native, locked 2026-05-23):**

- **Cloud vendor.** **AWS.** Pivoted from Azure 2026-05-23 after Australia / Melbourne job-market research: AWS Data Engineer postings on SEEK Australia (~934 nationally, ~521 Melbourne) outnumber Databricks-specific postings by ~2.8×, and Phil already has Azure stack keywords on his CV via Project #2 (Azure SQL). Adding AWS to the portfolio opens the AWS-shop half of the market without closing the Azure-shop half. Phil has prior AWS familiarity from his NEC Australia role (light exposure, not main role).
- **Operational source (Phase 0 decision).** Either AWS RDS (leaning Postgres on the Free Tier — 750h/month db.t3.micro + 20GB storage, 12 months free; modern DE default, cheaper than RDS SQL Server licensing) preserving the operational-system-of-record pattern from Project #2, OR direct-to-S3 lakehouse-native (skip RDS, land raw JSON straight in Bronze). Lock at Phase 0 — see Open decisions below.
- **Object storage.** Amazon S3 — Free Tier covers 5GB for 12 months, far exceeds the project's data budget. Houses Bronze / Silver / Gold layers.
- **Metastore.** AWS Glue Data Catalog — free up to 1M objects. The canonical index of all tables, schemas, and S3 file locations across Bronze / Silver / Gold.
- **Analytical platform — AWS-native lakehouse.** S3 (storage) + Glue Data Catalog (metastore) + Athena (serverless SQL query engine) + optionally Lake Formation (governance). Intentionally NOT Databricks — Databricks deferred to a follow-up mini-project (see Mini-projects section below) for the cost-vs-keyword trade-off. Pennies per query, $0 idle cost, no 14-day trial cliff — strong fit for the demo-durability principles. Genuine "lakehouse" pattern: open file formats (Parquet/Iceberg) on cheap object storage with SQL on top.
- **Modeling pattern.** **Data Vault 2.0** in the analytical layer. Hubs (business keys: company CIK, reporting period, taxonomy concept), Links (relationships: filing → company, filing → concept facts), Satellites (descriptive attributes + history: company metadata, filing metadata, fact values + restatement history). Native SCD, full audit lineage. Strong fit for regulated finance domain + heterogeneous XBRL taxonomy reconciliation. **Genuinely different from Project #2's Kimball star.** Modeling pattern unchanged by the AWS pivot — Data Vault 2.0 works equally well on any analytical platform.
- **Architectural layering.** Medallion (Bronze / Silver / Gold) — all layers as Parquet (or Iceberg) tables in S3, indexed by the Glue Data Catalog, queryable via Athena.
  - Bronze: raw SEC EDGAR JSON landed in S3 (append-only, partitioned by extraction date). If RDS is kept, a normalised operational mirror lives there in parallel.
  - Silver: Data Vault 2.0 raw vault (Hubs, Links, Satellites) PLUS XBRL taxonomy normalisation — canonical concept mapping (e.g. `Revenues` / `Revenue` / `SalesRevenueNet` reconciled to one canonical revenue concept). This normalisation IS the genuine DE story for the Silver layer.
  - Gold: information marts on top of the vault for BI consumption — P&L mart, peer-comparison mart, financial-ratios mart, etc. (specific themes chosen at Phase 0).
- **Transformation tool (Phase 0 decision).** Either dbt-athena (reuses Project #2 dbt muscle directly, fastest ramp, most professional default for AWS-native dbt) OR AWS Glue ETL (serverless Spark jobs, AWS-native, adds Spark + Glue ETL keywords). dbt-athena leaning per the "default to most professional senior-DE pattern" rule from TEACHING_PREFERENCES.md.
- **Orchestration (leaning AWS Step Functions).** Native to AWS, serverless, $0 idle, pay-per-state-transition fractions of a cent — strong fit for demo-durability principle #4. AWS MWAA (Managed Workflows for Apache Airflow) reuses Project #2 Airflow muscle but has a ~$0.49/hr minimum cost (~$350/month idle), which violates the $0-idle posture. Self-hosted Airflow on a tiny EC2 with auto-stop is a possible compromise. Final lock at Phase 0 — Step Functions strongly favoured.
- **BI.** Power BI (reuses Project #2 PBI skills, native Athena connector available).

**Data volume budget (locked 2026-05-22).** Bronze ≤ 2M rows. Gold marts ≤ 500K rows. SEC EDGAR data is intrinsically small: curate ~50-100 companies × ~40 quarterly filings × ~200 XBRL line items = roughly 500K-1M rows in Bronze. Avoids the Project #2 M5-scale (~36M rows) warehouse-sizing pain entirely. No Snowflake-style XS→XL warehouse upsize will ever be required.

**Demo-durability principles (locked 2026-05-22).** Project must be demo-able in interviews 4-6 weeks after build (job search lag), and ideally re-demonstrable years later for future job applications. Six principles bake into the Phase 0 architecture:

1. **Bronze = snapshot, not stream.** Run SEC EDGAR extraction ONCE during build, freeze raw JSON in Delta Lake. After build the API is NOT in the live demo path. (Also genuine production pattern — a raw zone is append-only history, not a live feed.)
2. **DAG runs on-demand, not on a schedule.** No live cron. Show DAG code + screenshots of past successful run logs in Databricks Workflows UI; optionally trigger one small incremental run live in interview. Demo dashboards never wait for it.
3. **Power BI in Import mode at publication.** .pbix file fully self-contained. Open it years later — no live warehouse connection required. Lock Import mode from page 1, not as a retrofit.
4. **AWS cost model (locked 2026-05-23 after pivot from Databricks).** S3: 5GB free for 12 months from account creation, then ~$0.023/GB/month — project budget keeps storage well under $1/month forever. Athena: $5 per TB scanned, pay-only-when-you-query — a single demo session scans GBs at most, ~$0.02 per demo. Glue Data Catalog: free up to 1M objects (project uses ~10-50). Glue ETL (if used): $0.44 per DPU-hour, only at transformation runtime. RDS (if used): Free Tier 750h/month db.t3.micro + 20GB for 12 months; ~$15/month after. Step Functions: $25 per 1M state transitions — pennies for a portfolio project. **Net effect: idle cost effectively $0 forever (no trial cliff), per-demo cost ~$0.05.** Decisively better than the Databricks 14-day trial + $3-5/demo model the original plan would have required.
5. **GitHub repo = canonical artifact.** Public repo with README, architecture diagram, screen recording of one full pipeline run, .pbix file, demo runbook. Even if the AWS account / Fabric tenant / Databricks workspace expires or is wiped, the repo demonstrates the build. Recruiters look at the repo first when they look at portfolios at all (~34% of engineering leaders actively review per the 2025 CodePath survey; close to 100% when used as in-interview talking material). README includes the standing AI-assistance disclosure block per TEACHING_PREFERENCES.md (locked 2026-05-23).
6. **Demo-day runbook from day 1.** A `DEMO_RUNBOOK.md` file authored DURING the build (not after), captured at Phase 0, refined per phase. Documents exactly what to show in a 10-min interview slot and in what order.

**Portfolio modeling variety across the three projects:**

- Project #1 — dbt analytics on GTFS transit data (reference: `C:\dbt\cdc_nt_gtfs\`).
- Project #2 — Kimball star schema warehouse on Snowflake, three-tier marts (Staging → Intermediate → Warehouse → Marts).
- Project #3 — Data Vault 2.0 inside medallion lakehouse on AWS-native stack (S3 + Glue + Athena + Lake Formation), SEC EDGAR corporate finance domain.

**Open decisions to lock at Phase 0 of Project #3 (revised 2026-05-23 post-pivot):**

- **Curated company universe** — likely 50-100 companies (e.g. S&P 100, or a sector slice like tech / financial / healthcare).
- **Years of history** — likely 5-10 years of quarterly + annual filings.
- **Operational layer** — keep an AWS RDS Postgres operational mirror (parallels Project #2's Azure SQL pattern, adds RDS keyword) OR skip and land SEC EDGAR JSON direct to S3 Bronze (cleaner lakehouse-native pattern, fewer moving parts).
- **Transformation tool** — dbt-athena (reuses Project #2 dbt muscle, fastest ramp, leaning) vs AWS Glue ETL Spark jobs (AWS-native, adds Spark + Glue ETL keywords).
- **Specific dashboard themes** — pick 3-5 from the candidate list: P&L trend + decomposition; peer / sector benchmarking; financial health + ratios; growth + forecasting; risk + anomaly (10-K/A restatements).
- **Power BI: continuous publish to .pbix file vs build once and freeze** (relates to demo-durability principle #3).

**No longer open (resolved during pre-Phase-0 housekeeping):**

- ~~API vendor (Alpha Vantage / Polygon.io / Tiingo)~~ — SEC EDGAR locked 2026-05-22.
- ~~Scope: equities vs equities+ETFs+FX~~ — N/A after domain pivot to corporate finance 2026-05-22.
- ~~Time horizon: bulk + daily incremental vs live-cron~~ — resolved by demo-durability principle #1 (bulk extraction once, freeze, no live cron).
- ~~Cloud vendor: Azure vs AWS~~ — AWS locked 2026-05-23.
- ~~Analytical platform: Databricks vs alternative~~ — AWS-native (S3 + Glue + Athena) locked 2026-05-23; Databricks deferred to mini-projects.
- ~~Orchestration: Workflows vs Airflow~~ — superseded by AWS-native equivalents; leaning AWS Step Functions for $0 idle cost; final lock at Phase 0.

---

## Mini-projects block — portfolio gap-fillers

Earmarked 2026-05-23. Phil's framing: the jump from his BI/Data-Analyst professional experience straight to full-scale ETL/ELT data-warehouse builds is potentially too big a leap for hiring managers to swallow on three large projects alone. Mini-projects fill in the specific keyword / capability gaps and demonstrate breadth — each one focused on a single technology cluster recruiters explicitly scan for.

**Slot count: 5 mini-projects** (locked 2026-05-23). BI tool split target: at least 1-2 Tableau + ~3 Power BI across the slots (Tableau included to keep that prior BI muscle visible on the CV alongside Power BI). Specific BI-tool-to-project assignment to be decided when the block starts.

**Sequencing principle (locked 2026-05-23).** Order the slots **less complex / more employer-friendly first → more complex / more niche later**. Lowest-conceptual-lift, highest-keyword-density work first so Phil ships fast and gets early portfolio momentum; bigger conceptual stretches (streaming patterns, ML pipelines) later when the muscle is built. Every slot still has to satisfy "real employer keyword match" — none of them are pure-curiosity projects.

**Position relative to training journey (locked 2026-05-23).** Mini-projects come AFTER Project #3 and BEFORE the 6-8 week training journey, NOT concurrent with it. Rationale: each mini-project surfaces fresh gaps and quirks that become high-quality material for the training journey to consolidate. Doing the mini-projects first means the training journey has 5 mini-project codebases to draw exercises and quiz questions from (on top of the three main projects), not just 3.

**Proposed slot order (simpler → more complex). Final BI-tool assignment per slot still TBD.**

1. **dbt Cloud + production CI/CD mini-project.** Port a dbt project (likely Project #2's) into dbt Cloud's free tier, set up scheduled jobs, slim CI, deferral. Lowest new-concept lift — Phil already knows dbt; this just adds operational polish. Highest employer-friendliness — "production-grade dbt" + "CI/CD" appears in nearly every mid-level DE posting. Ships fastest of the five.
2. **Databricks mini-project.** Use Databricks' 14-day free trial to read Project #3's existing S3 lakehouse data via a Databricks workspace, build one transformation + one small ML model (MLflow), capture screenshots / .ipynb / screen recording to GitHub before trial expiry. Reuses familiar S3 data, bounded by trial window. Fills the Databricks brand-keyword gap created by the AWS pivot. Cross-cloud premium: "Databricks" matches both AWS-shop and Azure-shop postings.
3. **Microsoft Fabric end-to-end mini-project.** Spin up a Microsoft 365 Developer tenant (free) + Fabric 60-day trial. Build a small end-to-end inside Fabric: public-API ingest → Fabric notebook transformation (Spark) → Fabric Warehouse mart → Power BI report. Optionally use a OneLake "shortcut" to read Project #3's S3 data and double the demo as a multi-cloud lakehouse story. Pausable F2 capacity post-trial keeps idle cost ~$0. "Microsoft Fabric" is a rising keyword in Australian DE postings, especially Azure-stack-heavy shops (government, financial services, Microsoft-stack enterprises) — Microsoft is pushing it hard as the consolidation of Synapse + ADF + Power BI Premium. Power BI is one of Fabric's seven workloads, so this slot naturally pairs with the Power BI BI-tool count.
4. **Iceberg vs Delta Lake comparison mini-project.** Write the same table in both open formats on S3, compare query performance / time-travel / schema evolution / partition handling. Shows the ability to reason about file-format trade-offs, not just use them. Apache Iceberg has serious enterprise momentum in 2026. More technical / narrower than the first three; smaller "wow" demo but reinforces architectural credibility. Tableau is a candidate for the comparison visuals — publication-quality side-by-side charts suit Tableau's design strengths.
5. **Streaming mini-project.** Real-time ingest using either Apache Kafka or AWS Kinesis → S3 → Athena (or Snowpipe → Snowflake if reusing Project #2's stack is cheaper). Biggest new-concept lift — streaming is a totally new pattern for Phil. Highest portfolio value-add (fills the zero-streaming gap) — "Streaming" / "Kafka" / "Kinesis" appears in roughly half of mid-level DE postings. Tableau real-time dashboard tile is a classic pairing and gives the second Tableau slot. **Recommended baseline shape (added 2026-05-23): AWS Kinesis (ingest) → AWS Glue ETL Spark Structured Streaming (process) → S3 (land) → Athena (query) → Tableau real-time tile.** Pairs Glue ETL Spark + PySpark keyword exposure with the streaming work where Spark genuinely earns its keep (real-time stream processing is classic Spark territory, unlike SEC EDGAR's 800K-row batch which is SQL-sized). Picks up streaming + Spark + PySpark + Glue ETL all in one mini-project — strong keyword density. Glue ETL Spark intentionally deferred from Project #3 to here so Spark doesn't get retrofitted into a use case it doesn't fit. **Open call to revisit when this slot starts: convert to Microsoft Fabric Real-Time Analytics + KQL** instead of Kinesis/Glue ETL if a second Fabric exposure is wanted — adds a different Fabric workload from slot 3, not a duplicate.

**Candidate BI-tool mapping (3 Power BI + 2 Tableau) — provisional, finalised per slot when the block begins:**

- Slot 1 (dbt Cloud + CI/CD) — Power BI (small dashboard) OR skip BI entirely
- Slot 2 (Databricks) — Power BI on top of Databricks SQL
- Slot 3 (Fabric end-to-end) — Power BI (Fabric's native BI workload IS Power BI)
- Slot 4 (Iceberg vs Delta) — Tableau (publication-quality comparison charts)
- Slot 5 (Streaming) — Tableau (real-time dashboard tile)

**Repo strategy.** Each mini-project gets its own small public GitHub repo (separate from Project #3) with its own README, demo runbook, .pbix/.twbx file, and screen recording — same demo-durability principles as the main projects. Each README includes the standing AI-assistance disclosure block per TEACHING_PREFERENCES.md (locked 2026-05-23) — same convention across all 8 portfolio repos (3 main + 5 mini), no exceptions. Cross-link from the main project READMEs so a recruiter clicking through sees the network of work.

**Open decisions to lock when the mini-project block begins:**

- Final BI-tool assignment per slot (candidate mapping above; revisit before each slot starts).
- Slot 5 final form — streaming (Kafka / Kinesis) vs Fabric Real-Time Analytics + KQL.
- Specific operational layer per slot (e.g. does the Databricks slot stand alone or extend Project #3?).
- Whether to publish a meta-README that indexes all 5 mini-projects + the 3 main projects as a single portfolio entry point.

---

## Post-Project #3 — 6-8 week DE training journey

Design locked 2026-05-19. Replaces and broadens the earlier Python-only block — same time slot, wider scope.

**Trigger.** Starts AFTER the 5 mini-projects ship (sequencing locked 2026-05-23 — see Mini-projects section). Runs while actively looking for work.

**Why.** Phil's three main projects + 5 mini-projects build breadth across the modern data stack, but he wants to consolidate code-writing fluency and conceptual fluency before job interviews and the first day on a DE team. The original Python-only block undersold the actual gap, which is broader than language syntax — YAML, SQL, dbt, Airflow patterns, modeling, Git, CLI tooling all need active-recall practice, not just exposure. Sequencing the journey AFTER the mini-projects (rather than concurrent) means the consolidation has 8 codebases to draw from (3 main + 5 mini), not 3 — richer exercise material, more varied quiz questions, more "I built this; let me reread it and articulate what I'd change" reflective passes.

**Goal.** Interview credibility + first-day confidence on a Data Engineer / Analytics Engineer team. NOT full mastery — Phil is not aiming to be senior-engineer fluent in 6-8 weeks. Beginner → early intermediate is the realistic target.

**Priority emphasis area — debugging fluency (locked 2026-05-23).** Explicitly the highest-priority skill gap to close in the training journey. Live-coding debug exercises are the single most common interview pattern that catches AI-assisted portfolio builders off guard — interviewers hand over a broken script and watch the candidate diagnose. Targets across the 6-8 weeks: read a Python traceback top-to-bottom and articulate the failure in plain English; use the VS Code debugger + pdb fluently (breakpoints, step into / step over / step out, watch expressions); read Airflow / dbt / Snowflake / Athena logs and extract the actionable signal from the noise; distinguish root cause from symptom; common dbt failure modes (compile vs run, ref/source errors, generic-test failures); common Python failure modes (ImportError, AttributeError, KeyError, type mismatches, env var not set). Format: dedicated debug-clinic sessions where Claude breaks something in one of Phil's existing project files and Phil drives the diagnosis-and-fix; debug-pattern quiz questions in the warm-up bank ("read this traceback — what's wrong?"). Standing in-session debug discipline is captured in TEACHING_PREFERENCES.md under "Anything else Claude should know."

**Format.**

- 2-hour sessions × 3-4 sessions/week × 6-8 weeks = ~36-64 hours total
- Code-first: code walkthrough → modify-and-extend → real exercises, with concepts woven in as they come up
- Split: ~80% code, ~20% conceptual / general knowledge
- Quiz warm-up first 10-15 min of every session (see quiz design below)
- Hands-on with Phil's own Project #1 / #2 / #3 code AND the 5 mini-project codebases wherever they fit — all 8 projects are the reference codebase the journey draws from
- Sessions tracked in a session log; quiz progress persisted to a quiz-log file so memory carries across sessions

**Code focus (the ~80%).**

- Python — idioms (pathlib, context managers, dataclasses, f-strings), virtual envs + dependency mgmt, retries + decorators, type hints + pyrightconfig, structured logging, requests / httpx, sqlalchemy, argparse / typer, pytest
- YAML — emphasised heavily because it shows up across the whole DE stack: dbt schema files / dbt_project.yml / profiles.yml, Airflow docker-compose, GitHub Actions workflows, Docker compose, eventually Kubernetes. One YAML-fluency block pays back across every tool.
- Airflow DAG Python — TaskFlow API, decorators, idempotency, sensors, dynamic task mapping, observability
- SQL — advanced (window functions, complex CTEs), dialect differences (Snowflake / T-SQL / BigQuery / Databricks), EXPLAIN plans, partitioning + clustering
- dbt SQL + Jinja — macros, materialisations strategy, custom tests

**General-knowledge focus (the ~20%).**

- Architecture patterns — medallion, Kimball star, Data Vault 2.0, lambda / kappa, hub-and-spoke
- Data model type comparisons — when to use which
- File formats — Parquet, Delta, Iceberg, ORC, Avro — what each is optimised for
- Git workflow — branching, rebase, conflict resolution, recovery from common mistakes
- PowerShell + Linux command-line for DE
- Docker basics for DE — Dockerfiles, compose, debugging

**Suggested 8-week outline (compressible to 6 by merging Python W1+W2 and Data Quality + Git/CI weeks).**

- Week 1 — Python for DE foundations: idioms, venv + dependency mgmt, type hints + pyrightconfig, structured logging. Hands-on with existing extract scripts.
- Week 2 — Python for DE advanced: retry patterns + decorators, requests / httpx for APIs, sqlalchemy, argparse / typer CLIs, pytest fundamentals.
- Week 3 — SQL deep dive: window functions, complex CTEs, dialect differences, EXPLAIN plans, partitioning. Refactor existing dbt model SQL.
- Week 4 — dbt patterns: materialisations strategy, tests beyond not_null (custom singular + dbt-expectations), macros + Jinja, sources / snapshots / exposures.
- Week 5 — Airflow + orchestration: TaskFlow API, idempotency patterns, sensors, branches, dynamic task mapping, observability. Extend existing DAG.
- Week 6 — Modeling patterns: Kimball walkthrough of Project #2 warehouse + Data Vault 2.0 mini-example (Project #3 reinforcement).
- Week 7 — Data quality + CI/CD: custom dbt tests, Great Expectations basics, GitHub Actions for dbt CI, pre-commit hooks (sqlfluff, ruff).
- Week 8 — Git / CLI / Docker: Git deep dive (branching, rebase, conflict resolution, recovery), PowerShell + Linux scripting, Docker for DE basics.

**Quiz warm-up design.**

- First 10-15 min of each 2hr session.
- 5-8 questions per session, mixed topics, adapting difficulty.
- Question format progresses through the 8 weeks:
  - Weeks 1-2: pure multiple choice ("which of these is the correct Git command to undo the last commit while keeping changes staged?")
  - Weeks 3-4: multiple-choice scenarios ("you have a dbt model failing this test — which of these is the most likely cause?")
  - Weeks 5-6: fill-in-the-blank ("complete this Airflow DAG decorator: @____ ...")
  - Weeks 7-8: type-the-command / write-the-snippet ("write the PowerShell one-liner to find all .py files modified in the last 7 days")
  - **All weeks: at least 1 debug-pattern question** ("read this traceback — what's wrong?", "this dbt model fails with X — what's the most likely cause?", "this Airflow task is stuck in scheduled state — what do you check first?"). Locked as a standing quiz-bank category 2026-05-23 to reinforce the debug-fluency emphasis.
- Right answer: green tick + brief explanation. Wrong: red cross + correct answer + 1-2 line reason.
- Topic mix per session, roughly:
  - 2 on concepts (architecture, modeling, file formats)
  - 2 on commands (Git / PowerShell / Linux)
  - 2 on syntax (Python / YAML / SQL)
  - 1-2 scenario-based (debug a snippet, pick the right approach)
- Cross-session memory: a `quiz-log.md` (or similar) in the training journey's project folder tracks topics nailed / missed / not-yet-seen. Claude reads it at session start, prioritises weak areas, avoids repeating recent questions. Same persistence pattern as PROJECT_CONTEXT.md works for projects.

**Folder + format.** Treat the training journey like a fourth project — its own folder following the existing `<name>-project` naming convention. Tentative name: `de-training-journey-project` (lock at Phase 0). Holds session logs, quiz log, exercise files, any mini-deliverables.

**Tooling: Claude Code (not Cowork).** Locked 2026-05-19. Reasons: (a) the journey is 80% code and terminal-native by design — Claude Code IS the terminal-native DE workflow, simulating job-day-1 conditions; (b) quizzes work fine in terminal (numbered MCQ → typed answer → typed command progression); (c) markdown persistence pattern (quiz-log.md, session log) works identically in Cowork and Code, so no continuity loss. Cowork stays useful for occasional admin/planning sessions and the final portfolio-publishing pass.

**What this journey is NOT.**

- A "learn computer science" detour — no data structures / algorithms drills. Strictly DE-applicable.
- A portfolio project in itself — it's a learning sprint with internal artefacts, not a public deliverable. (Optional: publish a sanitised version at the end as a "what I learned" GitHub repo.)

**Open decisions to lock at training journey Phase 0:**

- 6 weeks vs 8 weeks (depends on job-hunt timing).
- Folder name (`de-training-journey-project` is the working name).
- Whether to publish a sanitised public version as a portfolio artefact.
- Initial quiz topic seed list — concrete starter pool of ~50 questions across the 4 topic buckets.

---

## Career target context

Per Phil's own framing:

- Realistically aiming for **Analytics Engineer**, **Senior Data Analyst with pipeline work**, or **BI Engineer** roles immediately after Project #2 ships.
- The 6-8 week DE training journey opens the door to **mid-level Data Engineer** roles by the end of Project #3 + journey.
- Long-term direction: Data Engineer.

---

## Notes / changes

- 2026-05-13 — Initial creation. Six-week Python block captured per Phil's mid-Phase-2 reflection (after the "what does a real DE actually do?" conversation).
- 2026-05-19 — Project #3 stack locked. Finance API → Azure SQL Server → Databricks lakehouse, with Data Vault 2.0 modeling inside a Bronze/Silver/Gold medallion. Locks portfolio modeling variety: Kimball (#2) + Data Vault (#3) are genuinely distinct stories. Five open Phase 0 decisions captured.
- 2026-05-19 — Project #3 folder name locked as `financial-markets-pipeline-project` (under `C:\Users\Phil\Documents\Claude\Projects\`). Locked early to prevent mid-project rename — Project #2 had folder-rename connection breakage that we're not repeating.
- 2026-05-19 — Post-Project #3 training journey design locked. Replaces the earlier Python-only block with a broader 6-8 week, code-first, quiz-warm-up program covering Python + YAML + Airflow DAG Python + SQL + dbt + modeling + Git/CLI/Docker. Hands-on with Phil's own project code. 80/20 code-to-concept split. Beginner → early intermediate target. Quiz progression: multiple choice → fill-in-blank → type-the-command across weeks 1-8. Cross-session memory via a quiz-log file. Tentative folder name `de-training-journey-project`. Four open decisions captured for Phase 0.
- 2026-05-19 — Training journey tooling locked as Claude Code (not Cowork). Terminal-native workflow simulates real DE job conditions, quizzes work in-terminal, markdown persistence identical across tools. Cowork stays available for occasional admin/planning sessions.
- 2026-05-22 — **Project #2 shipped as v1.0.** All 6 phases complete across 22 sessions. Azure SQL operational source + Snowflake analytical warehouse + Airflow + Cosmos + dbt + Snowflake Cortex ML forecast + 5-page Power BI dashboard. Carry-forward LEARNINGS banked for Project #3 across Snowflake, Airflow, dbt, Power BI, and CI domains (see `LEARNINGS.md`).
- 2026-05-22 — **Pre-Phase-0 housekeeping session for Project #3 (run from the Project #2 folder).** Multiple updates to the Project #3 plan, all baked into the "Project #3 — locked stack" section above:
  - **Domain pivoted from equity markets to SEC EDGAR corporate finance.** The original "financial markets / OHLCV bars" framing didn't fit Phil's stated BA / FA dashboard goal (P&L, revenue, expenses, financial ratios, peer benchmarking). SEC EDGAR's XBRL data delivers real US-GAAP income statement / balance sheet / cash flow line items — a much stronger fit. Compared against Treasury Fiscal Data API and FRED before locking; SEC EDGAR ranked strongest for the stated dashboard intent.
  - **Data source verified live.** SEC docs page fetched (last reviewed April 2025): free, no API key, no published rate limit, User-Agent header required. Pre-Phase-0 live-API sanity check banked as a Project #1 carry-forward lesson (Transport Canberra dead-end).
  - **Folder name re-opened.** `financial-markets-pipeline-project` no longer accurate. New name to be locked before folder creation. Folder will be created in File Explorer first, then attached at Cowork project creation — no mid-project rename.
  - **Data volume budget locked**: Bronze ≤ 2M rows, Gold marts ≤ 500K rows. No Snowflake-style warehouse upsize will be required.
  - **Demo-durability principles locked (six).** Bronze-as-snapshot; on-demand DAG (no live cron); Power BI Import mode at publication (.pbix self-contained for years-later demos); Databricks cost model (free trial → Free Edition or auto-terminate pay-as-you-go, ~$0 idle, ~$3-5 per demo); GitHub as canonical artifact; demo runbook from day 1.
  - **Three previously-open Phase 0 decisions resolved early**: API vendor (SEC EDGAR), time horizon (bulk once + freeze, no live cron), orchestration (leaning Databricks Workflows for demo-cost reasons).
  - **Cowork folder hygiene.** Project #3 folder will be self-contained — no cross-project folder mounts. File copy list from Project #2 → Project #3 at folder creation: TEACHING_PREFERENCES.md, LEARNING_ROADMAP.md, LEARNINGS.md. NOT copied: PROJECT_PLAN.md, PROJECT_CONTEXT.md (project-specific, get authored fresh at Phase 0), POWERBI_PLAYBOOK.md (Project-#2 session plan; the carry-forward PBI rules already live in LEARNINGS.md). Also banked: `/compact` is a Claude Code command, not a Cowork command — Cowork auto-compacts at its own threshold.
- 2026-05-22 — **Project #3 folder name LOCKED as `financial-analytics-lakehouse-project`.** Selected from a shortlist of four (`financial-reporting-lakehouse-project`, `financial-analytics-lakehouse-project`, `corporate-financials-lakehouse-project`, `financial-statements-warehouse-project`). Phil's reasoning: "analytics" covers both the business-analyst and financial-analyst personas he's targeting (broader than "reporting", more specific than "data"). Combined with "lakehouse" gives strongest combined business + modern-tech signal on a GitHub repo list. Folder creation order locked as: (1) create empty folder in File Explorer at `C:\Users\Phil\Documents\Claude\Projects\financial-analytics-lakehouse-project`, (2) copy the three carry-forward .md files into it, (3) only THEN create the Cowork project pointing at the existing folder. Avoids the Project #2 rename-breakage.
- 2026-05-23 — **Project #3 Phase 0 kickoff session.** Five-part pre-Phase-0 work executed in order:
  - **SEC EDGAR live API check PASSED.** GET on `data.sec.gov/submissions/CIK0000320193.json` with User-Agent `Phil <pheluciam@outlook.com>` returned ~59KB JSON; verified Apple Inc payload and populated `filings.recent.accessionNumber` array. API is live and structurally sound. Banked Project #1 carry-forward lesson honoured (verify-before-Phase-0).
  - **Three non-blocking items resolved.** Databricks free-trial clock to start once Bronze landing is closer (demo-durability principle 4); Azure SQL was to be a fresh database on the existing Project #2 server (later superseded by AWS pivot); SEC EDGAR User-Agent format `Phil <pheluciam@outlook.com>` confirmed.
  - **PIVOT 1: Cloud vendor — Azure → AWS.** Driver: portfolio breadth for Australian DE job market. Research confirmed AWS holds ~30% global cloud share (vs Azure ~24%), Australia split is closer to 50/50 in DE postings (NOT 90/10 Azure as one risk hypothesis), Phil already has Azure stack on his CV via Project #2 so adding AWS opens the AWS-shop half of the market without closing the Azure-shop half. Phil has light prior AWS familiarity from his NEC Australia role. AWS Free Tier is 12-months-from-account-creation (not 30-day trial); Phil has no existing AWS account so the clock is fresh.
  - **PIVOT 2: Analytical platform — Databricks → AWS-native (S3 + Glue + Athena + Lake Formation).** Driver: cost-vs-keyword trade-off analysis. SEEK Australia job-count check showed Databricks ~330 jobs nationally vs AWS Data Engineer ~934 nationally / ~521 in Melbourne; AWS-native S3/Glue/Athena cluster appears in roughly 2.8× more AWS-shop postings than Databricks. AWS-native cost story decisively better for demo-durability: pennies per demo forever vs Databricks 14-day trial cliff and $3-5 per demo. "Lakehouse" architecture pattern preserved (Parquet/Iceberg on S3, Glue Catalog metastore, Athena SQL on top); Data Vault 2.0 modeling unchanged.
  - **Mini-projects block earmarked.** 4-5 mini-projects to be scheduled after Project #3 ships, filling specific keyword / capability gaps recruiters scan for. BI-tool target split: at least 1-2 Tableau + ~3 Power BI. Earmarked: Databricks (fills Databricks brand-keyword gap from the pivot, uses 14-day trial against Project #3's S3 data), streaming (Kafka/Kinesis — fills the zero-streaming gap), Iceberg vs Delta Lake comparison, dbt Cloud + production CI/CD, plus one open slot. Each mini-project sized at 1-2 weekends, separate public GitHub repo per project, cross-linked from main project READMEs.
  - **Phase 0 decisions list refreshed.** Now: company universe; years of history; operational layer (RDS Postgres vs direct-to-S3); transformation tool (dbt-athena vs Glue ETL Spark); dashboard themes; PBI continuous-publish vs build-once-and-freeze. Step Functions strongly favoured for orchestration (Free Tier idle = $0; MWAA's ~$0.49/hr minimum violates demo-durability principle 4).
- 2026-05-23 (continued) — **Mini-projects block fleshed out further.**
  - **Slot 5 LOCKED as Microsoft Fabric end-to-end mini-project.** Driver: Fabric is a rising keyword in Australian DE postings (particularly Azure-stack-heavy enterprises — government, banks, Microsoft-stack shops); Microsoft is consolidating Synapse + ADF + Power BI Premium into Fabric. Cost-feasible via free Microsoft 365 Developer Subscription tenant + 60-day Fabric trial; pausable F2 capacity post-trial = ~$0 idle. Power BI is one of Fabric's seven workloads so the slot pairs naturally with the Power BI BI-tool count. Earmarked TBD call: convert slot 5 (streaming) to Fabric Real-Time Analytics + KQL when that slot starts, if a second Fabric exposure is wanted.
  - **Slot count locked at 5** (was 4-5 open).
  - **Sequencing principle locked: less complex / more employer-friendly first → more complex / more niche later.** Proposed order: (1) dbt Cloud + CI/CD, (2) Databricks, (3) Microsoft Fabric end-to-end, (4) Iceberg vs Delta Lake, (5) Streaming. Each slot 1-2 weekends. Earliest slots ship fast for early portfolio momentum.
  - **Position relative to training journey locked: mini-projects come BEFORE training journey, not concurrent.** Rationale: each mini-project surfaces fresh gaps + quirks that become high-quality exercise / quiz material for the training journey. Doing mini-projects first means the journey has 8 codebases to draw from (3 main + 5 mini), not 3.
  - **Training journey scope expanded.** Now consolidates lessons from BOTH the 3 main projects AND the 5 mini-projects — explicit reference-codebase set of 8.
  - **Candidate BI-tool mapping captured (3 Power BI + 2 Tableau).** Provisional per-slot mapping recorded in the Mini-projects section; final assignment per slot revisited when each begins.
- 2026-05-23 (continued) — **Phase 0 orchestration locked: AWS Step Functions.** Driver: serverless, $0 idle, pay-per-state-transition fractions of a cent (preserves demo-durability principle 4); native AWS orchestration paradigm (state machine vs Airflow's DAG model) adds a different orchestration tool to the CV than Project #2's Airflow — good portfolio diversification rather than a duplicate. MWAA rejected (~$0.49/hr minimum violates $0-idle posture); self-hosted Airflow on EC2 rejected (adds OS-level maintenance overhead for portfolio scope).
- 2026-05-23 (continued) — **Phase 0 Decision 6 locked: 4 dashboard themes.** P&L trend + decomposition, Peer / sector benchmarking, Financial health + ratios, Growth + forecasting. Risk + anomaly (10-K/A restatements) dropped — highest cost / lowest value of the five candidates (requires identifying amended filings + comparing against originals; niche audience). 4 themed PBI pages + 1 executive overview page = 5 total .pbix pages, mirroring Project #2's page count. Forecasting compute approach for the 4th theme: simplest pragmatic on AWS is local Python forecasting (Prophet or statsmodels) producing a Parquet file that dbt picks up as a source — avoids the complexity of SageMaker / Amazon Forecast for a portfolio project. Phase 4 implementation detail, flagged here for the PROJECT_PLAN.md authoring.
- 2026-05-23 (continued) — **Phase 0 Decision 5 locked: curated company universe = S&P 100, current (mid-2026) constituent roster.** Driver: widest demo flexibility (peer / sector benchmarking + cross-sector contrasts + recognisable names like Apple, Microsoft, JP Morgan), universal interviewer recognition, ~800K Bronze rows comfortably under the 2M budget. Sector slice considered and rejected — would force every dashboard into one story shape and tie portfolio to a single audience type. Pragmatic constraints accepted: (1) use CURRENT roster, not point-in-time historical membership — companies added recently (e.g. Tesla in 2020) will have fewer years in our window, which is the realistic constraint production teams accept; (2) ticker → CIK mapping via the free sec.gov/files/company_tickers.json lookup file consumed at extract time.
- 2026-05-23 (continued) — **Phase 0 Decision 4 locked: Power BI publishing approach = continuous publish during build + freeze at v1.0 ship.** Same pattern as Project #2 (Phase 5 sessions 5.1 through 5.9). Most professional default — real BI teams iterate the .pbix against actual data, don't build-once-and-freeze. The freeze at v1.0 is the demo-durability discipline (per principle #3 — Import mode, self-contained .pbix as immortal demo artifact). **Carry-forward from Project #2 baked into the Project #3 mart design discipline:** Gold marts must be designed with Power BI consumption shape in mind from day 1 (relationships to required dims present, no premature aggregation that prevents slicing). At the dbt session that first creates each Gold mart, run a minimum-viable .pbix smoke test — drag 1-2 fields into 1-2 visuals, confirm correct slicing across the dims that will be needed. This 10-minute discipline would have caught the Project #2 mart-shape issue (mart-sourced measures showing the same value for every category when sliced by item/store dims, surfaced at session 5.2 mid-session reset) before it became expensive to fix. Carry into PROJECT_PLAN.md when authored.
- 2026-05-23 (continued) — **Phase 0 Decision 3 locked: transformation tool = dbt-athena for Project #3.** Driver: dbt-athena reuses Project #2 dbt muscle directly, Data Vault 2.0 modeling is naturally SQL-shaped (hubs/links/satellites express cleanly as SELECT statements), most professional default for AWS-native dbt, adds the dbt-athena adapter as a CV line separate from Project #2's dbt-snowflake. Earlier "hybrid" framing (use Glue ETL Spark specifically for XBRL normalisation) walked back — XBRL canonical-concept normalisation is a join against a mapping table, not Spark-shaped work. Glue ETL Spark + PySpark exposure deferred to mini-project slot 5 (streaming), where Spark genuinely earns its keep in real-time stream processing. Slot 5 baseline shape updated to AWS Kinesis → Glue ETL Spark Structured Streaming → S3 → Athena → Tableau real-time tile.
- 2026-05-23 (continued) — **Phase 0 Decisions 1 and 2 locked.** Decision 1 (history depth) = 10 years of SEC EDGAR filings — best balance of demo richness vs Bronze budget (~800K rows, ~5% of free-tier S3 cap), comfortably past XBRL adoption mandate boundary. Decision 2 (operational layer) = direct-to-S3, NO RDS Postgres intermediary. Walked back the initial RDS-Postgres leaning after weighing demo-durability principle #4 ($0 idle forever) against the RDS Free Tier 12-month expiry; the architectural justification for RDS was symmetry with Project #2, not technical need. Phil's prior Postgres experience from NEC Australia means the RDS keyword wasn't filling a real CV gap. Most-professional default wins: SEC EDGAR is API-sourced; lakehouse Bronze IS designed to be the raw zone for API-sourced data — a senior AWS-native DE wouldn't add an intermediate relational store.
- 2026-05-23 (continued) — **Debugging fluency locked as the priority emphasis area in the training journey.** Driver: live-coding debug exercises are the single most common interview pattern that catches AI-assisted portfolio builders off-guard — interviewers hand the candidate a broken script and watch the diagnostic. AI-assisted portfolio work compresses the natural break-and-fix reps Phil would otherwise get from organic build cycles, so debugging needs explicit deliberate practice. Three places this lands: (1) Training journey section now has a "Priority emphasis area — debugging fluency" subsection enumerating specific targets (tracebacks, debuggers, log triage, root-cause vs symptom, common dbt/Python/Airflow failure modes); (2) Quiz warm-up design now mandates ≥1 debug-pattern question every session as a standing topic category; (3) Standing in-session debug discipline added to TEACHING_PREFERENCES.md (Phil drives the diagnosis, not just accepts the fix; non-trivial bugs banked in LEARNINGS.md under Project #2's "Mistakes & diagnoses" pattern). Debug-clinic-style sessions earmarked: Claude breaks something in one of Phil's existing project files, Phil drives diagnosis-and-fix.
- 2026-05-23 (continued) — **AI-assistance disclosure convention locked across all 8 portfolio repos.** Driver: AI-assisted coding is the 2026 default (76% of developers per Stack Overflow 2024 survey, reaffirmed in 2025) and honest disclosure is the most professional signal — demonstrates modern tooling fluency + ownership of design decisions + pre-empts awkward interview moments. Convention: every public-facing GitHub README (3 main + 5 mini) includes a short "How this project was built" section with the standing template (paste-able template lives in TEACHING_PREFERENCES.md under "Anything else Claude should know"). Disclosure does NOT appear in CV / cover letter — different convention. Interview posture if asked: confident ownership ("I can walk through any line and explain why it's there"). Consolidation work to defend that promise lives in the 6-8 week training journey AFTER the mini-projects ship. When PROJECT_PLAN.md / PROJECT_CONTEXT.md are authored at Phase 0 they will include explicit reference to this convention; when each project's README is authored, the disclosure block goes in alongside the architecture diagram and demo runbook.

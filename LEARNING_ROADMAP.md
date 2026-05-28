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
| Project #3 — `financial-analytics-lakehouse-project` (AWS-native lakehouse + Data Vault 2.0, SEC EDGAR corporate finance) | 🚧 In progress — Phase 1 closed, Phase 2 session 3 closed 2026-05-28; ~50% through Phase 2 (Silver), 15-20 sessions estimated to v1.0 | See "Project #3 — locked stack" section below |
| **Mini-projects block — 5 BA/DA-to-next-level credibility stretches** | 📋 Lineup re-aligned 2026-05-28 to verified AU market demand (Precision Sourcing Feb 2026 report + SEEK Melbourne sample). Dropped Databricks + Streaming; added T-SQL + Microsoft stack and dbt patterns deep-dive | Sits AFTER Project #3, BEFORE the training journey. Target: 4-5 days each at full-time pace. See "Mini-projects" section below |
| **Post-mini-projects — 6-8 week BI-to-next-step training journey** | 📋 Scope refreshed 2026-05-28 — dbt-heavy weighting, basic-to-intermediate Python (was "Python for DE foundations" — recalibrated to BI-to-next-step relevance), 8-codebase consolidation, AI-tools-fluency check baked in | Runs AFTER the mini-projects block, not concurrently. See below |
| Subsequent projects | 🤔 TBD | Depends on job search outcome and direction. Likely first paid role; in-role Python progression toward DE over 1-2 years |

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

## Mini-projects block — BA/DA-to-next-level credibility stretches

Earmarked 2026-05-23. **Lineup re-aligned 2026-05-28** after a deep dive into the actual Australian (Melbourne-specific) data job market — see Notes/changes entries for that date for the full research synthesis. The 2026-05-23 framing was "DE-keyword gap fillers" assuming a target jump straight to mid-level DE. The 2026-05-28 reframe is honest: Phil is moving from BI Analyst to BI Developer / Senior DA with pipeline / BI Engineer / Senior Reporting Analyst (Data Engineer remains the longer-term stretch, not the immediate target). The mini-projects are now sized as legitimate, defensible stretch projects that take Phil from BA/DA toward "the next level" — each one a real new concept or skill, deliberately not overwhelming, defensible under interview pressure.

**Slot count: 5 mini-projects** (count preserved from 2026-05-23 lock; composition revised). BI tool split target: at least 1-2 Tableau + ~3 Power BI across the slots.

**Sequencing principle.** Order remains less complex / more employer-friendly first → more complex later. Lowest-conceptual-lift, highest-keyword-density work first so Phil ships fast and gets early portfolio momentum.

**Timing target (added 2026-05-28).** 4-5 days per mini-project at full-time pace (~6 hours/day). Five projects ≈ 4-5 weeks calendar. Real consolidation of skills lives in the 6-8 week training journey AFTER this block, not within individual mini-projects. Each mini-project ships an artefact + a README + a screen recording; depth lives elsewhere.

**Position relative to training journey (locked 2026-05-23, preserved).** Mini-projects come AFTER Project #3 and BEFORE the 6-8 week training journey, NOT concurrent. Doing mini-projects first gives the training journey 8 codebases to draw exercises from (3 main + 5 mini).

**Final slot order (simpler → more complex, locked 2026-05-28):**

1. **dbt Cloud + production CI/CD mini-project.** Port a dbt project (likely Project #2's or Project #3's) into dbt Cloud's free tier, set up scheduled jobs, slim CI, deferral. Lowest new-concept lift — Phil already knows dbt; this adds operational polish. "production-grade dbt" + "CI/CD" hits every Senior DA / BI Developer / BI Engineer posting. Tier 2 skill verified in Precision Sourcing 2026 market report. Ships fastest of the five.
   - **Skills built / CV-credible artefacts:** dbt Cloud orchestration, GitHub Actions YAML, dbt project YAML configuration, .env / dbt Cloud environment-variable management, git workflow (branching + PRs for CI), CI/CD concepts. Deliverable: live dbt Cloud project + GitHub Actions workflow YAML files + README walkthrough of the CI pipeline.

2. **T-SQL + Microsoft stack mini-project (NEW, added 2026-05-28).** T-SQL deep dive (stored procedures, functions, MERGE statement, DECLARE variables, TRY/CATCH) + a small SSIS or Azure Data Factory pipeline reading from one source landing in Azure SQL Database (Phil's Project #2 Azure SQL muscle is the foundation). Hits BI Developer postings directly (T-SQL appears in most AU BI Developer postings, more than the equivalent US market), plus many Senior DA postings in Microsoft-stack enterprises (government, financial services, insurance). Tableau OR Power BI on top for the visualization layer — likely Power BI to keep MS-stack consistency.
   - **Skills built / CV-credible artefacts:** T-SQL deep (procedures, MERGE, DECLARE, TRY/CATCH), Azure SQL Database operational layer, ADF pipeline JSON or SSIS package design, .env-driven Azure credentials, Power BI on top of T-SQL source, git versioning of SQL/ADF/SSIS artefacts. Deliverable: T-SQL stored-procedure library + ADF pipeline JSON or SSIS .dtsx + Power BI .pbix + README walkthrough.

3. **Microsoft Fabric end-to-end mini-project.** Spin up a Microsoft 365 Developer tenant (free) + Fabric 60-day trial. Build a small end-to-end inside Fabric: public-API ingest → Fabric notebook transformation (Spark) → Fabric Warehouse mart → Power BI report. Optionally use a OneLake "shortcut" to read Project #3's S3 data for a multi-cloud lakehouse story. Pausable F2 capacity post-trial keeps idle cost ~$0. Fabric is a rising keyword in AU postings — Precision Sourcing 2026 confirms growing adoption. Power BI is one of Fabric's seven workloads so this slot naturally pairs with the Power BI BI-tool count.
   - **Skills built / CV-credible artefacts:** Microsoft Fabric workspace + Lakehouse + Warehouse + Power BI all-in-one, OneLake shortcut concept, Fabric notebook (PySpark light), Fabric pipeline / Dataflows Gen2, basic Python (in the Fabric notebook), YAML in any Fabric pipeline configuration, git integration with Fabric workspaces, Power BI semantic model on Fabric. Deliverable: live Fabric workspace + .pbix + README + screen recording of the end-to-end run.

4. **dbt patterns deep-dive mini-project (NEW, added 2026-05-28).** Doubles down on Tier 1 dbt depth — the highest-leverage skill for every target role. Pick one of: advanced macros (custom generic tests, dbt-utils macro composition, custom materializations), or testing depth (dbt-expectations, custom singular tests, data contracts), or performance optimization (incremental strategy tuning, partition pruning, query cost analysis). Build against Project #2 or Project #3 codebase to amplify existing work. Tableau OR Power BI optional for visualization; the deliverable IS the dbt project polish itself, not the dashboard. This is the most direct interview-defensibility play — dbt depth is what senior interviewers probe.
   - **Skills built / CV-credible artefacts:** advanced dbt macros + Jinja, dbt-utils + dbt-expectations packages.yml composition, custom generic + singular tests, dbt schema YAML (_models.yml, _sources.yml, _seeds.yml) depth, dbt_project.yml configuration depth, materialization strategy decision-making, .env-driven dbt invocation, git tagging for dbt release management, basic Python (in any custom-test logic). Deliverable: a forked / extended dbt project with the new macros + tests + YAML contracts + README walkthrough.

5. **Iceberg vs Delta Lake comparison mini-project.** Write the same table in both open formats on S3, compare query performance / time-travel / schema evolution / partition handling. Reinforces architectural credibility. Apache Iceberg has serious enterprise momentum in 2026 and you'll already have Iceberg muscle from Project #3 — this slot consolidates and adds Delta exposure. More technical / narrower than slots 1-4; smaller "wow" demo but strong portfolio polish piece. Tableau likely for the comparison visuals — publication-quality side-by-side charts suit Tableau's design strengths.
   - **Skills built / CV-credible artefacts:** Iceberg vs Delta table format trade-offs, S3 + Glue Catalog table registration for both formats, dbt-athena (Iceberg) AND dbt-spark (Delta) adapter exposure, time-travel + schema-evolution patterns, YAML for table configuration, .env-driven multi-credential setup, Tableau publication-quality comparison visuals, git-tagged comparison report. Deliverable: comparison report (Markdown + Tableau .twbx) + dbt projects for both formats + README on when-to-use-which.

**DROPPED from the original 2026-05-23 lineup (justification per the 2026-05-28 market research):**

- **Databricks slot dropped.** Original rationale was filling the Databricks brand-keyword gap created by the AWS pivot. Precision Sourcing 2026 confirms Databricks dominance in AU data engineering broadly, BUT for Phil's actual target roles (Senior DA / BI Developer / BI Engineer / Senior Reporting Analyst), Databricks is less critical than T-SQL + Microsoft stack. Project #2's Snowflake muscle covers the cloud DW pattern exposure; Project #3's AWS lakehouse covers the open-format-on-object-storage pattern. Adding Databricks specifically would be Tier 2 keyword padding rather than a credibility-building stretch. If a Data Engineer / Analytics Engineer role becomes a stretch target later, Databricks can be added in-role or as a follow-up mini-project.
- **Streaming slot dropped.** Original rationale was filling the zero-streaming gap for mid-level DE postings. Market research confirms streaming does NOT appear in Phil's top-4 target role postings (Senior DA / BI Developer / BI Engineer / Senior Reporting Analyst) — only some Analytics Engineer / Data Engineer roles reference Kafka / Kinesis. Highest learning lift of all the original slots; lowest matching demand for actual targets. Replaced.

**Candidate BI-tool mapping (3 Power BI + 2 Tableau target preserved) — provisional, finalised per slot when the block begins:**

- Slot 1 (dbt Cloud + CI/CD) — Power BI (small dashboard) OR skip BI entirely
- Slot 2 (T-SQL + MS stack) — Power BI (MS-stack consistency)
- Slot 3 (Fabric end-to-end) — Power BI (Fabric's native BI workload IS Power BI)
- Slot 4 (dbt patterns deep-dive) — Tableau (the dbt artifacts ARE the deliverable; visualization is supporting evidence)
- Slot 5 (Iceberg vs Delta) — Tableau (publication-quality comparison charts)

**Repo strategy (unchanged).** Each mini-project gets its own small public GitHub repo (separate from Project #3) with its own README, demo runbook, .pbix/.twbx file, and screen recording — same demo-durability principles as the main projects. Each README includes the standing AI-assistance disclosure block per TEACHING_PREFERENCES.md — same convention across all 8 portfolio repos (3 main + 5 mini). Cross-link from the main project READMEs.

**Open decisions to lock when the mini-project block begins:**

- Final BI-tool assignment per slot (candidate mapping above; revisit before each slot starts).
- Slot 2 ETL specific (SSIS vs Azure Data Factory — likely ADF for the modern-stack alignment).
- Slot 4 dbt depth focus (advanced macros vs testing depth vs performance optimization — pick one for focus).
- Whether to publish a meta-README that indexes all 5 mini-projects + the 3 main projects as a single portfolio entry point.

---

## Post-mini-projects — 6-8 week BI-to-next-step training journey

Design originally locked 2026-05-19; **scope refreshed 2026-05-28** to align with verified Australian market demand and Phil's honest target reframe (BI Analyst → BI Developer / Senior DA / BI Engineer / Senior Reporting Analyst, NOT a leap to mid-level DE). The original "Python for DE foundations" weeks have been recalibrated — Python beyond basics is deferred to in-role learning post-first-job per the verified path most BAs/DAs take in the AU market.

**Trigger.** Starts AFTER the 5 mini-projects ship. Runs while actively looking for work.

**Why.** Phil's 3 main projects + 5 mini-projects build breadth across the modern data stack with AI assistance, but the credibility-gap reality check (named honestly 2026-05-28) is that watch-Claude-type-it-up doesn't build retention. The training journey is where Phil drives the keyboard, with Claude as the senior-DE pair-reviewer, and the skills consolidate from "I saw this built" to "I can rebuild this from scratch and defend every line in an interview." Sequencing the journey AFTER the mini-projects gives 8 codebases to draw exercises from (3 main + 5 mini).

**Goal.** Interview credibility + first-day confidence for BI Developer / Senior DA with pipeline / BI Engineer / Senior Reporting Analyst roles in Melbourne, Australia. NOT full DE mastery — Phil is not aiming to be senior-DE fluent in 6-8 weeks. The honest target is: SQL + dbt + Power BI + cloud DW + git + AI-tools-fluency at a level Phil can defend across any line of his portfolio in a senior interview.

**Duration flexibility (locked 2026-05-28).** The "6-8 week" framing is a TARGET, not a hard duration. The training journey is concurrent with active job hunting and adapts to that reality:

- **If Phil lands a paid role partway through the journey: STOP the journey at that point.** Real-job in-role consolidation beats out-of-role training every time — the next phase of skill building moves into the job. The training journey's job was to make Phil interview-credible enough to land the role; once that's done, the role itself becomes the training environment.
- **If the journey needs to run 10-12+ weeks because the job hunt is taking longer: extend it.** Better-prepared candidates with stronger interview narratives + deeper portfolio defense win in tight markets like AU 2026. Time spent here directly compounds into stronger interview performance.
- **If a specific skill gap surfaces during interviews (e.g. "they kept asking about MERGE statements and I fumbled it"): bring that into the next training-journey session as a targeted patch.** The journey adapts to actual interview feedback, not just the pre-locked syllabus.

Sessions tracked in the training-journey-project's own session log; the log itself becomes evidence of continuous learning Phil can reference in interview ("here's how I've been consolidating since shipping the portfolio").

**Priority emphasis areas (refreshed 2026-05-28 per AU market research):**

1. **dbt depth — Tier 1 across all target roles.** Materialization strategy (view vs table vs incremental vs ephemeral), test design (generic vs singular, dbt-expectations, custom data contracts), modeling layering (staging vs intermediate vs warehouse vs marts), Jinja macro composition. This is what senior interviewers probe; this is what the analytics-engineering workflow is.
2. **SQL + T-SQL depth — Tier 1 across all target roles.** Window functions, complex CTEs, dialect translation, partitioning strategies, T-SQL specifics (DECLARE @, MERGE, stored procedures, TRY/CATCH). Refactor existing dbt models for performance.
3. **Power BI / DAX depth — Tier 1 for BI Developer / BI Engineer / Senior Reporting Analyst.** DAX patterns, semantic-layer modeling, performance tuning, Tabular Editor / DAX Studio for production polish.
4. **Debugging fluency.** Live-coding debug exercises are the single most common interview pattern catching AI-assisted portfolio builders off-guard. Drive diagnosis on broken-script exercises. Read tracebacks. Use VS Code debugger fluently. Standing in-session debug discipline lives in TEACHING_PREFERENCES.md.
5. **AI-tools fluency.** 70% of data analysts now use AI tools in their daily work (Precision Sourcing 2026 / industry research). Using AI WELL is table-stakes, not a differentiator. The training journey reinforces honest AI-assisted workflow: pair-programming with AI, prompt discipline, when to verify against authoritative docs vs trust the tool.

**Format.**

- 2-hour sessions × 3-4 sessions/week × 6-8 weeks = ~36-64 hours total
- **Phil drives the keyboard.** Claude scaffolds, reviews, and explains; Phil types and debugs. Inverse of the Project #1-3 watch-Claude pattern. This is the credibility-building consolidation that the in-session driving could not fully deliver under time pressure.
- Code-first: code walkthrough (5 min) → Phil modifies and extends (40 min) → review and explain (15 min). With concepts woven in.
- Split: ~70% code (Phil typing), ~15% concept / general knowledge, ~15% interview prep (mock probes, behavioral framing, portfolio narration practice).
- Quiz warm-up first 10-15 min of every session (see quiz design below).
- Hands-on with Phil's own Project #1 / #2 / #3 code AND the 5 mini-project codebases wherever they fit — all 8 projects are the reference codebase.
- Sessions tracked in a session log; quiz progress persisted to a quiz-log file.

**Code focus (the ~70%, refreshed 2026-05-28).**

- **dbt (heaviest weighting).** Macros, materialization strategy, custom tests, Jinja deep dive, sources / snapshots / exposures, dbt-utils + dbt-expectations, performance optimization, model-layer best practices.
- **SQL + T-SQL.** Advanced (window functions, complex CTEs), dialect translation (Snowflake vs T-SQL vs Athena/Trino), EXPLAIN plans, partitioning + clustering, T-SQL stored procedures + MERGE + DECLARE patterns.
- **Power BI + DAX.** DAX patterns (calculated columns vs measures, CALCULATE, time intelligence, semantic-layer modeling), Tabular Editor for production polish, DAX Studio for performance triage.
- **Python — basic to intermediate only.** pathlib, requests, basic pandas, simple scripts, venv + dependency management, structured logging. Reading tracebacks. NOT going to deep Python (decorators-as-design-patterns, async, pytest-as-architecture) — that's deferred to in-role learning per Phil's locked plan.
- **YAML + config.** dbt schema files, dbt_project.yml, profiles.yml, GitHub Actions workflows. The schema-recognition mental map.
- **Git workflow.** Day-to-day commands (add, commit, push, pull, status, log, diff, checkout, branch); branching + rebase; conflict resolution; recovery from common mistakes. Reps come from the training journey's own session log being a git repo.

**General-knowledge focus (the ~15%).**

- Architecture patterns — medallion, Kimball star, Data Vault 2.0; when to use which.
- File formats — Parquet, Delta, Iceberg; what each is optimized for.
- AI-tools-fluency — using AI for code review, debugging, doc-search; verify-then-write discipline; when to escalate to authoritative docs.
- PowerShell + Linux command-line basics for daily use.
- Light Docker (just-enough-to-read-and-modify-a-Dockerfile; not for-DE-deep).

**Interview-prep focus (the ~15%, NEW 2026-05-28).**

- Project narration practice — walking through each of the 8 portfolio repos in 90 seconds (the "tell me about a project you're proud of" answer).
- Walk-through-the-code practice — for each main project, being able to explain any line under interview pressure ("why did you choose this materialization here?" / "what would you change about this model?" / "what would break if I removed this WHERE clause?").
- System-design lite — being asked "design a pipeline from API X to dashboard Y" and sketching the medallion / staging / warehouse / mart shape.
- Behavioral framing — STAR-method answers for "tell me about a time you debugged a tricky bug" using the LEARNINGS.md diagnosis loops as raw material.
- Salary expectation framing — using the Robert Half / Hays salary guides verified for the target roles in Melbourne.

**Suggested 8-week outline (refreshed 2026-05-28, compressible to 6 by merging weeks 5+6 and 7+8).**

- **Week 1 — SQL + T-SQL deep dive.** Window functions, complex CTEs, dialect translation, T-SQL stored procedures + MERGE + DECLARE. Phil refactors 3-5 existing dbt model SQL statements for performance and dialect-specific patterns. Quiz warm-ups focused on dialect differences.
- **Week 2 — dbt patterns (part 1).** Materialization strategy, test design, layering philosophy. Phil extends Project #3 with one new custom singular test + one materialization tuning. Quiz warm-ups focused on dbt failure modes.
- **Week 3 — dbt patterns (part 2).** Jinja macros, dbt-utils + dbt-expectations, custom generic tests, performance optimization. Phil writes one new dbt macro from scratch against an existing project. Quiz warm-ups debug-pattern questions on dbt.
- **Week 4 — Power BI + DAX depth.** DAX patterns, semantic-layer modeling, performance tuning. Phil extends Project #2 or #3 .pbix with 2-3 new advanced measures and one performance-tuned page. Quiz warm-ups focused on DAX evaluation context.
- **Week 5 — Python basics + scripting.** pathlib, requests, basic pandas, venv + deps, structured logging, reading tracebacks. Phil writes one small Python utility from scratch against the project's existing patterns. Quiz warm-ups focused on Python traceback reading.
- **Week 6 — Modeling + architecture patterns.** Kimball walkthrough of Project #2 + Data Vault 2.0 reinforcement of Project #3 + medallion review. System-design lite practice. Quiz warm-ups focused on when-to-use-which patterns.
- **Week 7 — Git + CI/CD + YAML / env / config fluency + AI-tools.** Git deep dive (branching, rebase, conflict resolution, recovery from common mistakes). GitHub Actions YAML for dbt CI + ruff lint + sqlfluff. Pre-commit hooks. **YAML fluency across the stack**: dbt schema YAMLs (_models.yml, _sources.yml, _seeds.yml), dbt_project.yml structure, profiles.yml, GitHub Actions workflow YAML, Docker Compose — the schema-recognition mental map across all the YAML you encounter daily. **Env file + secrets management fluency**: .env file conventions, python-dotenv wrapper pattern (project-standard from Project #3 Phase 2 session 1), .env.example as a committed template, .gitignore patterns for secrets, dbt Cloud environment variables, GitHub Actions secrets, AWS credential chain layering. **AI-tools fluency** consolidation: prompt discipline, verify-then-write pattern for stakes-sensitive tooling, when to escalate to authoritative docs. Quiz warm-ups focused on Git recovery scenarios + YAML schema gotchas.
- **Week 8 — Interview prep intensive.** Mock interviews per target role (Senior DA / BI Developer / BI Engineer). Project-narration practice for all 8 repos. System-design lite drill. Behavioral STAR practice from LEARNINGS.md material. Salary expectation framing.

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

**Refreshed 2026-05-28** after Phil's honest credibility-gap reframe + deep dive into the Australian (Melbourne-specific) data job market. Geographic context: Phil is in Melbourne, Australia — NOT US. "Analytics Engineer" is a US-coined title that hasn't transferred cleanly to Australian postings; equivalent roles use different titles here.

**Realistic Australian (Melbourne) targets — primary, in volume order:**

1. **Senior Data Analyst with pipeline / dbt responsibilities.** Highest-volume target in Melbourne (~500+ active SEEK postings as of May 2026). Skill ask: deep SQL, dbt, Power BI / DAX, data modeling, one cloud DW (Snowflake or Databricks most common), stakeholder skills. Direct match for Phil's portfolio (Project #2 Snowflake + dbt + PBI + Kimball star, Project #3 dbt + DV2.0 + AWS lakehouse + PBI).
2. **BI Developer.** High volume. Microsoft-stack-heavy. Skill ask: Power BI deep, DAX, Power Query, T-SQL, SSIS or ADF / ETL, semantic-layer modeling. Often 2+ years PBI required (Project #2's 5-page PBI dashboard + Project #3's PBI ahead provides this).
3. **BI Engineer.** Mid-volume. More technical than BI Developer — adds pipeline architecture + sometimes PySpark / specialty stacks. Project #3 lakehouse work is a strong differentiator versus pure-PBI candidates.
4. **Senior Reporting Analyst / Insights Analyst.** Mid-volume. SQL + Power BI or Tableau + business storytelling + lighter data modeling. Phil's BI deliverables + corporate-finance domain (Project #3) are direct fits.

**Stretch target:**

5. **Analytics Engineer.** Lower volume in Australia but real — premium employers (Linktree, ANZ Plus, financial services). dbt + SQL + cloud DW + git + CI/CD + modeling. The stretch end of Phil's realistic range; fewer postings but strong cultural fit for the dbt-heavy direction.

**Longer-term direction (not first-role target):**

- **Data Engineer (mid-level).** Achievable after 1-2 years in the next paid role, building Python depth + production-engineering reps in a real team setting. The verified AU progression path from BI Analyst is BI Developer / Senior DA → DE over 1-2+ years in-role, not a direct leap.

**Market realities to internalize (per Precision Sourcing 2026 + Robert Half / Hays salary guides 2026):**

- The AU data job market in 2026 is "highly selective, ROI-focused." Hundreds of applicants per posting. Hiring teams are choosy. Demonstrated platform expertise + real delivery outcomes + clean CV narratives matter more than tool lists.
- Roles limited to dashboard creation are becoming exposed. Adding pipeline + modeling skills (which Phil IS doing) is the correct strategic pivot.
- Junior entry to data engineering specifically is extremely hard right now — post-GFC-like conditions per recruiter commentary. Senior DA / BI Developer / BI Engineer are the realistic entry points, NOT DE directly.
- Senior Data Analyst typical salary in AU: ~$120K-$130K (Hays / Robert Half 2026 guides).
- 70% of analysts use AI tools daily — table stakes, not a differentiator. The AI-assistance disclosure on README is the honest professional default.

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
- 2026-05-28 — **Major reset: mini-projects lineup re-aligned to AU market + training journey refreshed + career target context honestly reframed.** End-of-Phase-2-session-3 conversation. Phil opened by naming the credibility-gap honestly: starting from BA/DA experience, the watch-Claude-type-it-up pattern hasn't built retention, and claiming DE-level credibility on the strength of three AI-assisted projects could backfire in interviews. Drove a deep-dive research pass into actual Australian (Melbourne-specific) data job market — Precision Sourcing 2026 webinar report, Robert Half / Hays salary guides, modern-data-stack 2026 trend pieces, SEEK + LinkedIn AU sample. Findings synthesized in chat (full sources in the session 3 conversation log). Three sets of changes landed in the roadmap:
  - **Mini-projects re-aligned**: DROPPED Databricks slot (Tier 2 in AU broadly but not in Phil's top-4 target roles; Project #2 Snowflake muscle covers cloud DW pattern) and Streaming slot (doesn't appear in target role postings). ADDED T-SQL + Microsoft stack mini-project (T-SQL deep dive + SSIS or ADF — hits BI Developer + many Senior DA postings directly) and dbt patterns deep-dive (advanced macros, custom tests, materialization strategies — doubles down on Tier 1 dbt depth). Final 5-slot lineup: dbt Cloud + CI/CD, T-SQL + MS stack, Fabric end-to-end, dbt patterns deep-dive, Iceberg vs Delta. Timing target locked at 4-5 days per mini-project at Phil's full-time pace (~6 hours/day; he's not currently working) — five projects ≈ 4-5 weeks calendar.
  - **Training journey refreshed**: Original "Python for DE foundations" weeks 1-2 recalibrated to basic-to-intermediate Python only (week 5 now). Heavy dbt weighting (weeks 2-3). T-SQL added explicitly to week 1. Power BI + DAX depth as week 4. Interview prep intensive added as week 8 (project narration, walk-through-the-code practice, system-design lite, behavioral STAR framing from LEARNINGS material, salary expectation framing per AU guides). AI-tools-fluency baked in across the journey since 70% of analysts now use AI tools daily — table stakes. Phil-drives-the-keyboard pattern locked: training journey inverts the watch-Claude-type-it-up pattern from Projects #1-3, with Claude as senior-DE pair-reviewer and Phil typing + debugging.
  - **Career target context honestly reframed**: Dropped Analytics Engineer as primary target (US-coined title, low AU volume — the 2026-05-23 framing called it out as a primary, today's research shows it's a stretch). Primary targets are now Senior DA with pipeline / BI Developer / BI Engineer / Senior Reporting Analyst (in Melbourne volume order). Analytics Engineer kept as stretch target. Mid-level DE remains the longer-term direction, achievable after 1-2 years in-role per the verified AU BA/DA-to-DE progression path. Salary expectations grounded in Robert Half / Hays 2026 guides (Senior DA ~$120K-$130K).
- 2026-05-28 (continued) — **Forward-projected risk pass at end of Phase 2 session 3.** Phil challenged the engineering-standards criterion 7 audit after today's debug loops surfaced query-pattern issues the data-shape-only audit didn't catch. Three forward-projected risks surfaced via restricted-domain web-search-verify against authoritative docs: (1) AutomateDV does NOT officially support dbt-Athena (verified directly against automate-dv.readthedocs.io Platform Support page) — Phase 2 warehouse-layer Data Vault 2.0 will be hand-rolled in plain dbt-athena SQL, NOT AutomateDV. Actually a stronger portfolio story (shows pattern understanding, not just library use); (2) Iceberg merge incremental + on_schema_change has a known duplicate-insertion bug (dbt-adapters issue #571) — real risk for SCD-2 satellites where duplicates corrupt audit lineage; mitigation: avoid on_schema_change on satellites, carefully control unique_key composition; (3) AWS Step Functions has NO native dbt integration — Step Functions can invoke Athena natively but to run dbt commands needs Lambda (250 MB layer limit tight), ECS Fargate task, or Glue Python Shell job. Phase 3 design call required at kickoff. ENGINEERING_STANDARDS.md criterion 7 strengthened to include consumption-pattern contracts in addition to data-shape contracts. New standing rule added: phase-kickoff forward-verify pass against authoritative docs before any phase work begins, findings banked in LEARNINGS.md as "Phase N projected risks."
- 2026-05-23 (continued) — **AI-assistance disclosure convention locked across all 8 portfolio repos.** Driver: AI-assisted coding is the 2026 default (76% of developers per Stack Overflow 2024 survey, reaffirmed in 2025) and honest disclosure is the most professional signal — demonstrates modern tooling fluency + ownership of design decisions + pre-empts awkward interview moments. Convention: every public-facing GitHub README (3 main + 5 mini) includes a short "How this project was built" section with the standing template (paste-able template lives in TEACHING_PREFERENCES.md under "Anything else Claude should know"). Disclosure does NOT appear in CV / cover letter — different convention. Interview posture if asked: confident ownership ("I can walk through any line and explain why it's there"). Consolidation work to defend that promise lives in the 6-8 week training journey AFTER the mini-projects ship. When PROJECT_PLAN.md / PROJECT_CONTEXT.md are authored at Phase 0 they will include explicit reference to this convention; when each project's README is authored, the disclosure block goes in alongside the architecture diagram and demo runbook.

# financial-analytics-lakehouse-project

> AWS-native data lakehouse — SEC EDGAR financial data → Data Vault 2.0
> medallion (S3 + Glue + Athena) → 5-page Power BI executive overview.
> Project #3 of Phil's data engineering portfolio.

**Status:** Phase 3 session 12 shipped (2026-05-29) — first end-to-end
orchestrated dbt-on-Glue-Python-Shell via AWS Step Functions LIVE.
State machine `financial-analytics-orchestrator`: Glue StartJobRun.sync
(dbt host) → Athena StartQueryExecution.sync (raw SQL verify). First
orchestrated run Succeeded in 4m 59s; inside the Glue task dbt build
PASS=157 / ERROR=0 / SKIP=0 / TOTAL=157 (9 incremental + 1 seed + 5 table
+ 2 view models + 140 data tests). Phase 2 Silver Data Vault 2.0
(3 hubs + 2 links + 4 sats incl. 1 multi-active + 1 dim + 1 PIT + 1 Bridge,
121/121 dbt schema + 114/114 SQL structural verify) preserved underneath.
Phase 3 session 13 (verify-side fan-out from 1 Athena task to 10 via a
Parallel state) next.

---

## What this project is

The third project in a portfolio sequence demonstrating end-to-end data
engineering work. Project #3 ingests US public-company corporate-finance
data from the SEC EDGAR API, models it as Data Vault 2.0 inside a Bronze
/ Silver / Gold medallion architecture on AWS-native infrastructure, and
surfaces it through a polished 5-page Power BI report.

Full architecture, decision history, and phase-by-phase delivery plan in
`PROJECT_PLAN.md`. Running session state in `PROJECT_CONTEXT.md`.

## Stack

| Layer | Choice |
|---|---|
| Cloud | AWS (us-east-1) |
| Object storage | Amazon S3, prefix-partitioned by zone + extract date |
| Metastore | AWS Glue Data Catalog |
| Query engine | Amazon Athena |
| Transformation | dbt-athena |
| Orchestration | AWS Step Functions |
| Modeling | Data Vault 2.0 inside Bronze / Silver / Gold medallion |
| BI | Power BI Desktop, Import mode .pbix |

## How this project was built

This project was built using AI-assisted pair programming (Claude by Anthropic).
All architecture decisions, technology selections, and final design choices are
my own; the AI accelerated implementation and acted as a senior-DE code reviewer.
The intent of the project is portfolio learning — every component was built with
explicit understanding of what it does and why. Walkthrough docs are in the
`*_PIPELINE.md` files at repo root; decision records and "diagnosis → fix → lesson"
loops are captured in `LEARNINGS.md`.

## Project documents

- `PROJECT_PLAN.md` — locked stack, locked decisions, phase delivery plan
- `PROJECT_CONTEXT.md` — running session state, session log
- `EXTRACT_PIPELINE.md` — Phase 1 extract pipeline walkthrough (stub)
- `LEARNING_ROADMAP.md` — broader pathway context
- `ENGINEERING_STANDARDS.md` — 10-criteria per-script audit
- `LEARNINGS.md` — diagnosis → fix → lesson loops
- `GLOSSARY.md` — term definitions
- `TEACHING_PREFERENCES.md` — working conventions (committed for transparency)

# financial-analytics-lakehouse-project

> AWS-native data lakehouse — SEC EDGAR financial data → Data Vault 2.0
> medallion (S3 + Glue + Athena) → 5-page Power BI executive overview.
> Project #3 of Phil's data engineering portfolio.

**Status:** **Phase 4 CLOSED 2026-05-30** at session 5. All 5 Phase 4
sessions SHIPPED. Four Gold marts live in `financial_analytics_silver`
— `mart_pl_trend` (10-year P&L trend per S&P 100, 19,336 rows),
`mart_peer_benchmark` (cross-company peer benchmarking at FY snapshots,
29,936 rows, sector-segmented), `mart_financial_health` (per-company
annual ratios spanning income statement + balance sheet + cash flow,
10,610 rows, 9 canonicals pivoted + 8 NULLIF-guarded derived ratios),
and `mart_growth_forecast` (per-company annual revenue trajectory
unifying 9,775 historical observed values from mart_pl_trend with 294
forward-looking 3-year forecasts produced by `scripts/forecast.py`
running statsmodels.tsa Holt-Winters Exponential Smoothing primary +
ARIMA(1,1,0) drift-walk fallback + 95% prediction intervals). All four
materialized as Iceberg/Parquet; forecast surface written to
`s3://<bucket>/zone=silver/forecasts/` as Snappy Parquet consumed via
dbt sources + external table. **84 dbt schema tests + 66 SQL structural
verify checks + 4 mart-shape PBI Desktop smoke tests all PASS.**
**Session 5 Phase 4 CLOSE landed:** Step Functions Parallel state
extended from 10 to 14 branches fanning out across all `sql/verify/03-16`
queries (10 warehouse + business_vault + 4 marts); end-to-end
orchestrated run (`phase-4-close-orchestrated-smoke-test-01-2026-05-30`)
Succeeded in 8 min 8 sec — Glue dbt build PASS + Athena hub_company
sanity + 14-branch Parallel verify all TaskSucceeded; phase-boundary
structural audit 6/6 (stale `dbt/models/marts/.gitkeep` cleaned up);
14 Phase 4 Risks (38-51) rolled into 4 pattern families (G-J) in
LEARNINGS.md; Phase 5 PBI kickoff forward-verify shipped 3 new Risks
(52-54) BEFORE any Phase 5 work begins. `scripts/deploy_state_machine.py`
shipped as the companion to `scripts/sync_phase3_artifacts_to_s3.py`
for the state machine definition deploy path. **Forecast orchestration
locked Option A** at kickoff direction-check — `scripts/forecast.py`
stays manual (annual cadence, on demand), not wired into the DAG.
10/10 ENGINEERING_STANDARDS audit PASS sessions 1+2+3+4 — TEN-session
unbroken streak (session 5 is phase-boundary, no new code surface).
Phase 3 fully preserved underneath: end-to-end orchestrated
dbt-on-Glue-Python-Shell via AWS Step Functions LIVE, now extending
the verify surface to the Phase 4 marts. Phase 2 Silver Data Vault 2.0
(3 hubs + 2 links + 4 sats + 1 dim + 1 PIT + 1 Bridge, 121/121 +
114/114 verify) preserved. **Next phase: Phase 5 session 1** — Power BI
executive overview page authoring against the 4 Gold marts via the
Amazon Athena ODBC v2 driver + Windows System DSN (Risk 39
pre-prerequisite shipped at session 1).

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

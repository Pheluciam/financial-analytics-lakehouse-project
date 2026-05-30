# financial-analytics-lakehouse-project

> AWS-native data lakehouse — SEC EDGAR financial data → Data Vault 2.0
> medallion (S3 + Glue + Athena) → 5-page Power BI executive overview.
> Project #3 of Phil's data engineering portfolio.

**Status:** Phase 4 sessions 1+2+3+4 SHIPPED 2026-05-30. Four Gold marts
live in `financial_analytics_silver` — `mart_pl_trend` (10-year P&L
trend per S&P 100, 19,336 rows), `mart_peer_benchmark` (cross-company
peer benchmarking at FY snapshots, 29,936 rows, sector-segmented),
`mart_financial_health` (per-company annual ratios spanning income
statement + balance sheet + cash flow, 10,610 rows, 9 canonicals
pivoted + 8 NULLIF-guarded derived ratios), and `mart_growth_forecast`
(per-company annual revenue trajectory unifying 9,775 historical
observed values from mart_pl_trend with 294 forward-looking 3-year
forecasts — 98 companies × 3 forecast years — produced by
`scripts/forecast.py` running statsmodels.tsa Holt-Winters Exponential
Smoothing primary + ARIMA(1,1,0) drift-walk fallback + 95% prediction
intervals). All four materialized as Iceberg/Parquet; forecast surface
written to `s3://<bucket>/zone=silver/forecasts/` as Snappy Parquet
consumed via dbt sources + external table. **84 dbt schema tests + 66
SQL structural verify checks + 4 mart-shape PBI Desktop smoke tests
all PASS.** Session 4 ships scripts/forecast.py (boto3 Athena → pandas
→ statsmodels → pyarrow Parquet to S3) per the Phase 3 session 14
Risk 38 lock (statsmodels over Prophet on annual cadence); forecast
architecture Option A (Parquet to S3 + dbt sources) locked at session 4
kickoff direction-check; triple-pinned forecast schema across the
Python writer + DDL + dbt sources YAML; Risks 50-51 banked (50 =
zone=silver/ S3 prefix + IAM scope forward-projection lesson; 51 =
schema triple-pin coordinated-drift contract). Apple revenue FY2009
~$42B → FY2024 ~$391B + 2026-2028 forecast with 95% CI band renders
analyst-correct in PBI. 10/10 ENGINEERING_STANDARDS audit PASS
sessions 1+2+3+4 — TEN-session unbroken streak. Phase 3 fully
preserved underneath: end-to-end orchestrated dbt-on-Glue-Python-Shell
via AWS Step Functions LIVE. Phase 2 Silver Data Vault 2.0 (3 hubs + 2
links + 4 sats + 1 dim + 1 PIT + 1 Bridge, 121/121 + 114/114 verify)
preserved. Phase 4 session 5 next: Phase 4 CLOSE — structural audit +
reflection rolling Phase 4 Risks 38-51 into pattern families + Phase 5
PBI kickoff forward-verify.

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

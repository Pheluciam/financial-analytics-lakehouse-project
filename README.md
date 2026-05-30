# financial-analytics-lakehouse-project

> AWS-native data lakehouse — SEC EDGAR financial data → Data Vault 2.0
> medallion (S3 + Glue + Athena) → 5-page Power BI executive overview.
> Project #3 of Phil's data engineering portfolio.

**Status:** Phase 4 session 1 SHIPPED 2026-05-30. First Gold mart
`mart_pl_trend` materialized as Iceberg/Parquet in `financial_analytics_silver`
— 10-year annual P&L trend per S&P 100 company over 10 fiscal year-end
as-of-dates, 19,393 rows after ASC 205 comparatives dedup, JOIN topology
bridge → PIT → sat_concept_value → hub_company + sat_company_metadata.
**20 dbt schema tests + 14 SQL structural verify checks + mart-shape PBI
Desktop smoke test all PASS.** Risk 39 Phase 5 pre-prerequisite cleared:
Amazon Athena ODBC v2.0.6.0 (x64) driver + Windows System DSN
"FinancialAnalyticsAthena" + ~/.aws/credentials [phil-dbt] section
populated from .env. Apple revenue line chart renders ~10-14 ascending
fiscal_year points via PBI Desktop → Athena ODBC, validating the
mart-shape architecture end-to-end. 6 new Risks banked (40-45) across
the ODBC install path + comparatives dedup discovery + sat_concept_value
MIN-collapse data-quality artifact. 10/10 ENGINEERING_STANDARDS audit
PASS on mart_pl_trend.sql — SEVEN-session unbroken streak. Phase 3 fully
preserved underneath: end-to-end orchestrated dbt-on-Glue-Python-Shell
via AWS Step Functions LIVE, last orchestrated run Succeeded in 6m 15s,
dbt build PASS=157 / ERROR=0 / SKIP=0 / TOTAL=157, all 10 Parallel verify
branches TaskSucceeded. Phase 2 Silver Data Vault 2.0 (3 hubs + 2 links +
4 sats incl. 1 multi-active + 1 dim + 1 PIT + 1 Bridge, 121/121 dbt schema
+ 114/114 SQL structural verify) preserved. Phase 4 sessions 2-5 next:
mart_peer_benchmark + mart_financial_health + mart_growth_forecast +
Phase 4 CLOSE.

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

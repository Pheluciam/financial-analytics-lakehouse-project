# financial-analytics-lakehouse-project

> AWS-native data lakehouse — SEC EDGAR financial data → Data Vault 2.0
> medallion (S3 + Glue + Athena) → 5-page Power BI executive overview.
> Project #3 of Phil's data engineering portfolio.

**Status:** Phase 4 sessions 1+2+3 SHIPPED 2026-05-30. Three Gold marts
live in `financial_analytics_silver` — `mart_pl_trend` (10-year P&L
trend per S&P 100, 19,336 rows), `mart_peer_benchmark` (cross-company
peer benchmarking at FY snapshots, 29,936 rows, now sector-segmented
via session 3 sp100_company_sector seed cascade — peer aggregates +
RANK + CUME_DIST percentile partition extended to 4-key
(as_of_date, fiscal_year, canonical_concept, gics_sector)), and
`mart_financial_health` (per-company annual ratios spanning income
statement + balance sheet + cash flow, 10,610 rows, 9 canonicals
pivoted onto columns + 8 NULLIF-guarded derived ratios — gross_margin,
operating_margin, net_margin, return_on_assets, return_on_equity,
debt_to_equity, operating_cf_margin, cash_to_assets). All three
materialized as Iceberg/Parquet on the BV+RV equi-join chain. **63 dbt
schema tests + 48 SQL structural verify checks + 3 mart-shape PBI
Desktop smoke tests all PASS.** Session 3 ships canonical seed
expansion 8 → 13 raw us-gaap tags (added OperatingIncomeLoss,
GrossProfit, CostOfRevenue, CashAndCashEquivalentsAtCarryingValue,
NetCashProvidedByUsedInOperatingActivities); new sp100_company_sector
seed (107 rows, GICS 11-sector taxonomy, CIKs authoritative via SEC
EDGAR company_tickers.json); mart_peer_benchmark sector cascade
(Option A bundle); Risk 49 banked (Salesforce 2010-2013 pre-ASC-606
gross_profit > revenue artifact, 0.12% of mart_financial_health rows —
documented + excluded at verify, not at mart). Apple FY2023 net_margin
renders at the analyst-correct 25.3%. 10/10 ENGINEERING_STANDARDS audit
PASS sessions 1+2+3 — NINE-session unbroken streak. Phase 3 fully
preserved underneath: end-to-end orchestrated dbt-on-Glue-Python-Shell
via AWS Step Functions LIVE. Phase 2 Silver Data Vault 2.0 (3 hubs + 2
links + 4 sats + 1 dim + 1 PIT + 1 Bridge, 121/121 + 114/114 verify)
preserved; canonical seed expansion adds +110 schema tests at the
warehouse/BV layers all PASS. Phase 4 sessions 4-5 next:
mart_growth_forecast + Phase 4 CLOSE.

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

# financial-analytics-lakehouse-project

> AWS-native data lakehouse — SEC EDGAR financial data → Data Vault 2.0
> medallion (S3 + Glue + Athena) → 5-page Power BI executive overview.
> Project #3 of Phil's data engineering portfolio.

**Status:** Phase 4 sessions 1+2 SHIPPED 2026-05-30. Two Gold marts live
in `financial_analytics_silver` — `mart_pl_trend` (10-year P&L trend per
S&P 100, 19,336 rows, revenue + net_income) and `mart_peer_benchmark`
(cross-company peer benchmarking at FY snapshots, 29,936 rows, revenue +
net_income + assets, per-row peer aggregates + RANK + CUME_DIST
percentile via window functions over the per-partition peer group).
Both materialized as Iceberg/Parquet, same 5-step BV+RV equi-join chain
from the Business Vault PIT/Bridge surface. **46 dbt schema tests + 31
SQL structural verify checks + 2 mart-shape PBI Desktop smoke tests all
PASS.** Session 2 resolved Risk 45 sat_concept_value MIN-collapse
artifact via 3-Risk cascade: Risk 46 (preferred-tag seed pattern —
canonical_concept_tag_preference seed + sat_concept_value refactor with
ORDER BY value DESC primary + preference_rank ASC tie-breaker), Risk 47
(v1→v2 ORDER BY flip after preference_rank ASC primary broke on ASC 606
transition), Risk 48 (mart-dedup intra-accession period-chunk filter
addressing SEC XBRL anomaly where multiple unrelated periods within
one 10-K accession tag fp=FY fy=filing_year). Apple FY2019 revenue now
renders at the analyst-correct $260.174B (vs session 1 MIN-collapse
$70B + v1 preferred-tag-primary $62.9B). 10/10 ENGINEERING_STANDARDS
audit PASS sessions 1+2 — EIGHT-session unbroken streak. Phase 3 fully
preserved underneath: end-to-end orchestrated dbt-on-Glue-Python-Shell
via AWS Step Functions LIVE, last orchestrated run Succeeded in 6m 15s,
dbt build PASS=157 / ERROR=0 / SKIP=0 / TOTAL=157, all 10 Parallel verify
branches TaskSucceeded. Phase 2 Silver Data Vault 2.0 (3 hubs + 2 links +
4 sats incl. 1 multi-active + 1 dim + 1 PIT + 1 Bridge, 121/121 dbt schema
+ 114/114 SQL structural verify) preserved. Phase 4 sessions 3-5 next:
mart_financial_health (+ canonical seed expansion + cik → sector seed) +
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

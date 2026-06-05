# financial-analytics-lakehouse-project

> AWS-native data lakehouse — SEC EDGAR financial data → Data Vault 2.0
> medallion (S3 + Glue + Athena) → 6-page Power BI executive suite →
> Step Functions orchestration → keyless GitHub OIDC CI/CD.
> Project #3 of Phil's data engineering portfolio.

**Status: COMPLETE — 2026-06-05.** End-to-end and interview-ready: Bronze (S3 raw SEC EDGAR) → Data Vault 2.0 warehouse (Glue / Athena / Iceberg) → canonical Gold marts → 6-page Power BI executive suite → AWS Step Functions orchestration → keyless GitHub OIDC CI/CD with a dbt-build-plus-verify gate. Full build history, design decisions and the risk log live in `PROJECT_CONTEXT.md` and `LEARNINGS.md`.

## What this project demonstrates

- **End-to-end lakehouse** from a public API source (SEC EDGAR) to a BI dashboard
- **AWS-native lakehouse** — S3 (raw) + Glue Data Catalog + Athena (serverless SQL) + Apache Iceberg table format
- **Data Vault 2.0** warehouse (hubs / links / satellites + PIT & bridge) inside a Bronze / Silver / Gold medallion
- **Canonical-concept mapping** collapsing heterogeneous SEC XBRL tags to stable financial concepts (seed-driven)
- **dbt-athena** transformations with singular + cross-mart data tests and a coverage regression guard
- **Orchestration** via AWS Step Functions (Glue Python Shell dbt build → 14-branch Athena verify fan-out)
- **Keyless GitHub OIDC CI/CD** deploying the project and running the orchestrator as an end-to-end gate
- **Univariate revenue forecasting** layer (Holt-Winters) conformed into the marts
- **6-page Power BI** executive report (Import mode — opens standalone for reviewers)

## Architecture

```mermaid
flowchart LR
    SEC["SEC EDGAR API (XBRL)"]
    S3[("Amazon S3 — Bronze raw JSON")]
    GLUE["AWS Glue Data Catalog"]
    ATH["Amazon Athena (dbt-athena)"]
    ICE[("Apache Iceberg — Silver + Gold marts")]
    PBI["Power BI — 6-page report"]
    SFN["AWS Step Functions"]
    GH["GitHub Actions — OIDC CI/CD"]

    SEC -->|Python extract| S3
    S3 -->|dbt sources| ATH
    GLUE --- ATH
    ATH -->|staging to warehouse to marts| ICE
    ICE -->|native connector| PBI
    SFN -.->|dbt build then 14-branch verify| ATH
    GH -.->|deploy + run orchestrator| SFN
```

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

## Project structure

```
financial-analytics-lakehouse-project/
├── dbt/                    # dbt-athena project
│   ├── models/
│   │   ├── staging/        # stg_* (Bronze JSON → typed columns)
│   │   ├── intermediate/   # int_* (concept extraction + canonical mapping)
│   │   ├── warehouse/      # Data Vault 2.0 hubs / links / satellites
│   │   ├── business_vault/ # PIT + bridge
│   │   └── marts/          # Gold: P&L trend, peer benchmark, health, forecast
│   ├── seeds/              # canonical-concept dictionary + S&P 100 roster
│   └── tests/              # singular + cross-mart data tests
├── scripts/                # Python: SEC extract, forecast, Glue dbt runner, deploy
├── sql/                    # ddl / diagnostic / verify / audit query packs
├── stepfunctions/          # Step Functions state machine definition
├── iam/                    # IAM policy documents
├── powerbi/                # financial_analytics.pbix + screenshots/
├── audit/                  # data-quality audit notes
├── .github/workflows/      # deploy.yml — keyless OIDC CI/CD
└── *.md                    # PROJECT_PLAN, PROJECT_CONTEXT, *_PIPELINE walkthroughs, LEARNINGS
```

## How this project was built

This project was built using AI-assisted pair programming (Claude by Anthropic).
All architecture decisions, technology selections, and final design choices are
my own; the AI accelerated implementation and acted as a senior-DE code reviewer.
The intent of the project is portfolio learning — every component was built with
explicit understanding of what it does and why. Layer-by-layer
walkthroughs live in the `*_PIPELINE.md` files; decision records and
diagnosis → fix → lesson loops are in `LEARNINGS.md`.

## Project documents

- `PROJECT_PLAN.md` — locked stack, decisions, phase delivery plan
- `PROJECT_CONTEXT.md` — running session state + full build history
- `DBT_PIPELINE.md` / `GOLD_MARTS_PIPELINE.md` / `ORCHESTRATION_PIPELINE.md` — layer walkthroughs
- `ENGINEERING_STANDARDS.md` — 10-criteria per-script audit
- `LEARNINGS.md` — diagnosis → fix → lesson loops (62 risks banked)

## Dashboard

Six interactive pages built in Power BI Desktop on the dbt Gold marts. Import
storage mode — the `.pbix` opens standalone for reviewers. Live report:
`powerbi/financial_analytics.pbix`.

### Executive Overview

![Executive Overview](powerbi/screenshots/01_executive_overview.png)

Universe headline KPIs — Total Revenue, Net Income, Net Margin and Revenue YoY %
at the latest complete fiscal year ($9.9T / $1.5T / 14.9%) — over a multi-year
revenue trend, with top revenue movers and margin/return scatters. Slicer-
responsive by sector.

### P&L Trend Deep-Dive

![P&L Trend Deep-Dive](powerbi/screenshots/02_p_and_l_trend.png)

Long-run revenue, net income and margin trends across fiscal years, with sector
and company breakdowns.

### Peer Benchmarking

![Peer Benchmarking](powerbi/screenshots/03_peer_benchmark.png)

Company-versus-peer comparison on the headline financials, ranking constituents
within their sector and against the S&P 100.

### Financial Health

![Financial Health](powerbi/screenshots/04_financial_health.png)

Eight canonical ratios in a Sector vs S&P 100 matrix with traffic-light
formatting; a net-income rank-movement ribbon chart (2009-2024); and a
multi-ratio sector trajectory line (net margin / ROE / ROA).

### Growth & Forecast

![Growth & Forecast](powerbi/screenshots/05_growth_and_forecast.png)

A cohort-locked revenue trajectory — solid actuals → dashed forecast → 95%
confidence fan — plus a forecast-highlights KPI strip, a historical-vs-forecast
CAGR acceleration scatter, and a Top 10 forecast-CAGR bar.

### Company Detail (drill-through)

![Company Detail](powerbi/screenshots/06_company_details.png)

Per-company drill-through: a KPI strip, a 15-year P&L line, an 8-ratio
Company / Sector / S&P 100 matrix, and a revenue-vs-sector gauge. Reached by
drilling from the Executive Overview top-movers and scatters.

## Related projects

Part of a three-project data-engineering portfolio:

- **Project #1 — CDC NT Transport Analytics** — dbt-first pipeline on PostgreSQL → Power BI; Kimball modelling foundation.
- **Project #2 — Retail Demand & Forecasting** — cloud warehouse + orchestration: Azure SQL → Snowflake → Airflow (Docker) → dbt → Power BI, with a Cortex forecast layer.
- **Project #3 — S&P 100 Financial Analytics Lakehouse** *(this one)* — AWS-native lakehouse: S3 + Glue + Athena + Iceberg, dbt-athena, Step Functions, 6-page Power BI, keyless OIDC CI/CD.

## Author

Phil McKechnie — Business Intelligence Analyst & Developer, Melbourne. 15+ years across operations, supply chain and analytics; the last 5 in dedicated BI roles (SQL, Tableau, Power BI). Building a data-engineering portfolio across dbt, cloud warehouses and AWS-native lakehouse work.

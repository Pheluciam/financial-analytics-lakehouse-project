# financial-analytics-lakehouse-project

> AWS-native data lakehouse — SEC EDGAR financial data → Data Vault 2.0
> medallion (S3 + Glue + Athena) → 5-page Power BI executive overview.
> Project #3 of Phil's data engineering portfolio.

**Status:** **Phase 5 session 1 v1 SHIPPED 2026-05-31 + complete 5-page
redesign queued for sessions 2-6.** Phase 5 session 1 shipped a working
v1 of the executive overview page (`powerbi/financial_analytics.pbix`)
— data model (4 marts + dim_company from `sp100_company_sector` seed +
dim_as_of_date from DISTINCT `mart_pl_trend.as_of_date`, all imported
via the locked ODBC SELECT-per-table pattern through DSN
`FinancialAnalyticsAthena`, 8 active many-to-one relationships on cik +
as_of_date), `_Measures` hidden table discipline (placeholder Column1
hidden in report view, all DAX measures live there not on fact tables),
4 KPI cards using the locked Latest-Complete-FY ≥80-of-107 self-correcting
threshold pattern (Total Revenue (Latest FY) $8.9T + Revenue YoY % 5.2%
+ Total Net Income (Latest FY) $1.2T + Net Margin (Latest FY) 13.7%, all
1-decimal precision via measure-level format string), hero revenue
trajectory line chart FY2009-2024 historical-only sourced from
`mart_pl_trend` (audit-anchored $8.88T at FY2024), 2 slicers (gics_sector
+ as_of_date Original Slicer Dropdown style at top-right), Executive
built-in theme, Bloomberg-style footer caveat strip carrying source +
universe + coverage + snapshot metadata. **Athena audit at session
midpoint** shipped 4 diagnostic SQLs (canonical_concept distribution +
company count per fiscal_year + revenue sum per fiscal_year + S&P 100
universe missing FY2024 revenue) surfacing the Risk 55 sector-specific
us-gaap revenue tag mapping gap (97/107 FY2024 coverage, 10-12%
under-count concentrated in Financials). **Phil's design call at session
close:** v1 looks too generic for a Project #3 portfolio piece — reads
like every beginner Power BI tutorial pattern (4 KPI cards + one line
chart + 2 slicers), no analytical distinction from the dashboards shipped
on Projects #1 (transport GTFS) and #2 (M5 retail), no demonstration of
the underlying Data Vault → Gold marts architecture in the visual layer.
**Complete 5-page redesign spec landed** in `POWERBI_PIPELINE.md`
section 3 covering: Page 1 Executive Overview redesign (KPI cards with
embedded sparkline backgrounds + annotated trajectory chart with
COVID/ASC 606/recession reference overlays + sector treemap + top movers
strip + drill-through to Page 6), Page 2 P&L Trend deep-dive (dual-axis
revenue + net income chart + sector-mix stacked area + 11-sector small
multiples + margin trend heatmap), Page 3 Peer Benchmarking (sector-driven
bubble chart + sector benchmark gauges + top/bottom 10 ranked + custom
tooltip page), Page 4 Financial Health (Decomposition Tree + 8-ratio
gauge grid with traffic-light comparison + 10-year ratio trajectory +
health heatmap), Page 5 Growth/Forecast (combined historical + forecast
with 95% CI bands + 11-sector forecast small multiples + top forecasted
growth ranking + model metadata panel), Page 6 Company Detail
(drill-through target from any of Pages 1-5). **3 new Risks banked at
session close**: Risk 55 (sector-specific us-gaap revenue tag mapping
gap, dbt-side fix deferred to dedicated Phase 6 mapping-expansion
session), Risk 56 (forecast horizon varies per company in
`mart_growth_forecast` creating apparent cliff at rightmost forecast
year in multi-company aggregations), **Risk 57 (PBI authoring discipline
— ship a deliberate design BEFORE clicking, not iteratively patch
through the visual; locked carry-forward for Phase 5 sessions 2-6:
each session opens with a 1-page design call before any PBI clicks)**.
v1 .pbix committed as the working baseline; sessions 2-6 extend the
same `powerbi/financial_analytics.pbix` per the locked continuous-publish
convention (no separate versioned filenames; git is the version control).
Phase 4 CLOSED 2026-05-30 preserved underneath: four Gold marts in
`financial_analytics_silver` (`mart_pl_trend` 19,336 rows + `mart_peer_benchmark`
29,936 rows sector-segmented + `mart_financial_health` 10,610 rows with 9
canonicals pivoted + 8 NULLIF-guarded derived ratios + `mart_growth_forecast`
10,069 rows = 9,775 historical + 294 forward-looking 3-year forecasts via
statsmodels.tsa Holt-Winters Exponential Smoothing + ARIMA(1,1,0) fallback
with 95% prediction intervals). 84 dbt schema tests + 66 SQL structural
verify checks + Step Functions Parallel state covering all `sql/verify/03-16`
queries all PASS. Phase 3 orchestration (dbt-on-Glue-Python-Shell via
AWS Step Functions) + Phase 2 Silver Data Vault 2.0 (3 hubs + 2 links +
4 sats + 1 dim + 1 PIT + 1 Bridge, 121/121 + 114/114 verify) preserved.
**Next phase: Phase 5 session 2** — Executive Overview page REDESIGN per
`POWERBI_PIPELINE.md` section 3.1, opening with a design call per the
locked Risk 57 carry-forward rule.

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

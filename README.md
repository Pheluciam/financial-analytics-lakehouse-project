# financial-analytics-lakehouse-project

> AWS-native data lakehouse — SEC EDGAR financial data → Data Vault 2.0
> medallion (S3 + Glue + Athena) → 6-page Power BI executive suite →
> Step Functions orchestration → keyless GitHub OIDC CI/CD.
> Project #3 of Phil's data engineering portfolio.

**Status:** **PROJECT #3 COMPLETE — Phase 6 session 2 CLOSED 2026-06-05.** The full lakehouse ships end to end: Bronze (S3 raw SEC EDGAR) → intermediate + Data Vault 2.0 warehouse (Glue/Athena/Iceberg) → canonical-collapsed Gold marts → 6-page Power BI executive suite → Step Functions orchestration → keyless GitHub OIDC CI/CD with an end-to-end dbt-build-plus-verify gate. Session 2 closed the final two items: (1) **Risk 55 (sector revenue tag-mapping gap) RESOLVED-by-prior-fixes** — a diagnostic proved FY2022-2025 already sit at 100% universe revenue coverage (FY2025 = $9.91T vs the broken $8.88T), healed by the earlier `InterestAndDividendIncomeOperating` add + Risk 58 period-end re-anchor; the speculative seed/Jinja expansion was correctly NOT run, and `sql/verify/19_phase6_revenue_coverage_audit.sql` was shipped as a permanent regression guard. (2) **CI/CD** — `.github/workflows/deploy.yml` (keyless OIDC) deploys the dbt project + Glue wrapper + Step Functions definition and triggers one orchestrator run (Glue dbt build → 14-branch Athena verify) as the CI gate; deploy scripts unified onto the boto3 default credential chain. 62 Risks banked across the journey. **Next: Databricks mini-project (portfolio slot 2).** Prior: **Phase 6 session 1 CLOSED 2026-06-05 — dbt `is_latest_complete_fy` flag shipped; the ≥80-CIK "Latest FY" DAX measure family retired.** The "latest complete fiscal year" rule — the most recent year for which at least 80 of the 107 S&P 100 companies have reported, measured at the latest snapshot — now lives in dbt as a precomputed boolean column on `mart_pl_trend` + `mart_financial_health`, driven by a single project var (`latest_fy_min_ciks`). It replaces a Power BI DAX recompute (`DISTINCTCOUNT(cik) >= 80`) that returned BLANK under single-company and single-sector filters and so needed band-aids. The flag is drill-safe and auto-advancing — a rebuild rolls it forward automatically (verified landing on FY2025, correctly skipping the partial FY2026 cohort that only the Jan/Feb fiscal-year-end filers have reported so far). Both marts rebuilt and tested green (`dbt run` PASS=2, `dbt test` PASS=48). The four Power BI Executive-Overview KPI measures were unwrapped — the ≥80 guard and the s11 `REMOVEFILTERS(dim_company)` band-aid both removed, collapsed to a simple `is_latest_complete_fy = TRUE` filter plus the snapshot pin; the cards are now blank-safe and slicer-responsive. **Next: Phase 6 — Risk 55 revenue tag-mapping expansion, then CI/CD forward-verify.** Prior: **Phase 5 session 11 CLOSED 2026-06-05 — Power BI formatting + QA pass; PHASE 5 (Power BI) COMPLETE — all 6 pages portfolio-grade** (consistent $/%/decimal number-format standard across every visual; five substantive QA bugs fixed; dynamic-format-string technique banked; measure set cleaned to 40). Prior: **Phase 5 session 10 CLOSED 2026-06-04 — Page 6 Company Detail drill-through (4 containers: new-Card KPI strip + 15-yr P&L line + 8-ratio Company/Sector/S&P 100 matrix + revenue-vs-sector gauge); drill-through proven from the Executive-Overview top-movers (ticker) and the scatters (entity_name), Back button verified.** Prior: **Phase 5 session 9 CLOSED 2026-06-04 — Page 5 Growth/Forecast shipped (4 containers).** Page 5 ships with: a cohort-locked revenue trajectory (solid actual → dashed forecast → 95% CI fan, locked to the FY2024 forecast cohort for one consistent panel); a "Forecast Highlights" smart-narrative KPI strip (3-yr forecast CAGR 3.5%, forecast revenue 2027 $6.6T, forecast ±95% range 25%); an acceleration scatter (historical CAGR × forecast CAGR, sized by revenue, coloured by sector); and a Top 10 forecast-CAGR bar. The forecast bridge waterfall was dropped at the data-veto (real sector deltas net negative — IT −$656bn is a univariate structural-break artifact). Hard-won lessons banked: never filter the axis column inside CALCULATE (gate with IF/SELECTEDVALUE outside it — the ~8-attempt flat-line bug); lock forecast aggregates to one cohort because forecast.py horizons are per-company; KPI strips via a copied smart-narrative box + text measure (smart narrative can't rename values or scale to Trillions). Full root-cause inventory in `POWERBI_PAGE5_AUDIT.md`. **Next: session 10 — Page 6 Company Detail drill-through; then session 11 — full Power BI QA/measure-cleanup/formatting pass.** Prior: **Phase 5 session 8 CLOSED 2026-06-03 — Page 4 Financial Health shipped (3 visuals after 4 during-build pivots).** Page 4 ships with: 8-ratio sector-vs-S&P 100 Matrix (Rows = 8 dbt-canonical ratios, Values = Sector / S&P 100 / Δ with traffic-light formatting driven by a Δ Direction helper that inverts the sign for D/E so lower-debt sectors render correctly green); Sector net income rank-movement Ribbon chart (Y = SUM(net_income), X = fiscal_year, Legend = gics_sector, 2009-2024) — brand-new viz idiom across the report telling "Tech overtook Financials around 2018" stories; multi-ratio Sector health trajectory Line chart (Y = Sector Net Margin + Sector ROE + Sector ROA on shared % axis, 2009-2024) using DIVIDE/SUM aggregate pattern after the spec's AVERAGE pattern blew up at 2014-2015 with a −2000% spike. Four during-build pivots banked as transferable lessons: (i) dbt mart is canon (spec's aspirational current_ratio + asset_turnover never existed; rebuilt with actual operating_margin + operating_cf_margin); (ii) V2 swapped from Decomposition tree to Ribbon chart after static-presentation + measure-context tests failed; (iii) DIVIDE/SUM beats AVERAGE for aggregate ratios on trajectory visuals; (iv) PBI visual filters INTERSECT page filters, they don't override — refactored to per-visual fiscal_year filters. Both .pbix files saved at V1+V2+V3 landed checkpoint. Prior: **Phase 5 session 7 CLOSED 2026-06-03 — Page 3 Peer Benchmarking shipped (3 visuals).** Prior: **Phase 5 session 6 CLOSED 2026-06-02 — Page 2 P&L Trend Deep-Dive shipped (3 visuals).** Prior: **Phase 5 session 5 CLOSED 2026-06-02 — Page 1 Executive Overview redesign landed at analyst-grade.** Prior: **Phase 5 session 4.5 CLOSED 2026-06-01 — Step M re-audit + three-layer sign-off all green.** Prior: **Phase 5 session 4 CLOSED 2026-06-01 — Fix-all phase landed across 8 fix families.** Prior: **Phase 5 session 3 CLOSED 2026-06-01 — 10-audit data quality campaign complete.** Phase 5
session 2 PAUSED for full data quality audit after Phil's direction-check
exposed mart data wasn't shippable; session 2 closed Audits 1-3 (universe
integrity + completeness + tag-evidence); session 3 closed Audits 4-10
(mart-pipeline filter diagnosis + collapse semantics + external anchor
checks + cross-mart consistency + snapshot stability / PIT logic +
forecast sanity + schema test coverage gap report). **TRIPLE CONVERGENCE
finding:** Audits 4 + 7 + 8 independently surfaced the SAME architectural
bug — mart `fiscal_year` anchored on the SEC `fy` attribute instead of
`year(period_end_date)`, causing 52/53-week filers' 10-Ks to drop
multiple period_end rows into the same Risk 42 dedup partition with the
same accession, triggering non-deterministic Trino ROW_NUMBER tie-break.
ONE fix (Risk 58 period-end re-anchor in mart_pl_trend + mart_peer_benchmark
+ mart_financial_health) heals SPGI's total FY2024 absence + 22
RECENT_PIPELINE_BUG cells + ~421 cross-mart divergences + 118
snapshot-stability drifts simultaneously. **Other findings.** Audit 5:
cash_and_equivalents needs canonical-specific collapse_rule override
(Risk 59 — preference_rank ASC PRIMARY for cash, vs Risk 47 value-DESC
default; heals 16 RESTRICTED_ONLY bank CIKs without inflating 45
RESTRICTED_LARGER cases). Audit 6: anchor truth PASS — mart values match
published 10-Ks for AAPL ($391B revenue) / MSFT ($245B) / JPM ($178B) /
BRK.B ($371B) / WMT ($648B) / XOM ($349B) within rounding tolerance;
S&P 100 aggregate $8.93T revenue + $1.25T net income matches Phase 5
session 1 PBI smoke test baseline; 11 GICS sector subtotals match sector
economics. Audit 9: forecast architecture sound (CI ordering PASS, AIC
distribution healthy), 3 GE/MMM model pathology rows (Risk 60 —
structural shocks not modeled by Holt-Winters); PBI Page 5 caveat strip
needs annotation. Audit 10: 249 current dbt schema tests are STRUCTURAL
only (Risk 62) — zero semantic coverage; 12 new data tests recommended
(6 anchor-CIK value-correctness + 3 cross-mart consistency + completeness
threshold + forecast CI ordering + snapshot stability + collapse_rule
enum). **5 new Risks banked (58-62).** **100% data integrity post-Fix:**
142 cells get correct values from the fixes (Risk 58 period-end re-anchor
+ Risk 59 cash collapse override + canonical_concepts_dictionary alias
expansion + mart-layer derivation columns + universe filter at
hub_company) + 49 cells correctly defended NULL with JSON-probe URL pin
per cell = 191 of 191 = ZERO incorrect cells. No "97% reporting" framing.
**ZERO mart / seed / DDL changes this session** — 100% read-only audit
per operating principle locked at session 2 kickoff. 8 audit artifacts +
2 markdown docs shipped to `sql/audit/` + `audit/`; `AUDIT_FINDINGS.md`
extended to cover all 10 audits; `LEARNINGS.md` extended with Risks
58-62; `PROJECT_CONTEXT.md` + `PROJECT_PLAN.md` + this Status line all
refreshed. **Task #30 Fix-all phase queued for the next session** — ONE
coherent commit batching every fix (Risk 58 period-end re-anchor in 3
marts + Risk 59 cash collapse_rule override on sat_concept_value +
canonical_concept_tag_preference seed extension with collapse_rule column
+ canonical_concepts_dictionary expansion + 6-place Jinja `{% set
concepts %}` lockstep edits across intermediate + 5 warehouse models +
mart-layer derivation columns in mart_financial_health + universe filter
at hub_company dropping 8 Bronze orphans + 12 new dbt schema/data tests
+ `audit/defended_nulls.md` JSON-evidence pin file for 49 defended-NULL
cells); ONE cascade rebuild via `dbt build`; ONE re-audit pass through
all 10 sql/audit/*.sql files; bundled commit + push. Estimated session
length 4.5-5 hours. After Fix-all closes, Phase 5 sessions 2-6 of the
5-page Power BI redesign resume on 100%-trusted data. **Phase 5 session 1
v1 SHIPPED 2026-05-31** preserved underneath — `powerbi/financial_analytics.pbix`
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

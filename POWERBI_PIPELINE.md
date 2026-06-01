# POWERBI_PIPELINE.md — financial-analytics-lakehouse-project

> Phase 5 Power BI walkthrough doc. Three-layer pattern: verbose-in-chat
> at authoring time, clean .pbix on disk at `powerbi/financial_analytics.pbix`,
> this doc carrying the technical depth + 5-page redesign spec.
>
> Created 2026-05-31 at Phase 5 session 1 close. Authored AI-assisted per
> the standing AI-assistance disclosure convention in TEACHING_PREFERENCES.md.

---

## 1. Phase 5 session 1 status — v1 SHIPPED, redesign queued; Phase 5 session 4.5 closed three-layer Step M sign-off (2026-06-01) — data trust now at 100% for redesign

Session 1 shipped a working v1 of the executive overview page —
data model, _Measures discipline, 4 KPI cards, hero trend chart, 2
slicers, coverage caveat — but the layout was too generic for a Project
#3 portfolio piece. It looked like every beginner Power BI tutorial:
4 cards on top, one line chart below, default theme, no analytical
distinction from Projects #1 and #2.

**Phil's call at session close (2026-05-31):** complete redesign across
all 5 pages with real complexity. v1 .pbix is committed as the working
baseline; sessions 2-6 implement the redesign per the spec in section 3
below.

**Phase 5 session 4.5 close update (2026-06-01).** Marts now at 100%
three-layer trust (Layer 1 local cascade PASS=265, Layer 2 Athena
sql/verify/18 48/48 PASS, Layer 3 Step Functions production execution
SUCCEEDED 15:52). The 2026-06-01 forward as_of_date (Risk 67) gives every
Page 1-6 mart query the latest annual snapshot including FY2025-10-K
comparative coverage. Session 5 kickoff prep — what to refresh / delete /
replace / add / keep on Page 1 — is in section 3.1 below.

---

## 2. Standing conventions

These hold across all 5 pages and any future PBI work on this project.

### 2.1 Storage mode = pure Import (Risk 53)

All 4 marts + dim_company + dim_as_of_date import via Power Query Import
mode. Composite / Dual / DirectQuery patterns are over-engineering at
the <100K total row scale of these marts (per Risk 53 forward-verify at
Phase 4 session 5 close). Revisit only if a future mart exceeds ~1M
rows.

### 2.2 ODBC connection pattern (Risk 39)

Amazon Athena ODBC v2 driver + Windows System DSN "FinancialAnalyticsAthena"
+ ~/.aws/credentials [phil-dbt] profile. PBI Power Query connector path:
generic ODBC connector, ODBC connection string = `dsn=FinancialAnalyticsAthena`,
Authentication kind = Anonymous (AWS auth happens at the ODBC driver
layer, not at Power Query), Advanced options SQL statement pasted for
each table imported. Bypasses the Navigator cache that snagged sessions
1-2 mart-shape smoke tests (per Risk 39).

### 2.3 SELECT-per-table import (not Navigator)

Each table comes in via an explicit `SELECT ... FROM
financial_analytics_silver.<table>` pasted into the Advanced options SQL
statement box, not via the Navigator pick-tables flow. Reasons:

- Column control — pull only what's needed, not every column.
- Stable contract — upstream renames break loudly with a clear error;
  Navigator silently grabs the new shape.
- Auditability — the .pbix carries readable SQL strings showing what
  was imported.
- Bypasses the Navigator cache issue (Risk 39).

### 2.4 _Measures hidden table discipline

All DAX measures live on a dedicated single-row hidden `_Measures`
table — never on the fact tables, never on the dims. Reasons:

- Clean separation — every measure findable in one place.
- No accidental measure-on-wrong-table bug (the kind that surfaced in
  Project #2 — see Project #2 Risk family E in LEARNINGS.md).
- Hidden placeholder column (`Column1`) keeps the model clean in
  report view.

### 2.5 Latest Complete FY pattern

Every "Latest FY" measure uses a self-correcting threshold: pick the
latest fiscal_year where ≥80 of 107 S&P 100 companies have reported
that canonical concept at the latest as_of_date snapshot. Auto-advances
when newer fiscal years fill in over time. DAX pattern:

```dax
VAR LatestSnapshot = MAX(mart_pl_trend[as_of_date])
VAR LatestCompleteFY =
    CALCULATE(
        MAX(mart_pl_trend[fiscal_year]),
        FILTER(
            VALUES(mart_pl_trend[fiscal_year]),
            CALCULATE(
                DISTINCTCOUNT(mart_pl_trend[cik]),
                mart_pl_trend[as_of_date] = LatestSnapshot,
                mart_pl_trend[canonical_concept] = "revenue"
            ) >= 80
        )
    )
```

### 2.6 Theme = Executive (built-in)

Power BI Desktop built-in Executive theme — navy / teal / muted accent
palette. Light background reproduces well in PDFs, GitHub README
screenshots, LinkedIn posts. Chosen at session 1 close after rejecting
Default + Accessible variants as too generic.

### 2.7 Data lineage & coverage caveat (Risk 55)

Every page carries a footer metadata strip with source + universe +
coverage + snapshot date:

```
Source: SEC EDGAR XBRL  |  Universe: S&P 100 (107 companies)  |  FY2024 coverage: 97 of 107  |  Snapshot: 2025-12-31
```

**Refresh from Phase 5 session 5 onwards (2026-06-01).** With Risk 67 forward as_of_date 2026-06-01 landed at session 4.5 close, the FY2024 coverage advances to 106 of 107 and the Snapshot caption advances to 2026-06-01. Updated template:

```
Source: SEC EDGAR XBRL  |  Universe: S&P 100 (107 companies)  |  FY2024 coverage: 106 of 107  |  Snapshot: 2026-06-01
```

Coverage figure references Risk 55 (sector-specific us-gaap tag mapping
gap — 18 of 107 S&P 100 companies missing FY2024 revenue, mostly
Financials using InterestAndDividendIncomeOperating /
RevenuesNetOfInterestExpense rather than Revenues / SalesRevenueNet).
Documented as a known data quality limitation; dbt-side fix deferred
to a dedicated mapping-expansion session in Phase 6 stretch.

---

## 3. Five-page redesign spec

Each page leverages something specific to its source mart's shape and
demonstrates the Data Vault → Gold marts architecture in the visual
layer. Sessions 2-6 implement these pages one at a time.

### 3.1 Page 1 — Executive Overview (redesign)

**Source marts.** mart_pl_trend (revenue + net_income trajectory),
dim_company (sector + ticker for slicer + sector breakdown),
dim_as_of_date (snapshot slicer).

**What makes this distinctive (not the v1 generic layout):**

- KPI cards with embedded sparklines. Each KPI shows the value + 10-year
  trend sparkline behind the value via the new PBI sparkline-in-card
  pattern (Microsoft Learn 2026 docs). 4 cards = 4 mini-charts in one
  scan — visually richer than the v1 plain-number cards.
- Annotated trajectory chart. Hero line chart with reference-line overlays:
  COVID-19 shading (FY2020), ASC 606 adoption marker (FY2018 — when
  RevenueFromContractWithCustomer tags replaced Revenues for most
  companies), 2008-2009 recession bars. Demonstrates domain knowledge.
- Sector treemap. Right-side treemap visual showing per-sector revenue
  contribution at latest FY. Demonstrates the dim_company → mart_pl_trend
  conformed dim relationship visually.
- Top movers strip. Bottom row: 5 biggest revenue YoY % gainers + 5
  biggest decliners as small horizontal bar tiles. Anomaly callouts.
- Drill-through to company detail page (Page 6 — see 3.6 below).

**Layout (16:9 canvas):**

- Header: title + 2 slicers (gics_sector + as_of_date) in top-right
  corner.
- Row 1: 4 KPI cards with sparkline backgrounds (Total Revenue, Revenue
  YoY %, Total Net Income, Net Margin).
- Row 2: Annotated trajectory chart (~2/3 width) + Sector treemap
  (~1/3 width).
- Row 3: Top 5 gainers (left) + Top 5 decliners (right) horizontal bar
  tiles.
- Footer: metadata caveat strip.

**Standing measures.** Total Revenue (Latest FY), Revenue YoY %,
Total Net Income (Latest FY), Net Margin (Latest FY) — all using the
Latest Complete FY pattern from 2.5. Add: Revenue Sparkline (per-year
revenue trajectory), Sector Revenue (sector breakdown), YoY Rank
measures.

**Session 5 kickoff prep (added 2026-06-01 at Phase 5 session 4.5 close).** Page 1 v1 is currently on disk at `powerbi/financial_analytics.pbix` with the generic layout (4 plain cards + plain trajectory + 2 slicers + footer). Walk into session 5 with this map in hand:

- **FIRST action — Power Query refresh.** The .pbix is on the stale 2025-12-31 snapshot. Risk 67 added the forward as_of_date 2026-06-01 and Risk 66 healed BKNG/CAT/MA/SO/TMO/CCI FY2024 net_income. Hit Home → Refresh in PBI Desktop before opening any visual. The 4 KPI card numbers ($9.9T / 6.5% / $1.5T / 14.9%) and the footer caveat strip (FY2024 coverage 97 → 106 of 107; Snapshot 2025-12-31 → 2026-06-01) all shift on refresh. Verify the refreshed values against the bands in `sql/verify/18` checks 7-15 before proceeding.
- **DELETE / REPLACE.** Plain KPI cards → KPI cards with embedded sparklines (PBI sparkline-in-card pattern, Microsoft Learn 2026 docs). Plain "Revenue Trend by fiscal_year" line chart → annotated trajectory with reference-line overlays for COVID shading (FY2020), ASC 606 marker (FY2018), 2008-2009 recession band. These are the two distinctive elements — domain-knowledge tells that signal financial-analytics, not generic time-series BI.
- **ADD.** Sector treemap on the right of the trajectory (~1/3 width) showing per-sector revenue contribution at latest FY (demonstrates dim_company → mart_pl_trend conformed dim visually). Bottom-row Top 5 revenue YoY gainers + Top 5 decliners as small horizontal bar tiles. Drill-through target setup pointing at Page 6 Company Detail (Page 6 itself gets built later; the drill-through wiring stub goes in now). Three new measures on _Measures: Revenue Sparkline, Sector Revenue, Revenue YoY Rank.
- **KEEP (no work needed).** _Measures table architecture and all 7 existing measures (Total Revenue / Revenue YoY % / Total Net Income / Net Margin / Revenue Trend / Revenue Historical / Revenue Forecast). Both slicers (gics_sector + as_of_date). All 8 model relationships (each mart → dim_company on cik + → dim_as_of_date on as_of_date). Theme = Executive. Coverage caveat strip pattern.
- **Open direction-check to decide at session kickoff (30 seconds, no question yet — choose at session open):** whether Revenue YoY Rank gets computed in DAX on the existing mart_pl_trend OR pre-computed as a new column in dbt. Architecturally-honest path is dbt — mart_peer_benchmark already pre-computes peer_rank; extending the same pattern to YoY rank in mart_pl_trend (or a sibling rank column) keeps the rank-computation discipline at the warehouse layer. Faster path is DAX. Senior-DE default = dbt unless time-pressured.

### 3.2 Page 2 — P&L Trend Deep-Dive

**Source mart.** mart_pl_trend (long-format, 19,336 rows = revenue +
net_income at canonical_concept × cik × fiscal_year × as_of_date).

**What makes this distinctive:**

- Dual-axis time series — revenue line + net income bar on the same
  chart, secondary Y-axis for net income. Single visual showing both
  scale and profitability over 15 years.
- Sector-mix stacked area chart — total revenue stacked by sector
  contribution, year-over-year. Demonstrates how sector composition
  has shifted (Tech rising, Energy falling, etc.).
- Small multiples panel — 11 mini line charts (one per sector) showing
  per-sector revenue trajectory. The PBI Small Multiples feature
  designed for this exact use case.
- Margin trend heatmap — sector × year matrix, cells colored by
  net margin. Visual scan of which sectors expanded margins when.

**Layout:**

- Header: title + sector slicer + year-range slicer.
- Row 1: Dual-axis revenue + net income chart (~2/3 width) + KPI
  callouts panel (~1/3 — Margin Trend, Best/Worst Year, etc.).
- Row 2: Sector-mix stacked area chart (full width).
- Row 3: Small multiples per sector (full width).
- Row 4: Margin heatmap (full width) + drill-through to Page 6.

### 3.3 Page 3 — Peer Benchmarking

**Source mart.** mart_peer_benchmark (29,936 rows, peer-stat columns
already pre-computed in dbt — peer_count, peer_mean_value,
peer_median_value, peer_rank within sector).

**What makes this distinctive:**

- Bubble chart at the center. X-axis = Revenue, Y-axis = Net Income,
  bubble size = Assets, color = peer_rank within selected sector.
  Single visual encoding 4 dimensions of company performance.
  Hover for company name + ticker.
- Sector picker slicer drives every visual on the page.
- Sector vs S&P 100 benchmark panel — radial gauges showing selected
  sector's average against the S&P 100 average for revenue / net
  income / assets.
- Top 10 + Bottom 10 in sector — two paired horizontal bar charts
  flanking the bubble. Selected sector's leaders and laggards.
- Tooltip page — hovering a bubble shows custom rich tooltip with the
  company's 5-year revenue mini-chart, latest FY net margin, return
  on assets, debt-to-equity.

**Layout:**

- Header: title + sector picker (single-select, defaults to highest-revenue sector).
- Row 1: Bubble chart (center, ~60% width) + Top 10 (left, ~20%) +
  Bottom 10 (right, ~20%).
- Row 2: Sector vs S&P 100 benchmark gauges (left ~50%) + Peer rank
  distribution histogram (right ~50%).
- Footer: caveat.

### 3.4 Page 4 — Financial Health

**Source mart.** mart_financial_health (10,610 rows, 9 canonicals
pivoted + 8 NULLIF-guarded derived ratios — gross_margin, net_margin,
current_ratio, debt_to_equity, ROA, ROE, asset_turnover, cash_to_assets).

**What makes this distinctive:**

- Decomposition tree visual (PBI native AI viz) — drill from Total
  Revenue → Sector → Industry Group → Company. PBI's AI auto-picks
  the next dimension to explore. Shows analytical depth.
- 8-ratio gauge grid for selected company — 4×2 layout of mini-gauges,
  each showing the company's ratio vs sector average vs S&P 100
  average. Traffic-light coloring (green / amber / red) based on
  quartile position.
- 10-year ratio trajectory for selected company — line chart with
  multi-series toggle (pick 2-3 ratios to overlay).
- Health heatmap — year × ratio matrix for the selected company,
  cells colored by quartile position vs sector. Visual story of where
  the company's strengths and weaknesses are over time.
- Sector-aggregate fallback when no company selected — page shows
  S&P 100 aggregate health ratios.

**Layout:**

- Header: company picker (search-as-you-type slicer on entity_name).
- Row 1: Decomposition tree (left ~50%) + 8-ratio gauge grid (right
  ~50%).
- Row 2: 10-year ratio trajectory (full width).
- Row 3: Health heatmap (full width).

### 3.5 Page 5 — Growth/Forecast

**Source mart.** mart_growth_forecast (10,069 rows — historical 9,775 +
forecast 294 = 98 companies × 3 forecast years, plus model metadata:
model_name, model_aic, historical_obs_count).

**What makes this distinctive — and what the v1 exec page hero chart
attempted but pulled out of:**

- Historical + forecast trajectory with 95% CI bands. The proper
  forecast visualization — solid historical line transitioning into
  dashed forecast line, with translucent CI band (lower_ci_95 to
  upper_ci_95) shaded behind the forecast. PBI's area chart layered
  under a line chart.
- Sector forecast small multiples — 11 mini charts, one per sector,
  each showing the sector's aggregate historical + forecast trajectory.
  Quick scan of which sectors are projected to grow vs flatten.
- Top forecasted growth ranking — horizontal bar chart of top N
  companies by projected 3-year revenue CAGR.
- Model metadata panel — per-company model_name (Holt-Winters vs
  ARIMA fallback), model_aic, historical_obs_count. Transparency
  about which forecasts have higher / lower confidence.
- Forecast horizon note. Forecast = 3 years out from each company's
  latest historical observation. Companies with FY2024 latest forecast
  to FY2025-2027; companies with FY2025 latest forecast to FY2026-2028.
  Documented as expected behavior (Risk 56).
- **Structural-shocks caveat strip (Risk 60).** Surface a small text
  callout on Page 5 reading: "Forecasts are 3-year Holt-Winters /
  ARIMA projections; structural events such as spinoffs, divestitures,
  and M&A are not modeled. Forecasts for post-divestiture filers like
  GE (2024 GE Vernova + GE HealthCare separations) and 3M (2024 fiber
  optics + food safety divestitures) should be interpreted accordingly."
  Audit 9 confirmed 3 such outlier forecast rows (GE 2027 0.42x, MMM
  2026 0.42x, MMM 2027 0.13x). Univariate models can't distinguish a
  one-time structural step-down from a continuing trend; explicit
  viewer caveat is the documented mitigation pending intervention
  analysis / structural-break detection in a future enhancement.

**Layout:**

- Header: title + sector slicer + company slicer.
- Row 1: Historical + forecast trajectory with CI band (~2/3 width)
  + KPI callouts (~1/3 — 3-yr CAGR, forecast vs historical YoY,
  model_aic average).
- Row 2: Sector forecast small multiples (full width).
- Row 3: Top forecasted growth bar (left ~50%) + Model metadata
  panel (right ~50%).

### 3.6 Page 6 — Company Detail (drill-through page)

**Source.** All 4 marts, joined via dim_company.cik.

**Purpose.** Right-click any company in any visual on Pages 1-5 →
drill-through → land on this page filtered to that company.

**Content.**

- Company header — entity_name, ticker, cik, gics_sector,
  gics_industry_group.
- 4 KPI cards — revenue, net income, net margin, peer rank within
  sector.
- 15-year P&L trajectory (revenue + net income).
- 8 financial health ratios with sector comparison.
- 3-year forecast trajectory with CI band.
- Back button to return to source page.

---

## 4. Risk 55 + Risk 56 — data quality known limitations

### Risk 55 — sector-specific us-gaap tag mapping gap

18 of 107 S&P 100 companies missing from FY2024 revenue in mart_pl_trend
due to canonical_concept_tag_preference seed mapping only 4 us-gaap
tags ("Revenues", "SalesRevenueNet",
"RevenueFromContractWithCustomerExcludingAssessedTax",
"RevenueFromContractWithCustomerIncludingAssessedTax") to canonical
"revenue". Financial-sector companies (banks: GS, MS, PNC, WFC; insurance:
CB; asset managers: SPGI) commonly use sector-specific tags like
"InterestAndDividendIncomeOperating", "RevenuesNetOfInterestExpense",
"PremiumsEarnedNet" that aren't currently mapped.

**Impact.** S&P 100 aggregate revenue at FY2024 reports as $8.88T vs
estimated true total ~$10T (10-12% under-count).

**Triage.** Documented as a known data quality limitation in the dashboard
caveat strip; dbt-side fix (extend canonical_concept_tag_preference seed +
parallel updates to 6 hardcoded Jinja `{% set concepts %}` lists across
intermediate + 5 warehouse models) deferred to a dedicated mapping-
expansion session in Phase 6 stretch.

**Interview talking point.** Demonstrates judgment: identified the gap
via Athena audit (4 diagnostic queries), triaged scope rigorously
(deep fix would have consumed a full session for a 10% accuracy gain),
chose to ship with documented caveat rather than block the portfolio
piece, scheduled the fix for the right phase.

### Risk 56 — forecast horizon varies per company

mart_growth_forecast forecast leg has 3-year horizon FROM each company's
latest historical year. Companies with FY2024 as their latest historical
forecast FY2025-2027; companies with FY2025 historical (21 of 107)
forecast FY2026-2028. Visually this surfaced on the v1 exec page hero
chart as an anomalous FY2028 drop (only the 21 companies with FY2025
historical have forecasts extending to FY2028, while the other ~80
stop at FY2027).

**Impact.** Forecast time-series visualizations on Page 5 need careful
handling — clip at FY2027 OR show explicit per-company forecast
horizons.

**Triage.** Documented; Page 5 spec (section 3.5) includes "Forecast
horizon note" panel making this explicit to dashboard viewers.

---

## 5. Continuous-publish convention

Per the Phase 0 lock — Power BI publishing = continuous + freeze at
v1.0. Working file is `powerbi/financial_analytics.pbix`. Sessions 2-6
extend this single file, page by page. v1.0 freeze = the git commit
that closes Phase 5 session 6 (no separate versioned filename — git is
the version control).

---

## 6. Cross-references

- `PROJECT_PLAN.md` section 9 — Phase 5 row + page-by-page session
  allocation.
- `PROJECT_CONTEXT.md` — running session log; session 20 entry is the
  Phase 5 session 1 close + this redesign spec landing.
- `GOLD_MARTS_PIPELINE.md` — the 4 marts' upstream design provenance.
- `DBT_PIPELINE.md` section 9 — per-mart column lists + accepted_values
  constraints (authoritative for what PBI sees).
- `LEARNINGS.md` — Risk register including Risks 55 + 56.

---

*Authored AI-assisted (Claude by Anthropic) per the standing
AI-assistance disclosure convention.*

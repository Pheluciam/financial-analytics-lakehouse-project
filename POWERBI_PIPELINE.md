# POWERBI_PIPELINE.md — financial-analytics-lakehouse-project

> Phase 5 Power BI walkthrough doc. Three-layer pattern: verbose-in-chat
> at authoring time, clean .pbix on disk at `powerbi/financial_analytics.pbix`,
> this doc carrying the technical depth + 5-page redesign spec.
>
> Created 2026-05-31 at Phase 5 session 1 close. Authored AI-assisted per
> the standing AI-assistance disclosure convention in TEACHING_PREFERENCES.md.

---

## 1. Phase 5 session 1 status — v1 SHIPPED, redesign queued; Phase 5 session 4.5 closed three-layer Step M sign-off (2026-06-01) — data trust now at 100% for redesign; sessions 5-7 shipped Pages 1-3 of the redesign

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

**Phase 5 session 7 close update (2026-06-03).** Pages 1, 2, 3 of the
redesign now shipped on the single `.pbix`. Page 3 Peer Benchmarking
shipped with 3 visuals + footer per the 4-visual budget cap locked
session 6: bubble scatter (revenue × net margin × assets × sector); sector
benchmark bar with the [Net Margin (Latest FY)] universe-median constant
line crossing the Materials/Communication Services band at ~15%;
within-sector top 5 horizontal bar by revenue. Sector slicer cross-filter
verified across all 3 visuals at session close. Pages 4 (Financial Health)
and 5 (Growth/Forecast) queued one per session per the existing cadence.

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

### 2.7 PBI filter precedence (locked session 8, 2026-06-03)

PBI filter mechanics — visual-level filters INTERSECT page-level
filters, they do NOT override. Confirmed via Microsoft Learn filter-
precedence docs after the V2 ribbon chart stayed pinned at FY=2024
during build despite a 2009-2024 visual-level filter (the page-level
FY=2024 pin AND-ed with the visual range, intersecting to FY=2024).

**Standing pattern.** When visuals on the same page need different
fiscal_year scopes (e.g. single-year snapshot vs multi-year
trajectory), do NOT use a page-level fiscal_year filter. Apply per-
visual filters instead:
- Single-year snapshot visuals: visual-level filter `fiscal_year =
  YYYY`.
- Multi-year trajectory visuals: visual-level filter `fiscal_year
  between A and B`.

When all visuals on a page DO need the same fiscal_year scope (Page 2
case — every visual wants 2009-2024), a page-level range filter is
fine and saves per-visual repetition.

The override-via-visual pattern that the original Page 4 v3 spec
prescribed is a documented anti-pattern. Per-visual filters are the
correct mechanism when ranges differ.

### 2.8 Data lineage & coverage caveat (Risk 55)

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

### 2.9 DAX: never filter the axis column inside CALCULATE (locked session 9, 2026-06-04)

The single most expensive bug of the Page 5 build (~8 failed line-chart
attempts). A boolean filter on a column INSIDE `CALCULATE` REPLACES that
column's filter/row context — it does not intersect it. So putting
`mart_growth_forecast[fiscal_year] <= 2024` inside `CALCULATE` while
`fiscal_year` is on the visual's axis makes every axis point evaluate to
the same grand total (the symptom: a flat line at ~$102.8T, every matrix
row identical).

**Standing pattern for any time-series measure that must blank part of
its own axis range:**
- Compute the value with `CALCULATE(SUM(...), <non-axis filters only>)` —
  pin the snapshot with `ALL(<table>)`, filter on `row_kind` /
  `as_of_date` etc. (different columns from the axis), never on the axis
  column.
- Gate the displayed window OUTSIDE `CALCULATE`:
  `VAR ThisYear = SELECTEDVALUE(mart_growth_forecast[fiscal_year])` then
  `RETURN IF(ThisYear <= AnchorYear, Val)` (or `SWITCH(TRUE(), ...)`).
- `SELECTEDVALUE` READS the row context without overriding it — that's
  the whole trick.

Pairs with the forecast-cohort lock: per-company forecast horizons
(`scripts/forecast.py` emits latest_year+1..+3 per company) make a raw
calendar-year `SUM(forecast_value)` smear/lumpy. Lock forecast measures
to one cohort (`latest_historical_year = <anchor>`) for a consistent
panel. Full detail: POWERBI_PAGE5_AUDIT.md + COPILOT_SPEC §9.2-9.3.

### 2.10 Verify PBI/Power-Platform UI against Microsoft Learn before prescribing clicks (re-locked session 9)

Three Page-5 stalls were all fixed by reading current docs, not training:
(a) smart-narrative text boxes show EITHER text OR a value and cannot
rename dynamic values (so KPI strips use copied smart-narrative boxes +
text measures, not 6 hand-aligned boxes); (b) copy/paste a visual needs
the visual selected (grey header), not in text-edit mode; (c) a slicer
needs **Single select OFF** to offer an "All + pick one" default. Doc
pages move (last-updated dates 2025-10 to 2026-01); assert from the live
Learn page, not memory.

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

**Source mart.** mart_pl_trend (long-format, ~21,400 rows = revenue +
net_income + per-row yoy_pct + yoy_rank at canonical_concept × cik ×
fiscal_year × as_of_date).

**Visual budget: 4 max per page** (project standing constraint locked
session 6 after the v1 5-row plan was tried and trimmed).

**What makes this distinctive:**

- Dual-axis combo (revenue bars + net income line) over 15 years —
  single visual showing both scale and profitability arc, with
  separate Y-axes (trillions for both, units calibrated for readability).
- KPI callout panel — 3 text boxes (Best year, Worst year, Avg net
  margin) driven by dedicated DAX measures. Replaces the v1 Card-strip
  pattern (project lock: no Card visuals).
- Per-sector net margin trend lines — single line chart, X = fiscal_year,
  legend = gics_sector (11 colored lines). Sector slicer narrows
  interactively. Replaces the v1 stacked-area + small-multiples + heatmap
  plan that triaged poorly at PBI Desktop's render width.

**Layout (3 visuals + footer):**

- Header: title + Date Range slicer + Sector slicer + Fiscal Year range
  slicer.
- Row 1: Dual-axis revenue + net income combo (~2/3 width) + KPI callout
  panel (~1/3 — 3 text boxes).
- Row 2: Per-sector net margin trend lines (full canvas width).
- Footer: caveat strip.

**Page-level filter:** dim_fiscal_year[fiscal_year] between 2009-2024
applied at "Filters on this page" so every visual inherits — no
per-visual fiscal_year filter needed.

**What was tried and dropped in session 6:**

- Stacked area with 11 sectors — bands at similar magnitudes,
  indistinguishable; legend wrap consumed more space than the chart.
- 11-sector small multiples grid — panel sizes ≤80×165 px crushed
  readability; sector titles failed to render reliably across PBI
  Desktop variants.
- Net margin heatmap matrix — 11×16 cells at half-canvas width too
  cramped; values clashed with color encoding.

The single Row 2 line chart with sector legend carries the
per-sector margin story interactively.

### 3.3 Page 3 — Peer Benchmarking

**Source mart.** mart_peer_benchmark (~29,900 rows, peer-stat columns
already pre-computed in dbt — peer_count, peer_mean_value,
peer_median_value, peer_rank within sector).

**Visual budget: 3 visuals + footer.**

**What makes this distinctive:**

- Bubble scatter — revenue (X) × net margin (Y), bubble size = assets,
  color = gics_sector. One visual encoding 4 dimensions per company
  across the universe.
- Sector benchmark bar — per-sector mean revenue (or margin) with a
  constant line at the S&P 100 universe median. Tells which sectors
  over/underperform the universe baseline.
- Within-sector top 5 — horizontal bar of the top 5 companies in the
  currently selected sector (via Sector slicer). When sector = All,
  shows top 5 across the universe.

**Layout (3 visuals + footer):**

- Header: title + Date Range slicer + Sector slicer.
- Row 1: Bubble scatter (full width or ~70%, depending on layout).
- Row 2: Sector benchmark bar (~50%) + Within-sector top 5 (~50%).
- Footer: caveat.

**What was dropped from v1:**

- Sector-vs-S&P-100 radial gauges — 3 sub-visuals consuming visual
  budget; sector benchmark bar with constant line carries the same
  story in one container.
- Peer rank distribution histogram — analyst marginal value vs the
  ranking story already in the bubble + top-5 bar.
- Custom tooltip page — defers; default PBI tooltip on bubble entries
  carries the company-snapshot story adequately for the portfolio
  audience.

### 3.4 Page 4 — Financial Health (shipped session 8, 2026-06-03)

**Source mart.** mart_financial_health (~10,600 rows, 9 canonicals
pivoted + 8 NULLIF-guarded derived ratios — gross_margin,
operating_margin, net_margin, return_on_assets, return_on_equity,
debt_to_equity, operating_cf_margin, cash_to_assets). Note: the dbt
mart's actual 8 ratios are NOT the 8 the original spec assumed (spec
had aspirational current_ratio + asset_turnover; mart has
operating_margin + operating_cf_margin in those slots). Always verify
column names from the dbt model source, not the spec.

**Visual budget: 3 visuals + footer** (shipped). Page is sector-level
financial health; per-company depth = Page 6 drill-through.

**What makes this distinctive (as shipped):**

- 8-ratio sector-vs-S&P 100 Matrix — Rows = 8 ratios, Values columns =
  Sector Ratio Value / S&P 100 Ratio Value / Δ. Traffic-light
  conditional formatting driven by Δ Direction helper measure that
  inverts the sign for D/E row (lower debt = healthier).
- Sector net income rank movement ribbon chart — brand-new viz idiom
  across the report. 11 sectors as 11 ribbons flowing across
  2009-2024, vertically reordered by rank at each year. Tells "Tech
  overtook Financials around 2018" stories visually. Strong static-
  screenshot presentation. Swapped in mid-build from spec v3's
  Decomposition tree (which failed both static-presentation and
  measure-context tests; see §3.4 dropped items).
- Sector health trajectory line — 3 ratios (Net margin, ROE, ROA) on
  shared % axis for selected sector over 2009-2024. DIVIDE/SUM
  pattern (NOT AVERAGE — the spec's AVERAGE pattern caused a −2000%
  spike at 2014-2015 from per-company small-denominator explosions).

**Layout (as shipped):**

- Header: title + Date Range slicer + Sector slicer (both synced from
  Page 1).
- Row 1: 8-ratio Matrix (~50% left) + Sector health trajectory
  (~50% right).
- Row 2: Sector net income ribbon chart (full width).
- Footer: caveat.

**Filter strategy (corrected during build).** No page-level
fiscal_year filter. Visual-level filters per visual:
- V1 Matrix: fiscal_year = 2024.
- V2 Ribbon: fiscal_year between 2009 and 2024.
- V3 Trajectory: fiscal_year between 2009 and 2024.

PBI mechanics gotcha: visual filters INTERSECT page filters, they
don't override. Original v3 plan (page-level FY=2024 with V3 visual-
level override) was incompatible with V2/V3 needing 2009-2024.

**Helpers required (as-shipped build order):**

1. Ratio Names — 8-row helper table (dbt-actual ratio names).
2. Sector Ratio Value — SWITCH on Ratio Names[Ratio], AVERAGE pattern
   at sector scope.
3. S&P 100 Ratio Value — `CALCULATE([Sector Ratio Value],
   REMOVEFILTERS(dim_company))` for universe scope.
4. Δ Ratio Value — subtraction.
5. Δ Direction — inverts D/E for traffic-light rules.
6. Sector ROE + Sector ROA — DIVIDE/SUM on mart_financial_health
   (NOT AVERAGE).
7. Sector Net Income — `SUM(mart_financial_health[net_income])` for
   V2 ribbon Y-axis.

**What was dropped from v1 / v2 / during-build:**

- v1 Decomposition tree on Total Revenue — revenue size/composition,
  not a health story.
- v2 Treemap of sector members — Page 1 already ships a Treemap.
- v3 spec Decomposition tree on Net Margin — swapped to ribbon chart
  during build. Failed static-presentation (landing state is a single
  block) and measure-context tests (REMOVEFILTERS in S&P 100 Net
  Margin broke drill context — every node returned 0.16).
- v1 8-gauge grid — 8 sub-visuals exceeds budget.
- v1 Health heatmap — redundant with the Matrix; fragile in PBI
  Desktop at 8×10 cells.
- v1 current_ratio + asset_turnover ratios — never existed in dbt
  mart. Replaced with operating_margin + operating_cf_margin (the
  actual columns).
- Page-level fiscal_year filter — PBI mechanics incompatible with
  per-visual fiscal_year needs. Visual-level filters per visual
  instead.

### 3.5 Page 5 — Growth/Forecast (shipped session 9, 2026-06-04)

> **AS-SHIPPED.** Modified v2: line+CI hero + KPI strip + acceleration
> scatter + Top 10 forecast-CAGR bar. The forecast bridge waterfall was
> dropped at the data-veto (real sector deltas net negative — IT −$656bn
> is a univariate structural-break artifact, not real). Full as-shipped
> detail: COPILOT_SPEC §9. Root cause + measure inventory:
> POWERBI_PAGE5_AUDIT.md.

**Source mart.** mart_growth_forecast. Discriminator is `row_kind`
('historical' | 'forecast'). Historical leg carries `value_numeric`;
forecast leg carries `forecast_value` + `lower_ci_95` / `upper_ci_95` +
`model_name` / `model_aic` + `latest_historical_year` (forecast rows
only). `scripts/forecast.py` forecasts each company's latest_year+1..+3,
so forecast rows span many calendar years across cohorts.

**Visual budget: 4 containers (V1 trajectory + KPI strip + scatter +
bar).** Slicers / footer don't count.

**The two things that made this hard (both now standing locks):**

- **Cohort lock.** A raw calendar-year `SUM(forecast_value)` smears
  across per-company horizons. Lock every forecast measure to
  `latest_historical_year = 2024` for one consistent panel (~half the
  index by revenue; ~half the S&P 100 already filed FY2025). Clean line +
  clean CI fan that reconciles with the KPIs.
- **No axis-column filter inside CALCULATE** (§2.9). Gate the year window
  with `IF(SELECTEDVALUE(fiscal_year) ...)` OUTSIDE `CALCULATE`; pin the
  snapshot with `ALL()`. This was the flat-$102.8T-line bug.

**As-shipped visuals:**

- V1 line chart, X = fiscal_year (ascending), four measures: Revenue
  Historical Line (solid blue), Revenue Forecast Line (dashed green,
  anchored at 2024 so it joins), Forecast Lower/Upper CI (light grey
  dashed, anchored at 2024 → band fans from the anchor).
- KPI strip "Forecast Highlights" — a smart-narrative box copied from the
  P&L page (not 6 text boxes). 3-yr forecast CAGR (3.5%), Forecast
  revenue 2027 ($6.6T via a text measure — smart narrative has no
  Trillions unit), Forecast ±95% range (25%).
- V2 acceleration scatter — Historical CAGR × Forecast CAGR, sized by
  revenue, coloured by sector.
- V3 Top 10 forecast-CAGR horizontal bar (Top N = 10).

**Risk 56 / Risk 60 disclosure.** Folded into the footer (no separate
caveat boxes — canvas at budget; the title already states cohort + 95%
CI). Footer appends: "Forecasts exclude spinoffs/divestitures (e.g. GE,
3M)". Audit 9's structural-break outliers (GE/3M) are the reason the
waterfall was vetoed and the reason for this disclosure.

**Slicers.** Sector (synced from Page 1) + Entity (`entity_name`, Single
select OFF + Show "Select all" ON → defaults to All, click one to focus).

**Owed (session 11 QA):** retire the revenue-trajectory measure sprawl —
POWERBI_PAGE5_AUDIT.md §4.

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

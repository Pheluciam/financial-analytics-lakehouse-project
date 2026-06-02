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

### 3.4 Page 4 — Financial Health

**Source mart.** mart_financial_health (~10,600 rows, 9 canonicals
pivoted + 8 NULLIF-guarded derived ratios — gross_margin, net_margin,
current_ratio, debt_to_equity, ROA, ROE, asset_turnover, cash_to_assets).

**Visual budget: 4 visuals + footer** (deepest analytical view in the
report, full budget used).

**What makes this distinctive:**

- Decomposition tree (PBI native AI visual) — drill Total Revenue →
  Sector → Industry Group → Company. Auto-picks next dimension.
- 8-ratio comparison Matrix — Rows = 8 ratios, Values columns =
  Selected Company / Sector Mean / S&P 100 Mean. Traffic-light
  conditional formatting per row (each ratio's domain differs).
  Single container replaces v1's 4×2 gauge grid (which was 8
  sub-visuals — over budget).
- Selected ratio trajectory line — chosen ratio (via Ratio slicer)
  over 10 years for selected company + sector mean overlay.
- Sector ratio ranking bar — one bar per sector for the selected
  ratio, sorted desc.

**Layout (4 visuals + footer):**

- Header: title + Sector slicer + Entity slicer (search-as-you-type)
  + Ratio slicer.
- Row 1: Decomposition tree (~50%) + 8-ratio comparison Matrix (~50%).
- Row 2: Selected ratio trajectory line chart (full width).
- Row 3: Sector ratio ranking bar (full width).
- Footer: caveat.

**Helpers required:**

- Ratio Selector — disconnected helper table (8 rows, ratio name + sort)
  driving the Ratio slicer.
- Selected Ratio Value — SWITCH measure that returns the
  selected-ratio column from mart_financial_health based on
  SELECTEDVALUE('Ratio Selector'[Ratio]).
- Sector Mean / S&P 100 Mean comparison measures using
  REMOVEFILTERS(dim_company) at the relevant scope.

**What was dropped from v1:**

- 8-gauge grid — 8 sub-visuals exceeds budget; collapsed into the
  single 8-ratio Matrix.
- Health heatmap — redundant with the Matrix; 8×10 per-row conditional
  formatting was fragile in PBI Desktop.

### 3.5 Page 5 — Growth/Forecast

**Source mart.** mart_growth_forecast (~10,100 rows — historical +
forecast, 98 companies × 3 forecast years, plus model metadata:
model_name, model_aic, historical_obs_count).

**Visual budget: 3 visuals + footer + 2 risk caveat text boxes**
(caveats are text strips, not visual containers).

**What makes this distinctive:**

- Historical + forecast trajectory with 95% CI band — solid historical
  line transitioning into dashed forecast line, with translucent CI
  band (lower_ci_95 → upper_ci_95) shaded behind the forecast portion.
  PBI's area chart layered under a line chart.
- KPI callouts panel — 3 text boxes (3-year forecast CAGR, forecast
  vs historical YoY, average model AIC). Same dynamic-value pattern
  as Page 2 §6.5. Average model AIC absorbs the v1 Model metadata
  panel's transparency story in one number.
- Top 10 forecasted growth ranking — horizontal bar chart of top 10
  companies by projected 3-year revenue CAGR.

**Risk 56 caveat (text strip near Row 1):** forecast horizons vary
per company — companies with FY2024 latest forecast FY2025-2027;
companies with FY2025 latest forecast FY2026-2028.

**Risk 60 caveat (text strip lower-left of Row 2):** structural events
(spinoffs, divestitures, M&A) not modeled. Post-divestiture filers
like GE (2024 separations) and 3M (2024 divestitures) interpret
accordingly. Audit 9 confirmed 3 outlier forecast rows (GE 2027 0.42x,
MMM 2026 0.42x, MMM 2027 0.13x). Univariate models can't distinguish
one-time structural step-downs from continuing trends; explicit
viewer caveat is the documented mitigation pending intervention
analysis / structural-break detection in a future enhancement.

**Layout (3 visuals + footer + 2 caveat boxes):**

- Header: title + Sector slicer + Entity slicer.
- Row 1: Historical + forecast trajectory with CI band (~2/3 width)
  + KPI callouts (~1/3).
- Row 2: Top 10 forecasted growth bar (full width) + Risk 60 caveat
  (small text strip overlay).
- Risk 56 caveat: small text strip below Row 1 title area.
- Footer: caveat strip.

**What was dropped from v1:**

- Per-sector forecast small multiples — same 11-panel crowding issue
  that Page 2 hit. Sector cross-cut now via Sector slicer + Row 1
  chart.
- Model metadata panel (per-company model_name + AIC + obs_count
  table) — analyst-facing page over budget; summarized via Average
  model AIC KPI callout.

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

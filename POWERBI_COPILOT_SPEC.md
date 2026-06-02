# Power BI Build Spec — S&P 100 Financial Analytics Dashboard

> Self-contained spec for Power BI Copilot. Attach this file alongside `powerbi/financial_analytics.pbix` and ask Copilot to build the visuals per the specifications below.
>
> Project context: portfolio-grade Power BI report consuming an AWS-native Iceberg lakehouse (Athena via ODBC). Marts are pre-built in dbt; PBI is consumption-only via Import mode. Six pages — five analytical themes + one drill-through detail page.
>
> Date built against: 2026-06-01 forward as_of_date snapshot.

---

## 1. Data model overview

The .pbix imports six tables via the Amazon Athena ODBC v2 driver (Windows System DSN `FinancialAnalyticsAthena`, `~/.aws/credentials [phil-dbt]` profile). Each table is loaded via a Power Query SELECT statement, not Navigator.

### 1.1 Loaded tables

| Table | Source | Grain | Row count (approx) |
|---|---|---|---|
| `mart_pl_trend` | `financial_analytics_silver.mart_pl_trend` | (cik, as_of_date, fiscal_year, canonical_concept) | ~21,400 |
| `mart_peer_benchmark` | `financial_analytics_silver.mart_peer_benchmark` | (cik, as_of_date, fiscal_year, canonical_concept) | ~29,900 |
| `mart_financial_health` | `financial_analytics_silver.mart_financial_health` | (cik, as_of_date, fiscal_year) | ~10,600 |
| `mart_growth_forecast` | `financial_analytics_silver.mart_growth_forecast` | (cik, fiscal_year) — historical + forecast | ~10,100 |
| `dim_company` | `financial_analytics_silver.sp100_company_sector` | 1 row per CIK in S&P 100 universe | 107 |
| `dim_as_of_dates` | `financial_analytics_silver.dim_as_of_dates` | 1 row per snapshot date | 11 |

Plus five Power BI-internal tables:

- `_Measures` — hidden single-row table that hosts all DAX measures. No data, just a placeholder column `Column1` (hidden).
- `KPI Lookup` — DAX-defined helper table for the Page 1 KPI matrix. 4 rows. Columns: KPI (STRING), Sort (INTEGER).
- `fiscal_year_dim` — DAX-defined conformed fiscal_year dimension. Built from `DISTINCT(mart_pl_trend[fiscal_year])`. Single column `fiscal_year` (INTEGER). 16 rows for the current data window.
- `KPI Fiscal Year Bridge` — DAX-defined many-to-many bridge from KPI Lookup to fiscal_year_dim. Built from `CROSSJOIN(SELECTCOLUMNS('KPI Lookup', "KPI", 'KPI Lookup'[KPI]), SELECTCOLUMNS(fiscal_year_dim, "fiscal_year", fiscal_year_dim[fiscal_year]))`. 64 rows (4 KPIs × 16 fiscal years). Columns: KPI (STRING), fiscal_year (INTEGER).
- `Calc groups` — none. Calculation groups not in use.

The fiscal_year_dim + KPI Fiscal Year Bridge pair solves the disconnected-helper-vs-sparkline issue (see §4.2). They are also the canonical fiscal_year axis for all other pages — see §4.3 for the recommended fiscal_year_dim relationships to add for Pages 2-5.

### 1.2 Power Query SELECT statements per table

Each table is loaded with an explicit column list (not `SELECT *`) for stable contracts. Paste these into each table's Source step "SQL statement" field in Power Query.

**mart_pl_trend** —

```sql
SELECT cik, entity_name, as_of_date, fiscal_year, canonical_concept, value_numeric, period_end_date, yoy_pct, yoy_rank FROM financial_analytics_silver.mart_pl_trend
```

**mart_peer_benchmark** —

```sql
SELECT cik, entity_name, as_of_date, fiscal_year, canonical_concept, value_numeric, peer_count, peer_mean_value, peer_median_value, peer_stddev_value, peer_min_value, peer_max_value, peer_rank, peer_percentile FROM financial_analytics_silver.mart_peer_benchmark
```

**mart_financial_health** —

```sql
SELECT cik, entity_name, as_of_date, fiscal_year, revenue, cost_of_revenue, gross_profit, operating_income, net_income, assets, liabilities, stockholders_equity, operating_cash_flow, cash_and_equivalents, gross_margin, net_margin, current_ratio, debt_to_equity, return_on_assets, return_on_equity, asset_turnover, cash_to_assets FROM financial_analytics_silver.mart_financial_health
```

**mart_growth_forecast** —

```sql
SELECT cik, entity_name, fiscal_year, series_type, value_numeric, lower_ci_95, upper_ci_95, model_name, model_aic, historical_obs_count FROM financial_analytics_silver.mart_growth_forecast
```

`series_type` is either `historical` or `forecast`.

**dim_company** —

```sql
SELECT cik, entity_name, ticker, gics_sector, gics_industry_group FROM financial_analytics_silver.sp100_company_sector
```

**dim_as_of_dates** —

```sql
SELECT as_of_date FROM financial_analytics_silver.dim_as_of_dates
```

### 1.3 Storage mode

All 6 imported tables are in pure Import mode (Risk 53 documented decision — total row count <100K, DirectQuery/Dual overhead not warranted). The 2 helper tables (_Measures, KPI Lookup) are DAX-defined and therefore Import by construction.

### 1.4 Relationships

Eleven active relationships in the current model — eight original fact→dim joins plus three from the Page 1 sparkline bridge pattern. All many-to-one, single-direction cross-filter.

| From | From column | To | To column | Active | Source |
|---|---|---|---|---|---|
| mart_pl_trend | cik | dim_company | cik | Yes | Session 1 |
| mart_pl_trend | as_of_date | dim_as_of_dates | as_of_date | Yes | Session 1 |
| mart_pl_trend | fiscal_year | fiscal_year_dim | fiscal_year | Yes | Session 5 (bridge) |
| mart_peer_benchmark | cik | dim_company | cik | Yes | Session 1 |
| mart_peer_benchmark | as_of_date | dim_as_of_dates | as_of_date | Yes | Session 1 |
| mart_financial_health | cik | dim_company | cik | Yes | Session 1 |
| mart_financial_health | as_of_date | dim_as_of_dates | as_of_date | Yes | Session 1 |
| mart_growth_forecast | cik | dim_company | cik | Yes | Session 1 |
| KPI Fiscal Year Bridge | KPI | KPI Lookup | KPI | Yes | Session 5 (bridge) |
| KPI Fiscal Year Bridge | fiscal_year | fiscal_year_dim | fiscal_year | Yes | Session 5 (bridge) |

`KPI Lookup` is now indirectly connected via the bridge — it provides row context for the Page 1 SWITCH measures and the bridge propagates that context to mart_pl_trend via fiscal_year_dim.

**Recommended addition for Pages 2-5 (not yet built):** add relationships from the other three marts to fiscal_year_dim so the conformed dimension drives every fiscal_year axis across the report. See §4.3.

### 1.5 Theme

Power BI Desktop built-in **Executive** theme. Navy / teal / muted accent palette. Reproduces well in PDF exports and GitHub README screenshots.

---

## 2. Standing conventions

These apply to every page and every measure.

### 2.1 _Measures hidden table

All DAX measures live on the `_Measures` table. Never on the fact or dim tables. Standard discipline pattern per SQLBI / Marco Russo.

The placeholder column `_Measures[Column1]` is hidden. The table itself stays visible (otherwise the measures hide too).

### 2.2 Latest Complete FY pattern

Every "Latest FY" measure uses a self-correcting threshold: pick the latest fiscal_year where ≥80 of 107 S&P 100 companies have reported the relevant canonical concept at the latest as_of_date. Auto-advances as newer fiscal years fill in.

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

### 2.3 Footer caveat strip

Every page carries this exact text in a footer text box at the bottom (small font, muted color):

```
Source: SEC EDGAR XBRL  |  Universe: S&P 100 (107 companies)  |  FY2024 coverage: 106 of 107  |  Snapshot: 2026-06-01
```

The "106 of 107" reflects the known Risk 55 data quality limitation — 1 of 107 S&P 100 companies (Financials sector) lacks a mapped revenue tag in the current canonical dictionary. Deferred fix.

### 2.4 Number formatting

- Currency (large): `$0.0` then concatenate "T" or "B" suffix. Use explicit DAX division `/ 1000000000000` for trillions, `/ 1000000000` for billions. Don't rely on FORMAT() comma-scaler — it's unreliable in DAX.
- Percentages: `"0.0%"`.
- Whole counts: `"#,0"`.

### 2.5 Drill-through

Every page that shows company-level data must support right-click drill-through to Page 6 Company Detail. Drill-through field = `dim_company[entity_name]`. See §8 for Page 6 setup.

---

## 3. Measures — existing and new

Build these on the `_Measures` table. List ordered alphabetically; build order doesn't matter except for dependencies noted inline.

### 3.1 Existing measures (from Phase 5 session 1 v1)

**Total Revenue (Latest FY)**

```dax
Total Revenue (Latest FY) = 
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
RETURN
    CALCULATE(
        SUM(mart_pl_trend[value_numeric]),
        mart_pl_trend[as_of_date] = LatestSnapshot,
        mart_pl_trend[fiscal_year] = LatestCompleteFY,
        mart_pl_trend[canonical_concept] = "revenue"
    )
```

Format: Currency, 1 decimal, thousands separator.

**Total Net Income (Latest FY)** — same shape as Total Revenue but `canonical_concept = "net_income"`. Format: Currency, 1 decimal, thousands separator.

**Net Margin (Latest FY)** —

```dax
Net Margin (Latest FY) = 
DIVIDE([Total Net Income (Latest FY)], [Total Revenue (Latest FY)])
```

Format: Percentage, 1 decimal.

**Revenue YoY %** —

```dax
Revenue YoY % = 
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
VAR CurrentRev = 
    CALCULATE(
        SUM(mart_pl_trend[value_numeric]),
        mart_pl_trend[as_of_date] = LatestSnapshot,
        mart_pl_trend[fiscal_year] = LatestCompleteFY,
        mart_pl_trend[canonical_concept] = "revenue"
    )
VAR PriorRev = 
    CALCULATE(
        SUM(mart_pl_trend[value_numeric]),
        mart_pl_trend[as_of_date] = LatestSnapshot,
        mart_pl_trend[fiscal_year] = LatestCompleteFY - 1,
        mart_pl_trend[canonical_concept] = "revenue"
    )
RETURN
    DIVIDE(CurrentRev - PriorRev, PriorRev)
```

Format: Percentage, 1 decimal.

**Revenue Trend / Revenue Historical / Revenue Forecast** — internal helper measures used in Page 5 forecast visualization. See §7 for details.

### 3.2 New measures (this session)

**Sector Revenue** — total revenue at the latest complete FY for the current sector filter context. Drives the Page 1 treemap.

```dax
Sector Revenue = 
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
RETURN
    CALCULATE(
        SUM(mart_pl_trend[value_numeric]),
        mart_pl_trend[as_of_date] = LatestSnapshot,
        mart_pl_trend[fiscal_year] = LatestCompleteFY,
        mart_pl_trend[canonical_concept] = "revenue"
    )
```

Format: Currency, 1 decimal, thousands separator.

**Revenue YoY Rank** — picks the pre-computed `yoy_rank` value from mart_pl_trend at the latest complete FY for revenue. Drives the Page 1 Top 5 gainers visual.

```dax
Revenue YoY Rank = 
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
RETURN
    CALCULATE(
        MAX(mart_pl_trend[yoy_rank]),
        mart_pl_trend[as_of_date] = LatestSnapshot,
        mart_pl_trend[fiscal_year] = LatestCompleteFY,
        mart_pl_trend[canonical_concept] = "revenue"
    )
```

Format: Whole Number.

**Revenue YoY Pct** — picks the pre-computed `yoy_pct` from mart_pl_trend. Drives the bar length / label on Top 5 gainers and decliners.

```dax
Revenue YoY Pct = 
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
RETURN
    CALCULATE(
        AVERAGE(mart_pl_trend[yoy_pct]),
        mart_pl_trend[as_of_date] = LatestSnapshot,
        mart_pl_trend[fiscal_year] = LatestCompleteFY,
        mart_pl_trend[canonical_concept] = "revenue"
    )
```

Format: Percentage, 1 decimal.

---

## 4. KPI Lookup helper table (for Page 1)

Disconnected helper table that drives the KPI matrix Table visual on Page 1. Create via Modeling → New table → paste:

```dax
KPI Lookup = 
DATATABLE(
    "KPI", STRING,
    "Sort", INTEGER,
    {
        {"Total revenue", 1},
        {"Total net income", 2},
        {"Net margin", 3},
        {"Revenue YoY %", 4}
    }
)
```

After creating: in the Data pane, select KPI Lookup → KPI column → Column tools tab → Sort by column → pick Sort. This makes the table sort by the numeric Sort column whenever KPI is displayed.

### 4.1 KPI Latest measure

```dax
KPI Latest = 
SWITCH(SELECTEDVALUE('KPI Lookup'[KPI]),
    "Total revenue",    FORMAT([Total Revenue (Latest FY)] / 1000000000000, "$0.0") & "T",
    "Total net income", FORMAT([Total Net Income (Latest FY)] / 1000000000000, "$0.0") & "T",
    "Net margin",       FORMAT([Net Margin (Latest FY)], "0.0%"),
    "Revenue YoY %",    FORMAT([Revenue YoY %], "0.0%")
)
```

Returns text. PBI auto-detects format as Text.

### 4.2 KPI Sparkline — bridge pattern (working, banked from Copilot pass)

The native PBI sparkline-in-table feature needs an active relationship path between the row-context dimension (KPI Lookup[KPI]) and the X-axis dimension (fiscal_year). A purely disconnected KPI Lookup does NOT work. The pattern that Copilot resolved during the Page 1 build:

**Two new helper tables + one new relationship into mart_pl_trend.**

**Helper table — `fiscal_year_dim`** (conformed fiscal_year dimension):

```dax
fiscal_year_dim = 
DISTINCT(mart_pl_trend[fiscal_year])
```

Single column: `fiscal_year` (INTEGER). 16 rows for the current data window.

**Helper table — `KPI Fiscal Year Bridge`** (4 KPIs × 16 fiscal_years cartesian product):

```dax
KPI Fiscal Year Bridge = 
CROSSJOIN(
    SELECTCOLUMNS('KPI Lookup', "KPI", 'KPI Lookup'[KPI]),
    SELECTCOLUMNS(fiscal_year_dim, "fiscal_year", fiscal_year_dim[fiscal_year])
)
```

64 rows. Two columns: `KPI` (STRING), `fiscal_year` (INTEGER).

**Relationships to add** (Modeling → Manage relationships → New):

- `KPI Fiscal Year Bridge[KPI]` → `KPI Lookup[KPI]`, many-to-one, Active.
- `KPI Fiscal Year Bridge[fiscal_year]` → `fiscal_year_dim[fiscal_year]`, many-to-one, Active.
- `mart_pl_trend[fiscal_year]` → `fiscal_year_dim[fiscal_year]`, many-to-one, Active.

The filter path is then: KPI Lookup → bridge → fiscal_year_dim ← mart_pl_trend. Both KPI and fiscal_year filter contexts reach mart_pl_trend through this path.

**KPI Sparkline measure** (the working formula):

```dax
KPI Sparkline = 
VAR KPIName = MAX('KPI Fiscal Year Bridge'[KPI])
VAR FY = MAX('KPI Fiscal Year Bridge'[fiscal_year])
RETURN
SWITCH(
    KPIName,
    "Total revenue",
        CALCULATE(
            SUM(mart_pl_trend[value_numeric]),
            mart_pl_trend[canonical_concept] = "revenue",
            mart_pl_trend[fiscal_year] = FY
        ),
    "Total net income",
        CALCULATE(
            SUM(mart_pl_trend[value_numeric]),
            mart_pl_trend[canonical_concept] = "net_income",
            mart_pl_trend[fiscal_year] = FY
        ),
    "Net margin",
        DIVIDE(
            CALCULATE(
                SUM(mart_pl_trend[value_numeric]),
                mart_pl_trend[canonical_concept] = "net_income",
                mart_pl_trend[fiscal_year] = FY
            ),
            CALCULATE(
                SUM(mart_pl_trend[value_numeric]),
                mart_pl_trend[canonical_concept] = "revenue",
                mart_pl_trend[fiscal_year] = FY
            )
        ),
    "Revenue YoY %",
        CALCULATE(
            AVERAGE(mart_pl_trend[yoy_pct]),
            mart_pl_trend[canonical_concept] = "revenue",
            mart_pl_trend[fiscal_year] = FY
        )
)
```

Note: this formula reads KPI + fiscal_year from the bridge table (not from KPI Lookup or fiscal_year_dim directly). That's the key insight — the bridge provides BOTH dimensions in a single row context, which the sparkline engine can iterate over.

**Adding the sparkline to the table visual:**

- Drop `KPI Lookup[KPI]`, `KPI Latest`, `KPI Sparkline` into the Table visual's Columns field well.
- Click the dropdown arrow next to KPI Sparkline → Add a sparkline → X-axis = `fiscal_year_dim[fiscal_year]` → Create.

### 4.3 fiscal_year_dim as conformed dimension across all pages

Now that `fiscal_year_dim` exists as a relationship target, USE IT instead of `mart_pl_trend[fiscal_year]` directly for any X-axis or row dimension on Pages 2, 3, 4, 5, 6 that needs fiscal_year. The conformed dimension cross-filters all four marts consistently if relationships are added:

- `mart_peer_benchmark[fiscal_year]` → `fiscal_year_dim[fiscal_year]`.
- `mart_financial_health[fiscal_year]` → `fiscal_year_dim[fiscal_year]`.
- `mart_growth_forecast[fiscal_year]` → `fiscal_year_dim[fiscal_year]`.

Add these three relationships before building Pages 2-5.

---

## 5. Page 1 — Executive Overview

### 5.1 Purpose

S&P 100 financial executive overview at the latest snapshot. Cross-cutting KPI strip + annotated revenue trajectory + sector breakdown + top movers + drill-through to company detail.

### 5.2 Page-level slicers (top-right)

- Slicer 1 — `dim_company[gics_sector]`. Style: dropdown. Default: All.
- Slicer 2 — `dim_as_of_dates[as_of_date]`. Style: dropdown. Default: latest.

### 5.3 Row 1 — KPI matrix table (full width, ~120px tall)

Visual: **Table** (not Matrix).

Field wells (in this exact order, left to right):
- `KPI Lookup[KPI]`
- `[KPI Latest]`
- `[KPI Sparkline]`

Then add the sparkline: click the dropdown arrow next to KPI Sparkline in the Columns well → Add a sparkline → X-axis = `fiscal_year_dim[fiscal_year]` → Create. This adds a fourth column "KPI Sparkline by fiscal_year" to the visual.

Polish (in order):
1. **Sort the rows** — click the visual → "..." More options → Sort axis → KPI Lookup → KPI → Sort ascending. Rows reorder to Total revenue / Total net income / Net margin / Revenue YoY % (the Sort by Column setting on KPI Lookup[KPI] uses the numeric Sort column under the hood).
2. **Hide the Total row** — Format pane → Totals → toggle Off.
3. **Hide the KPI Sparkline numeric column** — the sparkline depends on the underlying numeric column being in the field well, so DO NOT remove KPI Sparkline from the Columns well. Instead: Format pane → Specific column → pick KPI Sparkline → either "Hide column" toggle if available, or set Width to a very small value (e.g. 1px) so it's effectively invisible while still feeding the sparkline.
4. **Hide the table column headers** (optional, for a cleaner look) — Format pane → Column headers → Off.

End-state visible columns:
- KPI (text)
- KPI Latest ($9.9T / $1.5T / 14.9% / 6.5%)
- KPI Sparkline by fiscal_year (the mini line chart per row)

### 5.4 Row 2 — Annotated revenue trajectory (~2/3 width)

Visual: **Line chart**.

Field wells:
- X-axis: `mart_pl_trend[fiscal_year]`.
- Y-axis: `[Total Revenue (Latest FY)]` measure — BUT this returns the latest FY only. For the trajectory across years, use a helper measure `Revenue All Years`:

```dax
Revenue All Years = 
CALCULATE(
    SUM(mart_pl_trend[value_numeric]),
    mart_pl_trend[canonical_concept] = "revenue",
    mart_pl_trend[as_of_date] = MAX(mart_pl_trend[as_of_date])
)
```

Use `[Revenue All Years]` as the Y-axis measure for the line chart.

Filters (visual level):
- `mart_pl_trend[fiscal_year]` is on or between 2009 and 2024.

Format — reference lines and shaded regions (Analytics pane):
- **COVID shading**: shaded region from FY2020 to FY2020 (or FY2019.5 to FY2020.5 if shaded region supports partial-year). Fill: light pink/coral, low opacity. Label: "COVID-19".
- **ASC 606 marker**: constant vertical line at fiscal_year = 2018. Color: dashed pink. Label: "ASC 606 (FY2018)" — when companies adopted the new revenue recognition standard.
- **2008-2009 recession band**: shaded region from FY2009 to FY2009. Light gray, low opacity. Label: "Global financial crisis".

Title: "Revenue trajectory FY2009-2024 with structural overlays".

### 5.5 Row 2 — Sector treemap (~1/3 width)

Visual: **Treemap**.

Field wells:
- Category: `dim_company[gics_sector]`.
- Values: `[Sector Revenue]`.

Format:
- Data labels: show category name + value.
- Color: by category (Power BI default categorical palette).

Title: "Revenue by sector (latest FY)".

### 5.6 Row 3 — Top 5 gainers + Top 5 decliners (split 50/50)

Two **Bar chart (clustered horizontal)** visuals side by side.

**Left — Top 5 gainers:**
- Y-axis: `dim_company[ticker]`.
- X-axis: `[Revenue YoY Pct]`.
- Filters (visual level): Top N filter on `dim_company[ticker]` by `[Revenue YoY Rank]`, Top 5.
- Color: green (use the success color from the Executive theme).
- Data labels: ON, format as percentage with 1 decimal.
- Title: "Top 5 revenue YoY gainers (latest FY)".

**Right — Top 5 decliners:**
- Y-axis: `dim_company[ticker]`.
- X-axis: `[Revenue YoY Pct]`.
- Filters (visual level): Top N filter on `dim_company[ticker]` by `[Revenue YoY Pct]` ascending (so the most negative YoY ends up in Top N).
- Color: red.
- Data labels: ON, format as percentage with 1 decimal.
- Title: "Top 5 revenue YoY decliners (latest FY)".

Both visuals: enable right-click drill-through to Page 6 (Company Detail). Add drill-through field `dim_company[entity_name]` at the page level on Page 6.

### 5.7 Footer

Text box (full width, bottom of canvas), small font, muted color:

```
Source: SEC EDGAR XBRL  |  Universe: S&P 100 (107 companies)  |  FY2024 coverage: 106 of 107  |  Snapshot: 2026-06-01
```

### 5.8 Title

Text box at top: "S&P 100 financial executive overview". Font: 18px, weight 500.

---

## 6. Page 2 — P&L Trend Deep-Dive

### 6.1 Purpose

15-year P&L trend analysis: revenue + net income trajectories, sector composition over time, per-sector small multiples, margin heatmap.

### 6.2 Slicers (top of page)

- `dim_company[gics_sector]` — multi-select dropdown.
- `mart_pl_trend[fiscal_year]` — range slider, default 2009-2024.

### 6.3 Row 1 — Dual-axis revenue + net income (~2/3 width)

Visual: **Line and clustered column chart** (combo).

Field wells:
- X-axis: `mart_pl_trend[fiscal_year]`.
- Column y-axis: `[Revenue All Years]` (defined above).
- Line y-axis: `[Net Income All Years]` (build this measure, same pattern as Revenue All Years but for net_income).

Format:
- Column: solid blue, no gradient.
- Line: solid teal, 2px stroke, marker on each data point.
- Both Y-axes visible with units in billions.

Title: "Revenue (bars) and net income (line), FY2009-2024".

### 6.4 Row 1 — KPI callouts panel (~1/3 width)

Three stacked text boxes (not Card visuals) showing:
- Best revenue year: max fiscal_year by revenue.
- Worst revenue year: min by revenue YoY %.
- Margin trend: average net_margin over the window.

Use DAX measures to drive each text-box value. Build these on _Measures:

```dax
Best Revenue Year = 
CALCULATE(MAX(mart_pl_trend[fiscal_year]),
          TOPN(1, VALUES(mart_pl_trend[fiscal_year]),
               CALCULATE(SUM(mart_pl_trend[value_numeric]),
                         mart_pl_trend[canonical_concept] = "revenue"), DESC))
```

### 6.5 Row 2 — Sector-mix stacked area chart (full width)

Visual: **Stacked area chart**.

Field wells:
- X-axis: `mart_pl_trend[fiscal_year]`.
- Y-axis: `[Revenue All Years]`.
- Legend: `dim_company[gics_sector]`.

Title: "Revenue composition by sector over time".

### 6.6 Row 3 — Per-sector small multiples (full width)

Visual: **Line chart** with PBI's Small Multiples feature.

Field wells:
- X-axis: `mart_pl_trend[fiscal_year]`.
- Y-axis: `[Revenue All Years]`.
- Small multiples: `dim_company[gics_sector]` (renders one mini chart per sector, 11 panels).

### 6.7 Row 4 — Net margin heatmap (full width)

Visual: **Matrix** with conditional formatting on cell background.

Field wells:
- Rows: `dim_company[gics_sector]`.
- Columns: `mart_pl_trend[fiscal_year]`.
- Values: `[Sector Net Margin]` (build this — same pattern as Sector Revenue but for net_margin).

Format: Conditional formatting → Background color → Color scale: red (low) → white (mid) → green (high). Domain: -0.10 to +0.30.

### 6.8 Footer

Same caveat strip as §5.7.

---

## 7. Page 3 — Peer Benchmarking

### 7.1 Purpose

Cross-company benchmarking within sectors. Bubble chart encodes 4 dimensions; sector vs S&P 100 benchmarks; top/bottom 10 within sector.

### 7.2 Sector picker (top of page)

Single-select slicer on `dim_company[gics_sector]`. Default: highest-revenue sector.

### 7.3 Row 1 — Bubble chart (~60% width)

Visual: **Scatter chart**.

Field wells:
- X-axis: Revenue measure (build a helper that pivots mart_peer_benchmark to wide format, OR use mart_financial_health's already-pivoted revenue column).
- Y-axis: Net Income measure (same source).
- Size: Assets measure.
- Legend: `dim_company[gics_industry_group]` for color.
- Details: `dim_company[entity_name]`.

Tooltip: custom tooltip page (see §7.7).

Title: "Peer benchmark: revenue × net income × assets at latest FY".

### 7.4 Row 1 — Top 10 + Bottom 10 in sector (~20% each, flanking bubble)

Two bar charts. Y-axis = ticker. X-axis = revenue. Top N filter applied.

### 7.5 Row 2 — Sector vs S&P 100 benchmark gauges (~50% width)

Three gauges showing the selected sector's mean vs the S&P 100 mean for revenue, net income, assets. Use the **Gauge visual**.

Field wells per gauge:
- Value: sector mean (use `peer_mean_value` for the appropriate canonical concept).
- Max value: S&P 100 mean.
- Min value: 0.

### 7.6 Row 2 — Peer rank distribution histogram (~50% width)

Visual: **Column chart**.
- X-axis: `mart_peer_benchmark[peer_rank]` (bucketed).
- Y-axis: count of companies.
- Filtered to selected sector.

### 7.7 Tooltip page (custom)

Create a hidden report page named "Tooltip — Company snapshot". Size: tooltip (320x240). Disable the page in the page navigation but enable as tooltip on the bubble chart's Format → General → Tooltip.

Page contents:
- Company name (text box bound to `dim_company[entity_name]`).
- 5-year mini revenue trend.
- Latest FY net margin, ROA, debt/equity.

### 7.8 Footer

Same caveat strip.

---

## 8. Page 4 — Financial Health

### 8.1 Purpose

Per-company financial health deep-dive. Decomposition tree drills from revenue → sector → company. 8-ratio gauge grid with traffic-light comparison. 10-year ratio trajectory. Health heatmap.

### 8.2 Company picker

Slicer on `dim_company[entity_name]`. Style: search-as-you-type (Slicer Format → Search → On). Single-select. Default: blank (page falls back to S&P 100 aggregate when nothing selected).

### 8.3 Row 1 — Decomposition tree (~50% width)

Visual: **Decomposition tree** (PBI built-in AI visual).

Field wells:
- Analyze: `[Total Revenue (Latest FY)]`.
- Explain by: `dim_company[gics_sector]`, `dim_company[gics_industry_group]`, `dim_company[entity_name]` (in that order).

Title: "Revenue decomposition: sector → industry group → company".

### 8.4 Row 1 — 8-ratio gauge grid (~50% width)

4×2 grid of small gauges. Each gauge shows the selected company's ratio vs sector mean vs S&P 100 mean. Traffic-light color (green/amber/red based on quartile).

Ratios (from mart_financial_health):
1. gross_margin
2. net_margin
3. current_ratio
4. debt_to_equity
5. return_on_assets
6. return_on_equity
7. asset_turnover
8. cash_to_assets

Each gauge needs a sector-mean and S&P 100-mean comparison measure. Pattern (for gross_margin):

```dax
Gross Margin Selected = 
CALCULATE(AVERAGE(mart_financial_health[gross_margin]),
          mart_financial_health[as_of_date] = MAX(mart_financial_health[as_of_date]))

Gross Margin Sector Mean = 
CALCULATE(AVERAGE(mart_financial_health[gross_margin]),
          mart_financial_health[as_of_date] = MAX(mart_financial_health[as_of_date]),
          ALL(dim_company[entity_name]))
```

(Replicate for the other 7 ratios.)

### 8.5 Row 2 — 10-year ratio trajectory (full width)

Visual: **Line chart** with multi-series toggle.

Field wells:
- X-axis: `mart_financial_health[fiscal_year]`.
- Y-axis: a switch measure that picks the ratio based on a slicer.

Build a "Ratio Selector" disconnected helper table:

```dax
Ratio Selector = 
DATATABLE("Ratio", STRING, "Sort", INTEGER,
    {
        {"Gross margin", 1},
        {"Net margin", 2},
        {"Current ratio", 3},
        {"Debt to equity", 4},
        {"Return on assets", 5},
        {"Return on equity", 6},
        {"Asset turnover", 7},
        {"Cash to assets", 8}
    }
)
```

Plus a switch measure that returns the selected ratio's per-year value.

### 8.6 Row 3 — Health heatmap (full width)

Visual: **Matrix** with conditional formatting on cells.

Field wells:
- Rows: a categorical list of the 8 ratios (build a helper table similar to Ratio Selector).
- Columns: `mart_financial_health[fiscal_year]`.
- Values: the ratio value.

Conditional formatting: traffic-light scale per row (each ratio's domain differs).

### 8.7 Footer

Same caveat strip.

---

## 9. Page 5 — Growth / Forecast

### 9.1 Purpose

Historical + forecast revenue trajectories with 95% confidence intervals. Per-sector forecast small multiples. Top forecasted growth ranking. Model metadata transparency.

### 9.2 Slicers

- `dim_company[gics_sector]` — multi-select.
- `dim_company[entity_name]` — single-select dropdown.

### 9.3 Row 1 — Historical + forecast trajectory with CI band (~2/3 width)

Visual: **Line chart** layered with **Area chart** (Area underneath, Line on top).

Field wells (Line):
- X-axis: `mart_growth_forecast[fiscal_year]`.
- Y-axis: `mart_growth_forecast[value_numeric]`.
- Legend: `mart_growth_forecast[series_type]` (historical / forecast).

Format the line:
- `historical` segment: solid blue, 2px stroke.
- `forecast` segment: dashed blue, 2px stroke.

Layer underneath: Area chart with `lower_ci_95` and `upper_ci_95` from mart_growth_forecast, light translucent fill behind the forecast portion only.

### 9.4 Row 1 — KPI callouts (~1/3 width)

Three text boxes:
- 3-year forecasted CAGR.
- Forecast vs historical YoY %.
- Average model_aic across the selected universe (model fit quality indicator).

### 9.5 Row 2 — Per-sector forecast small multiples (full width)

Same pattern as Page 2 small multiples — line chart with sector as small-multiples dimension.

### 9.6 Row 3 — Top forecasted growth ranking (~50% width)

Visual: **Bar chart**. Top N companies by 3-year forecasted revenue CAGR.

### 9.7 Row 3 — Model metadata panel (~50% width)

Visual: **Table**.
- Columns: entity_name, ticker, model_name (Holt-Winters / ARIMA), model_aic, historical_obs_count.
- Sort: by model_aic ascending (best-fit first).

### 9.8 Risk 56 forecast horizon note

Insert a text box near Row 1 reading:

```
Forecasts extend 3 years from each company's latest historical observation. Companies with FY2024 latest forecast FY2025-2027; companies with FY2025 latest forecast FY2026-2028.
```

### 9.9 Risk 60 structural shocks caveat

Insert a small text box (lower-left) reading:

```
Forecasts are 3-year Holt-Winters / ARIMA projections; structural events such as spinoffs, divestitures, and M&A are not modeled. Forecasts for post-divestiture filers like GE (2024 GE Vernova + GE HealthCare separations) and 3M (2024 fiber optics + food safety divestitures) should be interpreted accordingly.
```

### 9.10 Footer

Same caveat strip.

---

## 10. Page 6 — Company Detail (drill-through)

### 10.1 Purpose

Drill-through destination from any company on Pages 1-5. Right-click any ticker / entity_name → drill through to this page filtered to that company.

### 10.2 Drill-through configuration

In Page 6's Page settings:
- Drill through fields → add `dim_company[entity_name]`.
- "Allow drill through when" → Used as category.
- Cross-report drill through: OFF.
- Keep all filters: ON.

### 10.3 Page layout

**Row 1 — Company header (full width)**

Text boxes (not Card visuals):
- Entity name (big, 28px).
- Ticker • Sector • Industry group (medium, 14px, muted).

**Row 2 — Headline KPIs (full width, 4 slots)**

Four small Matrix visuals (1 row × 1 column each) showing the headline number. Layout:
- Revenue at latest FY.
- Net income at latest FY.
- Net margin at latest FY.
- Peer rank within sector (from mart_peer_benchmark).

**Row 3 — 15-year P&L trajectory (full width)**

Line chart: X = fiscal_year, Y = revenue and net_income (dual axis).

**Row 4 — 8 financial health ratios (full width)**

Matrix visual: rows = ratio name, columns = (Company / Sector mean / S&P 100 mean). Traffic-light formatting.

**Row 5 — 3-year forecast trajectory with CI band (full width)**

Same layered Line + Area pattern as Page 5 §9.3.

**Row 6 — Back button**

Insert a button (Insert → Buttons → Back). Action: Back. This returns the user to the source page.

### 10.4 Footer

Same caveat strip.

---

## 11. Cross-page conventions

### 11.1 Slicer sync

If a slicer should sync across all 5 main pages, configure: select slicer → View → Sync slicers → tick the destination pages.

Recommended sync setup:
- `gics_sector` slicer syncs across Pages 1-5.
- `as_of_date` slicer syncs across Pages 1-4 (Page 5 forecast doesn't snapshot the same way).
- `entity_name` slicer (Page 4 + Page 5) stays local to each page.

### 11.2 Drill-through wiring

Pages 1, 2, 3, 4, 5 all drill through to Page 6 on `dim_company[entity_name]`. Add the field to Page 6 Page settings → Drill through fields. Verify by right-clicking any company-level visual element → menu shows "Drill through → Company Detail".

### 11.3 Page navigation

Create a left-side or top-bar navigation strip (View → Buttons → Page navigator OR built-in Page navigator visual). Anchors Pages 1-5 plus a hidden Page 6.

---

## 12. Known data quality limitations

These are documented project Risks that show up in the dashboards. The footer caveat strip surfaces them at low pixel weight.

### 12.1 Risk 55 — Revenue tag mapping gap

1 of 107 S&P 100 Financials-sector company lacks a mapped revenue canonical concept in the current dbt canonical_concepts_dictionary seed. Dashboard impact: FY2024 revenue aggregate excludes that company. Deferred fix lives in dbt; PBI carries the footer caveat as the user-facing acknowledgment.

### 12.2 Risk 56 — Forecast horizon varies per company

mart_growth_forecast extends 3 years from each company's latest historical observation. The latest historical year isn't uniform — most companies have FY2024 as their latest (forecasting FY2025-2027), but 21 of 107 have FY2025 historical (forecasting FY2026-2028). Pages 1 and 5 handle this differently:
- Page 1: shows historical only, no forecast at all.
- Page 5: surfaces the per-company horizon explicitly via §9.8 note.

### 12.3 Risk 60 — Structural shocks not modeled

Univariate Holt-Winters / ARIMA forecasts can't distinguish a one-time corporate action (spinoff, divestiture, M&A) from a continuing trend. GE 2024 and 3M 2024 are known examples in the audit. Page 5 surfaces this via §9.9 caveat.

---

## 13. Build order recommended for Copilot

If asked "build the whole thing in one pass", Copilot should follow this order to avoid mid-build broken-state visuals:

1. Verify the data model (§1.4) — all 8 relationships active.
2. Verify or create all measures from §3.1 and §3.2 (on _Measures).
3. Create the KPI Lookup helper table (§4).
4. Build Page 1 visuals in order: title → slicers → KPI matrix → trajectory → treemap → top movers → footer.
5. Build Page 6 drill-through target FIRST (before wiring drill-through from Pages 1-5).
6. Build Pages 2, 3, 4, 5 in order. Each page's footer + slicers first, then visuals.
7. Wire drill-through from Pages 1-5 to Page 6 (right-click any company visual → enable drill through).
8. Add page navigation (§11.3).
9. Theme: Executive (built-in) applied at View → Themes.
10. Final pass: confirm every page has the footer caveat with the current snapshot date.

---

*Authored AI-assisted (Claude by Anthropic) for portfolio learning project — financial-analytics-lakehouse-project.*

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
- Slicer 2 — `dim_as_of_dates[as_of_date]`. Style: between slider, titled "Date Range" (matches shipped state — between mode replaced the spec's dropdown during session 5 polish for cleaner range scoping; sync chain shares state with Pages 2/3/4/5).

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

15-year P&L story: macro revenue × net income trajectory + headline year/margin callouts + per-sector net margin trend lines. 3 visual containers (combo, KPI panel, line chart). Filterable interactively by Sector slicer.

**Visual budget: 4 max per page** (project standing constraint locked session 6). Page 2 ships with 3 visuals + footer caveat.

### 6.2 Slicers (header strip)

- Date Range — `dim_as_of_date[as_of_date]` (synced from Page 1).
- Sector — `dim_company[gics_sector]` (synced from Page 1).
- Fiscal Year — `dim_fiscal_year[fiscal_year]` range slider, default 2009-2024. Page 2 only — NOT synced.

### 6.3 Page-level filter

`dim_fiscal_year[fiscal_year]` between 2009 and 2024 applied at **Filters on this page**. Every visual on the page inherits — no per-visual fiscal_year filter needed.

### 6.4 Row 1 left — Dual-axis revenue + net income combo (~2/3 width)

Visual: **Line and clustered column chart**.

Field wells:
- X-axis: `dim_fiscal_year[fiscal_year]` (conformed dim, not the raw mart column).
- Column y-axis: `[Revenue All Years]`.
- Line y-axis: `[Net Income All Years]`.

Format:
- Both Y-axes set to Display units = Trillions, Decimal places = 1.
- Y-axis titles Off (legend + tick units carry the encoding).
- Line: marker = circle, stroke 2-3px.
- Both measures renamed in this visual to "Revenue" and "Net Income" via the field-well rename (preserves the underlying measure name elsewhere).

Title: "S&P 100 revenue and net income, FY2009-2024".

### 6.5 Row 1 right — KPI callouts (~1/3 width)

Three stacked text boxes (NO Card visuals — project-level lock). Each uses the PBI text-box dynamic value feature (+ Value button on the formatting toolbar). Required field: "Name your value" (Save greys out until populated — documented PBI quirk).

| Label (above value, ~10pt grey) | Measure inserted via + Value |
|---|---|
| Best year | `[Best Revenue Year]` |
| Worst year | `[Worst Revenue Year]` |
| Avg net margin | `[Avg Net Margin]` |

Value text: 16-24pt bold black.

### 6.6 Row 2 — Net margin trend lines per sector (full width)

Visual: **Line chart**.

Field wells:
- X-axis: `dim_fiscal_year[fiscal_year]`.
- Y-axis: `[Sector Net Margin]`.
- Legend: `dim_company[gics_sector]` (11 colored lines).

Format:
- Y-axis: Display units = None, Decimal places = 1 (renders as % via measure format).
- Markers On, shape = circle.

Title: "Net margin trend by sector, FY2009-2024".

Interactivity: Sector slicer narrows to selected sectors; with All, viewer sees all 11 colored lines for cross-sector comparison.

### 6.7 What was tried and dropped (rationale for the simplification)

The earlier 4-row plan (combo + KPIs + stacked area + small multiples + heatmap) was over-dense. Tried and dropped during session 6:

- **Stacked area with 11 sectors**: 11 thin bands at similar magnitudes, indistinguishable; legend wrapped across full width.
- **11-sector small multiples grid**: panel sizes ≤80×165 px crushed readability; sector titles failed to render reliably across PBI Desktop variants.
- **Net margin heatmap matrix**: 11×16 cells at half-canvas width too cramped; cell numeric values clashed with color encoding.

Single Row 2 line chart with sector legend replaces all three: tells the per-sector margin story interactively via Sector slicer, one visual idiom only.

### 6.8 Footer

Same caveat strip as §5.7.

---

## 7. Page 3 — Peer Benchmarking

### 7.1 Purpose

Cross-company benchmarking — where each company sits within its sector, and how sectors compare to the S&P 100 universe.

**Visual budget: 3 visuals + footer.** Per project standing 4-max constraint.

### 7.2 Slicers (header strip)

- Date Range — `dim_as_of_date[as_of_date]` (synced from Page 1).
- Sector — `dim_company[gics_sector]` (synced from Page 1).

### 7.3 Row 1 — Bubble scatter (full width, ~250-300px tall)

Visual: **Scatter chart**.

Field wells:
- X-axis: revenue (per-company, use `mart_financial_health[revenue]` directly or build a per-company revenue measure).
- Y-axis: net margin (per-company `mart_financial_health[net_margin]`).
- Size: `mart_financial_health[assets]`.
- Legend: `dim_company[gics_sector]` (color by sector).
- Details: `dim_company[entity_name]`.

Visual-level filter: latest FY only (pin to `mart_financial_health[fiscal_year]` = Latest Complete FY, OR via a measure that respects the universe-level threshold).

Tooltip: default PBI tooltip with entity_name + ticker. Custom tooltip page deferred (complexity vs analyst lift).

Title: "Companies by revenue and net margin, sized by assets — latest FY".

### 7.4 Row 2 left — Sector benchmark bar (~50% width)

Visual: **Clustered bar chart** (horizontal).

Field wells:
- Y-axis: `dim_company[gics_sector]`.
- X-axis: `[Sector Net Margin]` (or `[Sector Revenue]` — pick the one that tells the cleaner ranking story).

Format: Analytics pane → Constant line at S&P 100 universe median value (reference benchmark).

Sort: descending by measure.

Title: "Sector benchmarks vs S&P 100 median".

### 7.5 Row 2 right — Within-sector top 5 (~50% width)

Visual: **Clustered bar chart** (horizontal).

Field wells:
- Y-axis: `dim_company[ticker]`.
- X-axis: `mart_financial_health[net_margin]` or `mart_financial_health[revenue]`.
- Visual filter: Top N on ticker by the chosen measure, value = 5.

Filtered to selected sector via page-level Sector slicer. When sector = All, shows top 5 across the universe.

Sort: descending.

Title: "Top 5 in selected sector".

### 7.6 Footer

Same caveat strip.

---

## 8. Page 4 — Financial Health

> **Spec v3 + during-build pivots — session 8 close** (2026-06-03). Page shipped as **sector-level financial health**. Three visuals: 8-ratio Matrix (V1) + Ribbon chart on Sector Net Income (V2, swapped from Decomposition tree mid-build after dbt mart column-name reality bit) + multi-ratio trajectory Line (V3). Page-level fiscal_year filter pattern was abandoned during build — PBI visual filters INTERSECT page filters rather than override (corrected mental model). Visual-level fiscal_year filters applied per-visual instead.

### 8.1 Purpose

Sector-level financial health — 8-ratio sector vs S&P 100 comparison + drillable AI breakdown of net margin + multi-ratio sector trajectory over time.

**Visual budget: 3 visuals + footer.** (Page 6 drill-through carries the per-company depth.)

### 8.2 Slicers (header strip)

- Date Range — `dim_as_of_date[as_of_date]` between slider (synced from Page 1).
- Sector — `dim_company[gics_sector]` dropdown (synced from Page 1). Default: All.

No Entity slicer (per-company view = Page 6 drill-through). No Ratio slicer (visuals show fixed ratio panels for tighter page focus).

### 8.3 Ratio Names helper table (Page 4)

Disconnected DAX helper. Drives V1 Matrix rows only — not slicer-bound. **Critical reality check during build:** spec v3's original ratio list included `current_ratio` and `asset_turnover` — neither exists in the dbt mart. The mart ships 8 ratios but not those 2 (mart_financial_health.sql lines 396-403 are the canon). Rebuilt with the 8 actual ratios:

```dax
Ratio Names = 
DATATABLE("Ratio", STRING, "Sort", INTEGER,
    {
        {"Gross margin", 1},
        {"Operating margin", 2},
        {"Net margin", 3},
        {"Operating CF margin", 4},
        {"Return on assets", 5},
        {"Return on equity", 6},
        {"Debt to equity", 7},
        {"Cash to assets", 8}
    }
)
```

After creating: select Ratio Names → Ratio column → Column tools → Sort by column → Sort.

### 8.4 Filter strategy (corrected)

**Original v3 plan: page-level fiscal_year = 2024 with V3 visual-level override.** This was wrong on PBI mechanics — visual-level filters INTERSECT page-level filters, they do NOT override. Discovered during V2 build when ribbon chart stayed pinned at one year despite the 2009-2024 visual-level filter.

**Shipped pattern:** no page-level fiscal_year filter. Each visual carries its own visual-level filter:
- V1 Matrix — visual-level filter `mart_financial_health[fiscal_year] = 2024` (single-year health snapshot).
- V2 Ribbon — visual-level filter `dim_fiscal_year[fiscal_year]` between 2009 and 2024 (full trajectory).
- V3 Trajectory — visual-level filter `dim_fiscal_year[fiscal_year]` between 2009 and 2024 (full trajectory).

### 8.5 V1 — Sector vs S&P 100 — 8 health ratios (Matrix, Row 1 left)

Visual: **Matrix**.

Field wells:
- Rows: `Ratio Names[Ratio]`.
- Values (3 measures, side by side):
  - Sector Ratio Value — SWITCH on Ratio Names[Ratio], dispatching to AVERAGE of the corresponding mart column at sector scope (current Sector slicer filter).
  - S&P 100 Ratio Value — SWITCH on Ratio Names[Ratio], dispatching to AVERAGE of the corresponding mart column at universe scope (`REMOVEFILTERS(dim_company)` pattern).
  - Δ (Sector − S&P 100) — `[Sector Ratio Value] - [S&P 100 Ratio Value]`.

Visual-level filter: `mart_financial_health[fiscal_year] = 2024`.

Format: traffic-light conditional formatting on the Δ column. Driven by `Δ Direction` helper measure that inverts the sign for Debt to equity (lower D/E = healthier — so positive Δ means more leverage = unhealthier = red). Rules:
- Δ Direction ≥ 0 AND ≤ 100 → green hex `C0DD97`.
- Δ Direction ≥ −100 AND < 0 → red hex `F7C1C1`.

Title: `Sector vs S&P 100 — 8 health ratios (D/E inverted — lower debt = healthier)`. The title preserves the inversion explanation inline so viewers don't see "+92.4% red" and assume a bug.

### 8.6 V2 — Sector net income rank movement (Ribbon chart, Row 2 full width)

> **During-build swap from Decomposition tree to Ribbon chart** (session 8). Decomposition tree was the v3 spec pick for AI-visual variety, but two issues surfaced at build:
> 1. Static-screenshot presentation weak — landing state is a single block with a "+"; portfolio README screenshots don't read as data-rich.
> 2. Measure-context mismatch — `[S&P 100 Net Margin]` uses `REMOVEFILTERS(dim_company)` which broke drill context (every node returned universe net margin 0.16).
>
> Pivoted to ribbon chart for stronger static presentation + brand-new viz idiom + sector rank-movement story.

Visual: **Ribbon chart**.

Field wells:
- X-axis: `dim_fiscal_year[fiscal_year]`.
- Y-axis: `[Sector Net Income]` (new — `SUM(mart_financial_health[net_income])`).
- Legend: `dim_company[gics_sector]` (11 ribbons).

Visual-level filter: `dim_fiscal_year[fiscal_year]` between 2009 and 2024.

Format:
- Y-axis: Display units = Trillions, decimal places = 1.
- Data labels: Off (ribbons get cluttered).
- Legend: On, position bottom.
- Bar inner padding: ~15-20% for chunkier columns.

Title: `Sector net income — rank movement, 2009-2024`.

Variety rationale: ribbon chart is brand-new across the report (Pages 1/2/3/5 use none). Ribbons reorder vertically by rank at each year — tells "Tech overtook Financials around 2018" narratives visually. Renders strongly as a static screenshot.

### 8.7 V3 — Sector health trajectory (Line chart, Row 1 right)

Visual: **Line chart**.

Field wells:
- X-axis: `dim_fiscal_year[fiscal_year]` (conformed dim).
- Y-axis: 3 measures plotted as 3 series:
  - `[Sector Net Margin]` (existing, DIVIDE/SUM pattern from session 6).
  - `[Sector ROE]` (new — `DIVIDE(SUM(mart_financial_health[net_income]), SUM(mart_financial_health[stockholders_equity]))`).
  - `[Sector ROA]` (new — `DIVIDE(SUM(mart_financial_health[net_income]), SUM(mart_financial_health[assets]))`).

**Why DIVIDE/SUM not AVERAGE.** The original spec used `CALCULATE(AVERAGE(...))` for both ROE and ROA. At build, V3 trajectory showed a −2000% spike around 2014-2015 — individual companies with tiny or near-zero stockholders_equity blew up per-company ROE values, and the AVERAGE amplified the explosion. DIVIDE/SUM at universe-aggregate scope is the analyst-correct pattern and yields stable trajectories.

Visual-level filter: `dim_fiscal_year[fiscal_year]` between 2009 and 2024.

Format:
- Y-axis: Display units = None, Decimal places = 1 (% format).
- Markers On, shape = circle.
- 3 distinct colors — Net margin blue `185FA5`, ROE purple `534AB7`, ROA teal `1D9E75`.

Title: `Sector health trajectory — Net margin, ROE, ROA, 2009-2024`.

### 8.8 Footer

Same caveat strip as §5.7.

### 8.9 Helpers required (as-shipped build order)

1. `Ratio Names` helper table (§8.3 — 8 actual dbt ratios).
2. `Sector Ratio Value` SWITCH measure on _Measures (AVERAGE pattern at sector scope).
3. `S&P 100 Ratio Value` measure on _Measures (`CALCULATE([Sector Ratio Value], REMOVEFILTERS(dim_company))`).
4. `Δ Ratio Value` = `[Sector Ratio Value] - [S&P 100 Ratio Value]`.
5. `Δ Direction` helper for traffic-light inversion on D/E row: `SWITCH(SELECTEDVALUE('Ratio Names'[Ratio]), "Debt to equity", -[Δ Ratio Value], [Δ Ratio Value])`.
6. `Sector ROE` and `Sector ROA` measures — DIVIDE/SUM pattern on mart_financial_health (NOT the AVERAGE pattern originally specified; see §8.7 rationale).
7. `Sector Net Income` measure — `SUM(mart_financial_health[net_income])` for V2 ribbon Y-axis.
8. `S&P 100 Net Margin` measure (already existed in some installs; built fresh in session 8 — `CALCULATE(AVERAGE(mart_financial_health[net_margin]), REMOVEFILTERS(dim_company))`. Not used in shipped V2 after the ribbon swap but kept for potential future use.)

### 8.10 What was dropped from v1 / v2 / during-build

- **v1 Decomposition tree on Total Revenue** — revenue size/composition story, not a health story.
- **v2 Treemap of sector members** — visual idiom already used on Page 1; rejected at v2 mockup review for redundancy.
- **v3 spec Decomposition tree on Net Margin** — swapped to ribbon chart during build (see §8.6 preamble). Failed both static-presentation and measure-context tests.
- **v1 8-gauge grid (4×2)** — 8 sub-visuals exceeds the 4-max budget.
- **v1 Health heatmap (Row 3)** — redundant with the Matrix; fragile in PBI Desktop at 8×10 cells.
- **v1 Selected-ratio trajectory + Sector ratio ranking bar** — both depended on a Ratio slicer that v3 dropped.
- **v1 Entity slicer + Ratio slicer** — Entity dropped because per-company view = Page 6 drill-through; Ratio dropped because v3 picks fixed ratios for tighter page focus.
- **v1 current_ratio + asset_turnover** in the Ratio Names list — neither column exists in the dbt mart (mart_financial_health.sql is canon, not the spec). Replaced with the actual dbt columns operating_margin and operating_cf_margin.
- **Page-level fiscal_year = 2024 filter** — PBI mechanics (visual filters intersect page filters, don't override) made the page-level approach incompatible with V2/V3 needing 2009-2024. Visual-level filters per visual instead.

---

## 9. Page 5 — Growth / Forecast

> **Session 9 reshape candidate sketched in session 8 (2026-06-03) — NOT locked.** Held loose at Phil's call; current §9.3-§9.5 stand. v2 candidate direction (revisit at session 9 open):
>
> - Keep V1 (historical + forecast line w/ 95% CI band) — directly tells growth/forecast story.
> - Keep KPI strip (3 dynamic-value text boxes).
> - Drop **Top 10 forecasted growth clustered bar (current §9.5)** — Pages 1/2/3 already use horizontal bars heavily, and the bar tells a "who" story that's secondary to the "trajectory" story.
> - Add **acceleration scatter** — historical CAGR (X) vs forecast CAGR (Y), sized by revenue, coloured by sector, with y = x reference diagonal. Above the diagonal = accelerating; below = decelerating. Brand-new viz idiom in the report (Page 3 bubble is revenue × margin; this is CAGR × CAGR).
> - Add **forecast bridge waterfall** — FY-latest-historical S&P 100 revenue → FY+3 forecast, decomposed by sector contribution. Brand-new viz idiom (waterfall not used on any other page).
> - Final layout: V1 line+CI (top-left ~2/3) + KPI strip (top-right ~1/3) + V2 acceleration scatter (mid-left ~50%) + V3 forecast waterfall (mid-right ~50%) + 2 risk caveats + footer.
>
> Decide at session 9 open whether to ship v2 candidate or keep current §9 layout.

### 9.1 Purpose

Historical + 3-year forecast revenue trajectory with 95% CI band. Headline forecast KPIs + top forecasted growth ranking.

**Visual budget: 3 visuals + footer + 2 risk caveat boxes** (caveats are text strips, not visual containers).

### 9.2 Slicers (header strip)

- Sector — `dim_company[gics_sector]` (synced from Page 1 — note Page 5 forecasts are not snapshot-versioned, but Sector still cross-filters meaningfully).
- Entity — `dim_company[entity_name]` single-select (Page 5 local).

### 9.3 Row 1 left — Historical + forecast trajectory with CI band (~2/3 width)

Visual: **Line chart** layered with **Area chart** (Area underneath, Line on top).

Field wells (Line):
- X-axis: `mart_growth_forecast[fiscal_year]`.
- Y-axis: `mart_growth_forecast[value_numeric]`.
- Legend: `mart_growth_forecast[series_type]` (historical / forecast).

Format the line:
- `historical` segment: solid blue, 2px stroke.
- `forecast` segment: dashed blue, 2px stroke.

Layer underneath: Area chart with `mart_growth_forecast[lower_ci_95]` and `mart_growth_forecast[upper_ci_95]`, light translucent fill behind the forecast portion only.

Title: "Revenue trajectory — historical + 3-year forecast with 95% CI".

### 9.4 Row 1 right — KPI callouts (~1/3 width)

Three stacked text boxes (no Card visuals — project lock). Same dynamic-value pattern as Page 2 §6.5 (each box uses + Value, "Name your value" populated to enable Save).

| Label | Measure |
|---|---|
| 3-year forecast CAGR | CAGR of forecast revenue from latest historical year to +3 forecast year. |
| Forecast vs historical YoY | first-year forecast YoY % vs the last historical YoY %. |
| Average model AIC | `AVERAGE(mart_growth_forecast[model_aic])` — model fit quality indicator. |

### 9.5 Row 2 — Top 10 forecasted growth (full width)

Visual: **Clustered bar chart** (horizontal).

Field wells:
- Y-axis: `dim_company[ticker]`.
- X-axis: per-company 3-year forecast CAGR measure.
- Visual filter: Top N on ticker by CAGR, value = 10.

Sort: descending.

Title: "Top 10 forecasted revenue CAGR (3-year)".

### 9.6 Risk 56 forecast horizon caveat

Small text box near Row 1:

```
Forecasts extend 3 years from each company's latest historical observation. Companies with FY2024 latest forecast FY2025-2027; companies with FY2025 latest forecast FY2026-2028.
```

### 9.7 Risk 60 structural shocks caveat

Small text box (lower-left of Row 2):

```
Forecasts are 3-year Holt-Winters / ARIMA projections; structural events such as spinoffs, divestitures, and M&A are not modeled. Post-divestiture filers like GE (2024 GE Vernova + GE HealthCare separations) and 3M (2024 fiber optics + food safety divestitures) should be interpreted accordingly.
```

### 9.8 Footer

Same caveat strip.

### 9.9 What was dropped from v1

- **Per-sector forecast small multiples** (v1 Row 2) dropped — 11 mini panels has the same crowding issue Page 2 hit. Sector cross-cut available via the Sector slicer + Row 1 chart.
- **Model metadata panel** (v1 Row 3 right) dropped — analyst-facing page over-budget; model fit quality summarized via the Average model AIC KPI callout in Row 1 right.

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

# Power BI report audit — full inventory + Page 5 hero-chart root cause

> Written 2026-06-04 (Phase 5 session 9), at Phil's request after the
> Growth/Forecast trajectory line failed ~8-10 build attempts. Audits
> every table, relationship, and measure in the model, then isolates why
> the hero line chart specifically would not render correctly.
>
> Method / sources: dbt model SQL (canonical — `dbt/models/marts/*.sql`),
> `scripts/forecast.py` (forecast generation logic), Model-view
> screenshots (tables + relationships), and the `_Measures` field list.
> Live Athena data was NOT queried (no warehouse access from this
> session) — coverage/cohort facts below are inferred from the script
> logic and the on-screen matrix values, and are flagged where inferred.

---

## 1. Headline finding

The line chart kept failing for **four compounding reasons**, three of
which are mine. None of them are a Power BI bug, and none are hard once
named. In priority order:

1. **In-measure year filter overrode the axis.** My `Revenue Actual` /
   `Revenue Projected` put `mart_growth_forecast[fiscal_year] <= 2024`
   *inside* CALCULATE. A boolean filter on the same column that's on the
   axis **replaces** the axis context — so every year showed the same
   total ($102.8T). This is the flat-line bug.
2. **No Latest-Complete-FY guard.** Every working Page 1-4 measure pins
   to the latest snapshot AND the latest *complete* fiscal year (the
   ≥80-CIK coverage pattern, §2.5). My Page 5 measures skipped it, so the
   partial tail year (a handful of early FY2026 filers) dragged the
   actual line off a cliff at the right edge.
3. **Forecast horizon is per-company-relative.** `forecast.py` forecasts
   `latest_year+1 .. latest_year+3` **per company** (line 282-283). Stale
   filers whose latest actual is 2014 get forecasts for 2015-2017. So the
   forecast surface smears across ~2015-2028, and a calendar-year SUM is
   lumpy because company cohorts enter and exit each year. This is the
   "flat green bits at 2015-2017 / 2020-2022" and the 6→9→9.6→3.3 wobble.
4. **Measure duplication.** Working Page-5 forecast measures already
   existed (`Revenue Historical`, `Revenue Forecast`, `Revenue Trend`)
   plus `Revenue All Years` (which already drives Page 1's near-identical
   trajectory line and works). I reinvented them as `Revenue Actual`,
   `Revenue Projected`, `Latest Historical Revenue`, `Final Forecast
   Revenue` — overlapping, and the new ones carried bugs 1-2.

The fix is to stop reinventing, use the proven measures, gate the
forecast window *outside* CALCULATE, and restrict the forecast to the
current forward cohort. Detail in §5.

---

## 2. Tables (11 + model chrome)

| Table | Role | Key | Notes |
|---|---|---|---|
| dim_company | Company dimension | cik | entity_name, gics_sector, gics_industry_group, ticker. Star centre for company filtering. |
| dim_fiscal_year | Conformed year dim | fiscal_year | Shared X-axis dim across marts (spec §4.3). |
| dim_as_of_date | Snapshot dim | as_of_date | Drives the Pages 1-4 snapshot slicer. Page 5 deliberately omits it. |
| dim_kpi | KPI label dim | KPI | Page 1 KPI matrix labels + sort. |
| bridge_kpi_fiscal_year | KPI bridge | KPI + fiscal_year | Many-to-many bridge feeding the Page 1 KPI sparkline. |
| mart_pl_trend | P&L / revenue history fact | cik+fiscal_year+as_of_date+concept | Source of all revenue history. value_numeric, yoy_pct, yoy_rank. Snapshot-versioned. |
| mart_financial_health | Ratio fact | cik+fiscal_year+as_of_date | 8 ratios (gross/operating/net margin, ROA, ROE, D/E, cash_to_assets, operating_cf_margin). |
| mart_peer_benchmark | Peer-stats fact | cik+fiscal_year+as_of_date | peer_mean/median/min/max/percentile/rank/stddev/count. |
| mart_growth_forecast | Forecast + history fact | cik+concept+fiscal_year+as_of_date+row_kind | UNION of historical (mart_pl_trend) + forecast surface. See §3. |
| _Measures | Measure home | — | Hidden. Holds all measures. (Column1 placeholder is fine.) |
| Ratio Names | Disconnected helper | Ratio | DAX DATATABLE driving the Page 4 ratio matrix rows. |

## 2.1 mart_growth_forecast columns (the Page 5 source)

`row_kind` ('historical' | 'forecast') is the leg discriminator.

- Historical leg: `value_numeric` populated; `forecast_value`,
  `lower_ci_95`, `upper_ci_95`, `model_*`, `latest_historical_year` NULL.
- Forecast leg: `forecast_value`, `lower_ci_95`, `upper_ci_95`,
  `model_name`, `model_aic`, `historical_obs_count`,
  `latest_historical_year` populated; `value_numeric` NULL.

Critical for measures: `latest_historical_year` exists ONLY on forecast
rows. `value_numeric` and `forecast_value` are never both present on one
row — so the trajectory needs two measures (or a COALESCE), never a raw
SUM of one column.

---

## 3. Why the forecast data is shaped the way it is (forecast.py)

- Per-company Holt-Winters (additive trend), ARIMA(1,1,0) fallback for
  short/flat series, skip if <2 observations.
- **Horizon = each company's own latest observed year + 1..+3.** Not a
  fixed calendar window. THIS is the smear source.
- 95% prediction interval → `lower_ci_95` / `upper_ci_95`. These are the
  band the hero chart should show and currently doesn't.
- One forecast vintage, written at run date as the `as_of_date`
  partition.

Consequence for an aggregate calendar-year line: no single future year
has full company coverage unless we restrict to one horizon cohort.
Inferred from the on-screen matrix (2025 $6.1T, 2026 $9.2T, 2027 $9.7T,
2028 $3.3T): at least two live cohorts (latest year 2024 → 2025-27, and
2025 → 2026-28), plus stale filers producing pre-2025 forecast noise.

---

## 4. Measures inventory (37) — keep / fix / retire

**Core, working (mart_pl_trend / Page 1-2), KEEP:** Total Revenue (Latest
FY), Total Net Income (Latest FY), Net Margin (Latest FY), Revenue YoY %,
Revenue YoY Pct, Revenue YoY Rank, Revenue All Years, Net Income All
Years, Avg Net Margin, Best Revenue Year, Worst Revenue Year, KPI Latest,
KPI Sparkline, Sector Revenue.

**Page 3/4 (peer + health), KEEP:** Sector Ratio Value, S&P 100 Ratio
Value, Δ Ratio Value, Δ Direction, Sector ROA, Sector ROE, Sector Net
Income, Sector Net Margin, S&P 100 Net Margin.

**Pre-existing Page-5 forecast helpers (built earlier, NOT used this
session — assess before rebuilding):** Revenue Trend, Revenue Historical,
Revenue Forecast.

**Session-9 new (mine) — OVERLAP / retire after fix:** Latest Historical
Revenue, Final Forecast Revenue, Forecast CAGR, Historical CAGR, Revenue
Actual, Revenue Projected. (Forecast CAGR / Historical CAGR are still
needed — they drive the working scatter + Top 10 bar. Revenue Actual /
Revenue Projected are the broken pair to replace. Latest Historical /
Final Forecast Revenue feed CAGR + the KPI strip — keep or fold.)

**Revenue-trajectory duplication cluster (the mess):** Revenue Trend,
Revenue Historical, Revenue Forecast, Revenue All Years, Revenue Actual,
Revenue Projected, Latest Historical Revenue, Final Forecast Revenue —
eight measures circling the same idea. Target end-state: one historical
trajectory measure + one forecast trajectory measure + the two CAGR
anchors + CI band. Retire the rest.

---

## 5. Definitive fix for the hero line

Principle: gate the display window with IF/SELECTEDVALUE **outside**
CALCULATE (never a same-column filter inside it), reuse the proven
snapshot pattern, restrict the forecast to the forward cohort, add the CI
band.

1. **Historical line** — reuse `Revenue All Years` (already drives the
   working Page 1 trajectory), or a thin equivalent. Pin latest snapshot,
   respect year context, gate to ≤ latest complete FY via a visual-level
   filter on the axis (NOT inside the measure).
2. **Forecast line** — new measure: forecast SUM pinned to latest
   forecast snapshot, restricted to `latest_historical_year >= <current>`
   (kills stale smear), gated to forward years with
   `IF(SELECTEDVALUE(year) >= <cutoff+1>, ...)`.
3. **CI band** — area chart layered under the line using `lower_ci_95` /
   `upper_ci_95`, same cohort restriction.
4. **Verify in a matrix BEFORE charting** — fiscal_year on rows, the
   historical + forecast + lower + upper measures as values. Confirm the
   numbers read cleanly, THEN build the visual.

Open decision for the cohort: lock to the single latest-complete cohort
(cleanest line, drops a few stale companies) vs keep all forward cohorts
(full coverage, mild year-to-year wobble). Recommendation: lock to the
single cohort for a hero visual — clean beats complete here.

---

## 6. Cleanup actions (after the chart works)

- Retire the duplicate revenue-trajectory measures (§4) down to the
  target end-state set.
- Confirm the three pre-existing forecast helpers (Revenue Trend /
  Historical / Forecast) are either adopted or deleted — don't leave
  three orphaned measures named almost identically to the live ones.
- Document the final Page-5 measure set in POWERBI_COPILOT_SPEC.md §9.

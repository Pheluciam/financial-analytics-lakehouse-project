-- sql/audit/08_cross_mart_consistency.sql
--
-- Phase 5 audit 7 of 10 — cross-mart consistency.
--
-- Goal: for every canonical that appears in 2+ marts at the same grain,
-- verify the value agrees per (cik, fiscal_year, as_of_date_at_latest).
-- All 4 marts source from sat_concept_value via the same 5-step BV+RV
-- equi-join chain — values should match by construction. Any divergence =
-- real bug (mart filter divergence, dedup divergence, or pivot bug).
--
-- A2.5 (Audit 2) already confirmed COUNT consistency for revenue across
-- mart_pl_trend + mart_peer_benchmark + mart_financial_health across all
-- 16 fiscal years. A7 verifies VALUE consistency — counts can match while
-- values diverge if one mart's filter excludes a row another mart's does.
--
-- Per-canonical surface coverage across the 4 marts:
--   revenue              — mart_pl_trend, mart_peer_benchmark,
--                          mart_financial_health, mart_growth_forecast
--                          (historical leg)
--   net_income           — mart_pl_trend, mart_peer_benchmark,
--                          mart_financial_health
--   assets               — mart_peer_benchmark, mart_financial_health
--   gross_profit         — mart_financial_health only
--   operating_income     — mart_financial_health only
--   liabilities          — mart_financial_health only
--   stockholders_equity  — mart_financial_health only
--   cash_and_equivalents — mart_financial_health only
--   operating_cash_flow  — mart_financial_health only
--
-- 3 multi-mart canonicals to cross-check: revenue (4 marts), net_income
-- (3 marts), assets (2 marts).
--
-- =============================================================================
-- SCHEMA REFERENCE — ground-truthed against dbt model files 2026-06-01
-- =============================================================================
--
-- financial_analytics_silver.mart_pl_trend
--   cols: cik, entity_name, as_of_date, fiscal_year, canonical_concept,
--         value_numeric, unit, period_end_date, ...
--   canonicals: revenue, net_income
--
-- financial_analytics_silver.mart_peer_benchmark
--   cols: cik, entity_name, as_of_date, fiscal_year, canonical_concept,
--         gics_sector, gics_industry_group, value_numeric, unit,
--         peer_count, peer_mean, peer_median, peer_stddev, peer_min,
--         peer_max, peer_rank, peer_percentile, period_end_date, ...
--   canonicals: revenue, net_income, assets
--
-- financial_analytics_silver.mart_financial_health  (pivoted shape)
--   cols: cik, entity_name, as_of_date, fiscal_year, period_end_date,
--         revenue, gross_profit, operating_income, net_income, assets,
--         liabilities, stockholders_equity, cash_and_equivalents,
--         operating_cash_flow, gross_margin, ...
--
-- financial_analytics_silver.mart_growth_forecast
--   cols: cik, fiscal_year, canonical_concept, value_numeric,
--         forecast_value, lower_ci_95, upper_ci_95, row_kind, as_of_date,
--         ...
--   row_kind values: 'historical' (sourced from mart_pl_trend revenue),
--                    'forecast'   (statsmodels output at latest as_of_date)
--   canonicals: revenue only (per Phase 4 session 4 scope)
--
-- =============================================================================
-- EXECUTION
-- =============================================================================
-- Athena Console, signed in as phil-admin, workgroup wg_financial_analytics,
-- us-east-1. One query at a time.
-- =============================================================================


-- =============================================================================
-- A7 — Cross-mart consistency check (one consolidated query)
-- =============================================================================
-- For each multi-mart canonical, FULL OUTER JOIN per-mart values at
-- (cik, fiscal_year). Count divergent rows where abs(delta) > $1 (raw
-- DECIMAL(28,2) rounding tolerance). FY range 2009-2024.
--
-- Expected result: divergent_rows = 0 for every check. Any non-zero
-- requires per-row root-cause via the divergent-rows companion query
-- below.
WITH
mpt_latest AS (SELECT MAX(as_of_date) AS d FROM financial_analytics_silver.mart_pl_trend),
mpb_latest AS (SELECT MAX(as_of_date) AS d FROM financial_analytics_silver.mart_peer_benchmark),
mfh_latest AS (SELECT MAX(as_of_date) AS d FROM financial_analytics_silver.mart_financial_health),
mgf_latest AS (SELECT MAX(as_of_date) AS d FROM financial_analytics_silver.mart_growth_forecast WHERE row_kind = 'forecast'),

-- Per-mart, per-canonical values at latest snapshot, FY 2009-2024 only
pl_rev AS (
    SELECT cik, fiscal_year, value_numeric AS v
    FROM financial_analytics_silver.mart_pl_trend
    WHERE canonical_concept = 'revenue'
      AND as_of_date = (SELECT d FROM mpt_latest)
      AND fiscal_year BETWEEN 2009 AND 2024
),
pl_ni AS (
    SELECT cik, fiscal_year, value_numeric AS v
    FROM financial_analytics_silver.mart_pl_trend
    WHERE canonical_concept = 'net_income'
      AND as_of_date = (SELECT d FROM mpt_latest)
      AND fiscal_year BETWEEN 2009 AND 2024
),
pb_rev AS (
    SELECT cik, fiscal_year, value_numeric AS v
    FROM financial_analytics_silver.mart_peer_benchmark
    WHERE canonical_concept = 'revenue'
      AND as_of_date = (SELECT d FROM mpb_latest)
      AND fiscal_year BETWEEN 2009 AND 2024
),
pb_ni AS (
    SELECT cik, fiscal_year, value_numeric AS v
    FROM financial_analytics_silver.mart_peer_benchmark
    WHERE canonical_concept = 'net_income'
      AND as_of_date = (SELECT d FROM mpb_latest)
      AND fiscal_year BETWEEN 2009 AND 2024
),
pb_assets AS (
    SELECT cik, fiscal_year, value_numeric AS v
    FROM financial_analytics_silver.mart_peer_benchmark
    WHERE canonical_concept = 'assets'
      AND as_of_date = (SELECT d FROM mpb_latest)
      AND fiscal_year BETWEEN 2009 AND 2024
),
fh AS (
    SELECT cik, fiscal_year, revenue AS rev, net_income AS ni, assets AS a
    FROM financial_analytics_silver.mart_financial_health
    WHERE as_of_date = (SELECT d FROM mfh_latest)
      AND fiscal_year BETWEEN 2009 AND 2024
),
gf_hist_rev AS (
    SELECT cik, fiscal_year, value_numeric AS v
    FROM financial_analytics_silver.mart_growth_forecast
    WHERE row_kind = 'historical'
      AND canonical_concept = 'revenue'
      AND fiscal_year BETWEEN 2009 AND 2024
),

-- Pairwise comparison CTEs — FULL OUTER JOIN to catch missing rows
chk_rev_pl_fh AS (
    SELECT pl.cik, pl.fiscal_year,
           pl.v AS pl_value, fh.rev AS fh_value,
           CASE
               WHEN pl.v IS NULL AND fh.rev IS NULL THEN 0
               WHEN pl.v IS NULL OR fh.rev IS NULL THEN 1
               WHEN ABS(pl.v - fh.rev) > 1 THEN 1
               ELSE 0
           END AS divergent
    FROM pl_rev pl
    FULL OUTER JOIN fh ON fh.cik = pl.cik AND fh.fiscal_year = pl.fiscal_year
),
chk_rev_pl_pb AS (
    SELECT pl.cik, pl.fiscal_year,
           pl.v AS pl_value, pb.v AS pb_value,
           CASE
               WHEN pl.v IS NULL AND pb.v IS NULL THEN 0
               WHEN pl.v IS NULL OR pb.v IS NULL THEN 1
               WHEN ABS(pl.v - pb.v) > 1 THEN 1
               ELSE 0
           END AS divergent
    FROM pl_rev pl
    FULL OUTER JOIN pb_rev pb ON pb.cik = pl.cik AND pb.fiscal_year = pl.fiscal_year
),
chk_rev_pl_gf AS (
    SELECT pl.cik, pl.fiscal_year,
           pl.v AS pl_value, gf.v AS gf_value,
           CASE
               WHEN pl.v IS NULL AND gf.v IS NULL THEN 0
               WHEN pl.v IS NULL OR gf.v IS NULL THEN 1
               WHEN ABS(pl.v - gf.v) > 1 THEN 1
               ELSE 0
           END AS divergent
    FROM pl_rev pl
    FULL OUTER JOIN gf_hist_rev gf ON gf.cik = pl.cik AND gf.fiscal_year = pl.fiscal_year
),
chk_ni_pl_fh AS (
    SELECT pl.cik, pl.fiscal_year,
           pl.v AS pl_value, fh.ni AS fh_value,
           CASE
               WHEN pl.v IS NULL AND fh.ni IS NULL THEN 0
               WHEN pl.v IS NULL OR fh.ni IS NULL THEN 1
               WHEN ABS(pl.v - fh.ni) > 1 THEN 1
               ELSE 0
           END AS divergent
    FROM pl_ni pl
    FULL OUTER JOIN fh ON fh.cik = pl.cik AND fh.fiscal_year = pl.fiscal_year
),
chk_ni_pl_pb AS (
    SELECT pl.cik, pl.fiscal_year,
           pl.v AS pl_value, pb.v AS pb_value,
           CASE
               WHEN pl.v IS NULL AND pb.v IS NULL THEN 0
               WHEN pl.v IS NULL OR pb.v IS NULL THEN 1
               WHEN ABS(pl.v - pb.v) > 1 THEN 1
               ELSE 0
           END AS divergent
    FROM pl_ni pl
    FULL OUTER JOIN pb_ni pb ON pb.cik = pl.cik AND pb.fiscal_year = pl.fiscal_year
),
chk_assets_fh_pb AS (
    SELECT fh.cik, fh.fiscal_year,
           fh.a AS fh_value, pb.v AS pb_value,
           CASE
               WHEN fh.a IS NULL AND pb.v IS NULL THEN 0
               WHEN fh.a IS NULL OR pb.v IS NULL THEN 1
               WHEN ABS(fh.a - pb.v) > 1 THEN 1
               ELSE 0
           END AS divergent
    FROM fh
    FULL OUTER JOIN pb_assets pb ON pb.cik = fh.cik AND pb.fiscal_year = fh.fiscal_year
)

SELECT 'revenue: pl_trend vs financial_health' AS check_name,
       SUM(divergent) AS divergent_rows,
       COUNT(*) AS total_rows
FROM chk_rev_pl_fh
UNION ALL
SELECT 'revenue: pl_trend vs peer_benchmark',
       SUM(divergent), COUNT(*)
FROM chk_rev_pl_pb
UNION ALL
SELECT 'revenue: pl_trend vs growth_forecast historical',
       SUM(divergent), COUNT(*)
FROM chk_rev_pl_gf
UNION ALL
SELECT 'net_income: pl_trend vs financial_health',
       SUM(divergent), COUNT(*)
FROM chk_ni_pl_fh
UNION ALL
SELECT 'net_income: pl_trend vs peer_benchmark',
       SUM(divergent), COUNT(*)
FROM chk_ni_pl_pb
UNION ALL
SELECT 'assets: financial_health vs peer_benchmark',
       SUM(divergent), COUNT(*)
FROM chk_assets_fh_pb
ORDER BY check_name;


-- =============================================================================
-- A7-FOLLOWUP — Divergent row drilldown (run only if A7 surfaces non-zero).
-- =============================================================================
-- For any check with divergent_rows > 0, re-run with the chk_X CTE
-- definition and filter WHERE divergent = 1 to inspect the per-row deltas.
-- Template (uncomment + adapt to the failing check):
--
-- SELECT cik, fiscal_year, pl_value, fh_value, ABS(pl_value - fh_value) AS delta
-- FROM chk_rev_pl_fh
-- WHERE divergent = 1
-- ORDER BY delta DESC;


-- =============================================================================
-- AUDIT 7 RESULTS — banked 2026-06-01
-- =============================================================================
--
-- A7 consolidated cross-mart check — DIVERGENCES SURFACED:
--   revenue: pl_trend vs financial_health           — 19 / 1703 divergent
--   revenue: pl_trend vs peer_benchmark             — 59 / 1592
--   revenue: pl_trend vs growth_forecast historical — 225 / 11236
--   net_income: pl_trend vs financial_health        — 17 / 1703
--   net_income: pl_trend vs peer_benchmark          — 39 / 1526
--   assets: financial_health vs peer_benchmark      — 62 / 1703
--   Total: ~421 divergent (cik, fy) rows across the 6 checks.
--
-- A7-step2 — snapshot drift HYPOTHESIS REJECTED. All 4 marts share the
-- same as_of_date grid (10 snapshots, 2016-12-31 to 2025-12-31).
--
-- A7-step3 — drilldown pattern: every divergent row is a 52/53-week
-- fiscal-year-end retailer or consumer company (WMT, HD, TGT, LOW, TJX,
-- NVDA, CRM, JNJ 53-week FY2021).
--
-- A7-step4 — root cause CONFIRMED via per-row WMT FY2012/FY2013 sat probe.
--   - WMT's FY2013 10-K (accn=0000104169-13-000011, filed early 2013)
--     is tagged by SEC with fy=2012 (period-START-year convention, not
--     period-END-year). WMT internally calls this filing "Fiscal 2013."
--   - This 10-K's XBRL reports BOTH current-year and prior-year
--     comparatives under fy=2012 with DIFFERENT period_end_dates:
--       fy=2012, period_end=2012-01-31, value=$446,950M (FY2012 actual)
--       fy=2012, period_end=2013-01-31, value=$469,162M (FY2013 current
--                                                        on this filer's
--                                                        naming)
--   - Both pass the mart's `year(period_end) IN (fy, fy+1)` filter:
--       2012 in (2012, 2013) — row 1 PASSES
--       2013 in (2012, 2013) — row 2 PASSES
--   - Both pass the date_diff BETWEEN 350 AND 380 filter (364 + 365 days).
--   - Both share the SAME accession_number. Risk 42 dedup ORDER BY
--     accession_number DESC produces a TIE.
--   - Trino ROW_NUMBER tie-break is non-deterministic — different mart
--     rebuilds pick different rows from the tied set.
--   - mart_pl_trend picked row at $469B (2013-01-31).
--     mart_financial_health picked row at $447B (2012-01-31).
--   - SAME root cause across all 6 cross-mart checks.
--
-- ARCHITECTURAL FIX — Audit 4's recommended fix resolves Audit 7 too.
--   Re-anchor mart `fiscal_year` on `year(period_end_date)` instead of
--   the SEC `fy` attribute. After re-anchor:
--     - Row 14 ($447B at period_end=2012-01-31) → mart fiscal_year=2012
--     - Row 18 ($469B at period_end=2013-01-31) → mart fiscal_year=2013
--   No partition ambiguity. Risk 42 dedup becomes deterministic by
--   construction. ALL 421 cross-mart divergences heal simultaneously
--   with the Audit 4 fix.
--
-- AUDIT 4 + AUDIT 7 CONVERGENCE — Strong signal. Two independent audits
-- diagnose the same architectural mismatch (SEC fy anchor vs
-- period-end-year anchor). Fix-all phase ships the period-end re-anchor
-- with high confidence — one fix heals both audits.
--
-- AUDIT 7 STATUS — CLOSED.
-- Root cause identified. Fix shape documented. No fix applied per the
-- no-fixes-during-audit operating principle. Verification post-Fix:
-- re-run A7 and confirm divergent_rows = 0 across all 6 checks.
-- Next: Audit 8 — snapshot consistency / PIT logic per AUDITS_4_TO_10_SCOPE.md.

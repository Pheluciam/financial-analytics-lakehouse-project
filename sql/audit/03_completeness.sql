-- sql/audit/03_completeness.sql
--
-- Phase 5 audit 2 of 10 — completeness across all 4 marts × all FYs.
--
-- Goal: build the full coverage heat-map. For each (mart × canonical ×
-- fiscal_year), what fraction of the 107 S&P 100 universe reports it?
-- Exposes whether gaps are FY2024-only (filing lag) or chronic
-- (tag-mapping or structural).
--
-- All checks scope to the 107 seed universe (INNER JOIN to
-- sp100_company_sector) — strips out the 8 Bronze orphans we found in
-- Audit 1.
--
-- Execution: Athena Console, signed in as phil-admin, workgroup
-- wg_financial_analytics, us-east-1. One query at a time.

-- ============================================================
-- A2.1 — mart_financial_health coverage heat-map per (canonical, FY).
-- 9 canonicals × 16 fiscal years FY2009-2024 = 144 cells.
-- Shows per-FY gap profile per canonical — identifies whether gaps are
-- FY2024-only (recent filing lag) or chronic (mapping/structural).
-- ============================================================
WITH latest AS (
    SELECT MAX(as_of_date) AS d FROM financial_analytics_silver.mart_financial_health
),
universe_x_years AS (
    SELECT s.cik, y.fy AS fiscal_year
    FROM financial_analytics_silver.sp100_company_sector s
    CROSS JOIN UNNEST(ARRAY[2009,2010,2011,2012,2013,2014,2015,2016,2017,2018,2019,2020,2021,2022,2023,2024]) AS y(fy)
),
joined AS (
    SELECT
        u.cik,
        u.fiscal_year,
        m.revenue,
        m.net_income,
        m.gross_profit,
        m.operating_income,
        m.assets,
        m.liabilities,
        m.stockholders_equity,
        m.cash_and_equivalents,
        m.operating_cash_flow
    FROM universe_x_years u
    LEFT JOIN financial_analytics_silver.mart_financial_health m
        ON u.cik = m.cik
        AND u.fiscal_year = m.fiscal_year
        AND m.as_of_date = (SELECT d FROM latest)
),
long_format AS (
    SELECT fiscal_year, 'revenue'              AS canonical, CASE WHEN revenue              IS NOT NULL THEN 1 ELSE 0 END AS rpt FROM joined
    UNION ALL
    SELECT fiscal_year, 'net_income',           CASE WHEN net_income           IS NOT NULL THEN 1 ELSE 0 END FROM joined
    UNION ALL
    SELECT fiscal_year, 'gross_profit',         CASE WHEN gross_profit         IS NOT NULL THEN 1 ELSE 0 END FROM joined
    UNION ALL
    SELECT fiscal_year, 'operating_income',     CASE WHEN operating_income     IS NOT NULL THEN 1 ELSE 0 END FROM joined
    UNION ALL
    SELECT fiscal_year, 'assets',               CASE WHEN assets               IS NOT NULL THEN 1 ELSE 0 END FROM joined
    UNION ALL
    SELECT fiscal_year, 'liabilities',          CASE WHEN liabilities          IS NOT NULL THEN 1 ELSE 0 END FROM joined
    UNION ALL
    SELECT fiscal_year, 'stockholders_equity',  CASE WHEN stockholders_equity  IS NOT NULL THEN 1 ELSE 0 END FROM joined
    UNION ALL
    SELECT fiscal_year, 'cash_and_equivalents', CASE WHEN cash_and_equivalents IS NOT NULL THEN 1 ELSE 0 END FROM joined
    UNION ALL
    SELECT fiscal_year, 'operating_cash_flow',  CASE WHEN operating_cash_flow  IS NOT NULL THEN 1 ELSE 0 END FROM joined
)
SELECT
    fiscal_year,
    canonical,
    SUM(rpt) AS reporting,
    107 - SUM(rpt) AS missing,
    ROUND(100.0 * SUM(rpt) / 107, 1) AS pct_coverage
FROM long_format
GROUP BY fiscal_year, canonical
ORDER BY fiscal_year DESC, missing DESC;


-- ============================================================
-- A2.2 — mart_pl_trend coverage per (canonical, FY).
-- mart_pl_trend holds revenue + net_income in long format. 2 canonicals
-- × 16 FYs = 32 cells. Compare to mart_financial_health to expose any
-- drift between the two marts on the same canonicals.
-- ============================================================
WITH latest AS (
    SELECT MAX(as_of_date) AS d FROM financial_analytics_silver.mart_pl_trend
)
SELECT
    m.fiscal_year,
    m.canonical_concept,
    COUNT(DISTINCT m.cik) AS reporting,
    107 - COUNT(DISTINCT m.cik) AS missing,
    ROUND(100.0 * COUNT(DISTINCT m.cik) / 107, 1) AS pct_coverage
FROM financial_analytics_silver.mart_pl_trend m
INNER JOIN financial_analytics_silver.sp100_company_sector s ON m.cik = s.cik
INNER JOIN latest l ON m.as_of_date = l.d
WHERE m.fiscal_year BETWEEN 2009 AND 2024
GROUP BY m.fiscal_year, m.canonical_concept
ORDER BY m.fiscal_year DESC, missing DESC;


-- ============================================================
-- A2.3 — mart_peer_benchmark coverage per (canonical, FY).
-- mart_peer_benchmark holds revenue + net_income + assets. 3 canonicals
-- × 16 FYs = 48 cells. Same shape check as above.
-- ============================================================
WITH latest AS (
    SELECT MAX(as_of_date) AS d FROM financial_analytics_silver.mart_peer_benchmark
)
SELECT
    m.fiscal_year,
    m.canonical_concept,
    COUNT(DISTINCT m.cik) AS reporting,
    107 - COUNT(DISTINCT m.cik) AS missing,
    ROUND(100.0 * COUNT(DISTINCT m.cik) / 107, 1) AS pct_coverage
FROM financial_analytics_silver.mart_peer_benchmark m
INNER JOIN financial_analytics_silver.sp100_company_sector s ON m.cik = s.cik
INNER JOIN latest l ON m.as_of_date = l.d
WHERE m.fiscal_year BETWEEN 2009 AND 2024
GROUP BY m.fiscal_year, m.canonical_concept
ORDER BY m.fiscal_year DESC, missing DESC;


-- ============================================================
-- A2.4 — mart_growth_forecast historical leg + forecast leg coverage.
-- Historical leg = revenue from mart_pl_trend (should match A2.2 revenue).
-- Forecast leg = 3-year forward at latest as_of_date.
-- ============================================================
WITH latest AS (
    SELECT MAX(as_of_date) AS d FROM financial_analytics_silver.mart_growth_forecast
)
SELECT
    m.row_kind,
    m.fiscal_year,
    COUNT(DISTINCT m.cik) AS reporting,
    107 - COUNT(DISTINCT m.cik) AS missing,
    ROUND(100.0 * COUNT(DISTINCT m.cik) / 107, 1) AS pct_coverage
FROM financial_analytics_silver.mart_growth_forecast m
INNER JOIN financial_analytics_silver.sp100_company_sector s ON m.cik = s.cik
WHERE (
    -- Historical leg uses fiscal_year-keyed as_of_date from mart_pl_trend
    -- Forecast leg uses run-date as_of_date — to get the latest forecast,
    -- INNER JOIN to MAX over forecast rows specifically
    m.row_kind = 'historical'
    OR (m.row_kind = 'forecast' AND m.as_of_date = (SELECT d FROM latest))
)
AND m.fiscal_year BETWEEN 2009 AND 2028
GROUP BY m.row_kind, m.fiscal_year
ORDER BY m.fiscal_year DESC, m.row_kind;


-- ============================================================
-- A2.5 — Cross-mart revenue consistency.
-- mart_pl_trend revenue count vs mart_financial_health revenue count
-- vs mart_peer_benchmark revenue count, per fiscal_year. Counts must
-- match per FY — if not, the marts disagree on the same underlying
-- canonical = a drift bug.
-- ============================================================
WITH pl_latest AS (
    SELECT MAX(as_of_date) AS d FROM financial_analytics_silver.mart_pl_trend
),
fh_latest AS (
    SELECT MAX(as_of_date) AS d FROM financial_analytics_silver.mart_financial_health
),
pb_latest AS (
    SELECT MAX(as_of_date) AS d FROM financial_analytics_silver.mart_peer_benchmark
),
pl_revenue AS (
    SELECT m.fiscal_year, COUNT(DISTINCT m.cik) AS pl_rev
    FROM financial_analytics_silver.mart_pl_trend m
    INNER JOIN financial_analytics_silver.sp100_company_sector s ON m.cik = s.cik
    INNER JOIN pl_latest ON m.as_of_date = pl_latest.d
    WHERE m.canonical_concept = 'revenue' AND m.fiscal_year BETWEEN 2009 AND 2024
    GROUP BY m.fiscal_year
),
fh_revenue AS (
    SELECT m.fiscal_year, COUNT(DISTINCT m.cik) AS fh_rev
    FROM financial_analytics_silver.mart_financial_health m
    INNER JOIN financial_analytics_silver.sp100_company_sector s ON m.cik = s.cik
    INNER JOIN fh_latest ON m.as_of_date = fh_latest.d
    WHERE m.revenue IS NOT NULL AND m.fiscal_year BETWEEN 2009 AND 2024
    GROUP BY m.fiscal_year
),
pb_revenue AS (
    SELECT m.fiscal_year, COUNT(DISTINCT m.cik) AS pb_rev
    FROM financial_analytics_silver.mart_peer_benchmark m
    INNER JOIN financial_analytics_silver.sp100_company_sector s ON m.cik = s.cik
    INNER JOIN pb_latest ON m.as_of_date = pb_latest.d
    WHERE m.canonical_concept = 'revenue' AND m.fiscal_year BETWEEN 2009 AND 2024
    GROUP BY m.fiscal_year
)
SELECT
    COALESCE(pl.fiscal_year, fh.fiscal_year, pb.fiscal_year) AS fiscal_year,
    COALESCE(pl.pl_rev, 0) AS mart_pl_trend_revenue_ciks,
    COALESCE(fh.fh_rev, 0) AS mart_financial_health_revenue_ciks,
    COALESCE(pb.pb_rev, 0) AS mart_peer_benchmark_revenue_ciks,
    CASE
        WHEN COALESCE(pl.pl_rev, 0) = COALESCE(fh.fh_rev, 0)
         AND COALESCE(fh.fh_rev, 0) = COALESCE(pb.pb_rev, 0)
        THEN 'PASS'
        ELSE 'FAIL'
    END AS consistency_check
FROM pl_revenue pl
FULL OUTER JOIN fh_revenue fh ON pl.fiscal_year = fh.fiscal_year
FULL OUTER JOIN pb_revenue pb ON COALESCE(pl.fiscal_year, fh.fiscal_year) = pb.fiscal_year
ORDER BY fiscal_year DESC;

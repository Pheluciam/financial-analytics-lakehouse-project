-- sql/audit/01_canonical_coverage.sql
--
-- Phase 5 session 2 — canonical coverage audit (Block A).
--
-- Goal: quantify the canonical-coverage gap across the S&P 100 universe
-- so we can fix it (not caveat it) before any Power BI authoring. Risk 55
-- exposed one 10-12% under-count on revenue; this audit measures the
-- equivalent gap on all 9 in-scope canonicals.
--
-- Output of this file (5 queries) is the gap matrix. The tag-evidence
-- pass (Block B) follows in sql/audit/02_tag_evidence.sql once we know
-- which (cik, canonical) cells need investigation.
--
-- Execution: Athena Console, signed in as phil-admin, workgroup
-- wg_financial_analytics, us-east-1. One query at a time per the
-- one-query-per-block convention.

-- ============================================================
-- A1 — Universe baseline by sector.
-- Sanity check: confirms 107 total + per-sector counts match the
-- sp100_company_sector seed. Anchor for every downstream percentage.
-- ============================================================
SELECT
    COALESCE(gics_sector, 'TOTAL') AS gics_sector,
    COUNT(DISTINCT cik) AS company_count
FROM financial_analytics_silver.sp100_company_sector
GROUP BY ROLLUP (gics_sector)
ORDER BY
    CASE WHEN gics_sector IS NULL THEN 1 ELSE 0 END,
    company_count DESC,
    gics_sector;


-- ============================================================
-- A2 — Per-canonical FY2024 coverage. The headline gap number.
-- 9 rows: canonical + universe + reporting + missing + pct_coverage.
-- Sourced from mart_financial_health at the latest as_of_date snapshot.
-- UNION ALL pivot rather than UNNEST(ARRAY[ROW(...)]) — Trino can't
-- unpack inline-ROW field names without explicit ARRAY(ROW(...)) cast.
-- ============================================================
WITH latest AS (
    SELECT MAX(as_of_date) AS latest_as_of
    FROM financial_analytics_silver.mart_financial_health
),
universe AS (
    SELECT COUNT(DISTINCT cik) AS n_companies
    FROM financial_analytics_silver.sp100_company_sector
),
fy2024 AS (
    SELECT m.*
    FROM financial_analytics_silver.mart_financial_health m
    INNER JOIN latest l ON m.as_of_date = l.latest_as_of
    WHERE m.fiscal_year = 2024
),
per_canonical AS (
    SELECT 'revenue' AS canonical_concept,
           COUNT(DISTINCT CASE WHEN revenue IS NOT NULL THEN cik END) AS reporting
    FROM fy2024
    UNION ALL
    SELECT 'net_income',
           COUNT(DISTINCT CASE WHEN net_income IS NOT NULL THEN cik END)
    FROM fy2024
    UNION ALL
    SELECT 'gross_profit',
           COUNT(DISTINCT CASE WHEN gross_profit IS NOT NULL THEN cik END)
    FROM fy2024
    UNION ALL
    SELECT 'operating_income',
           COUNT(DISTINCT CASE WHEN operating_income IS NOT NULL THEN cik END)
    FROM fy2024
    UNION ALL
    SELECT 'assets',
           COUNT(DISTINCT CASE WHEN assets IS NOT NULL THEN cik END)
    FROM fy2024
    UNION ALL
    SELECT 'liabilities',
           COUNT(DISTINCT CASE WHEN liabilities IS NOT NULL THEN cik END)
    FROM fy2024
    UNION ALL
    SELECT 'stockholders_equity',
           COUNT(DISTINCT CASE WHEN stockholders_equity IS NOT NULL THEN cik END)
    FROM fy2024
    UNION ALL
    SELECT 'cash_and_equivalents',
           COUNT(DISTINCT CASE WHEN cash_and_equivalents IS NOT NULL THEN cik END)
    FROM fy2024
    UNION ALL
    SELECT 'operating_cash_flow',
           COUNT(DISTINCT CASE WHEN operating_cash_flow IS NOT NULL THEN cik END)
    FROM fy2024
)
SELECT
    p.canonical_concept,
    u.n_companies AS universe,
    p.reporting,
    u.n_companies - p.reporting AS missing,
    ROUND(100.0 * p.reporting / u.n_companies, 1) AS pct_coverage
FROM per_canonical p
CROSS JOIN universe u
ORDER BY missing DESC, canonical_concept;


-- ============================================================
-- A3 — Per-canonical × per-sector FY2024 gap breakdown.
-- Only emits rows where missing > 0. Tells us whether each gap clusters
-- by sector (Risk 55 pattern — Financials concentrate on revenue) or is
-- scattered (suggests a different root cause).
-- ============================================================
WITH latest AS (
    SELECT MAX(as_of_date) AS latest_as_of
    FROM financial_analytics_silver.mart_financial_health
),
fy2024_with_sector AS (
    SELECT
        s.gics_sector,
        s.cik,
        m.revenue,
        m.net_income,
        m.gross_profit,
        m.operating_income,
        m.assets,
        m.liabilities,
        m.stockholders_equity,
        m.cash_and_equivalents,
        m.operating_cash_flow
    FROM financial_analytics_silver.sp100_company_sector s
    LEFT JOIN financial_analytics_silver.mart_financial_health m
        ON s.cik = m.cik
        AND m.as_of_date = (SELECT latest_as_of FROM latest)
        AND m.fiscal_year = 2024
),
long_format AS (
    SELECT gics_sector, 'revenue'              AS canonical_concept, CASE WHEN revenue              IS NOT NULL THEN 1 ELSE 0 END AS reporting FROM fy2024_with_sector
    UNION ALL
    SELECT gics_sector, 'net_income',           CASE WHEN net_income           IS NOT NULL THEN 1 ELSE 0 END FROM fy2024_with_sector
    UNION ALL
    SELECT gics_sector, 'gross_profit',         CASE WHEN gross_profit         IS NOT NULL THEN 1 ELSE 0 END FROM fy2024_with_sector
    UNION ALL
    SELECT gics_sector, 'operating_income',     CASE WHEN operating_income     IS NOT NULL THEN 1 ELSE 0 END FROM fy2024_with_sector
    UNION ALL
    SELECT gics_sector, 'assets',               CASE WHEN assets               IS NOT NULL THEN 1 ELSE 0 END FROM fy2024_with_sector
    UNION ALL
    SELECT gics_sector, 'liabilities',          CASE WHEN liabilities          IS NOT NULL THEN 1 ELSE 0 END FROM fy2024_with_sector
    UNION ALL
    SELECT gics_sector, 'stockholders_equity',  CASE WHEN stockholders_equity  IS NOT NULL THEN 1 ELSE 0 END FROM fy2024_with_sector
    UNION ALL
    SELECT gics_sector, 'cash_and_equivalents', CASE WHEN cash_and_equivalents IS NOT NULL THEN 1 ELSE 0 END FROM fy2024_with_sector
    UNION ALL
    SELECT gics_sector, 'operating_cash_flow',  CASE WHEN operating_cash_flow  IS NOT NULL THEN 1 ELSE 0 END FROM fy2024_with_sector
)
SELECT
    gics_sector,
    canonical_concept,
    COUNT(*) AS universe_in_sector,
    SUM(reporting) AS reporting,
    COUNT(*) - SUM(reporting) AS missing
FROM long_format
GROUP BY gics_sector, canonical_concept
HAVING COUNT(*) - SUM(reporting) > 0
ORDER BY missing DESC, gics_sector, canonical_concept;


-- ============================================================
-- A4 — Per-CIK × per-canonical presence matrix at FY2024 latest snapshot.
-- 107 rows × 9 cols = the triage matrix. Every 'MISSING' cell is a
-- decision: fix the seed (tag exists under a different name) vs defended
-- NULL (company genuinely doesn't file the concept).
-- ============================================================
WITH latest AS (
    SELECT MAX(as_of_date) AS latest_as_of
    FROM financial_analytics_silver.mart_financial_health
)
SELECT
    s.cik,
    s.ticker,
    s.entity_name,
    s.gics_sector,
    CASE WHEN m.revenue              IS NULL THEN 'MISSING' ELSE 'OK' END AS revenue,
    CASE WHEN m.net_income           IS NULL THEN 'MISSING' ELSE 'OK' END AS net_income,
    CASE WHEN m.gross_profit         IS NULL THEN 'MISSING' ELSE 'OK' END AS gross_profit,
    CASE WHEN m.operating_income     IS NULL THEN 'MISSING' ELSE 'OK' END AS operating_income,
    CASE WHEN m.assets               IS NULL THEN 'MISSING' ELSE 'OK' END AS assets,
    CASE WHEN m.liabilities          IS NULL THEN 'MISSING' ELSE 'OK' END AS liabilities,
    CASE WHEN m.stockholders_equity  IS NULL THEN 'MISSING' ELSE 'OK' END AS stockholders_equity,
    CASE WHEN m.cash_and_equivalents IS NULL THEN 'MISSING' ELSE 'OK' END AS cash_and_equivalents,
    CASE WHEN m.operating_cash_flow  IS NULL THEN 'MISSING' ELSE 'OK' END AS operating_cash_flow
FROM financial_analytics_silver.sp100_company_sector s
LEFT JOIN financial_analytics_silver.mart_financial_health m
    ON s.cik = m.cik
    AND m.as_of_date = (SELECT latest_as_of FROM latest)
    AND m.fiscal_year = 2024
ORDER BY s.gics_sector, s.entity_name;


-- ============================================================
-- A5 — Multi-year coverage trend FY2015-2024.
-- Same shape as A2 but per fiscal_year. Tells us whether the gap is
-- FY2024-only (recent filer lag, will self-heal) or chronic (a stable
-- tag-mapping gap that's been there all along — same fix needed for
-- backfilled years).
-- ============================================================
WITH latest AS (
    SELECT MAX(as_of_date) AS latest_as_of
    FROM financial_analytics_silver.mart_financial_health
),
universe AS (
    SELECT COUNT(DISTINCT cik) AS n_companies
    FROM financial_analytics_silver.sp100_company_sector
),
by_year AS (
    SELECT
        m.fiscal_year,
        COUNT(DISTINCT CASE WHEN m.revenue              IS NOT NULL THEN m.cik END) AS revenue,
        COUNT(DISTINCT CASE WHEN m.net_income           IS NOT NULL THEN m.cik END) AS net_income,
        COUNT(DISTINCT CASE WHEN m.gross_profit         IS NOT NULL THEN m.cik END) AS gross_profit,
        COUNT(DISTINCT CASE WHEN m.operating_income     IS NOT NULL THEN m.cik END) AS operating_income,
        COUNT(DISTINCT CASE WHEN m.assets               IS NOT NULL THEN m.cik END) AS assets,
        COUNT(DISTINCT CASE WHEN m.liabilities          IS NOT NULL THEN m.cik END) AS liabilities,
        COUNT(DISTINCT CASE WHEN m.stockholders_equity  IS NOT NULL THEN m.cik END) AS stockholders_equity,
        COUNT(DISTINCT CASE WHEN m.cash_and_equivalents IS NOT NULL THEN m.cik END) AS cash_and_equivalents,
        COUNT(DISTINCT CASE WHEN m.operating_cash_flow  IS NOT NULL THEN m.cik END) AS operating_cash_flow
    FROM financial_analytics_silver.mart_financial_health m
    INNER JOIN latest l ON m.as_of_date = l.latest_as_of
    WHERE m.fiscal_year BETWEEN 2015 AND 2024
    GROUP BY m.fiscal_year
)
SELECT
    b.fiscal_year,
    u.n_companies AS universe,
    b.revenue,
    b.net_income,
    b.gross_profit,
    b.operating_income,
    b.assets,
    b.liabilities,
    b.stockholders_equity,
    b.cash_and_equivalents,
    b.operating_cash_flow
FROM by_year b
CROSS JOIN universe u
ORDER BY b.fiscal_year DESC;

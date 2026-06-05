-- sql/verify/19_phase6_revenue_coverage_audit.sql
--
-- Phase 6 session 2 — Risk 55 regression guard (2026-06-05).
-- Standalone re-runnable artefact — paste the whole thing into Athena
-- Query Editor under workgroup wg_financial_analytics signed in as
-- phil-admin, region us-east-1.
--
-- WHY THIS FILE EXISTS. Risk 55 (sector-specific revenue tag-mapping gap;
-- banked Phase 5 session 1) was the observation that 18 S&P 100 companies
-- were missing FY2024 revenue in mart_pl_trend, dragging the universe
-- headline to $8.88T vs an estimated true ~$10T. The s2 diagnostic
-- (2026-06-05) proved the gap was already HEALED by two prior fixes —
-- the InterestAndDividendIncomeOperating tag add and the Risk 58
-- re-anchor of fiscal_year to year(period_end_date). FY2022-2025 all sit
-- at 100% universe revenue coverage; FY2025 = $9.91T. Risk 55 closes as
-- RESOLVED-by-prior-fixes (LEARNINGS Phase 6 session 2 entry).
--
-- This audit is the carry-forward the Risk 55 entry itself proposed: a
-- SQL-layer coverage check that FAILs if a recent COMPLETE fiscal year's
-- per-canonical company coverage silently drops below the universe bar —
-- catching any future mapping-gap or seed-roster regression at the data
-- layer BEFORE it surfaces as a Power BI visual surprise.
--
-- DESIGN. "Complete FY" = a fiscal_year whose distinct-company count at
-- the latest as_of_date clears the project coverage threshold
-- (latest_fy_min_ciks = 80 of 107; same gate that drives the dbt
-- is_latest_complete_fy flag). The guard asserts the latest complete FY
-- and the two preceding calendar years each hold >= 95% of the 107-CIK
-- universe for both headline canonicals (revenue + net_income), plus a
-- universe revenue reconciliation floor. It deliberately does NOT assert
-- anything about pre-2016 sparse-XBRL history or the in-progress current
-- calendar year (only a handful of early-FYE filers have filed) — those
-- are expected-low, not regressions.
--
--   1. Latest complete FY revenue coverage >= 102 CIKs (95% of 107).
--   2. Latest complete FY net_income coverage >= 102 CIKs.
--   3. Recent 3 complete FYs each hold revenue coverage >= 95% (FAIL
--      lists any offending year).
--   4. Latest complete FY universe revenue total >= $9.5T
--      (reconciliation floor; observed $9.91T at 2026-06-05).
--
-- Universe size and the 95% bar are derived from sp100_company_sector at
-- runtime, so the checks self-adjust if the roster seed changes.

WITH latest AS (
    SELECT MAX(as_of_date) AS aod FROM financial_analytics_silver.mart_pl_trend
),

universe AS (
    SELECT CAST(COUNT(*) AS double) AS n
    FROM financial_analytics_silver.sp100_company_sector
),

-- 95%-of-universe coverage bar, rounded up to a whole company.
bar AS (
    SELECT CAST(CEIL(0.95 * n) AS bigint) AS min_ciks FROM universe
),

-- Per-(fiscal_year, canonical) distinct-company coverage at the latest
-- snapshot, restricted to the two headline canonicals.
coverage AS (
    SELECT
        m.fiscal_year,
        m.canonical_concept,
        COUNT(DISTINCT m.cik) AS ciks
    FROM financial_analytics_silver.mart_pl_trend m
    CROSS JOIN latest l
    WHERE m.as_of_date = l.aod
      AND m.canonical_concept IN ('revenue', 'net_income')
    GROUP BY m.fiscal_year, m.canonical_concept
),

-- "Complete" fiscal years: revenue cohort clears the 80-CIK gate.
complete_fys AS (
    SELECT c.fiscal_year
    FROM coverage c
    WHERE c.canonical_concept = 'revenue' AND c.ciks >= 80
),

latest_complete_fy AS (
    SELECT MAX(fiscal_year) AS fy FROM complete_fys
),

-- The latest complete FY plus the two preceding calendar years.
recent_window AS (
    SELECT fy FROM latest_complete_fy
    UNION ALL SELECT fy - 1 FROM latest_complete_fy
    UNION ALL SELECT fy - 2 FROM latest_complete_fy
),

latest_revenue_total AS (
    SELECT COALESCE(SUM(m.value_numeric), 0) AS total
    FROM financial_analytics_silver.mart_pl_trend m
    CROSS JOIN latest l
    CROSS JOIN latest_complete_fy f
    WHERE m.as_of_date = l.aod
      AND m.canonical_concept = 'revenue'
      AND m.fiscal_year = f.fy
),

checks AS (
    -- 1. Latest complete FY revenue coverage >= 95% bar.
    SELECT
        1 AS check_no,
        'Latest complete FY revenue coverage >= 95% universe' AS check_name,
        CASE WHEN cov.ciks >= b.min_ciks THEN 'PASS' ELSE 'FAIL' END AS result,
        CAST(cov.ciks AS varchar) || ' CIKs at FY' || CAST(f.fy AS varchar)
            || ' (bar ' || CAST(b.min_ciks AS varchar) || ')' AS detail
    FROM latest_complete_fy f
    JOIN coverage cov
        ON cov.fiscal_year = f.fy AND cov.canonical_concept = 'revenue'
    CROSS JOIN bar b

    UNION ALL
    -- 2. Latest complete FY net_income coverage >= 95% bar.
    SELECT
        2,
        'Latest complete FY net_income coverage >= 95% universe',
        CASE WHEN cov.ciks >= b.min_ciks THEN 'PASS' ELSE 'FAIL' END,
        CAST(cov.ciks AS varchar) || ' CIKs at FY' || CAST(f.fy AS varchar)
            || ' (bar ' || CAST(b.min_ciks AS varchar) || ')'
    FROM latest_complete_fy f
    JOIN coverage cov
        ON cov.fiscal_year = f.fy AND cov.canonical_concept = 'net_income'
    CROSS JOIN bar b

    UNION ALL
    -- 3. Each of the recent 3 complete FYs holds revenue >= 95% bar.
    SELECT
        3,
        'Recent 3 complete FYs revenue coverage >= 95% universe',
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN COUNT(*) = 0
             THEN 'all recent complete FYs clear bar'
             ELSE 'below-bar years: ' || ARRAY_JOIN(ARRAY_AGG(
                  CAST(viol.fiscal_year AS varchar) ORDER BY viol.fiscal_year), ', ')
        END
    FROM (
        SELECT cov.fiscal_year
        FROM coverage cov
        JOIN recent_window rw ON rw.fy = cov.fiscal_year
        CROSS JOIN bar b
        WHERE cov.canonical_concept = 'revenue' AND cov.ciks < b.min_ciks
    ) viol

    UNION ALL
    -- 4. Latest complete FY universe revenue total >= $9.5T floor.
    SELECT
        4,
        'Latest complete FY universe revenue total >= $9.5T floor',
        CASE WHEN t.total >= 9.5e12 THEN 'PASS' ELSE 'FAIL' END,
        '$' || CAST(ROUND(t.total / 1e12, 2) AS varchar) || 'T'
    FROM latest_revenue_total t
)

SELECT check_no, check_name, result, detail
FROM checks
ORDER BY check_no;

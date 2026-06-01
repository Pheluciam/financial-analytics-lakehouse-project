-- sql/audit/02_universe_integrity.sql
--
-- Phase 5 audit 1 of 10 — universe integrity.
--
-- Goal: confirm every layer of the warehouse (seed, Bronze, hub_company,
-- 4 marts) holds exactly the 107 S&P 100 CIKs with no orphans, no
-- duplicates, no silently-missing companies. Block-by-block PASS/FAIL.
--
-- Execution: Athena Console, signed in as phil-admin, workgroup
-- wg_financial_analytics, us-east-1. One query at a time.

-- ============================================================
-- A1.1 — Seed sanity.
-- sp100_company_sector should have exactly 107 distinct CIKs and zero
-- duplicate ticker rows.
-- ============================================================
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT cik) AS distinct_ciks,
    COUNT(DISTINCT ticker) AS distinct_tickers,
    COUNT(DISTINCT entity_name) AS distinct_names,
    CASE
        WHEN COUNT(*) = 107
         AND COUNT(DISTINCT cik) = 107
         AND COUNT(DISTINCT ticker) = 107
        THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM financial_analytics_silver.sp100_company_sector;


-- ============================================================
-- A1.2 — Bronze CIK coverage vs seed.
-- All 107 seed CIKs present in Bronze. Orphans (Bronze CIKs not in seed)
-- listed by ticker for investigation.
-- ============================================================
WITH bronze_ciks AS (
    SELECT DISTINCT cik FROM financial_analytics_silver.stg_sec_edgar__companyfacts_raw
),
seed_ciks AS (
    SELECT cik FROM financial_analytics_silver.sp100_company_sector
)
SELECT
    (SELECT COUNT(*) FROM bronze_ciks) AS bronze_total,
    (SELECT COUNT(*) FROM seed_ciks) AS seed_total,
    (SELECT COUNT(*) FROM seed_ciks s WHERE EXISTS (SELECT 1 FROM bronze_ciks b WHERE b.cik = s.cik)) AS seed_in_bronze,
    (SELECT COUNT(*) FROM seed_ciks s WHERE NOT EXISTS (SELECT 1 FROM bronze_ciks b WHERE b.cik = s.cik)) AS seed_not_in_bronze,
    (SELECT COUNT(*) FROM bronze_ciks b WHERE NOT EXISTS (SELECT 1 FROM seed_ciks s WHERE s.cik = b.cik)) AS bronze_not_in_seed_orphans,
    CASE
        WHEN (SELECT COUNT(*) FROM seed_ciks s WHERE NOT EXISTS (SELECT 1 FROM bronze_ciks b WHERE b.cik = s.cik)) = 0
         AND (SELECT COUNT(*) FROM bronze_ciks b WHERE NOT EXISTS (SELECT 1 FROM seed_ciks s WHERE s.cik = b.cik)) = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS result;


-- ============================================================
-- A1.3 — Bronze orphan identification.
-- List the orphan CIKs by their entityname (from Bronze) so we can decide
-- if they're legitimate S&P 100 historical rotations vs accidental
-- extracts.
-- ============================================================
SELECT
    b.cik,
    MAX(b.entityname) AS entityname
FROM financial_analytics_bronze.sec_edgar_companyfacts b
WHERE NOT EXISTS (
    SELECT 1 FROM financial_analytics_silver.sp100_company_sector s
    WHERE s.cik = b.cik
)
GROUP BY b.cik
ORDER BY MAX(b.entityname);


-- ============================================================
-- A1.4 — Hub_company integrity.
-- Should hold the universe of CIKs from Bronze (~115 after backfill).
-- Identifies any hub orphans (in hub but not in Bronze) — would indicate
-- a stale Iceberg row not refreshed correctly.
-- ============================================================
WITH hub_ciks AS (
    SELECT DISTINCT cik FROM financial_analytics_silver.hub_company
),
bronze_ciks AS (
    SELECT DISTINCT cik FROM financial_analytics_silver.stg_sec_edgar__companyfacts_raw
),
seed_ciks AS (
    SELECT cik FROM financial_analytics_silver.sp100_company_sector
)
SELECT
    (SELECT COUNT(*) FROM hub_ciks) AS hub_total,
    (SELECT COUNT(*) FROM bronze_ciks) AS bronze_total,
    (SELECT COUNT(*) FROM seed_ciks) AS seed_total,
    (SELECT COUNT(*) FROM seed_ciks s WHERE EXISTS (SELECT 1 FROM hub_ciks h WHERE h.cik = s.cik)) AS seed_in_hub,
    (SELECT COUNT(*) FROM seed_ciks s WHERE NOT EXISTS (SELECT 1 FROM hub_ciks h WHERE h.cik = s.cik)) AS seed_not_in_hub,
    (SELECT COUNT(*) FROM hub_ciks h WHERE NOT EXISTS (SELECT 1 FROM bronze_ciks b WHERE b.cik = h.cik)) AS hub_not_in_bronze,
    CASE
        WHEN (SELECT COUNT(*) FROM seed_ciks s WHERE NOT EXISTS (SELECT 1 FROM hub_ciks h WHERE h.cik = s.cik)) = 0
         AND (SELECT COUNT(*) FROM hub_ciks h WHERE NOT EXISTS (SELECT 1 FROM bronze_ciks b WHERE b.cik = h.cik)) = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS result;


-- ============================================================
-- A1.5 — Each mart's CIK universe.
-- Every mart's distinct CIK set should ⊆ seed-or-Bronze. Lists any
-- mart-orphans (in mart, not in seed) — flags Bronze orphans
-- propagating downstream.
-- ============================================================
WITH seed_ciks AS (
    SELECT cik FROM financial_analytics_silver.sp100_company_sector
),
pl_trend_ciks AS (
    SELECT DISTINCT cik FROM financial_analytics_silver.mart_pl_trend
),
peer_benchmark_ciks AS (
    SELECT DISTINCT cik FROM financial_analytics_silver.mart_peer_benchmark
),
financial_health_ciks AS (
    SELECT DISTINCT cik FROM financial_analytics_silver.mart_financial_health
),
growth_forecast_ciks AS (
    SELECT DISTINCT cik FROM financial_analytics_silver.mart_growth_forecast
)
SELECT 'mart_pl_trend' AS mart,
       (SELECT COUNT(*) FROM pl_trend_ciks) AS distinct_ciks,
       (SELECT COUNT(*) FROM pl_trend_ciks m WHERE NOT EXISTS (SELECT 1 FROM seed_ciks s WHERE s.cik = m.cik)) AS orphans_not_in_seed,
       (SELECT COUNT(*) FROM seed_ciks s WHERE NOT EXISTS (SELECT 1 FROM pl_trend_ciks m WHERE m.cik = s.cik)) AS seed_missing_from_mart
UNION ALL
SELECT 'mart_peer_benchmark',
       (SELECT COUNT(*) FROM peer_benchmark_ciks),
       (SELECT COUNT(*) FROM peer_benchmark_ciks m WHERE NOT EXISTS (SELECT 1 FROM seed_ciks s WHERE s.cik = m.cik)),
       (SELECT COUNT(*) FROM seed_ciks s WHERE NOT EXISTS (SELECT 1 FROM peer_benchmark_ciks m WHERE m.cik = s.cik))
UNION ALL
SELECT 'mart_financial_health',
       (SELECT COUNT(*) FROM financial_health_ciks),
       (SELECT COUNT(*) FROM financial_health_ciks m WHERE NOT EXISTS (SELECT 1 FROM seed_ciks s WHERE s.cik = m.cik)),
       (SELECT COUNT(*) FROM seed_ciks s WHERE NOT EXISTS (SELECT 1 FROM financial_health_ciks m WHERE m.cik = s.cik))
UNION ALL
SELECT 'mart_growth_forecast',
       (SELECT COUNT(*) FROM growth_forecast_ciks),
       (SELECT COUNT(*) FROM growth_forecast_ciks m WHERE NOT EXISTS (SELECT 1 FROM seed_ciks s WHERE s.cik = m.cik)),
       (SELECT COUNT(*) FROM seed_ciks s WHERE NOT EXISTS (SELECT 1 FROM growth_forecast_ciks m WHERE m.cik = s.cik))
ORDER BY mart;


-- ============================================================
-- A1.6 — Composite PK uniqueness per mart at latest as_of_date.
-- Backstop on the dbt schema test for unique_combination_of_columns —
-- confirms no duplicate rows at the grain we'd report on.
-- ============================================================
WITH pl_latest AS (
    SELECT MAX(as_of_date) AS d FROM financial_analytics_silver.mart_pl_trend
),
pl_grain AS (
    SELECT cik, as_of_date, fiscal_year, canonical_concept, COUNT(*) AS row_count
    FROM financial_analytics_silver.mart_pl_trend m
    INNER JOIN pl_latest ON m.as_of_date = pl_latest.d
    GROUP BY cik, as_of_date, fiscal_year, canonical_concept
    HAVING COUNT(*) > 1
),
pb_latest AS (
    SELECT MAX(as_of_date) AS d FROM financial_analytics_silver.mart_peer_benchmark
),
pb_grain AS (
    SELECT cik, as_of_date, fiscal_year, canonical_concept, COUNT(*) AS row_count
    FROM financial_analytics_silver.mart_peer_benchmark m
    INNER JOIN pb_latest ON m.as_of_date = pb_latest.d
    GROUP BY cik, as_of_date, fiscal_year, canonical_concept
    HAVING COUNT(*) > 1
),
fh_latest AS (
    SELECT MAX(as_of_date) AS d FROM financial_analytics_silver.mart_financial_health
),
fh_grain AS (
    SELECT cik, as_of_date, fiscal_year, COUNT(*) AS row_count
    FROM financial_analytics_silver.mart_financial_health m
    INNER JOIN fh_latest ON m.as_of_date = fh_latest.d
    GROUP BY cik, as_of_date, fiscal_year
    HAVING COUNT(*) > 1
),
gf_latest AS (
    SELECT MAX(as_of_date) AS d FROM financial_analytics_silver.mart_growth_forecast
),
gf_grain AS (
    SELECT cik, as_of_date, fiscal_year, canonical_concept, row_kind, COUNT(*) AS row_count
    FROM financial_analytics_silver.mart_growth_forecast m
    INNER JOIN gf_latest ON m.as_of_date = gf_latest.d
    GROUP BY cik, as_of_date, fiscal_year, canonical_concept, row_kind
    HAVING COUNT(*) > 1
)
SELECT
    'mart_pl_trend' AS mart,
    (SELECT COUNT(*) FROM pl_grain) AS duplicate_rows_at_pk_grain,
    CASE WHEN (SELECT COUNT(*) FROM pl_grain) = 0 THEN 'PASS' ELSE 'FAIL' END AS result
UNION ALL
SELECT 'mart_peer_benchmark',
    (SELECT COUNT(*) FROM pb_grain),
    CASE WHEN (SELECT COUNT(*) FROM pb_grain) = 0 THEN 'PASS' ELSE 'FAIL' END
UNION ALL
SELECT 'mart_financial_health',
    (SELECT COUNT(*) FROM fh_grain),
    CASE WHEN (SELECT COUNT(*) FROM fh_grain) = 0 THEN 'PASS' ELSE 'FAIL' END
UNION ALL
SELECT 'mart_growth_forecast',
    (SELECT COUNT(*) FROM gf_grain),
    CASE WHEN (SELECT COUNT(*) FROM gf_grain) = 0 THEN 'PASS' ELSE 'FAIL' END
ORDER BY mart;

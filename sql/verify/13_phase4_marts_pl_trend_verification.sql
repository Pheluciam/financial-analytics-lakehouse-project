-- sql/verify/13_phase4_marts_pl_trend_verification.sql
--
-- Phase 4 session 1 — first Gold mart: mart_pl_trend. 10-year annual
-- P&L trend per S&P 100 company over the 10 fiscal year-end as-of-dates
-- in dim_as_of_dates, filtered to canonical_concept IN ('revenue',
-- 'net_income') AND fiscal_period = 'FY'.
--
-- Standalone re-runnable artefact — paste the whole thing into Athena
-- Query Editor under workgroup wg_financial_analytics signed in as
-- phil-admin, region us-east-1.
--
-- Checks 14 invariants on mart_pl_trend:
--
--   1. mart_pl_trend_hk is unique across all rows.
--   2. mart_pl_trend_hk is NOT NULL.
--   3. mart_pl_trend_hk is exactly 64 hex chars.
--   4. FK closure to hub_company via cik (every row's cik exists in hub).
--   5. FK closure to dim_as_of_dates via as_of_date.
--   6. FK closure to hub_concept via canonical_concept.
--   7. Composite natural PK (cik, as_of_date, fiscal_year, canonical_concept)
--      is unique across all rows.
--   8. Distinct as_of_date count = 10.
--   9. canonical_concept is restricted to ('revenue', 'net_income').
--  10. unit is constant 'USD' across all rows.
--  11. record_source is constant 'mart.mart_pl_trend'.
--  12. value_numeric is NOT NULL across all rows (analyst-facing fact
--      column — never silently NULL).
--  13. Mart hash determinism on Apple's first (as_of_date, fiscal_year,
--      canonical_concept) tuple — recomputes the 4-component composite
--      SHA-256 chain (cik || as_of_date || fiscal_year || canonical_concept)
--      and confirms stored hash matches.
--  14. Row count falls within the prediction band [1,000, 20,000] — wide
--      band for first-run defensive tolerance. Tightens at Phase 4 session 2+
--      once empirical baseline is established.

WITH apple_sample AS (
    SELECT
        m.mart_pl_trend_hk,
        m.cik,
        m.as_of_date,
        m.fiscal_year,
        m.canonical_concept
    FROM financial_analytics_silver.mart_pl_trend m
    WHERE m.cik = '0000320193'
    ORDER BY m.as_of_date, m.fiscal_year, m.canonical_concept
    LIMIT 1
),

checks AS (

    SELECT
        'check_01_mart_hk_unique' AS check_name,
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_pl_trend) AS expected,
        (SELECT COUNT(DISTINCT mart_pl_trend_hk) FROM financial_analytics_silver.mart_pl_trend) AS actual

    UNION ALL SELECT
        'check_02_mart_hk_not_null',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_pl_trend),
        (SELECT COUNT(mart_pl_trend_hk) FROM financial_analytics_silver.mart_pl_trend)

    UNION ALL SELECT
        'check_03_mart_hk_length_64',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_pl_trend),
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_pl_trend WHERE length(mart_pl_trend_hk) = 64)

    UNION ALL SELECT
        'check_04_mart_fk_closure_hub_company',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_pl_trend),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.mart_pl_trend m
         INNER JOIN financial_analytics_silver.hub_company h
           ON m.cik = h.cik)

    UNION ALL SELECT
        'check_05_mart_fk_closure_dim_as_of',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_pl_trend),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.mart_pl_trend m
         INNER JOIN financial_analytics_silver.dim_as_of_dates d
           ON m.as_of_date = d.as_of_date)

    UNION ALL SELECT
        'check_06_mart_fk_closure_hub_concept',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_pl_trend),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.mart_pl_trend m
         INNER JOIN financial_analytics_silver.hub_concept c
           ON m.canonical_concept = c.canonical_concept)

    UNION ALL SELECT
        'check_07_mart_composite_pk_unique',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_pl_trend),
        (SELECT COUNT(*)
         FROM (
             SELECT DISTINCT cik, as_of_date, fiscal_year, canonical_concept
             FROM financial_analytics_silver.mart_pl_trend
         ))

    UNION ALL SELECT
        'check_08_distinct_as_of_count',
        CAST(10 AS bigint),
        (SELECT COUNT(DISTINCT as_of_date) FROM financial_analytics_silver.mart_pl_trend)

    UNION ALL SELECT
        'check_09_canonical_concept_accepted_values',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_pl_trend),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.mart_pl_trend
         WHERE canonical_concept IN ('revenue', 'net_income'))

    UNION ALL SELECT
        'check_10_unit_constant_usd',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_pl_trend),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.mart_pl_trend
         WHERE unit = 'USD')

    UNION ALL SELECT
        'check_11_record_source_constant',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_pl_trend),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.mart_pl_trend
         WHERE record_source = 'mart.mart_pl_trend')

    UNION ALL SELECT
        'check_12_value_numeric_not_null',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_pl_trend),
        (SELECT COUNT(value_numeric) FROM financial_analytics_silver.mart_pl_trend)

    UNION ALL SELECT
        'check_13_mart_hk_reproducible',
        CAST(1 AS bigint),
        (SELECT COUNT(*)
         FROM apple_sample
         WHERE mart_pl_trend_hk = to_hex(sha256(to_utf8(
               CAST(cik AS varchar) || '||' ||
               CAST(as_of_date AS varchar) || '||' ||
               CAST(fiscal_year AS varchar) || '||' ||
               CAST(canonical_concept AS varchar)
           ))))

    UNION ALL SELECT
        'check_14_row_count_band',
        CAST(1 AS bigint),
        (SELECT CASE
                  WHEN COUNT(*) BETWEEN 1000 AND 20000 THEN 1
                  ELSE 0
                END
         FROM financial_analytics_silver.mart_pl_trend)
)

SELECT
    check_name,
    expected,
    actual,
    CASE WHEN expected = actual THEN 'PASS' ELSE 'FAIL' END AS result
FROM checks
ORDER BY check_name;

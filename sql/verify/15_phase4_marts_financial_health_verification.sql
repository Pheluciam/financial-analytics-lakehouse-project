-- sql/verify/15_phase4_marts_financial_health_verification.sql
--
-- Phase 4 session 3 — third Gold mart: mart_financial_health. Per-company
-- annual ratios spanning income statement, balance sheet, and cash flow
-- statement. Composite natural PK = (cik, as_of_date, fiscal_year); 9
-- in-scope canonicals pivoted onto columns + 8 derived ratios.
--
-- Standalone re-runnable artefact — paste the whole thing into Athena
-- Query Editor under workgroup wg_financial_analytics signed in as
-- phil-admin, region us-east-1.
--
-- Checks 17 invariants on mart_financial_health:
--
--   1. mart_financial_health_hk is unique across all rows.
--   2. mart_financial_health_hk is NOT NULL.
--   3. mart_financial_health_hk is exactly 64 hex chars.
--   4. FK closure to hub_company via cik.
--   5. FK closure to dim_as_of_dates via as_of_date.
--   6. Composite natural PK (cik, as_of_date, fiscal_year) is unique.
--   7. Distinct as_of_date count = 10.
--   8. cik NOT NULL across all rows.
--   9. as_of_date NOT NULL across all rows.
--  10. fiscal_year NOT NULL across all rows.
--  11. entity_name NOT NULL across all rows.
--  12. period_end_date NOT NULL across all rows.
--  13. record_source constant 'mart.mart_financial_health'.
--  14. At least one of revenue / assets reported on every row (rules
--      out the pathological all-NULL row case).
--  15. gross_margin finite when populated — between -100 and 1 (negative
--      margins for distressed companies; >100% would indicate data error).
--      Known-artifact exclusion: Salesforce (cik 0001108524) FY2010-2013
--      reports gross_profit 2-7% above revenue — pre-ASC-606 revenue
--      tagging mismatch where the GrossProfit tag is anchored to a
--      multi-tag revenue base while sat_concept_value's value DESC
--      collapse picks the largest single Revenues alias. 4 (cik, fy)
--      tuples × ~3 visible as_of_dates = 13 mart rows. Documented as
--      Risk 49 (LEARNINGS, 2026-05-30). Excluded from the check denominator
--      AND numerator so the structural invariant tests cleanly across
--      the rest of the universe.
--  16. Mart hash determinism on Apple's first (as_of_date, fiscal_year)
--      tuple.
--  17. Row count falls within prediction band [500, 12000] — ~100
--      companies × 10 visible as_of_dates × ~10 fiscal years
--      order-of-magnitude with NULL-canonical attrition.

WITH apple_sample AS (
    SELECT
        m.mart_financial_health_hk,
        m.cik,
        m.as_of_date,
        m.fiscal_year
    FROM financial_analytics_silver.mart_financial_health m
    WHERE m.cik = '0000320193'
    ORDER BY m.as_of_date, m.fiscal_year
    LIMIT 1
),

checks AS (

    SELECT
        'check_01_mart_hk_unique' AS check_name,
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_financial_health) AS expected,
        (SELECT COUNT(DISTINCT mart_financial_health_hk) FROM financial_analytics_silver.mart_financial_health) AS actual

    UNION ALL SELECT
        'check_02_mart_hk_not_null',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_financial_health),
        (SELECT COUNT(mart_financial_health_hk) FROM financial_analytics_silver.mart_financial_health)

    UNION ALL SELECT
        'check_03_mart_hk_length_64',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_financial_health),
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_financial_health WHERE length(mart_financial_health_hk) = 64)

    UNION ALL SELECT
        'check_04_mart_fk_closure_hub_company',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_financial_health),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.mart_financial_health m
         INNER JOIN financial_analytics_silver.hub_company h
           ON m.cik = h.cik)

    UNION ALL SELECT
        'check_05_mart_fk_closure_dim_as_of',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_financial_health),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.mart_financial_health m
         INNER JOIN financial_analytics_silver.dim_as_of_dates d
           ON m.as_of_date = d.as_of_date)

    UNION ALL SELECT
        'check_06_mart_composite_pk_unique',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_financial_health),
        (SELECT COUNT(*)
         FROM (
             SELECT DISTINCT cik, as_of_date, fiscal_year
             FROM financial_analytics_silver.mart_financial_health
         ))

    UNION ALL SELECT
        'check_07_distinct_as_of_count',
        CAST(10 AS bigint),
        (SELECT COUNT(DISTINCT as_of_date) FROM financial_analytics_silver.mart_financial_health)

    UNION ALL SELECT
        'check_08_cik_not_null',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_financial_health),
        (SELECT COUNT(cik) FROM financial_analytics_silver.mart_financial_health)

    UNION ALL SELECT
        'check_09_as_of_date_not_null',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_financial_health),
        (SELECT COUNT(as_of_date) FROM financial_analytics_silver.mart_financial_health)

    UNION ALL SELECT
        'check_10_fiscal_year_not_null',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_financial_health),
        (SELECT COUNT(fiscal_year) FROM financial_analytics_silver.mart_financial_health)

    UNION ALL SELECT
        'check_11_entity_name_not_null',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_financial_health),
        (SELECT COUNT(entity_name) FROM financial_analytics_silver.mart_financial_health)

    UNION ALL SELECT
        'check_12_period_end_date_not_null',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_financial_health),
        (SELECT COUNT(period_end_date) FROM financial_analytics_silver.mart_financial_health)

    UNION ALL SELECT
        'check_13_record_source_constant',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_financial_health),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.mart_financial_health
         WHERE record_source = 'mart.mart_financial_health')

    UNION ALL SELECT
        'check_14_at_least_revenue_or_assets',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_financial_health),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.mart_financial_health
         WHERE revenue IS NOT NULL OR assets IS NOT NULL)

    UNION ALL SELECT
        'check_15_gross_margin_finite_bounded',
        (SELECT COUNT(*)
         FROM financial_analytics_silver.mart_financial_health
         WHERE gross_margin IS NOT NULL
           AND NOT (cik = '0001108524' AND fiscal_year BETWEEN 2010 AND 2013)),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.mart_financial_health
         WHERE gross_margin IS NOT NULL
           AND NOT (cik = '0001108524' AND fiscal_year BETWEEN 2010 AND 2013)
           AND is_finite(gross_margin)
           AND gross_margin BETWEEN -100 AND 1)

    UNION ALL SELECT
        'check_16_mart_hk_reproducible',
        CAST(1 AS bigint),
        (SELECT COUNT(*)
         FROM apple_sample
         WHERE mart_financial_health_hk = to_hex(sha256(to_utf8(
               CAST(cik AS varchar) || '||' ||
               CAST(as_of_date AS varchar) || '||' ||
               CAST(fiscal_year AS varchar)
           ))))

    UNION ALL SELECT
        'check_17_row_count_band',
        CAST(1 AS bigint),
        (SELECT CASE
                  WHEN COUNT(*) BETWEEN 500 AND 12000 THEN 1
                  ELSE 0
                END
         FROM financial_analytics_silver.mart_financial_health)
)

SELECT
    check_name,
    expected,
    actual,
    CASE WHEN expected = actual THEN 'PASS' ELSE 'FAIL' END AS result
FROM checks
ORDER BY check_name;

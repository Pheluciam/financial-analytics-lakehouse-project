-- sql/verify/16_phase4_marts_growth_forecast_verification.sql
--
-- Phase 4 session 4 — fourth Gold mart: mart_growth_forecast. Per-company
-- annual revenue trajectory unifying historical observed values (from
-- mart_pl_trend) and forward-looking 3-year forecasts (from
-- scripts/forecast.py via the forecast_surface external table).
-- Composite natural PK = (cik, canonical_concept, fiscal_year, as_of_date,
-- row_kind). UNION ALL over historical + forecast legs.
--
-- Standalone re-runnable artefact — paste the whole thing into Athena
-- Query Editor under workgroup wg_financial_analytics signed in as
-- phil-admin, region us-east-1.
--
-- Checks 18 invariants on mart_growth_forecast:
--
--   1. mart_growth_forecast_hk is unique across all rows.
--   2. mart_growth_forecast_hk is NOT NULL.
--   3. mart_growth_forecast_hk is exactly 64 hex chars.
--   4. FK closure to hub_company via cik.
--   5. Composite natural PK (cik, canonical_concept, fiscal_year,
--      as_of_date, row_kind) is unique.
--   6. cik NOT NULL across all rows.
--   7. fiscal_year NOT NULL across all rows.
--   8. canonical_concept NOT NULL across all rows.
--   9. row_kind NOT NULL across all rows.
--  10. entity_name NOT NULL across all rows.
--  11. record_source constant 'mart.mart_growth_forecast'.
--  12. canonical_concept = 'revenue' across all rows (session 4 scope).
--  13. row_kind IN ('historical', 'forecast') across all rows.
--  14. Historical-leg rows: value_numeric IS NOT NULL AND forecast_value
--      IS NULL.
--  15. Forecast-leg rows: forecast_value IS NOT NULL AND value_numeric
--      IS NULL.
--  16. Forecast CIs are coherent: lower_ci_95 <= forecast_value <= upper_ci_95
--      on every forecast row.
--  17. Forecast horizon: forecast rows span exactly 3 distinct
--      forecast_year values per company (3-year horizon).
--  18. Row count falls within prediction band [10000, 40000] —
--      ~9,700 historical revenue rows from mart_pl_trend (post Risk 48
--      filter, ~100 companies × ~10 fiscal years × 10 as_of_dates) +
--      ~300 forecast rows (~100 companies × 3 forecast years).

WITH checks AS (

    SELECT
        'check_01_mart_hk_unique' AS check_name,
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_growth_forecast) AS expected,
        (SELECT COUNT(DISTINCT mart_growth_forecast_hk) FROM financial_analytics_silver.mart_growth_forecast) AS actual

    UNION ALL SELECT
        'check_02_mart_hk_not_null',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_growth_forecast),
        (SELECT COUNT(mart_growth_forecast_hk) FROM financial_analytics_silver.mart_growth_forecast)

    UNION ALL SELECT
        'check_03_mart_hk_length_64',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_growth_forecast),
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_growth_forecast WHERE length(mart_growth_forecast_hk) = 64)

    UNION ALL SELECT
        'check_04_mart_fk_closure_hub_company',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_growth_forecast),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.mart_growth_forecast m
         INNER JOIN financial_analytics_silver.hub_company h
           ON m.cik = h.cik)

    UNION ALL SELECT
        'check_05_mart_composite_pk_unique',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_growth_forecast),
        (SELECT COUNT(*)
         FROM (
             SELECT DISTINCT cik, canonical_concept, fiscal_year, as_of_date, row_kind
             FROM financial_analytics_silver.mart_growth_forecast
         ))

    UNION ALL SELECT
        'check_06_cik_not_null',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_growth_forecast),
        (SELECT COUNT(cik) FROM financial_analytics_silver.mart_growth_forecast)

    UNION ALL SELECT
        'check_07_fiscal_year_not_null',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_growth_forecast),
        (SELECT COUNT(fiscal_year) FROM financial_analytics_silver.mart_growth_forecast)

    UNION ALL SELECT
        'check_08_canonical_concept_not_null',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_growth_forecast),
        (SELECT COUNT(canonical_concept) FROM financial_analytics_silver.mart_growth_forecast)

    UNION ALL SELECT
        'check_09_row_kind_not_null',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_growth_forecast),
        (SELECT COUNT(row_kind) FROM financial_analytics_silver.mart_growth_forecast)

    UNION ALL SELECT
        'check_10_entity_name_not_null',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_growth_forecast),
        (SELECT COUNT(entity_name) FROM financial_analytics_silver.mart_growth_forecast)

    UNION ALL SELECT
        'check_11_record_source_constant',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_growth_forecast),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.mart_growth_forecast
         WHERE record_source = 'mart.mart_growth_forecast')

    UNION ALL SELECT
        'check_12_canonical_revenue_only',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_growth_forecast),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.mart_growth_forecast
         WHERE canonical_concept = 'revenue')

    UNION ALL SELECT
        'check_13_row_kind_accepted_values',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_growth_forecast),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.mart_growth_forecast
         WHERE row_kind IN ('historical', 'forecast'))

    UNION ALL SELECT
        'check_14_historical_leg_columns_populated',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_growth_forecast
         WHERE row_kind = 'historical'),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.mart_growth_forecast
         WHERE row_kind = 'historical'
           AND value_numeric IS NOT NULL
           AND forecast_value IS NULL
           AND lower_ci_95 IS NULL
           AND upper_ci_95 IS NULL
           AND model_name IS NULL)

    UNION ALL SELECT
        'check_15_forecast_leg_columns_populated',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_growth_forecast
         WHERE row_kind = 'forecast'),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.mart_growth_forecast
         WHERE row_kind = 'forecast'
           AND forecast_value IS NOT NULL
           AND value_numeric IS NULL
           AND lower_ci_95 IS NOT NULL
           AND upper_ci_95 IS NOT NULL
           AND model_name IS NOT NULL)

    UNION ALL SELECT
        'check_16_forecast_ci_coherent',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_growth_forecast
         WHERE row_kind = 'forecast'),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.mart_growth_forecast
         WHERE row_kind = 'forecast'
           AND lower_ci_95 <= forecast_value
           AND forecast_value <= upper_ci_95)

    UNION ALL SELECT
        'check_17_forecast_horizon_3_years_per_company',
        (SELECT COUNT(DISTINCT cik) FROM financial_analytics_silver.mart_growth_forecast
         WHERE row_kind = 'forecast'),
        (SELECT COUNT(*)
         FROM (
             SELECT cik
             FROM financial_analytics_silver.mart_growth_forecast
             WHERE row_kind = 'forecast'
             GROUP BY cik
             HAVING COUNT(DISTINCT fiscal_year) = 3
         ))

    UNION ALL SELECT
        'check_18_row_count_band',
        CAST(1 AS bigint),
        (SELECT CASE
                  WHEN COUNT(*) BETWEEN 10000 AND 40000 THEN 1
                  ELSE 0
                END
         FROM financial_analytics_silver.mart_growth_forecast)
)

SELECT
    check_name,
    expected,
    actual,
    CASE WHEN expected = actual THEN 'PASS' ELSE 'FAIL' END AS result
FROM checks
ORDER BY check_name;

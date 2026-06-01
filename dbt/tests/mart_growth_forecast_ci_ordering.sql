-- dbt data test: mart_growth_forecast confidence-interval ordering.
--
-- Asserts that for every forecast row, lower_ci_95 <= forecast_value AND
-- forecast_value <= upper_ci_95. Catches CI corruption from a future
-- statsmodels behavior change or a script bug in scripts/forecast.py.
-- Audit 9 confirmed 0 violations across the 336 forecast rows at audit
-- close; this test locks that property.
--
-- Source: AUDIT_FINDINGS.md Audit 9 + Audit 10 A10.4 spec item 6.
-- PASS condition: zero rows returned.

SELECT cik, fiscal_year, forecast_value, lower_ci_95, upper_ci_95
FROM {{ ref('mart_growth_forecast') }}
WHERE row_kind = 'forecast'
  AND (
      lower_ci_95 IS NULL
      OR forecast_value IS NULL
      OR upper_ci_95 IS NULL
      OR lower_ci_95 > forecast_value
      OR forecast_value > upper_ci_95
  )

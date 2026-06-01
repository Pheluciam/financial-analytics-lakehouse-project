-- dbt data test: cross-mart revenue consistency between mart_pl_trend
-- and mart_financial_health.
--
-- Asserts that for every (cik, fiscal_year) tuple present in both marts
-- at the latest as_of_date, revenue agrees within $1 (raw DECIMAL(28,2)
-- rounding tolerance). Catches regressions of the Risk 58 period-end
-- re-anchor — Audit 7 surfaced 19 / 1703 divergent rows under the prior
-- SEC fy attribute anchor; post-Fix expectation is zero.
--
-- Source: AUDIT_FINDINGS.md Audit 7 + Audit 10 A10.4 spec item 3.
-- PASS condition: zero rows returned.

WITH pl_latest AS (
    SELECT MAX(as_of_date) AS d FROM {{ ref('mart_pl_trend') }}
),
fh_latest AS (
    SELECT MAX(as_of_date) AS d FROM {{ ref('mart_financial_health') }}
),
pl AS (
    SELECT cik, fiscal_year, value_numeric AS revenue
    FROM {{ ref('mart_pl_trend') }}
    WHERE canonical_concept = 'revenue'
      AND as_of_date = (SELECT d FROM pl_latest)
),
fh AS (
    SELECT cik, fiscal_year, revenue
    FROM {{ ref('mart_financial_health') }}
    WHERE as_of_date = (SELECT d FROM fh_latest)
      AND revenue IS NOT NULL
)
SELECT pl.cik, pl.fiscal_year, pl.revenue AS pl_value, fh.revenue AS fh_value,
       ABS(pl.revenue - fh.revenue) AS delta
FROM pl
INNER JOIN fh ON fh.cik = pl.cik AND fh.fiscal_year = pl.fiscal_year
WHERE ABS(pl.revenue - fh.revenue) > 1

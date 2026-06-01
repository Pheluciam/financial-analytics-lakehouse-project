-- dbt data test: cross-mart net_income consistency between mart_pl_trend
-- and mart_financial_health.
--
-- Asserts that for every (cik, fiscal_year) tuple present in both marts
-- at the latest as_of_date, net_income agrees within $1. Audit 7 surfaced
-- 17 / 1703 divergent rows pre-Fix; post-Fix expectation is zero.
--
-- Source: AUDIT_FINDINGS.md Audit 7 + Audit 10 A10.4 spec item 4.
-- PASS condition: zero rows returned.

WITH pl_latest AS (
    SELECT MAX(as_of_date) AS d FROM {{ ref('mart_pl_trend') }}
),
fh_latest AS (
    SELECT MAX(as_of_date) AS d FROM {{ ref('mart_financial_health') }}
),
pl AS (
    SELECT cik, fiscal_year, value_numeric AS net_income
    FROM {{ ref('mart_pl_trend') }}
    WHERE canonical_concept = 'net_income'
      AND as_of_date = (SELECT d FROM pl_latest)
),
fh AS (
    SELECT cik, fiscal_year, net_income
    FROM {{ ref('mart_financial_health') }}
    WHERE as_of_date = (SELECT d FROM fh_latest)
      AND net_income IS NOT NULL
)
SELECT pl.cik, pl.fiscal_year, pl.net_income AS pl_value, fh.net_income AS fh_value,
       ABS(pl.net_income - fh.net_income) AS delta
FROM pl
INNER JOIN fh ON fh.cik = pl.cik AND fh.fiscal_year = pl.fiscal_year
WHERE ABS(pl.net_income - fh.net_income) > 1

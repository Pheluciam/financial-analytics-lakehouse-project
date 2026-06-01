-- dbt data test: cross-mart assets consistency between mart_peer_benchmark
-- and mart_financial_health.
--
-- Asserts that for every (cik, fiscal_year) tuple present in both marts at
-- the latest as_of_date, assets agrees within $1. Audit 7 surfaced 62 / 1703
-- divergent rows pre-Fix (the largest single-canonical divergence count);
-- post-Fix expectation is zero.
--
-- Source: AUDIT_FINDINGS.md Audit 7 + Audit 10 A10.4 spec item 5.
-- PASS condition: zero rows returned.

WITH pb_latest AS (
    SELECT MAX(as_of_date) AS d FROM {{ ref('mart_peer_benchmark') }}
),
fh_latest AS (
    SELECT MAX(as_of_date) AS d FROM {{ ref('mart_financial_health') }}
),
pb AS (
    SELECT cik, fiscal_year, value_numeric AS assets
    FROM {{ ref('mart_peer_benchmark') }}
    WHERE canonical_concept = 'assets'
      AND as_of_date = (SELECT d FROM pb_latest)
),
fh AS (
    SELECT cik, fiscal_year, assets
    FROM {{ ref('mart_financial_health') }}
    WHERE as_of_date = (SELECT d FROM fh_latest)
      AND assets IS NOT NULL
)
SELECT pb.cik, pb.fiscal_year, pb.assets AS pb_value, fh.assets AS fh_value,
       ABS(pb.assets - fh.assets) AS delta
FROM pb
INNER JOIN fh ON fh.cik = pb.cik AND fh.fiscal_year = pb.fiscal_year
WHERE ABS(pb.assets - fh.assets) > 1

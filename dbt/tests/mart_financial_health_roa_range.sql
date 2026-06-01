-- dbt data test: mart_financial_health.return_on_assets range sanity.
--
-- Asserts that return_on_assets (when non-NULL) falls within [-1.0, 1.0].
-- ROA = net_income / assets; values outside [-100%, 100%] indicate
-- denominator corruption (very small assets) or a ratio-computation bug.
-- Asset-light services companies can post ROA above 50% legitimately, but
-- crossing 100% means net_income exceeds the asset base for the period —
-- a data quality signal.
--
-- Source: AUDIT_FINDINGS.md Audit 10 A10.4 spec item 10 (range test in
-- place of dbt_expectations dependency).
-- PASS condition: zero rows returned.

SELECT cik, fiscal_year, net_income, assets, return_on_assets
FROM {{ ref('mart_financial_health') }}
WHERE return_on_assets IS NOT NULL
  AND (return_on_assets < -1.0 OR return_on_assets > 1.0)

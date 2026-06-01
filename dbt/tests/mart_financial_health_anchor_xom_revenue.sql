-- dbt data test: XOM FY2024 revenue anchor.
--
-- Asserts XOM revenue at fiscal_year = 2024 at the latest as_of_date falls
-- within [$340B, $360B]. Anchor value $349.585B from mart_financial_health
-- (matches Exxon Mobil's published FY2024 10-K $349.6B within 0.004%),
-- captured in audit/anchor_truth.md.
--
-- Source: AUDIT_FINDINGS.md Audit 6 + Audit 10 A10.4 spec item 2.
-- PASS condition: zero rows returned.

WITH latest AS (
    SELECT MAX(as_of_date) AS d FROM {{ ref('mart_financial_health') }}
)
SELECT cik, fiscal_year, revenue
FROM {{ ref('mart_financial_health') }}
WHERE cik = '0000034088'
  AND fiscal_year = 2024
  AND as_of_date = (SELECT d FROM latest)
  AND (revenue IS NULL OR revenue < 340000000000 OR revenue > 360000000000)

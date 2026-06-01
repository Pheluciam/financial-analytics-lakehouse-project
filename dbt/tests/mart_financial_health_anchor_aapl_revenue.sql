-- dbt data test: AAPL FY2024 revenue anchor.
--
-- Asserts AAPL revenue at fiscal_year = 2024 at the latest as_of_date falls
-- within [$380B, $400B]. Anchor value $391.035B verified against Apple's
-- FY2024 10-K (filed 2024-11-01), captured in audit/anchor_truth.md.
-- ±2.5% tolerance band catches material drift without false-flagging minor
-- alias coverage changes.
--
-- Source: AUDIT_FINDINGS.md Audit 6 + Audit 10 A10.4 spec item 2.
-- PASS condition: zero rows returned.

WITH latest AS (
    SELECT MAX(as_of_date) AS d FROM {{ ref('mart_financial_health') }}
)
SELECT cik, fiscal_year, revenue
FROM {{ ref('mart_financial_health') }}
WHERE cik = '0000320193'
  AND fiscal_year = 2024
  AND as_of_date = (SELECT d FROM latest)
  AND (revenue IS NULL OR revenue < 380000000000 OR revenue > 400000000000)

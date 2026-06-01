-- dbt data test: MSFT FY2024 revenue anchor.
--
-- Asserts MSFT revenue at fiscal_year = 2024 at the latest as_of_date falls
-- within [$238B, $252B]. Anchor value $245.122B verified against Microsoft
-- FY2024 10-K, captured in audit/anchor_truth.md. MSFT fiscal year ends in
-- June; the calendar-year-of-period-end re-anchor (Risk 58) places this
-- under fiscal_year = 2024 in the mart (period_end_date 2024-06-30).
--
-- Source: AUDIT_FINDINGS.md Audit 6 + Audit 10 A10.4 spec item 2.
-- PASS condition: zero rows returned.

WITH latest AS (
    SELECT MAX(as_of_date) AS d FROM {{ ref('mart_financial_health') }}
)
SELECT cik, fiscal_year, revenue
FROM {{ ref('mart_financial_health') }}
WHERE cik = '0000789019'
  AND fiscal_year = 2024
  AND as_of_date = (SELECT d FROM latest)
  AND (revenue IS NULL OR revenue < 238000000000 OR revenue > 252000000000)

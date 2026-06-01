-- dbt data test: WMT FY2024 revenue anchor.
--
-- Asserts WMT revenue at fiscal_year = 2024 at the latest as_of_date falls
-- within [$630B, $665B]. Anchor value $648.125B verified against Walmart
-- FY2024 10-K, captured in audit/anchor_truth.md. WMT is a 52/53-week
-- filer with January fiscal-year-end — its FY2024 period_end_date is
-- 2024-01-31. Under Risk 58 period-end re-anchor, the mart row falls at
-- fiscal_year = 2024 by calendar-year-of-period-end (NOT by SEC fy
-- attribute which would be 2023 for this row). Direct regression
-- coverage for the WMT FY2012/FY2013 dedup non-determinism Audit 7
-- diagnosed.
--
-- Source: AUDIT_FINDINGS.md Audit 6 + Audit 10 A10.4 spec item 2.
-- PASS condition: zero rows returned.

WITH latest AS (
    SELECT MAX(as_of_date) AS d FROM {{ ref('mart_financial_health') }}
)
SELECT cik, fiscal_year, revenue
FROM {{ ref('mart_financial_health') }}
WHERE cik = '0000104169'
  AND fiscal_year = 2024
  AND as_of_date = (SELECT d FROM latest)
  AND (revenue IS NULL OR revenue < 630000000000 OR revenue > 665000000000)

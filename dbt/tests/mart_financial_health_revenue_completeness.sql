-- dbt data test: mart_financial_health revenue completeness threshold at FY2024.
--
-- Asserts that at the latest as_of_date, at least 95 of the 107 S&P 100 CIKs
-- report a non-null revenue value at fiscal_year = 2024. Catches regressions
-- of the Audit 4 + Audit 5 fixes (period-end re-anchor + Financials sector
-- revenue alias). Audit 6 anchor count was 106 of 107 reporting CIKs pre-Fix
-- (SPGI absent due to Audit 4 bug); post-Fix expectation is ~106-107.
-- Threshold set at 95 to absorb future minor alias-coverage drift without
-- false-flagging, while still catching catastrophic completeness regressions.
--
-- Source: AUDIT_FINDINGS.md Audit 10 A10.4 spec item 1.
-- PASS condition: zero rows returned.

WITH latest AS (
    SELECT MAX(as_of_date) AS d FROM {{ ref('mart_financial_health') }}
),
reporting_count AS (
    SELECT COUNT(DISTINCT cik) AS reporting_ciks
    FROM {{ ref('mart_financial_health') }}
    WHERE as_of_date = (SELECT d FROM latest)
      AND fiscal_year = 2024
      AND revenue IS NOT NULL
)
SELECT *
FROM reporting_count
WHERE reporting_ciks < 95

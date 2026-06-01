-- dbt data test: JPM FY2024 revenue anchor.
--
-- Asserts JPM revenue at fiscal_year = 2024 at the latest as_of_date falls
-- within [$172B, $183B]. Anchor value $177.556B verified against JPMorgan
-- Chase FY2024 10-K, captured in audit/anchor_truth.md. JPM is a bank — its
-- revenue is sourced via the InterestAndDividendIncomeOperating alias
-- added at Phase 5 session 4 Fix-all Step B (Risk 55 Financials sector
-- coverage), not the legacy Revenues tag.
--
-- Source: AUDIT_FINDINGS.md Audit 6 + Audit 10 A10.4 spec item 2.
-- PASS condition: zero rows returned.

WITH latest AS (
    SELECT MAX(as_of_date) AS d FROM {{ ref('mart_financial_health') }}
)
SELECT cik, fiscal_year, revenue
FROM {{ ref('mart_financial_health') }}
WHERE cik = '0000019617'
  AND fiscal_year = 2024
  AND as_of_date = (SELECT d FROM latest)
  AND (revenue IS NULL OR revenue < 172000000000 OR revenue > 183000000000)

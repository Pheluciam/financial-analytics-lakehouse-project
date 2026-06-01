-- dbt data test: BRK.B FY2024 revenue anchor.
--
-- Asserts BRK.B revenue at fiscal_year = 2024 at the latest as_of_date
-- falls within [$361B, $382B]. Anchor value $371.433B verified against
-- Berkshire Hathaway FY2024 10-K, captured in audit/anchor_truth.md.
-- BRK.B is one of the 10 MULTI_TAG_DISAGREE CIKs from Audit 5 A5.1
-- where Risk 47 value-DESC collapse picks the analyst-headline tag
-- across the 4-tag revenue alias zoo.
--
-- Source: AUDIT_FINDINGS.md Audit 6 + Audit 10 A10.4 spec item 2.
-- PASS condition: zero rows returned.

WITH latest AS (
    SELECT MAX(as_of_date) AS d FROM {{ ref('mart_financial_health') }}
)
SELECT cik, fiscal_year, revenue
FROM {{ ref('mart_financial_health') }}
WHERE cik = '0001067983'
  AND fiscal_year = 2024
  AND as_of_date = (SELECT d FROM latest)
  AND (revenue IS NULL OR revenue < 361000000000 OR revenue > 382000000000)

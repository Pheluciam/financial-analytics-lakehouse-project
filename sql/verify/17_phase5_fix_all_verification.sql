-- sql/verify/17_phase5_fix_all_verification.sql
--
-- Phase 5 session 4 Fix-all post-cascade verification (2026-06-01).
-- Standalone re-runnable artefact — paste the whole thing into Athena
-- Query Editor under workgroup wg_financial_analytics signed in as
-- phil-admin, region us-east-1.
--
-- Checks 12 invariants confirming the Fix-all phase landed correctly,
-- consolidating the most material audit-derived expectations from the
-- AUDIT_FINDINGS Audit 1 universe + Audit 4 SPGI canary + Audit 5 cash
-- collapse override + Audit 6 anchor truth into a single PASS/FAIL
-- surface. The dbt test suite (242 PASS at session close) covers the
-- structural + cross-mart + range tests; this verify file covers the
-- audit-derived spot-checks not present as dbt tests.
--
--   1. mart_financial_health distinct CIK count = 107 (Audit 1 universe).
--   2. mart_pl_trend distinct CIK count = 107.
--   3. mart_peer_benchmark distinct CIK count = 107.
--   4. mart_growth_forecast distinct CIK count = 107.
--   5. hub_company row count = 107 (universe filter at source).
--   6. SPGI (0000064040) FY2024 row exists in mart_financial_health
--      (Audit 4 SPGI canary — pre-Fix this row was ABSENT due to the
--      year-IN filter rejecting comparative data tagged fy=2025).
--   7. mart_financial_health FY2024 revenue completeness — at least
--      100 CIKs report revenue (Audit 4 + Audit 5 healing; pre-Fix 103
--      of 107, expected post-Fix ~107).
--   8. mart_financial_health FY2024 net_income completeness — at least
--      100 CIKs report net_income (Audit 4 healing of 7 RECENT_PIPELINE_BUG
--      cells via Risk 58).
--   9. mart_financial_health FY2024 cash_and_equivalents completeness —
--      at least 95 CIKs report cash (Audit 5 Risk 59 collapse_rule
--      override heals 16 RESTRICTED_ONLY CIKs + 3 PIPELINE_BUG).
--  10. mart_financial_health FY2024 stockholders_equity completeness —
--      at least 100 CIKs report SE (Audit 3 mart-layer derivation
--      SE = SEIncludingNCI − minority_interest heals 4 NEVER_IN_SAT + 6
--      OLD_TAG_RENAME).
--  11. mart_financial_health FY2024 liabilities completeness — at least
--      95 CIKs report liabilities (Audit 3 mart-layer derivation
--      Liab = LiabAndSE − SE heals 29 NEVER_IN_SAT + 3 OLD_TAG_RENAME).
--  12. JPM (0000019617) FY2024 revenue between $172B and $183B at the
--      latest as_of_date (Audit 6 anchor — confirms Risk 55 Financials
--      revenue alias + Risk 58 re-anchor for JPM specifically).

WITH latest AS (
    SELECT MAX(as_of_date) AS d FROM financial_analytics_silver.mart_financial_health
),

checks AS (

    SELECT
        'check_01_mfh_universe_107' AS check_name,
        107 AS expected,
        (SELECT COUNT(DISTINCT cik)
         FROM financial_analytics_silver.mart_financial_health) AS actual

    UNION ALL SELECT
        'check_02_pl_trend_universe_107',
        107,
        (SELECT COUNT(DISTINCT cik)
         FROM financial_analytics_silver.mart_pl_trend)

    UNION ALL SELECT
        'check_03_peer_benchmark_universe_107',
        107,
        (SELECT COUNT(DISTINCT cik)
         FROM financial_analytics_silver.mart_peer_benchmark)

    UNION ALL SELECT
        'check_04_growth_forecast_universe_le_107',
        107,
        (SELECT COUNT(DISTINCT cik)
         FROM financial_analytics_silver.mart_growth_forecast)

    UNION ALL SELECT
        'check_05_hub_company_universe_107',
        107,
        (SELECT COUNT(*) FROM financial_analytics_silver.hub_company)

    UNION ALL SELECT
        'check_06_spgi_fy2024_present',
        1,
        (SELECT COUNT(*)
         FROM financial_analytics_silver.mart_financial_health
         WHERE cik = '0000064040'
           AND fiscal_year = 2024
           AND as_of_date = (SELECT d FROM latest))

    UNION ALL SELECT
        'check_07_fy2024_revenue_completeness_ge_100',
        1,
        (SELECT CASE WHEN COUNT(DISTINCT cik) >= 100 THEN 1 ELSE 0 END
         FROM financial_analytics_silver.mart_financial_health
         WHERE as_of_date = (SELECT d FROM latest)
           AND fiscal_year = 2024
           AND revenue IS NOT NULL)

    UNION ALL SELECT
        'check_08_fy2024_net_income_completeness_ge_100',
        1,
        (SELECT CASE WHEN COUNT(DISTINCT cik) >= 100 THEN 1 ELSE 0 END
         FROM financial_analytics_silver.mart_financial_health
         WHERE as_of_date = (SELECT d FROM latest)
           AND fiscal_year = 2024
           AND net_income IS NOT NULL)

    UNION ALL SELECT
        'check_09_fy2024_cash_completeness_ge_95',
        1,
        (SELECT CASE WHEN COUNT(DISTINCT cik) >= 95 THEN 1 ELSE 0 END
         FROM financial_analytics_silver.mart_financial_health
         WHERE as_of_date = (SELECT d FROM latest)
           AND fiscal_year = 2024
           AND cash_and_equivalents IS NOT NULL)

    UNION ALL SELECT
        'check_10_fy2024_se_completeness_ge_100',
        1,
        (SELECT CASE WHEN COUNT(DISTINCT cik) >= 100 THEN 1 ELSE 0 END
         FROM financial_analytics_silver.mart_financial_health
         WHERE as_of_date = (SELECT d FROM latest)
           AND fiscal_year = 2024
           AND stockholders_equity IS NOT NULL)

    UNION ALL SELECT
        'check_11_fy2024_liabilities_completeness_ge_95',
        1,
        (SELECT CASE WHEN COUNT(DISTINCT cik) >= 95 THEN 1 ELSE 0 END
         FROM financial_analytics_silver.mart_financial_health
         WHERE as_of_date = (SELECT d FROM latest)
           AND fiscal_year = 2024
           AND liabilities IS NOT NULL)

    UNION ALL SELECT
        'check_12_jpm_fy2024_revenue_anchor',
        1,
        (SELECT CASE
                  WHEN revenue BETWEEN 172000000000 AND 183000000000 THEN 1
                  ELSE 0
                END
         FROM financial_analytics_silver.mart_financial_health
         WHERE cik = '0000019617'
           AND fiscal_year = 2024
           AND as_of_date = (SELECT d FROM latest))

)

SELECT
    check_name,
    expected,
    actual,
    CASE WHEN expected = actual THEN 'PASS' ELSE 'FAIL' END AS result
FROM checks
ORDER BY check_name;

-- =============================================================================
-- Phase 2 session 2 Silver intermediate verification suite
-- =============================================================================
-- CTE-based PASS/FAIL pattern parallel to sql/verify/01_phase1_bronze_verification.sql.
-- Six checks confirming the new Bronze raw-text table reads cleanly, the
-- intermediate model returns the expected concepts for Apple, and the
-- extracted Revenues values reconcile to Apple's public 10-K filings for
-- FY2016, FY2017, FY2018 (the years Apple used the bare "Revenues" XBRL
-- tag before switching to RevenueFromContractWithCustomerExcludingAssessedTax
-- under ASC 606).
--
-- Scope: Phase 2 session 2 first intermediate model + raw-text Bronze table.
-- Run via Athena workgroup wg_financial_analytics. Expected result: 6 rows
-- ALL showing PASS in the status column. Any FAIL = the json_extract chain
-- has drifted somewhere between the raw S3 JSON files and the int_sec_edgar__concepts
-- view. Investigate the failing check's logic + actual_value before declaring
-- Phase 2 session 2 ship-ready.
--
-- Why these particular Apple values: public 10-K filings are immutable
-- historical records; any drift in the json_extract pipeline that changes
-- a number for a 10+-year-old reported fact is a pipeline bug, not a data
-- update. Values cross-referenced against Apple's published 10-K filings
-- on the SEC website.
--
-- Companion to:
--   sql/ddl/02_create_bronze_raw_text_table.sql       (raw-text Bronze DDL)
--   dbt/models/staging/stg_sec_edgar__companyfacts_raw.sql
--   dbt/models/intermediate/int_sec_edgar__concepts.sql
--   DBT_PIPELINE.md section 7                          (walkthrough doc)
--
-- Run order in Athena Console: this entire file is ONE SQL statement
-- (CTE-based) and can be pasted in as a single query.
-- =============================================================================

WITH raw_text AS (
    -- Bronze raw-text table read for Apple (CIK 0000320193) at the freeze
    -- extract date. Injected partition projection on cik means the WHERE
    -- predicate MUST list explicit cik values.
    SELECT cik, extract_date, length(json_text) AS json_byte_length
    FROM financial_analytics_bronze.sec_edgar_companyfacts_raw
    WHERE cik = '0000320193'
      AND extract_date = '2026-05-25'
),
concepts AS (
    -- Intermediate model panel for Apple at the same freeze extract date.
    -- Filters down to the in-scope concept set declared in the model's
    -- Jinja concept list.
    SELECT concept_name, period_end_date, period_fiscal_period, value
    FROM financial_analytics_silver.int_sec_edgar__concepts
    WHERE cik = '0000320193'
      AND extract_date = DATE '2026-05-25'
),
expected AS (
    SELECT 'check_1_bronze_raw_apple_row_count' AS check_name,
        CAST(1 AS DECIMAL(28,2)) AS expected_value UNION ALL
    SELECT 'check_2_bronze_raw_apple_min_byte_length',
        CAST(1000000 AS DECIMAL(28,2)) UNION ALL
    SELECT 'check_3_apple_distinct_concept_count',
        CAST(5 AS DECIMAL(28,2)) UNION ALL
    SELECT 'check_4_apple_fy2018_revenues_annual',
        CAST(265595000000 AS DECIMAL(28,2)) UNION ALL
    SELECT 'check_5_apple_fy2017_revenues_annual',
        CAST(229234000000 AS DECIMAL(28,2)) UNION ALL
    SELECT 'check_6_apple_fy2016_revenues_annual',
        CAST(215639000000 AS DECIMAL(28,2))
),
actual AS (
    -- Check 1: exactly one Bronze raw-text row for Apple at freeze date
    SELECT 'check_1_bronze_raw_apple_row_count' AS check_name,
        CAST((SELECT COUNT(*) FROM raw_text) AS DECIMAL(28,2)) AS actual_value
    UNION ALL
    -- Check 2: Apple's companyfacts json_text is at least 1 MB (sanity:
    -- actual measured value is ~3.75 MB; this is a "file isn't truncated"
    -- floor, not a strict equality)
    SELECT 'check_2_bronze_raw_apple_min_byte_length',
        CAST(
            CASE WHEN (SELECT json_byte_length FROM raw_text) >= 1000000
                 THEN 1000000
                 ELSE 0
            END AS DECIMAL(28,2)
        )
    UNION ALL
    -- Check 3: intermediate model returns all 5 in-scope concepts for Apple.
    -- If a concept is missing the model's json_extract path for that concept
    -- failed (or Apple really doesn't report it; the 5 in-scope concepts
    -- were chosen for S&P 100 universality)
    SELECT 'check_3_apple_distinct_concept_count',
        CAST((SELECT COUNT(DISTINCT concept_name) FROM concepts) AS DECIMAL(28,2))
    UNION ALL
    -- Check 4: Apple FY2018 annual Revenues = $265.595B (per FY2018 10-K).
    -- MAX(value) within (concept, end_date) collapses the annual row past
    -- any same-end-date quarterly rows — Q4 < FY by construction, so MAX
    -- always picks the annual entry. Acceptable workaround until the next
    -- intermediate model adds period_start_date for unambiguous filtering.
    SELECT 'check_4_apple_fy2018_revenues_annual',
        CAST(
            (SELECT MAX(value) FROM concepts
             WHERE concept_name = 'Revenues'
               AND period_end_date = DATE '2018-09-29')
            AS DECIMAL(28,2)
        )
    UNION ALL
    -- Check 5: Apple FY2017 annual Revenues = $229.234B (per FY2018 10-K
    -- prior-year comparative)
    SELECT 'check_5_apple_fy2017_revenues_annual',
        CAST(
            (SELECT MAX(value) FROM concepts
             WHERE concept_name = 'Revenues'
               AND period_end_date = DATE '2017-09-30')
            AS DECIMAL(28,2)
        )
    UNION ALL
    -- Check 6: Apple FY2016 annual Revenues = $215.639B (per FY2018 10-K
    -- two-years-prior comparative)
    SELECT 'check_6_apple_fy2016_revenues_annual',
        CAST(
            (SELECT MAX(value) FROM concepts
             WHERE concept_name = 'Revenues'
               AND period_end_date = DATE '2016-09-24')
            AS DECIMAL(28,2)
        )
)
SELECT
    e.check_name,
    e.expected_value,
    a.actual_value,
    CASE WHEN e.expected_value = a.actual_value
         THEN 'PASS'
         ELSE 'FAIL'
    END AS status
FROM expected e
JOIN actual a ON e.check_name = a.check_name
ORDER BY e.check_name;

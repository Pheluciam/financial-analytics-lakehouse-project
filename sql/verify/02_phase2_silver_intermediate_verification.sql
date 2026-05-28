-- =============================================================================
-- Phase 2 session 2-3 Silver intermediate verification suite
-- =============================================================================
-- CTE-based PASS/FAIL pattern parallel to sql/verify/01_phase1_bronze_verification.sql.
-- Eleven checks: the first six confirm the session-2 raw-text Bronze table
-- and int_sec_edgar__concepts panel reconcile against Apple's published
-- FY2016-FY2018 10-K filings (the years Apple used the bare Revenues XBRL
-- tag). Checks 7-11 are session-3 additions covering the canonical-concept
-- reconciliation model: Apple FY2019-FY2021 revenue under the new ASC 606
-- alias RevenueFromContractWithCustomerExcludingAssessedTax must surface
-- under canonical 'revenue' (proving the alias collapse works); the new
-- period_start_date column must be populated for income-statement concepts
-- and NULL for balance-sheet point-in-time concepts.
--
-- Scope: Phase 2 sessions 2-3 — raw-text Bronze table + int_sec_edgar__concepts
-- + int_sec_edgar__concepts_canonical + canonical_concepts_dictionary seed.
-- Run via Athena workgroup wg_financial_analytics. Expected result: 11 rows
-- ALL showing PASS in the status column. Any FAIL = the json_extract / join
-- chain has drifted somewhere between the raw S3 JSON files and the
-- canonical view. Investigate the failing check's logic + actual_value before
-- declaring Phase 2 session 3 ship-ready.
--
-- Why these particular Apple values: public 10-K filings are immutable
-- historical records; any drift in the pipeline that changes a number for
-- a 5+-year-old reported fact is a pipeline bug, not a data update. Values
-- cross-referenced against Apple's published 10-K filings on the SEC website.
--
-- Companion to:
--   sql/ddl/02_create_bronze_raw_text_table.sql       (raw-text Bronze DDL)
--   dbt/models/staging/stg_sec_edgar__companyfacts_raw.sql
--   dbt/models/intermediate/int_sec_edgar__concepts.sql
--   dbt/models/intermediate/int_sec_edgar__concepts_canonical.sql
--   dbt/seeds/canonical_concepts_dictionary.csv
--   DBT_PIPELINE.md section 7                          (walkthrough doc)
--
-- Run order in Athena Console: this entire file is ONE SQL statement
-- (CTE-based) and can be pasted in as a single query.
-- =============================================================================

WITH raw_text AS (
    -- Bronze raw-text table read for Apple (CIK 0000320193) at the freeze
    -- extract date. cik partition projection is type=enum (post Phase 2
    -- session 3) so the WHERE predicate filter is for query selectivity
    -- only, not a hard partition-projection requirement.
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
canonical AS (
    -- Canonical-concept-enriched panel for Apple. canonical_concept is the
    -- semantic name (revenue / net_income / assets / liabilities /
    -- stockholders_equity); concept_name is still the raw XBRL tag for
    -- audit purposes.
    SELECT canonical_concept, concept_name, period_start_date,
           period_end_date, period_fiscal_year, period_fiscal_period, value
    FROM financial_analytics_silver.int_sec_edgar__concepts_canonical
    WHERE cik = '0000320193'
      AND extract_date = DATE '2026-05-25'
),
expected AS (
    SELECT 'check_01_bronze_raw_apple_row_count' AS check_name,
        CAST(1 AS DECIMAL(28,2)) AS expected_value UNION ALL
    SELECT 'check_02_bronze_raw_apple_min_byte_length',
        CAST(1000000 AS DECIMAL(28,2)) UNION ALL
    SELECT 'check_03_apple_distinct_concept_count',
        CAST(5 AS DECIMAL(28,2)) UNION ALL
    SELECT 'check_04_apple_fy2018_revenues_annual',
        CAST(265595000000 AS DECIMAL(28,2)) UNION ALL
    SELECT 'check_05_apple_fy2017_revenues_annual',
        CAST(229234000000 AS DECIMAL(28,2)) UNION ALL
    SELECT 'check_06_apple_fy2016_revenues_annual',
        CAST(215639000000 AS DECIMAL(28,2)) UNION ALL
    SELECT 'check_07_apple_fy2019_canonical_revenue_annual',
        CAST(260174000000 AS DECIMAL(28,2)) UNION ALL
    SELECT 'check_08_apple_fy2020_canonical_revenue_annual',
        CAST(274515000000 AS DECIMAL(28,2)) UNION ALL
    SELECT 'check_09_apple_fy2021_canonical_revenue_annual',
        CAST(365817000000 AS DECIMAL(28,2)) UNION ALL
    SELECT 'check_10_apple_canonical_revenue_min_distinct_fiscal_years',
        CAST(6 AS DECIMAL(28,2)) UNION ALL
    SELECT 'check_11_period_start_date_populated_for_revenue_at_least_one',
        CAST(1 AS DECIMAL(28,2))
),
actual AS (
    -- Check 1: exactly one Bronze raw-text row for Apple at freeze date
    SELECT 'check_01_bronze_raw_apple_row_count' AS check_name,
        CAST((SELECT COUNT(*) FROM raw_text) AS DECIMAL(28,2)) AS actual_value
    UNION ALL
    -- Check 2: Apple's companyfacts json_text is at least 1 MB (sanity:
    -- actual measured value is ~3.75 MB; this is a "file isn't truncated"
    -- floor, not a strict equality)
    SELECT 'check_02_bronze_raw_apple_min_byte_length',
        CAST(
            CASE WHEN (SELECT json_byte_length FROM raw_text) >= 1000000
                 THEN 1000000
                 ELSE 0
            END AS DECIMAL(28,2)
        )
    UNION ALL
    -- Check 3: int_sec_edgar__concepts_canonical returns all 5 canonical
    -- concepts for Apple (revenue, net_income, assets, liabilities,
    -- stockholders_equity). If a canonical is missing the seed join failed
    -- or the upstream extract dropped a tag.
    SELECT 'check_03_apple_distinct_concept_count',
        CAST((SELECT COUNT(DISTINCT canonical_concept) FROM canonical) AS DECIMAL(28,2))
    UNION ALL
    -- Check 4: Apple FY2018 annual Revenues = $265.595B (per FY2018 10-K).
    -- MAX(value) within (concept, end_date) collapses the annual row past
    -- any same-end-date quarterly rows — Q4 < FY by construction, so MAX
    -- always picks the annual entry. Acceptable workaround until the next
    -- intermediate model adds period_start_date for unambiguous filtering.
    SELECT 'check_04_apple_fy2018_revenues_annual',
        CAST(
            (SELECT MAX(value) FROM concepts
             WHERE concept_name = 'Revenues'
               AND period_end_date = DATE '2018-09-29')
            AS DECIMAL(28,2)
        )
    UNION ALL
    -- Check 5: Apple FY2017 annual Revenues = $229.234B (per FY2018 10-K
    -- prior-year comparative)
    SELECT 'check_05_apple_fy2017_revenues_annual',
        CAST(
            (SELECT MAX(value) FROM concepts
             WHERE concept_name = 'Revenues'
               AND period_end_date = DATE '2017-09-30')
            AS DECIMAL(28,2)
        )
    UNION ALL
    -- Check 6: Apple FY2016 annual Revenues = $215.639B (per FY2018 10-K
    -- two-years-prior comparative)
    SELECT 'check_06_apple_fy2016_revenues_annual',
        CAST(
            (SELECT MAX(value) FROM concepts
             WHERE concept_name = 'Revenues'
               AND period_end_date = DATE '2016-09-24')
            AS DECIMAL(28,2)
        )
    UNION ALL
    -- Check 7: Apple FY2019 canonical revenue = $260.174B (per FY2019 10-K).
    -- This is the canary check: Apple switched from the bare Revenues tag
    -- to RevenueFromContractWithCustomerExcludingAssessedTax on ASC 606
    -- adoption in FY2019. If the canonical-concept reconciliation works,
    -- this query returns the FY2019 value under canonical_concept='revenue'.
    -- If the alias collapse failed, this check returns 0 / NULL.
    SELECT 'check_07_apple_fy2019_canonical_revenue_annual',
        CAST(
            (SELECT MAX(value) FROM canonical
             WHERE canonical_concept = 'revenue'
               AND period_fiscal_period = 'FY'
               AND period_end_date = DATE '2019-09-28')
            AS DECIMAL(28,2)
        )
    UNION ALL
    -- Check 8: Apple FY2020 canonical revenue = $274.515B (per FY2020 10-K).
    SELECT 'check_08_apple_fy2020_canonical_revenue_annual',
        CAST(
            (SELECT MAX(value) FROM canonical
             WHERE canonical_concept = 'revenue'
               AND period_fiscal_period = 'FY'
               AND period_end_date = DATE '2020-09-26')
            AS DECIMAL(28,2)
        )
    UNION ALL
    -- Check 9: Apple FY2021 canonical revenue = $365.817B (per FY2021 10-K).
    SELECT 'check_09_apple_fy2021_canonical_revenue_annual',
        CAST(
            (SELECT MAX(value) FROM canonical
             WHERE canonical_concept = 'revenue'
               AND period_fiscal_period = 'FY'
               AND period_end_date = DATE '2021-09-25')
            AS DECIMAL(28,2)
        )
    UNION ALL
    -- Check 10: Apple canonical revenue has continuous annual coverage —
    -- at least 6 distinct fiscal years (FY2016-FY2021). Proves the alias
    -- collapse bridges the FY2018→FY2019 discontinuity caused by the
    -- ASC 606 tag rename. Pre-canonical, this count was 3 (FY2016-FY2018
    -- under bare Revenues); post-canonical, it should be ≥6.
    SELECT 'check_10_apple_canonical_revenue_min_distinct_fiscal_years',
        CAST(
            CASE WHEN (
                SELECT COUNT(DISTINCT period_fiscal_year) FROM canonical
                WHERE canonical_concept = 'revenue'
                  AND period_fiscal_period = 'FY'
            ) >= 6 THEN 6 ELSE 0 END
            AS DECIMAL(28,2)
        )
    UNION ALL
    -- Check 11: period_start_date is populated for flow concepts. At least
    -- one canonical revenue row must have a non-NULL period_start_date.
    -- Confirms the session-3 schema addition extracts cleanly from $.start.
    -- Balance-sheet concepts (assets, liabilities) naturally have NULL here
    -- because SEC EDGAR omits start for instant-period facts — that's by
    -- design, not tested as a failure mode.
    SELECT 'check_11_period_start_date_populated_for_revenue_at_least_one',
        CAST(
            CASE WHEN (
                SELECT COUNT(*) FROM canonical
                WHERE canonical_concept = 'revenue'
                  AND period_start_date IS NOT NULL
            ) >= 1 THEN 1 ELSE 0 END
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

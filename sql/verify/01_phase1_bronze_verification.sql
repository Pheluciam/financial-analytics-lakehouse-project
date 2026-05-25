-- =============================================================================
-- Phase 1 Bronze verification suite — SEC EDGAR companyfacts
-- =============================================================================
-- CTE-based PASS/FAIL verification pattern carried from Project #2 LEARNINGS.
-- Six checks confirming partition discovery, CIK completeness, partition
-- split by extract_date, and JSON parseability (no NULL entitynames).
--
-- Run via Athena workgroup wg_financial_analytics. Expected result: 6 rows
-- ALL showing PASS in the status column. Any FAIL = pipeline broken somewhere
-- between extract_sec_edgar.py and the Bronze table; investigate the failing
-- check's logic + actual_value before declaring Phase 1 ship-ready.
--
-- Companion to:
--   scripts/extract_sec_edgar.py            (Bronze loader)
--   sql/ddl/01_create_bronze_tables.sql     (Bronze table DDL)
--   EXTRACT_PIPELINE.md                     (walkthrough doc)
--
-- Out of scope (deferred to a separate boto3-based check):
--   - S3 object byte-count verification (lives in S3 metadata, not JSON)
--   - sha256 fingerprint uniqueness per CIK (lives in S3 object metadata)
-- =============================================================================

WITH base AS (
    -- Partition filter required: injected projection on cik means
    -- Athena needs the cik values in the WHERE clause to know which
    -- partitions to scan. All downstream checks read from this set.
    SELECT cik, extract_date, entityname
    FROM financial_analytics_bronze.sec_edgar_companyfacts
    WHERE cik IN (
        '0000019617', '0000034088', '0000070858', '0000080424',
        '0000093410', '0000104169', '0000200406', '0000320193',
        '0000731766', '0000789019', '0001045810'
    )
),
expected AS (
    SELECT 'check_1_total_row_count'      AS check_name, 11 AS expected_value  UNION ALL
    SELECT 'check_2_distinct_cik_count',   11                                  UNION ALL
    SELECT 'check_3_extract_date_count',   2                                   UNION ALL
    SELECT 'check_4_today_row_count',      10                                  UNION ALL
    SELECT 'check_5_yesterday_row_count',  1                                   UNION ALL
    SELECT 'check_6_non_null_entitynames', 11
),
actual AS (
    SELECT 'check_1_total_row_count' AS check_name,
        (SELECT COUNT(*) FROM base) AS actual_value
    UNION ALL
    SELECT 'check_2_distinct_cik_count',
        (SELECT COUNT(DISTINCT cik) FROM base)
    UNION ALL
    SELECT 'check_3_extract_date_count',
        (SELECT COUNT(DISTINCT extract_date) FROM base)
    UNION ALL
    SELECT 'check_4_today_row_count',
        (SELECT COUNT(*) FROM base WHERE extract_date = '2026-05-25')
    UNION ALL
    SELECT 'check_5_yesterday_row_count',
        (SELECT COUNT(*) FROM base WHERE extract_date = '2026-05-24')
    UNION ALL
    SELECT 'check_6_non_null_entitynames',
        (SELECT COUNT(*) FROM base WHERE entityname IS NOT NULL)
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

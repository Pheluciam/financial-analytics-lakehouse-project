-- =============================================================================
-- Phase 1 Bronze verification suite — SEC EDGAR companyfacts
-- =============================================================================
-- CTE-based PASS/FAIL verification pattern carried from Project #2 LEARNINGS.
-- Six checks confirming partition discovery, CIK completeness, partition
-- split by extract_date, and JSON parseability (no NULL entitynames).
--
-- Scope: Phase 1 Bronze freeze — full S&P 100 roster at extract_date 2026-05-25
-- plus Apple at extract_date 2026-05-24 (session 2). 101 expected rows across
-- 100 distinct CIKs (Alphabet's GOOGL + GOOG share a single SEC filer CIK).
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
-- Out of scope here — covered by scripts/verify_bronze_s3_metadata.py instead:
--   - S3 object byte-count verification (lives in S3 metadata, not JSON)
--   - sha256 fingerprint uniqueness across CIKs (lives in S3 object metadata)
-- Run both verifications back-to-back for the full Phase 1 Bronze surface.
-- =============================================================================

WITH base AS (
    -- Partition filter required: injected projection on cik means
    -- Athena needs the cik values in the WHERE clause to know which
    -- partitions to scan. All downstream checks read from this set.
    SELECT cik, extract_date, entityname
    FROM financial_analytics_bronze.sec_edgar_companyfacts
    WHERE cik IN (
        '0000001800', '0000002488', '0000004962', '0000005272', '0000012927', '0000014272', '0000018230', '0000019617', '0000021344', '0000021665',
        '0000027419', '0000032604', '0000034088', '0000036104', '0000040533', '0000040545', '0000050863', '0000051143', '0000059478', '0000060667',
        '0000063908', '0000064803', '0000066740', '0000070858', '0000072971', '0000077476', '0000078003', '0000080424', '0000092122', '0000093410',
        '0000097476', '0000097745', '0000100885', '0000101829', '0000104169', '0000200406', '0000310158', '0000313616', '0000315189', '0000316709',
        '0000318154', '0000320187', '0000320193', '0000354950', '0000731766', '0000732712', '0000732717', '0000753308', '0000764180', '0000773840',
        '0000789019', '0000796343', '0000804328', '0000829224', '0000831001', '0000858877', '0000882095', '0000886982', '0000895421', '0000896878',
        '0000909832', '0000927628', '0000936468', '0001018724', '0001035267', '0001045810', '0001048911', '0001053507', '0001063761', '0001065280',
        '0001067983', '0001075531', '0001090727', '0001099219', '0001103982', '0001108524', '0001141391', '0001163165', '0001166691', '0001283699',
        '0001318605', '0001321655', '0001326160', '0001326801', '0001341439', '0001373715', '0001390777', '0001403161', '0001413329', '0001467373',
        '0001467858', '0001543151', '0001551152', '0001613103', '0001633917', '0001652044', '0001707925', '0001730168', '0001744489', '0002012383'
    )
),
expected AS (
    SELECT 'check_1_total_row_count'      AS check_name, 101 AS expected_value UNION ALL
    SELECT 'check_2_distinct_cik_count',   100                                 UNION ALL
    SELECT 'check_3_extract_date_count',   2                                   UNION ALL
    SELECT 'check_4_today_row_count',      100                                 UNION ALL
    SELECT 'check_5_yesterday_row_count',  1                                   UNION ALL
    SELECT 'check_6_non_null_entitynames', 101
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

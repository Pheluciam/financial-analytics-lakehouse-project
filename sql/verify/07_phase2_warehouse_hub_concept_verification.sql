-- sql/verify/07_phase2_warehouse_hub_concept_verification.sql
--
-- Phase 2 session 8 — third warehouse-layer Data Vault 2.0 hub:
-- hub_concept. Business key = canonical_concept. Expected 5 rows
-- (revenue, net_income, assets, liabilities, stockholders_equity per
-- session 8 forward-verify probe 1).
--
-- Standalone re-runnable artefact — paste the whole thing into Athena
-- Query Editor under workgroup wg_financial_analytics signed in as
-- phil-admin, region us-east-1.
--
-- Checks 8 invariants on hub_concept:
--
--   1. hub_concept_hk is unique across all rows.
--   2. hub_concept_hk is NOT NULL across all rows.
--   3. hub_concept_hk is exactly 64 hex chars (SHA-256 length contract).
--   4. canonical_concept is unique across all rows (BK uniqueness).
--   5. canonical_concept is NOT NULL across all rows.
--   6. Source-coverage parity — hub row count = distinct
--      canonical_concept count in int_sec_edgar__concepts_canonical
--      (every observed canonical landed in the hub).
--   7. hub_concept_hk determinism on 'revenue' — recomputes
--      to_hex(sha256(to_utf8(CAST(canonical_concept AS varchar)))) and
--      confirms the stored hash matches.
--   8. record_source is constant 'sec_edgar.companyfacts' on every
--      row (single source this session; lineage contract).
--
-- Idempotency check is separately performed by re-running
--   dotenv -f ..\.env run -- dbt run --select hub_concept
-- Expected output: NO-OP per the is_incremental NOT IN filter — no new
-- canonical concepts entering on a repeat extract.

WITH revenue_sample AS (
    SELECT hub_concept_hk, canonical_concept
    FROM financial_analytics_silver.hub_concept
    WHERE canonical_concept = 'revenue'
),

checks AS (

    SELECT
        'check_01_hub_hk_unique' AS check_name,
        (SELECT COUNT(*) FROM financial_analytics_silver.hub_concept) AS expected,
        (SELECT COUNT(DISTINCT hub_concept_hk) FROM financial_analytics_silver.hub_concept) AS actual

    UNION ALL SELECT
        'check_02_hub_hk_not_null',
        (SELECT COUNT(*) FROM financial_analytics_silver.hub_concept),
        (SELECT COUNT(hub_concept_hk) FROM financial_analytics_silver.hub_concept)

    UNION ALL SELECT
        'check_03_hub_hk_length_64',
        (SELECT COUNT(*) FROM financial_analytics_silver.hub_concept),
        (SELECT COUNT(*) FROM financial_analytics_silver.hub_concept WHERE length(hub_concept_hk) = 64)

    UNION ALL SELECT
        'check_04_bk_unique',
        (SELECT COUNT(*) FROM financial_analytics_silver.hub_concept),
        (SELECT COUNT(DISTINCT canonical_concept) FROM financial_analytics_silver.hub_concept)

    UNION ALL SELECT
        'check_05_bk_not_null',
        (SELECT COUNT(*) FROM financial_analytics_silver.hub_concept),
        (SELECT COUNT(canonical_concept) FROM financial_analytics_silver.hub_concept)

    UNION ALL SELECT
        'check_06_source_coverage_parity',
        (SELECT COUNT(DISTINCT canonical_concept)
         FROM financial_analytics_silver.int_sec_edgar__concepts_canonical
         WHERE canonical_concept IS NOT NULL),
        (SELECT COUNT(*) FROM financial_analytics_silver.hub_concept)

    UNION ALL SELECT
        'check_07_hub_hk_reproducible',
        CAST(1 AS bigint),
        (SELECT COUNT(*)
         FROM revenue_sample
         WHERE hub_concept_hk = to_hex(sha256(to_utf8(
               CAST(canonical_concept AS varchar)
           ))))

    UNION ALL SELECT
        'check_08_record_source_constant',
        (SELECT COUNT(*) FROM financial_analytics_silver.hub_concept),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.hub_concept
         WHERE record_source = 'sec_edgar.companyfacts')
)

SELECT
    check_name,
    expected,
    actual,
    CASE WHEN expected = actual THEN 'PASS' ELSE 'FAIL' END AS result
FROM checks
ORDER BY check_name;

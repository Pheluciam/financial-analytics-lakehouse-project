-- sql/verify/03_phase2_warehouse_verification.sql
--
-- Phase 2 session 4 — first warehouse-layer Data Vault 2.0 hub model
-- (hub_company). Structural verification surface complementing dbt's
-- schema tests on the same model. Standalone re-runnable artefact —
-- paste the whole thing into Athena Query Editor under workgroup
-- wg_financial_analytics signed in as phil-admin, region us-east-1.
--
-- Checks 9 invariants:
--
--   1. Hub row count = 100 (S&P 100 universe parity).
--   2. hub_company_hk is unique across all rows.
--   3. hub_company_hk is NOT NULL across all rows.
--   4. hub_company_hk is exactly 64 hex chars (SHA-256 length contract —
--      32-byte digest, hex-encoded, always 64 chars).
--   5. cik (business key) is unique across all rows.
--   6. Hub row count = source distinct CIK count in
--      stg_sec_edgar__companyfacts (lineage parity).
--   7. Apple (cik '0000320193') hash matches deterministic recomputation
--      of to_hex(sha256(to_utf8(CAST('0000320193' AS varchar)))) — proves
--      hash reproducibility AND that the in-model function chain
--      produced the expected output. Same input → same hash, always.
--   8. load_datetime is NOT NULL and within reasonable UTC bounds
--      (>= 2026-01-01 and <= current UTC time).
--   9. record_source = 'sec_edgar.companyfacts' for every row (single
--      source this session; future multi-source loads relax this check).
--
-- Idempotency check is separately performed by re-running
--   dotenv -f ..\.env run -- dbt run --select hub_company
-- Expected output: NO-OP (0 rows merged) per the is_incremental
-- source-side filter excluding seen-before hash keys.
--
-- Schema tests in dbt/models/warehouse/_models.yml cover checks 2, 3, 5
-- structurally; this verify suite restates them in raw queryable form
-- (portfolio-grade — every check is auditable from one paste-able SQL
-- artifact) and adds 4, 6, 7, 8, 9 which YAML schema tests can't express.

WITH checks AS (
    SELECT
        'check_01_hub_row_count' AS check_name,
        CAST(100 AS bigint) AS expected,
        (SELECT COUNT(*) FROM financial_analytics_silver.hub_company) AS actual

    UNION ALL SELECT
        'check_02_hk_unique',
        (SELECT COUNT(*) FROM financial_analytics_silver.hub_company),
        (SELECT COUNT(DISTINCT hub_company_hk) FROM financial_analytics_silver.hub_company)

    UNION ALL SELECT
        'check_03_hk_not_null',
        (SELECT COUNT(*) FROM financial_analytics_silver.hub_company),
        (SELECT COUNT(hub_company_hk) FROM financial_analytics_silver.hub_company)

    UNION ALL SELECT
        'check_04_hk_length_64',
        (SELECT COUNT(*) FROM financial_analytics_silver.hub_company),
        (SELECT COUNT(*) FROM financial_analytics_silver.hub_company WHERE length(hub_company_hk) = 64)

    UNION ALL SELECT
        'check_05_cik_unique',
        (SELECT COUNT(*) FROM financial_analytics_silver.hub_company),
        (SELECT COUNT(DISTINCT cik) FROM financial_analytics_silver.hub_company)

    UNION ALL SELECT
        'check_06_source_parity',
        (SELECT COUNT(DISTINCT cik) FROM financial_analytics_silver.stg_sec_edgar__companyfacts),
        (SELECT COUNT(*) FROM financial_analytics_silver.hub_company)

    UNION ALL SELECT
        'check_07_apple_hash_reproducible',
        CAST(1 AS bigint),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.hub_company
         WHERE cik = '0000320193'
           AND hub_company_hk = to_hex(sha256(to_utf8(CAST('0000320193' AS varchar)))))

    UNION ALL SELECT
        'check_08_load_datetime_valid',
        (SELECT COUNT(*) FROM financial_analytics_silver.hub_company),
        (SELECT COUNT(*) FROM financial_analytics_silver.hub_company
         WHERE load_datetime IS NOT NULL
           AND load_datetime >= TIMESTAMP '2026-01-01 00:00:00'
           AND load_datetime <= CAST(current_timestamp AT TIME ZONE 'UTC' AS timestamp(6)))

    UNION ALL SELECT
        'check_09_record_source_constant',
        (SELECT COUNT(*) FROM financial_analytics_silver.hub_company),
        (SELECT COUNT(*) FROM financial_analytics_silver.hub_company WHERE record_source = 'sec_edgar.companyfacts')
)

SELECT
    check_name,
    expected,
    actual,
    CASE WHEN expected = actual THEN 'PASS' ELSE 'FAIL' END AS result
FROM checks
ORDER BY check_name;

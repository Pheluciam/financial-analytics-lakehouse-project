-- sql/verify/06_phase2_warehouse_sat_company_metadata_verification.sql
--
-- Phase 2 session 7 — second warehouse-layer Data Vault 2.0 satellite:
-- sat_company_metadata. Parent = hub_company (cik business key). 1
-- company-level payload attribute (entity_name) from the SEC EDGAR
-- companyfacts JSON cover-page section. 1:1 cardinality with
-- hub_company on first load — every parent has exactly one sat row
-- when no history has accumulated.
--
-- Forward-verify pass at session 7 kickoff surfaced an empirical
-- cardinality fact (LEARNINGS Risk 13 candidate, 2026-05-28): Bronze
-- raw-text has 101 rows / 100 distinct CIKs / 2 distinct extract_dates
-- / 100 distinct entityNames — one CIK was extracted twice with the
-- SAME entityName both times. DISTINCT (cik, entity_name) collapses
-- the model's source-side to 100 rows; expected first-load sat row
-- count = 100 = hub_company parent count. Cardinality probe query
-- preserved in DBT_PIPELINE.md section 8.14.
--
-- Standalone re-runnable artefact — paste the whole thing into Athena
-- Query Editor under workgroup wg_financial_analytics signed in as
-- phil-admin, region us-east-1.
--
-- Checks 11 invariants on sat_company_metadata:
--
--   1. sat_company_metadata_hk is unique across all rows.
--   2. sat_company_metadata_hk is NOT NULL across all rows.
--   3. sat_company_metadata_hk is exactly 64 hex chars (SHA-256
--      length contract).
--   4. hashdiff is NOT NULL across all rows. Proves the
--      COALESCE-sentinel pattern (LEARNINGS Risk 8) is in place —
--      defensive standard even though entity_name is reliably
--      populated upstream.
--   5. hashdiff is exactly 64 hex chars (SHA-256 length contract).
--   6. FK closure to hub_company — every sat row's hub_company_hk
--      exists in hub_company.hub_company_hk (no orphan FKs).
--   7. Composite natural PK (hub_company_hk, load_datetime) is unique
--      across all rows. Independently confirms the DV2.0 textbook
--      contract that the engine-level single-column unique_key on
--      sat_company_metadata_hk enforces.
--   8. Parent coverage parity — sat row count = distinct hub_company_hk
--      in sat = hub_company row count on first load (1:1 cardinality
--      invariant). Expected = 100 = S&P 100 universe size. This is
--      the cheapest structural guard for the satellite 1:1 contract;
--      Risk 13's empirical cardinality probe at the forward-verify
--      pass is the design-time counterpart to this run-time check.
--   9. sat_company_metadata_hk determinism on Apple (cik 0000320193) —
--      recomputes to_hex(sha256(to_utf8(hub_company_hk || '||' ||
--      CAST(load_datetime AS varchar)))) and confirms the stored hash
--      matches. Proves the sat-hash function chain reproduces
--      deterministically (Risk 10).
--  10. hashdiff determinism on Apple — recomputes the full
--      COALESCE-protected single-column payload hash and confirms the
--      stored hashdiff matches. Proves the hashdiff chain (Risk 8)
--      reproduces. Single-column payload means no '||' delimiter
--      inside the hashed expression.
--  11. record_source is constant 'sec_edgar.companyfacts' on every
--      row (single source this session; lineage contract).
--
-- Idempotency check is separately performed by re-running
--   dotenv -f ..\.env run -- dbt run --select sat_company_metadata
-- Expected output: NO-OP (0 rows merged) per the is_incremental
-- NOT EXISTS anti-join filter on the model — the latest stored
-- hashdiff for every parent matches the inbound recomputed hashdiff
-- (payload unchanged), so the anti-join excludes every inbound row
-- from the merge.
--
-- Schema tests in dbt/models/warehouse/_models.yml cover the
-- relationships + unique + not_null + composite natural PK contracts;
-- this verify suite restates them in raw queryable form plus adds the
-- SHA-256-length, parent-coverage parity, and hash-determinism checks
-- YAML can't express.

WITH apple_sample AS (
    -- Apple's sat row — cik 0000320193 is the canonical test fixture
    -- across every verify file in this project. 1:1 sat means exactly
    -- one row per cik on first load.
    SELECT
        s.sat_company_metadata_hk,
        s.hashdiff,
        s.hub_company_hk,
        s.cik,
        s.entity_name,
        s.load_datetime
    FROM financial_analytics_silver.sat_company_metadata s
    WHERE s.cik = '0000320193'
),

checks AS (

    SELECT
        'check_01_sat_hk_unique' AS check_name,
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_company_metadata) AS expected,
        (SELECT COUNT(DISTINCT sat_company_metadata_hk) FROM financial_analytics_silver.sat_company_metadata) AS actual

    UNION ALL SELECT
        'check_02_sat_hk_not_null',
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_company_metadata),
        (SELECT COUNT(sat_company_metadata_hk) FROM financial_analytics_silver.sat_company_metadata)

    UNION ALL SELECT
        'check_03_sat_hk_length_64',
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_company_metadata),
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_company_metadata WHERE length(sat_company_metadata_hk) = 64)

    UNION ALL SELECT
        'check_04_hashdiff_not_null',
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_company_metadata),
        (SELECT COUNT(hashdiff) FROM financial_analytics_silver.sat_company_metadata)

    UNION ALL SELECT
        'check_05_hashdiff_length_64',
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_company_metadata),
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_company_metadata WHERE length(hashdiff) = 64)

    UNION ALL SELECT
        'check_06_sat_fk_closure_company',
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_company_metadata),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.sat_company_metadata s
         INNER JOIN financial_analytics_silver.hub_company h
           ON s.hub_company_hk = h.hub_company_hk)

    UNION ALL SELECT
        'check_07_sat_composite_pk_unique',
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_company_metadata),
        (SELECT COUNT(*)
         FROM (
             SELECT DISTINCT hub_company_hk, load_datetime
             FROM financial_analytics_silver.sat_company_metadata
         ))

    UNION ALL SELECT
        'check_08_sat_parent_coverage_parity',
        (SELECT COUNT(*) FROM financial_analytics_silver.hub_company),
        (SELECT COUNT(DISTINCT hub_company_hk) FROM financial_analytics_silver.sat_company_metadata)

    UNION ALL SELECT
        'check_09_sat_hk_reproducible',
        CAST(1 AS bigint),
        (SELECT COUNT(*)
         FROM apple_sample
         WHERE sat_company_metadata_hk = to_hex(sha256(to_utf8(
               CAST(hub_company_hk AS varchar) || '||' || CAST(load_datetime AS varchar)
           ))))

    UNION ALL SELECT
        'check_10_hashdiff_reproducible',
        CAST(1 AS bigint),
        (SELECT COUNT(*)
         FROM apple_sample
         WHERE hashdiff = to_hex(sha256(to_utf8(
               COALESCE(CAST(entity_name AS varchar), '^^')
           ))))

    UNION ALL SELECT
        'check_11_record_source_constant',
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_company_metadata),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.sat_company_metadata
         WHERE record_source = 'sec_edgar.companyfacts')
)

SELECT
    check_name,
    expected,
    actual,
    CASE WHEN expected = actual THEN 'PASS' ELSE 'FAIL' END AS result
FROM checks
ORDER BY check_name;

-- sql/verify/05_phase2_warehouse_satellites_verification.sql
--
-- Phase 2 session 6 — first warehouse-layer Data Vault 2.0 satellite:
-- sat_filing_metadata. Parent = hub_filing (accession_number business
-- key). 2 truly filing-level payload attributes (form_type, filed_date).
-- 1:1 cardinality with hub_filing on first load — every parent has
-- exactly one sat row when no history has accumulated.
--
-- Scope note. Initially scoped at session 6 kickoff with 4 additional
-- per-period-instance payload columns (period_start_date,
-- period_end_date, fiscal_year, fiscal_period); trimmed at first-run
-- time after the cardinality miss surfaced (45,851 rows ≠ expected
-- 6,551). See LEARNINGS Risk 12 (2026-05-28). Those columns belong on
-- a future model class (hub_period + link_filing_period, OR baked
-- into sat_concept_value).
--
-- Standalone re-runnable artefact — paste the whole thing into Athena
-- Query Editor under workgroup wg_financial_analytics signed in as
-- phil-admin, region us-east-1.
--
-- Checks 11 invariants on sat_filing_metadata:
--
--   1. sat_filing_metadata_hk is unique across all rows.
--   2. sat_filing_metadata_hk is NOT NULL across all rows.
--   3. sat_filing_metadata_hk is exactly 64 hex chars (SHA-256
--      length contract).
--   4. hashdiff is NOT NULL across all rows. Proves the
--      COALESCE-sentinel pattern (LEARNINGS Risk 8) is in place —
--      defensive standard even though both payload columns are
--      reliably populated upstream.
--   5. hashdiff is exactly 64 hex chars (SHA-256 length contract).
--   6. FK closure to hub_filing — every sat row's hub_filing_hk
--      exists in hub_filing.hub_filing_hk (no orphan FKs).
--   7. Composite natural PK (hub_filing_hk, load_datetime) is
--      unique across all rows. Independently confirms the DV2.0
--      textbook contract that the engine-level single-column
--      unique_key on sat_filing_metadata_hk enforces.
--   8. Parent coverage parity — sat row count = distinct
--      hub_filing_hk in sat = hub_filing row count on first load
--      (1:1 cardinality invariant). This is the check that
--      surfaced the original scope miss; it's now the cheapest
--      structural guard for the satellite 1:1 contract.
--   9. sat_filing_metadata_hk determinism on Apple's
--      lexicographically smallest accession — recomputes
--      to_hex(sha256(to_utf8(hub_filing_hk || '||' ||
--      CAST(load_datetime AS varchar)))) and confirms the stored
--      hash matches. Proves the sat-hash function chain
--      reproduces deterministically (Risk 10).
--  10. hashdiff determinism on Apple's smallest accession —
--      recomputes the full COALESCE-protected 2-column payload
--      hash and confirms the stored hashdiff matches. Proves the
--      hashdiff chain (Risk 8) reproduces.
--  11. record_source is constant 'sec_edgar.companyfacts' on every
--      row (single source this session; lineage contract).
--
-- Idempotency check is separately performed by re-running
--   dotenv -f ..\.env run -- dbt run --select sat_filing_metadata
-- Expected output: NO-OP (0 rows merged) per the is_incremental
-- NOT EXISTS anti-join filter on the model — the latest stored
-- hashdiff for every parent matches the inbound recomputed
-- hashdiff (payload unchanged), so the anti-join excludes every
-- inbound row from the merge.
--
-- Schema tests in dbt/models/warehouse/_models.yml cover the
-- relationships + unique + not_null + composite natural PK
-- contracts; this verify suite restates them in raw queryable form
-- plus adds the SHA-256-length, parent-coverage parity, and
-- hash-determinism checks YAML can't express.

WITH apple_sample AS (
    -- Apple's smallest-accession satellite row — pick one
    -- deterministic row for the hash-recompute checks. MIN over
    -- accession_number is stable across runs.
    SELECT
        s.sat_filing_metadata_hk,
        s.hashdiff,
        s.hub_filing_hk,
        s.accession_number,
        s.form_type,
        s.filed_date,
        s.load_datetime
    FROM financial_analytics_silver.sat_filing_metadata s
    INNER JOIN financial_analytics_silver.hub_filing hf
        ON s.hub_filing_hk = hf.hub_filing_hk
    WHERE hf.accession_number = (
        SELECT MIN(hf2.accession_number)
        FROM financial_analytics_silver.hub_filing hf2
        INNER JOIN financial_analytics_silver.link_company_filing l
            ON hf2.hub_filing_hk = l.hub_filing_hk
        WHERE l.cik = '0000320193'
    )
),

checks AS (

    SELECT
        'check_01_sat_hk_unique' AS check_name,
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_filing_metadata) AS expected,
        (SELECT COUNT(DISTINCT sat_filing_metadata_hk) FROM financial_analytics_silver.sat_filing_metadata) AS actual

    UNION ALL SELECT
        'check_02_sat_hk_not_null',
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_filing_metadata),
        (SELECT COUNT(sat_filing_metadata_hk) FROM financial_analytics_silver.sat_filing_metadata)

    UNION ALL SELECT
        'check_03_sat_hk_length_64',
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_filing_metadata),
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_filing_metadata WHERE length(sat_filing_metadata_hk) = 64)

    UNION ALL SELECT
        'check_04_hashdiff_not_null',
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_filing_metadata),
        (SELECT COUNT(hashdiff) FROM financial_analytics_silver.sat_filing_metadata)

    UNION ALL SELECT
        'check_05_hashdiff_length_64',
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_filing_metadata),
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_filing_metadata WHERE length(hashdiff) = 64)

    UNION ALL SELECT
        'check_06_sat_fk_closure_filing',
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_filing_metadata),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.sat_filing_metadata s
         INNER JOIN financial_analytics_silver.hub_filing h
           ON s.hub_filing_hk = h.hub_filing_hk)

    UNION ALL SELECT
        'check_07_sat_composite_pk_unique',
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_filing_metadata),
        (SELECT COUNT(*)
         FROM (
             SELECT DISTINCT hub_filing_hk, load_datetime
             FROM financial_analytics_silver.sat_filing_metadata
         ))

    UNION ALL SELECT
        'check_08_sat_parent_coverage_parity',
        (SELECT COUNT(*) FROM financial_analytics_silver.hub_filing),
        (SELECT COUNT(DISTINCT hub_filing_hk) FROM financial_analytics_silver.sat_filing_metadata)

    UNION ALL SELECT
        'check_09_sat_hk_reproducible',
        CAST(1 AS bigint),
        (SELECT COUNT(*)
         FROM apple_sample
         WHERE sat_filing_metadata_hk = to_hex(sha256(to_utf8(
               CAST(hub_filing_hk AS varchar) || '||' || CAST(load_datetime AS varchar)
           ))))

    UNION ALL SELECT
        'check_10_hashdiff_reproducible',
        CAST(1 AS bigint),
        (SELECT COUNT(*)
         FROM apple_sample
         WHERE hashdiff = to_hex(sha256(to_utf8(
               COALESCE(CAST(form_type AS varchar), '^^') || '||' ||
               COALESCE(CAST(filed_date AS varchar), '^^')
           ))))

    UNION ALL SELECT
        'check_11_record_source_constant',
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_filing_metadata),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.sat_filing_metadata
         WHERE record_source = 'sec_edgar.companyfacts')
)

SELECT
    check_name,
    expected,
    actual,
    CASE WHEN expected = actual THEN 'PASS' ELSE 'FAIL' END AS result
FROM checks
ORDER BY check_name;

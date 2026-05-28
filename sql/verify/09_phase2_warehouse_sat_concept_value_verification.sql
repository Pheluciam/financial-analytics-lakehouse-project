-- sql/verify/09_phase2_warehouse_sat_concept_value_verification.sql
--
-- Phase 2 session 8 — third warehouse-layer Data Vault 2.0 satellite:
-- sat_concept_value. Parent = link_filing_concept_period (3-way standard
-- link). 2 payload attributes: value (DECIMAL(28,2)) + unit ('USD'
-- within current scope). 1:1 cardinality with link parent on first load
-- — every observation has exactly one sat row when no history has
-- accumulated. Expected 89,821 rows (= link row count from dbt run
-- result, confirmed via composite-PK dbt test PASS).
--
-- This is THE model holding the actual numerical SEC EDGAR financial
-- data — every downstream Gold mart in Phase 4 joins through here to
-- access fact values. Apple's FY2023 revenue, Microsoft's quarterly
-- net income, S&P 100 balance-sheet totals — all live in this table.
--
-- Standalone re-runnable artefact — paste the whole thing into Athena
-- Query Editor under workgroup wg_financial_analytics signed in as
-- phil-admin, region us-east-1.
--
-- Checks 12 invariants on sat_concept_value:
--
--   1. sat_concept_value_hk is unique across all rows.
--   2. sat_concept_value_hk is NOT NULL across all rows.
--   3. sat_concept_value_hk is exactly 64 hex chars (SHA-256 length).
--   4. hashdiff is NOT NULL across all rows (COALESCE-sentinel pattern
--      defends against Trino concat NULL propagation per Risk 8).
--   5. hashdiff is exactly 64 hex chars (SHA-256 length).
--   6. FK closure to link_filing_concept_period — every sat row's
--      link_filing_concept_period_hk exists in the link's PK column.
--   7. Composite natural PK (link_filing_concept_period_hk,
--      load_datetime) is unique across all rows. Independently
--      confirms the DV2.0 textbook contract that the engine-level
--      single-column unique_key on sat_concept_value_hk enforces.
--   8. Parent coverage parity — sat row count = distinct
--      link_filing_concept_period_hk in sat = link row count on first
--      load (1:1 cardinality invariant). Cheapest structural guard
--      for the satellite 1:1 contract per Risk 12 carry-forward.
--   9. value is NOT NULL across all rows (source-side WHERE filter
--      excludes NULL values upstream — contract validity check).
--  10. sat_concept_value_hk determinism on Apple's first observed row
--      — recomputes to_hex(sha256(to_utf8(link_hk || '||' ||
--      CAST(load_datetime AS varchar)))) and confirms the stored hash
--      matches (Risk 10 function chain).
--  11. hashdiff determinism on Apple's first observed row — recomputes
--      the COALESCE-protected (value, unit) hashdiff and confirms the
--      stored hashdiff matches (Risk 8 function chain).
--  12. record_source is constant 'sec_edgar.companyfacts' on every row.
--
-- Idempotency check is separately performed by re-running
--   dotenv -f ..\.env run -- dbt run --select sat_concept_value
-- Expected output: NO-OP per the is_incremental NOT EXISTS anti-join
-- filter — the latest stored hashdiff for every parent matches the
-- inbound recomputed hashdiff (payload unchanged within current Bronze).

WITH apple_sample AS (
    -- Apple's first observed row — cik 0000320193, canonical 'revenue',
    -- lexicographically smallest accession + period. Deterministic
    -- across runs.
    SELECT
        s.sat_concept_value_hk,
        s.hashdiff,
        s.link_filing_concept_period_hk,
        s.value,
        s.unit,
        s.load_datetime
    FROM financial_analytics_silver.sat_concept_value s
    WHERE s.cik = '0000320193'
      AND s.canonical_concept = 'revenue'
    ORDER BY s.accession_number, s.period_end_date
    LIMIT 1
),

checks AS (

    SELECT
        'check_01_sat_hk_unique' AS check_name,
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_concept_value) AS expected,
        (SELECT COUNT(DISTINCT sat_concept_value_hk) FROM financial_analytics_silver.sat_concept_value) AS actual

    UNION ALL SELECT
        'check_02_sat_hk_not_null',
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_concept_value),
        (SELECT COUNT(sat_concept_value_hk) FROM financial_analytics_silver.sat_concept_value)

    UNION ALL SELECT
        'check_03_sat_hk_length_64',
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_concept_value),
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_concept_value WHERE length(sat_concept_value_hk) = 64)

    UNION ALL SELECT
        'check_04_hashdiff_not_null',
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_concept_value),
        (SELECT COUNT(hashdiff) FROM financial_analytics_silver.sat_concept_value)

    UNION ALL SELECT
        'check_05_hashdiff_length_64',
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_concept_value),
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_concept_value WHERE length(hashdiff) = 64)

    UNION ALL SELECT
        'check_06_sat_fk_closure_link',
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_concept_value),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.sat_concept_value s
         INNER JOIN financial_analytics_silver.link_filing_concept_period l
           ON s.link_filing_concept_period_hk = l.link_filing_concept_period_hk)

    UNION ALL SELECT
        'check_07_sat_composite_pk_unique',
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_concept_value),
        (SELECT COUNT(*)
         FROM (
             SELECT DISTINCT link_filing_concept_period_hk, load_datetime
             FROM financial_analytics_silver.sat_concept_value
         ))

    UNION ALL SELECT
        'check_08_sat_parent_coverage_parity',
        (SELECT COUNT(*) FROM financial_analytics_silver.link_filing_concept_period),
        (SELECT COUNT(DISTINCT link_filing_concept_period_hk) FROM financial_analytics_silver.sat_concept_value)

    UNION ALL SELECT
        'check_09_value_not_null',
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_concept_value),
        (SELECT COUNT(value) FROM financial_analytics_silver.sat_concept_value)

    UNION ALL SELECT
        'check_10_sat_hk_reproducible',
        CAST(1 AS bigint),
        (SELECT COUNT(*)
         FROM apple_sample
         WHERE sat_concept_value_hk = to_hex(sha256(to_utf8(
               CAST(link_filing_concept_period_hk AS varchar) || '||' ||
               CAST(load_datetime AS varchar)
           ))))

    UNION ALL SELECT
        'check_11_hashdiff_reproducible',
        CAST(1 AS bigint),
        (SELECT COUNT(*)
         FROM apple_sample
         WHERE hashdiff = to_hex(sha256(to_utf8(
               COALESCE(CAST(value AS varchar), '^^') || '||' ||
               COALESCE(CAST(unit AS varchar), '^^')
           ))))

    UNION ALL SELECT
        'check_12_record_source_constant',
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_concept_value),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.sat_concept_value
         WHERE record_source = 'sec_edgar.companyfacts')
)

SELECT
    check_name,
    expected,
    actual,
    CASE WHEN expected = actual THEN 'PASS' ELSE 'FAIL' END AS result
FROM checks
ORDER BY check_name;

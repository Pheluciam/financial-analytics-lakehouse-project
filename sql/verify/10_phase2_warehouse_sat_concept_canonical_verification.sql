-- sql/verify/10_phase2_warehouse_sat_concept_canonical_verification.sql
--
-- Phase 2 session 9 — fourth warehouse-layer Data Vault 2.0 satellite,
-- first MULTI-ACTIVE SATELLITE (MAS) in the project: sat_concept_canonical.
-- Parent = hub_concept (5 rows). Audit-lineage payload — raw XBRL US-GAAP
-- tag name as both Child Dependent Key (CDK = sub_sequence_key) and
-- descriptive content (degenerate-payload pattern per LEARNINGS Risk 17).
-- Expected first-load row count = 8 (4 revenue alias tags collapsing to
-- canonical 'revenue' + 4 identity-mapped tags). Empirically anchored at
-- session 9 forward-verify probe 2: 8 distinct (canonical, raw_tag)
-- pairs = canonical_concepts_dictionary seed row count exactly.
--
-- THE AUDIT LINEAGE MODEL. Defends sat_concept_value's MIN(value)
-- information-loss decision (session 8) by preserving regulatory-
-- defensible provenance to the original XBRL US-GAAP tag every fact
-- was reported under.
--
-- Standalone re-runnable artefact — paste the whole thing into Athena
-- Query Editor under workgroup wg_financial_analytics signed in as
-- phil-admin, region us-east-1.
--
-- Checks 14 invariants on sat_concept_canonical (2 more than standard
-- sat verify suites because MAS carries an extra hash column
-- sub_sequence_key AND an MAS-specific cardinality invariant guard
-- beyond the standard parent-coverage check):
--
--   1.  sat_concept_canonical_hk is unique across all rows.
--   2.  sat_concept_canonical_hk is NOT NULL across all rows.
--   3.  sat_concept_canonical_hk is exactly 64 hex chars (SHA-256 length).
--   4.  hashdiff is NOT NULL across all rows.
--   5.  hashdiff is exactly 64 hex chars.
--   6.  sub_sequence_key is NOT NULL across all rows.
--   7.  sub_sequence_key is exactly 64 hex chars.
--   8.  FK closure to hub_concept — every sat row's hub_concept_hk
--       exists in hub_concept's PK column.
--   9.  Composite natural PK (hub_concept_hk, sub_sequence_key,
--       load_datetime) is unique. 3-COLUMN MAS variant (vs 2-column
--       composite for sessions 6/7/8 sats).
--   10. MAS cardinality invariant — sat row count = 8 = distinct
--       (hub_concept_hk, sub_sequence_key) pair count. The first-load
--       MAS-grain guard: every (parent, CDK) pair observed in source
--       lands as exactly one sat row.
--   11. Parent coverage — sat carries all 5 distinct canonical concepts
--       (every canonical observed in source has at least one MAS row).
--   12. sat_concept_canonical_hk determinism on canonical 'revenue' +
--       raw tag 'Revenues' sample — recomputes
--       to_hex(sha256(to_utf8(parent_hk || '||' || sub_sequence_key
--       || '||' || CAST(load_datetime AS varchar)))) and confirms the
--       stored hash matches (Risk 10 MAS-extended function chain).
--   13. hashdiff determinism on same sample — recomputes
--       to_hex(sha256(to_utf8(COALESCE(CAST(concept_name AS varchar),
--       '^^')))) and confirms the stored hashdiff matches (Risk 8
--       single-column function chain).
--   14. record_source is constant 'sec_edgar.companyfacts' on every row.
--
-- Idempotency check is separately performed by re-running
--   dotenv -f ..\.env run -- dbt run --select sat_concept_canonical
-- Expected output: NO-OP per the is_incremental MAS NOT EXISTS anti-join
-- filter — every (parent, CDK) pair is already present in {{ this }}
-- and the degenerate hashdiff matches by construction.

WITH revenue_sample AS (
    -- Canonical 'revenue' + raw tag 'Revenues' — the deterministic
    -- portfolio-anchor pair. Picks the original pre-ASC-606 revenue
    -- tag (Revenues), which exists in seed and was observed in source
    -- per forward-verify probe 2.
    SELECT
        s.sat_concept_canonical_hk,
        s.hashdiff,
        s.hub_concept_hk,
        s.sub_sequence_key,
        s.concept_name,
        s.load_datetime
    FROM financial_analytics_silver.sat_concept_canonical s
    WHERE s.canonical_concept = 'revenue'
      AND s.concept_name = 'Revenues'
    LIMIT 1
),

checks AS (

    SELECT
        'check_01_sat_hk_unique' AS check_name,
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_concept_canonical) AS expected,
        (SELECT COUNT(DISTINCT sat_concept_canonical_hk) FROM financial_analytics_silver.sat_concept_canonical) AS actual

    UNION ALL SELECT
        'check_02_sat_hk_not_null',
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_concept_canonical),
        (SELECT COUNT(sat_concept_canonical_hk) FROM financial_analytics_silver.sat_concept_canonical)

    UNION ALL SELECT
        'check_03_sat_hk_length_64',
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_concept_canonical),
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_concept_canonical WHERE length(sat_concept_canonical_hk) = 64)

    UNION ALL SELECT
        'check_04_hashdiff_not_null',
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_concept_canonical),
        (SELECT COUNT(hashdiff) FROM financial_analytics_silver.sat_concept_canonical)

    UNION ALL SELECT
        'check_05_hashdiff_length_64',
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_concept_canonical),
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_concept_canonical WHERE length(hashdiff) = 64)

    UNION ALL SELECT
        'check_06_sub_sequence_key_not_null',
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_concept_canonical),
        (SELECT COUNT(sub_sequence_key) FROM financial_analytics_silver.sat_concept_canonical)

    UNION ALL SELECT
        'check_07_sub_sequence_key_length_64',
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_concept_canonical),
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_concept_canonical WHERE length(sub_sequence_key) = 64)

    UNION ALL SELECT
        'check_08_sat_fk_closure_hub_concept',
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_concept_canonical),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.sat_concept_canonical s
         INNER JOIN financial_analytics_silver.hub_concept h
           ON s.hub_concept_hk = h.hub_concept_hk)

    UNION ALL SELECT
        'check_09_sat_composite_pk_unique_3col',
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_concept_canonical),
        (SELECT COUNT(*)
         FROM (
             SELECT DISTINCT hub_concept_hk, sub_sequence_key, load_datetime
             FROM financial_analytics_silver.sat_concept_canonical
         ))

    UNION ALL SELECT
        'check_10_mas_cardinality_invariant',
        CAST(8 AS bigint),
        (SELECT COUNT(*)
         FROM (
             SELECT DISTINCT hub_concept_hk, sub_sequence_key
             FROM financial_analytics_silver.sat_concept_canonical
         ))

    UNION ALL SELECT
        'check_11_parent_coverage_5_canonicals',
        CAST(5 AS bigint),
        (SELECT COUNT(DISTINCT hub_concept_hk) FROM financial_analytics_silver.sat_concept_canonical)

    UNION ALL SELECT
        'check_12_sat_hk_reproducible',
        CAST(1 AS bigint),
        (SELECT COUNT(*)
         FROM revenue_sample
         WHERE sat_concept_canonical_hk = to_hex(sha256(to_utf8(
               CAST(hub_concept_hk AS varchar) || '||' ||
               CAST(sub_sequence_key AS varchar) || '||' ||
               CAST(load_datetime AS varchar)
           ))))

    UNION ALL SELECT
        'check_13_hashdiff_reproducible',
        CAST(1 AS bigint),
        (SELECT COUNT(*)
         FROM revenue_sample
         WHERE hashdiff = to_hex(sha256(to_utf8(
               COALESCE(CAST(concept_name AS varchar), '^^')
           ))))

    UNION ALL SELECT
        'check_14_record_source_constant',
        (SELECT COUNT(*) FROM financial_analytics_silver.sat_concept_canonical),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.sat_concept_canonical
         WHERE record_source = 'sec_edgar.companyfacts')
)

SELECT
    check_name,
    expected,
    actual,
    CASE WHEN expected = actual THEN 'PASS' ELSE 'FAIL' END AS result
FROM checks
ORDER BY check_name;

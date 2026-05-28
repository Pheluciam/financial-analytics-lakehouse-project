-- dbt/models/warehouse/hub_concept.sql
--
-- Warehouse-layer Data Vault 2.0 hub model — third hub in the project.
-- Records the immutable first-observed instance of each unique canonical
-- XBRL concept (business key = canonical_concept) across the SEC EDGAR
-- source.
--
-- Hand-rolled per the Phase 2 session 3 close-amend lock — AutomateDV
-- does not officially support dbt-athena (LEARNINGS Risk 1, 2026-05-28),
-- so every DV2.0 model in this project is written in plain dbt-athena
-- SQL with no third-party DV2.0 macros. Mirrors hub_company structurally
-- — same hash chain, same source-side filter pattern, same insert-only
-- semantics; only the source path + business-key column differ.
--
-- Source: int_sec_edgar__concepts_canonical (the intermediate view that
-- joins int_sec_edgar__concepts to canonical_concepts_dictionary by raw
-- concept_name). Sourcing from the canonical view rather than the seed
-- directly is intentional — DV2.0 hubs hold first-observed business keys
-- in actual data, not enumerated reference lists. A canonical concept
-- defined in the seed but never reported by any S&P 100 company
-- shouldn't appear in hub_concept. Empirical session 8 probe 1 confirmed
-- 5 distinct canonicals reported: revenue, net_income, assets,
-- liabilities, stockholders_equity (the 4 revenue alias raw tags
-- collapse to canonical 'revenue' inside the canonical view).
--
-- Hash key: SHA-256 of the business key (canonical_concept). Function
-- chain identical to hub_company / hub_filing: to_hex(sha256(to_utf8(
-- CAST(<bk> AS varchar)))) per LEARNINGS Risk 4 (2026-05-28). Defensive
-- CAST guards against future staging-side type changes silently breaking
-- the hash. Five 64-character SHA-256 hashes at S&P 100 scale is a
-- trivially-small reference hub by every measure — but the hash chain
-- is still applied for visual + lineage consistency with the other two
-- hubs.
--
-- Insert-only semantics: same source-side is_incremental filter pattern
-- as hub_company / hub_filing. Re-seeing an already-loaded
-- canonical_concept on a subsequent extract excludes it from the source
-- SELECT before the engine reaches the merge — load_datetime +
-- record_source on the original row are immutable. unique_key acts as a
-- belt-and-braces engine-level safety net.
--
-- Materialization defaults (incremental + iceberg + parquet +
-- on_schema_change=ignore) live in dbt_project.yml under the warehouse
-- block. Only the per-model unique_key is set here.
--
-- Walkthrough: DBT_PIPELINE.md section 8.

{{
  config(
    unique_key='hub_concept_hk'
  )
}}

WITH source AS (
    SELECT DISTINCT canonical_concept
    FROM {{ ref('int_sec_edgar__concepts_canonical') }}
    WHERE canonical_concept IS NOT NULL
),

hashed AS (
    SELECT
        to_hex(sha256(to_utf8(CAST(canonical_concept AS varchar)))) AS hub_concept_hk,
        canonical_concept,
        CAST(current_timestamp AT TIME ZONE 'UTC' AS timestamp(6)) AS load_datetime,
        'sec_edgar.companyfacts' AS record_source
    FROM source
)

SELECT * FROM hashed
{% if is_incremental() %}
WHERE hub_concept_hk NOT IN (SELECT hub_concept_hk FROM {{ this }})
{% endif %}

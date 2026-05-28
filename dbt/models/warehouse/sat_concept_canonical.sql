-- dbt/models/warehouse/sat_concept_canonical.sql
--
-- Warehouse-layer Data Vault 2.0 multi-active satellite (MAS) — first MAS
-- in the project, fourth satellite overall. Parent = hub_concept
-- (5 rows, BK = canonical_concept). One row per (canonical_concept, raw
-- XBRL tag name) pair observed in actual SEC EDGAR companyfacts data.
-- Expected first-load row count = 8 — empirically verified at session 9
-- forward-verify probe 2 (8 distinct (canonical_concept, concept_name)
-- pairs) and matches canonical_concepts_dictionary seed row count exactly.
--
-- THE AUDIT LINEAGE MODEL. Preserves the raw concept_name →
-- canonical_concept mapping with DV2.0-native immutability, defending the
-- MIN(value) information-loss decision baked into sat_concept_value
-- (session 8) by retaining regulatory-defensible provenance to the
-- original XBRL US-GAAP taxonomy tag every fact was reported under. If a
-- regulator or analyst ever asks "which raw tag did Apple report FY2019
-- revenue under, and how does that reconcile with the canonical
-- aggregation we showed on the dashboard" — this model answers without
-- replaying the canonical-collapse logic.
--
-- Multi-active satellite (NEW DV2.0 MECHANIC relative to sessions 6/7/8
-- 1:1 sat shape). MAS allows multiple concurrent active rows per parent
-- hash key at the same point in time. Required here because a single
-- canonical_concept (e.g. 'revenue') has multiple active raw tags
-- (Revenues, SalesRevenueNet,
-- RevenueFromContractWithCustomerExcludingAssessedTax,
-- RevenueFromContractWithCustomerIncludingAssessedTax) — all valid
-- simultaneously in source. The textbook MAS primary key is composite:
-- (parent_hk, sub_sequence_key, load_datetime). Verified against
-- AutomateDV ma_sat tutorial + Scalefree multi-active part 1 at the
-- session 9 forward-verify pass (2026-05-29).
--
-- Child Dependent Key (CDK) = SHA-256 of raw concept_name (LEARNINGS
-- Risk 18, 2026-05-29). Scalefree explicit guidance: when source
-- provides a stable type code identifying each active row, use it as
-- CDK directly; sub-sequence auto-numbering is the FALLBACK pattern for
-- sources without a stable identifier. Raw XBRL US-GAAP tag names are
-- stable taxonomy identifiers — they don't drift between extracts for
-- the same logical concept (a 10-K filed under 'Revenues' in 2017 is
-- still tagged 'Revenues' on every re-extract today). Hashing the raw
-- tag name fixes the CDK at SHA-256 64-char width for visual consistency
-- with the rest of the hash-key surface. Auto-numbering rejected:
-- fragile if seed reordered, not source-faithful, would re-shuffle the
-- CDK assignment on every dbt refresh.
--
-- Degenerate payload — CDK == payload (LEARNINGS Risk 17, 2026-05-29).
-- The raw concept_name IS BOTH the active-row identifier AND the
-- audit-lineage attribute being preserved. There is no separate
-- descriptive payload (business_area in the canonical dictionary is 1:1
-- with canonical_concept and would belong on a regular sat on
-- hub_concept, not on this MAS — semantically it's a parent-level
-- attribute). Hashdiff column is structurally constant per (parent, CDK)
-- by construction — once a (canonical, raw_tag) pair is observed, the
-- hashdiff for that row never changes. SCD-2 mechanic still fires
-- correctly: new (parent, CDK) pair = new sat row inserted; existing
-- pair = anti-join skip. Hashdiff column kept for project-wide visual
-- consistency with sessions 6/7/8 satellites + future-proofing if
-- payload attributes are added (e.g., a future per-raw-tag
-- deprecation_date or first_observed_date column).
--
-- Source: int_sec_edgar__concepts_canonical (matches hub_concept's
-- lineage rule — DV2.0 hubs/sats source raw tags observed in actual
-- data, not seed-enumerated reference lists). A canonical concept or
-- raw tag defined in the seed but never reported by any S&P 100 company
-- in our 10-year window shouldn't appear in this sat — same contract
-- as hub_concept. DISTINCT (canonical_concept, concept_name) collapse
-- at source-side CTE per Risk 16 post-canonical natural cardinal tuple
-- discipline collapses 93,869 source rows to 8 distinct pairs (forward-
-- verify probe 2, 2026-05-29).
--
-- sat_concept_canonical_hk (LEARNINGS Risk 10, with MAS extension).
-- Dedicated single-column satellite hash key over (hub_concept_hk ||
-- '||' || sub_sequence_key || '||' || load_datetime). MAS-specific
-- extension of the 2-component sat hash from sessions 6/7/8
-- (parent_hk + load_datetime) — the natural PK now includes
-- sub_sequence_key as the third component, so the surrogate hash
-- includes it too. Keeps the hub/link/sat surface visually consistent
-- (every warehouse-layer model has one column named <class>_<entity>_hk
-- that's its single-column unique_key). Composite natural PK
-- (hub_concept_hk, sub_sequence_key, load_datetime) enforced at test
-- time via dbt_utils.unique_combination_of_columns in _models.yml.
--
-- hashdiff (LEARNINGS Risk 8). SHA-256 over COALESCE-sentinel-protected
-- raw concept_name. Single-column hashdiff drops the '||' delimiter
-- (carry-forward from session 7 sat_company_metadata: delimiter defends
-- against multi-column concat ambiguity not present here). '^^' sentinel
-- defeats Trino's concat NULL propagation — defensive standard even
-- though concept_name is guaranteed NOT NULL upstream.
--
-- MAS SCD-2 anti-join filter (LEARNINGS Risk 9, MAS adaptation). The
-- window function partitions by (hub_concept_hk, sub_sequence_key) —
-- NOT just hub_concept_hk — picking the latest stored hashdiff per
-- active row, not per parent. The NOT EXISTS clause matches inbound on
-- both (parent, CDK) before checking hashdiff equality. Without the
-- sub_sequence_key in the partition + match, every newly-extracted raw
-- tag for the same canonical would compare against the WRONG row's
-- latest hashdiff and either re-insert duplicates or skip valid new
-- rows incorrectly.
--
-- Materialization defaults (incremental + iceberg + parquet +
-- on_schema_change=ignore) live in dbt_project.yml under the warehouse
-- block. on_schema_change=ignore MANDATORY for satellites per Risk 2
-- (Iceberg merge + on_schema_change=sync_all_columns has a documented
-- duplicate-insertion bug in dbt-adapters issue #571). Only the
-- per-model unique_key is set here.
--
-- Walkthrough: DBT_PIPELINE.md section 8.

{{
  config(
    unique_key='sat_concept_canonical_hk'
  )
}}

WITH source AS (
    -- DISTINCT (canonical_concept, concept_name) collapse per Risk 16 —
    -- 93,869 source rows have ~11,733 rows per (canonical, raw_tag) pair
    -- due to the per-period UNNEST cardinality upstream; this DISTINCT
    -- collapses them to the 8 distinct pairs that define the MAS grain.
    -- Excludes NULL on both columns defensively; int_sec_edgar__concepts_canonical's
    -- INNER JOIN to the seed guarantees both populated in practice.
    SELECT DISTINCT
        canonical_concept,
        concept_name
    FROM {{ ref('int_sec_edgar__concepts_canonical') }}
    WHERE canonical_concept IS NOT NULL
      AND concept_name IS NOT NULL
),

-- Compute parent hub FK (hub_concept_hk) via single-key SHA-256 chain
-- identical to hub_concept so FK = hub PK by construction. Compute CDK
-- (sub_sequence_key) via the same chain over raw concept_name — stable
-- type code per Risk 18. Add LDTS + record_source.
enriched AS (
    SELECT
        to_hex(sha256(to_utf8(CAST(canonical_concept AS varchar)))) AS hub_concept_hk,
        to_hex(sha256(to_utf8(CAST(concept_name AS varchar)))) AS sub_sequence_key,
        canonical_concept,
        concept_name,
        CAST(current_timestamp AT TIME ZONE 'UTC' AS timestamp(6)) AS load_datetime,
        'sec_edgar.companyfacts' AS record_source
    FROM source
),

-- sat_concept_canonical_hk + hashdiff. Three-component sat hash over
-- (parent_hk || '||' || sub_sequence_key || '||' || load_datetime) —
-- MAS extension of sessions 6/7/8 two-component sat hash. Single-column
-- hashdiff over COALESCE-sentinel-protected raw concept_name (Risk 8).
hashed AS (
    SELECT
        to_hex(sha256(to_utf8(
            CAST(hub_concept_hk AS varchar) || '||' ||
            CAST(sub_sequence_key AS varchar) || '||' ||
            CAST(load_datetime AS varchar)
        ))) AS sat_concept_canonical_hk,
        to_hex(sha256(to_utf8(
            COALESCE(CAST(concept_name AS varchar), '^^')
        ))) AS hashdiff,
        hub_concept_hk,
        sub_sequence_key,
        canonical_concept,
        concept_name,
        load_datetime,
        record_source
    FROM enriched
)

SELECT * FROM hashed inbound
{% if is_incremental() %}
-- MAS SCD-2 insert-on-change anti-join filter (Risk 9 MAS adaptation).
-- Window PARTITION + NOT EXISTS match BOTH on (hub_concept_hk,
-- sub_sequence_key) — the active-row PK — not just hub_concept_hk.
-- Inbound rows pass through to merge if (a) no existing row for that
-- (parent, CDK) pair OR (b) hashdiff differs from latest for that
-- exact (parent, CDK) pair. Degenerate payload (Risk 17) means branch
-- (b) won't fire in practice — every refresh of stable seed mappings
-- hits branch (a)-or-anti-join-skip on existing pairs.
WHERE NOT EXISTS (
    SELECT 1
    FROM (
        SELECT
            hub_concept_hk,
            sub_sequence_key,
            hashdiff,
            ROW_NUMBER() OVER (
                PARTITION BY hub_concept_hk, sub_sequence_key
                ORDER BY load_datetime DESC
            ) AS rn
        FROM {{ this }}
    ) latest
    WHERE latest.hub_concept_hk = inbound.hub_concept_hk
      AND latest.sub_sequence_key = inbound.sub_sequence_key
      AND latest.hashdiff = inbound.hashdiff
      AND latest.rn = 1
)
{% endif %}

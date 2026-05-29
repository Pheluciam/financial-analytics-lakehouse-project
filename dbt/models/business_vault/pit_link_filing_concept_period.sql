-- dbt/models/business_vault/pit_link_filing_concept_period.sql
--
-- Business Vault Point-In-Time table — first PIT in the project. Spine =
-- link_filing_concept_period (the 3-way standard link associating
-- hub_company + hub_filing + hub_concept at the per-period observation
-- grain, 89,821 rows). Single satellite resolved: sat_concept_value.
--
-- Hand-rolled per Risk 1 (2026-05-28). AutomateDV's pit + pit_incremental
-- materialization don't ship for dbt-athena; the structural pattern carries
-- across — for each as_of_date, the PIT identifies the relevant satellite
-- row's hash key + load_datetime so downstream Phase 4 mart queries replace
-- the SCD-2 latest-row anti-join with a single equi-join lookup.
--
-- Single-sat PIT framing (LEARNINGS Risk 19, 2026-05-29). AutomateDV's
-- canonical recommendation is to use PIT when 2+ satellites hang off the
-- same parent (especially with different update rates) — that's where
-- collapsing multi-sat LDTS lookups to single equi-join rows delivers
-- material query gain. Our Raw Vault topology has 1 sat per parent
-- everywhere; sat_concept_value is the only sat on link_filing_concept_period.
-- Picked THIS spine (over hub_company / hub_filing) because it's THE
-- fact-shape every Phase 4 mart will consume — equi-join from PIT to
-- sat_concept_value resolves "value at as_of_date" without recomputing
-- the SCD-2 latest-row anti-join at query time, real downstream benefit.
-- Future-proofs for when sat_concept_value gets joined with a second sat
-- (e.g., sat_concept_value_restatement_flag) — the PIT shape is already
-- in place. NOT building one PIT per parent — pattern-for-pattern's-sake
-- proliferation is anti-portfolio.
--
-- Temporal anchor — filed_date, NOT load_datetime (LEARNINGS Risk 23,
-- 2026-05-29). Canonical PIT semantics use MAX(sat.load_datetime) <=
-- as_of_date to resolve "what was visible at as_of_date." Project #3's
-- load_datetime captures ingestion-time (dbt-run wall clock — every row
-- timestamped May 2026), NOT observation-time (the SEC filing's filed
-- date). Naively applied, every as_of_date 2016-2025 would resolve to
-- ZERO visible rows. Project-specific deviation: PIT joins through
-- hub_filing → sat_filing_metadata to access filed_date and uses
-- filed_date <= as_of_date as the temporal filter. load_datetime is
-- preserved on the PIT row as the canonical lineage column even though
-- it's not the temporal filter — every PIT row's sat_concept_value_ldts
-- is the same May-2026 ingestion timestamp by construction.
--
-- Ghost-record deferral (LEARNINGS Risk 22, 2026-05-29). AutomateDV
-- emits a zero-hash-key ghost record reference when a parent has no
-- matching satellite at as_of_date. We haven't shipped ghost records
-- on any of our 4 sats. The hand-rolled simpler substitute: structure
-- the JOIN such that only (link, as_of_date) pairs with a visible
-- filing produce a PIT row. Downstream marts handle "no row at this
-- as_of_date" via standard COALESCE/CASE in mart-side SQL. Ghost
-- records remain a Phase 4+ enhancement if Power BI specifically
-- demands inner-join semantics on the PIT.
--
-- Composite natural PK = (link_filing_concept_period_hk, as_of_date).
-- Single-column surrogate PK = pit_link_filing_concept_period_hk via
-- SHA-256 over the composite — visual consistency with hub/link/sat
-- single-hash-PK surface (Risk 10 carry from session 6). Composite
-- natural PK enforced at test time via
-- dbt_utils.unique_combination_of_columns in _models.yml.
--
-- Materialization: plain table (Iceberg/Parquet) per business_vault
-- layer defaults in dbt_project.yml. NOT incremental + merge — PIT is
-- a non-historized query helper; every dbt run is a full refresh, which
-- structurally avoids the Risk 2 (LEARNINGS 2026-05-28) Iceberg merge
-- on_schema_change duplicate-insertion bug class.
--
-- Walkthrough: DBT_PIPELINE.md section 8.22-8.23.

WITH as_of AS (
    SELECT as_of_date FROM {{ ref('dim_as_of_dates') }}
),

-- Join link to sat_filing_metadata via hub_filing_hk to bring filed_date
-- onto each link row. filed_date is the observation-time temporal anchor
-- (Risk 23). sat_filing_metadata is 1:1 with hub_filing per session 6
-- so this inner join doesn't fan out the link cardinality.
link_with_filed_date AS (
    SELECT
        l.link_filing_concept_period_hk,
        sfm.filed_date
    FROM {{ ref('link_filing_concept_period') }} l
    INNER JOIN {{ ref('sat_filing_metadata') }} sfm
        ON l.hub_filing_hk = sfm.hub_filing_hk
),

-- Cross-join link × as_of_dates with the filed_date temporal filter, then
-- left-join the sat to resolve sat-side coordinates for each (link,
-- as_of_date) pair. Within our Raw Vault, every link has exactly one sat
-- row (no SCD-2 history accumulated within the 2 Bronze extract_dates),
-- so the LEFT JOIN resolves to one sat row per visible link. LEFT JOIN
-- semantics preserved as the ghost-record substitute (Risk 22).
sat_coordinates AS (
    SELECT
        l.link_filing_concept_period_hk,
        a.as_of_date,
        s.sat_concept_value_hk AS sat_concept_value_pk,
        s.load_datetime AS sat_concept_value_ldts
    FROM link_with_filed_date l
    CROSS JOIN as_of a
    LEFT JOIN {{ ref('sat_concept_value') }} s
        ON s.link_filing_concept_period_hk = l.link_filing_concept_period_hk
    WHERE l.filed_date <= a.as_of_date
),

-- Compute the PIT surrogate hash + project the final shape. SHA-256
-- chain identical to every other warehouse-layer hash column (Risk 4
-- single-key + Risk 6 '||' composite delimiter).
hashed AS (
    SELECT
        to_hex(sha256(to_utf8(
            CAST(link_filing_concept_period_hk AS varchar) || '||' ||
            CAST(as_of_date AS varchar)
        ))) AS pit_link_filing_concept_period_hk,
        link_filing_concept_period_hk,
        as_of_date,
        sat_concept_value_pk,
        sat_concept_value_ldts,
        CAST(current_timestamp AT TIME ZONE 'UTC' AS timestamp(6)) AS load_datetime,
        'business_vault.pit_link_filing_concept_period' AS record_source
    FROM sat_coordinates
)

SELECT * FROM hashed

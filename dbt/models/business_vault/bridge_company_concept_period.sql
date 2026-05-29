-- dbt/models/business_vault/bridge_company_concept_period.sql
--
-- Business Vault Bridge table — first Bridge in the project. Spine =
-- hub_company. Walks through the 5-hop hub-link-hub graph:
-- hub_company → link_company_filing → hub_filing → link_filing_concept_period
-- → hub_concept. Collapses what would otherwise be a 5+ join navigation
-- in Phase 4's mart_pl_trend and mart_peer_benchmark to a single equi-join
-- SELECT against this bridge.
--
-- Hand-rolled per Risk 1 (2026-05-28). AutomateDV's bridge + bridge_incremental
-- materialization don't ship for dbt-athena; the structural pattern carries
-- across.
--
-- No effectivity satellites (LEARNINGS Risk 20, 2026-05-29). AutomateDV's
-- bridge_walk metadata structure assumes each link carries an Effectivity
-- Satellite tracking relationship end-dates. We don't ship eff_sats —
-- our links are insert-only with no end-date semantics (a (cik,
-- accession_number) relationship doesn't "end" in SEC reporting; a filing
-- exists or doesn't, and once filed it remains observable forever). The
-- Scalefree Bridge Tables 101 SQL idiom without eff_sat references is
-- correct fit. bridge_walk columns are simplified: hub hash keys + link
-- hash keys + period payload + as_of_date, NO eff_sat_*_end_date or
-- eff_sat_*_load_date columns.
--
-- Temporal anchor — filed_date, NOT load_datetime (LEARNINGS Risk 23,
-- 2026-05-29). Same deviation as the sister PIT: project's load_datetime
-- captures ingestion-time, not observation-time. Bridge joins through
-- hub_filing → sat_filing_metadata to access filed_date and uses
-- filed_date <= as_of_date as the visibility filter. A (cik, accession,
-- canonical, period) relationship is "visible at as_of_date" iff the
-- underlying SEC filing was filed on or before that date. Carries
-- load_datetime as the canonical lineage column — by construction every
-- row's load_datetime is the same May-2026 ingestion timestamp.
--
-- Bridge composition. Each row carries:
--   - bridge_company_concept_period_hk (single-column surrogate PK,
--     SHA-256 over composite of hub_company_hk + link_company_filing_hk
--     + link_filing_concept_period_hk + as_of_date — uniquely identifies
--     this snapshot relationship at this as_of_date)
--   - hub_company_hk + hub_filing_hk + hub_concept_hk (hub-side FK
--     references — direct equi-join into hubs from the bridge)
--   - link_company_filing_hk + link_filing_concept_period_hk (link-side
--     FK references — direct equi-join into links for the relationship
--     instance)
--   - period_end_date + fiscal_year + fiscal_period (link-level payload
--     carried for mart-side time-axis grouping without re-joining link)
--   - as_of_date (the snapshot timestamp this row belongs to)
--   - load_datetime + record_source (lineage)
--
-- Composite natural PK = (link_filing_concept_period_hk, as_of_date).
-- The link PK already captures (cik, accession, canonical, period_*) as
-- a 7-column composite hash — adding as_of_date as the snapshot
-- dimension produces a unique row per (relationship, snapshot). Enforced
-- at test time via dbt_utils.unique_combination_of_columns in _models.yml.
--
-- Materialization: plain table (Iceberg/Parquet) per business_vault
-- layer defaults — Bridge is a non-historized query helper, full rebuild
-- per dbt run, structurally avoiding the Risk 2 Iceberg-merge bug class.
--
-- Walkthrough: DBT_PIPELINE.md section 8.24-8.25.

WITH as_of AS (
    SELECT as_of_date FROM {{ ref('dim_as_of_dates') }}
),

-- Join link_filing_concept_period to sat_filing_metadata via hub_filing_hk
-- to bring filed_date onto each link row. sat_filing_metadata is 1:1 with
-- hub_filing per session 6 so this inner join doesn't fan out the link
-- cardinality (89,821 link rows in, 89,821 enriched rows out).
link_with_filed_date AS (
    SELECT
        l.link_filing_concept_period_hk,
        l.hub_company_hk,
        l.hub_filing_hk,
        l.hub_concept_hk,
        l.period_end_date,
        l.fiscal_year,
        l.fiscal_period,
        sfm.filed_date
    FROM {{ ref('link_filing_concept_period') }} l
    INNER JOIN {{ ref('sat_filing_metadata') }} sfm
        ON l.hub_filing_hk = sfm.hub_filing_hk
),

-- Join in link_company_filing to bring the link_company_filing_hk onto
-- each bridge row. Match on the composite (hub_company_hk, hub_filing_hk)
-- — both sides of the link_company_filing PK semantically — so the join
-- is exact-cardinality (no fan-out). link_company_filing is 1:1 with
-- (cik, accession_number) per session 5.
link_walk AS (
    SELECT
        l.link_filing_concept_period_hk,
        l.hub_company_hk,
        l.hub_filing_hk,
        l.hub_concept_hk,
        lcf.link_company_filing_hk,
        l.period_end_date,
        l.fiscal_year,
        l.fiscal_period,
        l.filed_date
    FROM link_with_filed_date l
    INNER JOIN {{ ref('link_company_filing') }} lcf
        ON l.hub_company_hk = lcf.hub_company_hk
        AND l.hub_filing_hk = lcf.hub_filing_hk
),

-- Cross-join the walk × as_of_dates with the filed_date visibility filter.
-- Each row = "this (company, filing, concept, period) relationship was
-- visible at this as_of_date." Filings filed after as_of_date are excluded.
bridge_rows AS (
    SELECT
        l.link_filing_concept_period_hk,
        l.hub_company_hk,
        l.hub_filing_hk,
        l.hub_concept_hk,
        l.link_company_filing_hk,
        l.period_end_date,
        l.fiscal_year,
        l.fiscal_period,
        a.as_of_date
    FROM link_walk l
    CROSS JOIN as_of a
    WHERE l.filed_date <= a.as_of_date
),

-- Compute the bridge surrogate hash + project final shape. SHA-256 chain
-- identical to every other warehouse hash column (Risk 4 single-key + Risk
-- 6 '||' composite delimiter). 4-component composite: hub_company_hk +
-- link_company_filing_hk + link_filing_concept_period_hk + as_of_date —
-- the link-side PKs uniquely identify the relationship instance; as_of_date
-- adds the snapshot dimension.
hashed AS (
    SELECT
        to_hex(sha256(to_utf8(
            CAST(hub_company_hk AS varchar) || '||' ||
            CAST(link_company_filing_hk AS varchar) || '||' ||
            CAST(link_filing_concept_period_hk AS varchar) || '||' ||
            CAST(as_of_date AS varchar)
        ))) AS bridge_company_concept_period_hk,
        hub_company_hk,
        hub_filing_hk,
        hub_concept_hk,
        link_company_filing_hk,
        link_filing_concept_period_hk,
        period_end_date,
        fiscal_year,
        fiscal_period,
        as_of_date,
        CAST(current_timestamp AT TIME ZONE 'UTC' AS timestamp(6)) AS load_datetime,
        'business_vault.bridge_company_concept_period' AS record_source
    FROM bridge_rows
)

SELECT * FROM hashed

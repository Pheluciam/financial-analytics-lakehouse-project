-- dbt/models/warehouse/sat_company_metadata.sql
--
-- Warehouse-layer Data Vault 2.0 satellite model — second satellite in
-- the project. Parent = hub_company (cik business key). Carries 1
-- company-level descriptive attribute (entity_name) observed in the
-- SEC EDGAR companyfacts JSON cover-page section. One row per company
-- on first load — 1:1 cardinality with hub_company.
--
-- Inherits the satellite pattern locked at Phase 2 session 6 from
-- sat_filing_metadata: SCD-2 NOT EXISTS anti-join on
-- latest-hashdiff-per-parent (LEARNINGS Risk 9, 2026-05-28),
-- COALESCE-sentinel hashdiff (Risk 8), dedicated single-column sat
-- hash key with composite natural PK enforced at test time (Risk 10),
-- DISTINCT collapse at source-side (Risk 11). Materially simpler model
-- body than session 6 because entityName is a top-level JSON field
-- exposed by the typed cover-page staging — no Jinja for-loop, no
-- CROSS JOIN UNNEST.
--
-- Forward-verify pass at Phase 2 session 7 kickoff surfaced an empirical
-- cardinality fact that the design-time calculation alone would have
-- missed (LEARNINGS Risk 13 candidate, banked 2026-05-28). The Bronze
-- raw-text table holds 101 rows / 100 distinct CIKs / 2 distinct
-- extract_dates / 100 distinct entityNames — one CIK has been
-- extracted twice on two different dates with the SAME entityName both
-- times. Reading staging directly without DISTINCT would have shipped
-- 101 satellite rows on first load, breaking the 1:1 parent-coverage
-- invariant with hub_company (100 rows). DISTINCT (cik, entity_name)
-- collapses cleanly to 100 since entity_name is consistent across the
-- duplicate extract. Cardinality probe artefact preserved in
-- DBT_PIPELINE.md section 8.14.
--
-- Source = stg_sec_edgar__companyfacts (typed cover-page columns —
-- cik, extract_date, entity_name). Same upstream staging model as
-- hub_company so parent and satellite share lineage symmetry. The
-- alternative source — stg_sec_edgar__companyfacts_raw + json_extract
-- on $.entityName — would yield identical row content but at the cost
-- of a json walk inside this model.
--
-- Hand-rolled per the Phase 2 session 3 close-amend lock — AutomateDV
-- does not officially support dbt-athena (LEARNINGS Risk 1, 2026-05-28),
-- so every DV2.0 model in this project is written in plain dbt-athena
-- SQL with no third-party DV2.0 macros. The SCD-2 insert-on-change
-- mechanic below is the hand-rolled equivalent of AutomateDV's sat
-- macro output for a standard non-multi-active satellite.
--
-- hashdiff function chain (LEARNINGS Risk 8, 2026-05-28). SHA-256 over
-- the COALESCE-sentinel-protected payload column. Single-column payload
-- means no '||' delimiter is required (delimiter defends against
-- multi-column concat ambiguity, not present here). COALESCE-to-'^^'
-- sentinel still applies as project standard defensive shield against
-- Trino's concat NULL propagation — even though entity_name is
-- reliably populated upstream per the Bronze openx SerDe contract
-- (NULL entity_name fails fast at extract time, not here).
--
-- sat_company_metadata_hk (LEARNINGS Risk 10, 2026-05-28). Dedicated
-- single-column satellite hash key over (hub_company_hk || '||' ||
-- load_datetime) — keeps the warehouse-layer surface visually
-- consistent (every hub/link/sat carries a single-column hash key as
-- unique_key). The composite natural PK (hub_company_hk, load_datetime)
-- is enforced at test time via dbt_utils.unique_combination_of_columns
-- in _models.yml, not at runtime via the unique_key list.
--
-- Materialization defaults (incremental + iceberg + parquet +
-- on_schema_change=ignore) live in dbt_project.yml under the warehouse
-- block. on_schema_change=ignore is MANDATORY for satellites per Risk 2
-- (Iceberg merge + on_schema_change=sync_all_columns has a known
-- duplicate-insertion bug in dbt-glue issue #571). Schema evolution on
-- satellites is handled via full-refresh, never via on_schema_change.
-- Only the per-model unique_key is set here.
--
-- Walkthrough: DBT_PIPELINE.md section 8.

{{
  config(
    unique_key='sat_company_metadata_hk'
  )
}}

WITH source AS (
    -- Universe filter (Phase 5 session 4 Fix-all, 2026-06-01). INNER JOIN
    -- to sp100_company_sector seed scopes the warehouse to the 107 S&P 100
    -- CIKs. Mirrors hub_company.sql's universe contract — keeps sat
    -- company-metadata rows aligned with the universe-scoped hub_company
    -- so the relationships test passes from sat back to hub.
    SELECT s.cik, s.entity_name
    FROM {{ ref('stg_sec_edgar__companyfacts') }} s
    INNER JOIN {{ ref('sp100_company_sector') }} u ON u.cik = s.cik
),

-- DISTINCT collapse per Risk 11 (carry-forward from session 6) and
-- Risk 13 candidate (cardinality drift across extract_dates surfaced
-- at the session 7 forward-verify pass). Bronze has 101 rows / 100
-- distinct CIKs / 2 distinct extract_dates; the duplicate CIK has the
-- same entity_name in both extract rows so DISTINCT (cik, entity_name)
-- collapses to 100 rows. Future loads bringing a renamed entity_name
-- for an existing CIK would produce a new DISTINCT tuple — SCD-2
-- anti-join below would then correctly fire and insert a new row.
distinct_companies AS (
    SELECT DISTINCT
        cik,
        entity_name
    FROM source
    WHERE cik IS NOT NULL
),

-- Compute hub_company_hk (parent FK) + load_datetime + record_source
-- alongside the payload. Single load_datetime expression evaluated
-- once per query so every row in this batch shares it — DV2.0
-- contract: a "batch" of changes lands with one consistent LDTS.
-- hub_company_hk hash chain matches hub_company.sql exactly so FK
-- joins are valid by construction.
enriched AS (
    SELECT
        to_hex(sha256(to_utf8(CAST(cik AS varchar)))) AS hub_company_hk,
        cik,
        entity_name,
        CAST(current_timestamp AT TIME ZONE 'UTC' AS timestamp(6)) AS load_datetime,
        'sec_edgar.companyfacts' AS record_source
    FROM distinct_companies
),

-- hashdiff over COALESCE-sentinel-protected payload. SHA-256 chain
-- identical to every other hash in the project (Risk 4). Single
-- payload column means no '||' delimiter required — the delimiter
-- defends against multi-column concat ambiguity, not present here.
-- '^^' sentinel still applies as project standard defensive shield.
hashed AS (
    SELECT
        to_hex(sha256(to_utf8(
            CAST(hub_company_hk AS varchar) || '||' ||
            CAST(load_datetime AS varchar)
        ))) AS sat_company_metadata_hk,
        to_hex(sha256(to_utf8(
            COALESCE(CAST(entity_name AS varchar), '^^')
        ))) AS hashdiff,
        hub_company_hk,
        cik,
        entity_name,
        load_datetime,
        record_source
    FROM enriched
)

SELECT * FROM hashed inbound
{% if is_incremental() %}
-- SCD-2 insert-on-change anti-join filter (Risk 9). The subquery
-- computes the latest stored hashdiff per parent_hk via ROW_NUMBER
-- ordered by load_datetime DESC. The NOT EXISTS clause excludes
-- inbound rows whose hashdiff matches the latest stored hashdiff for
-- the same parent — i.e. unchanged payloads are dropped. Inbound rows
-- pass through to merge if (a) no existing row for that parent OR (b)
-- the inbound hashdiff differs from the latest stored hashdiff.
-- Engine-level merge then inserts the new SCD-2 row with the new
-- load_datetime, preserving every prior row for audit lineage.
WHERE NOT EXISTS (
    SELECT 1
    FROM (
        SELECT
            hub_company_hk,
            hashdiff,
            ROW_NUMBER() OVER (
                PARTITION BY hub_company_hk
                ORDER BY load_datetime DESC
            ) AS rn
        FROM {{ this }}
    ) latest
    WHERE latest.hub_company_hk = inbound.hub_company_hk
      AND latest.hashdiff = inbound.hashdiff
      AND latest.rn = 1
)
{% endif %}

-- dbt/models/warehouse/hub_company.sql
--
-- Warehouse-layer Data Vault 2.0 hub model — first hub in the project.
-- Records the immutable first-observed instance of each unique company
-- (business key = SEC Central Index Key) across the SEC EDGAR source.
--
-- Hand-rolled per the Phase 2 session 3 close-amend lock — AutomateDV
-- does not officially support dbt-athena (LEARNINGS Risk 1, 2026-05-28),
-- so every DV2.0 model in this project is written in plain dbt-athena
-- SQL with no third-party DV2.0 macros.
--
-- Hash key: SHA-256 of the business key (cik). Verified at Phase 2
-- session 4 kickoff forward-verify pass (LEARNINGS Risk 4, 2026-05-28)
-- against Scalefree + AutomateDV docs — SHA-256 is the higher-strength
-- option vs MD5 default, picked here for portfolio depth. Collision rate
-- is theoretical at S&P 100 scale (100 rows); the choice signals
-- deliberate engineering, not default acceptance.
--
-- Insert-only semantics: dbt-athena's default Iceberg merge OVERWRITES
-- matched rows, which would silently corrupt the DV2.0 audit lineage
-- on every refresh (LEARNINGS Risk 5, 2026-05-28). The is_incremental
-- block below filters source to only-new hash keys before the merge,
-- so matched rows never exist at engine level. unique_key acts as a
-- belt-and-braces safety net.
--
-- Source: stg_sec_edgar__companyfacts (one row per cik per extract_date,
-- 100 distinct CIKs from the S&P 100 universe). Reading from staging
-- rather than int_sec_edgar__concepts_canonical so the hub contains
-- every CIK that landed in Bronze — independent of whether a given
-- company reported any in-scope XBRL concepts.
--
-- Materialization defaults (incremental + iceberg + parquet +
-- on_schema_change=ignore) live in dbt_project.yml under the warehouse
-- block. Only the per-model unique_key is set here.
--
-- Walkthrough: DBT_PIPELINE.md section 8.

{{
  config(
    unique_key='hub_company_hk'
  )
}}

WITH source AS (
    SELECT DISTINCT cik
    FROM {{ ref('stg_sec_edgar__companyfacts') }}
),

hashed AS (
    SELECT
        to_hex(sha256(to_utf8(CAST(cik AS varchar)))) AS hub_company_hk,
        cik,
        CAST(current_timestamp AT TIME ZONE 'UTC' AS timestamp(6)) AS load_datetime,
        'sec_edgar.companyfacts' AS record_source
    FROM source
)

SELECT * FROM hashed
{% if is_incremental() %}
WHERE hub_company_hk NOT IN (SELECT hub_company_hk FROM {{ this }})
{% endif %}

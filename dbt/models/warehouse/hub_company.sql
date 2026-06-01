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
-- Source: stg_sec_edgar__companyfacts (one row per cik per extract_date)
-- INNER JOINed to sp100_company_sector seed (Phase 5 session 4 Fix-all,
-- 2026-06-01) to scope the hub to the 107 S&P 100 seed CIKs. Audit 1
-- A1.2 surfaced 8 Bronze orphans (AIG, CVS, GD, LMT, MET, PLTR, SPG, UBER)
-- that landed in Bronze via prior backfills but are not in the
-- 2025-12-31 seed snapshot — they propagated downstream into all 4 marts
-- (115 = 107 seed + 8 orphans). The seed JOIN at the hub layer drops
-- them cleanly without removing data from Bronze, restoring the mart
-- universe to the documented 107-CIK S&P 100 surface.
--
-- Architectural decision: filter at the hub rather than at each mart.
-- Hub-layer universe is the single source of truth for "which companies
-- belong in this warehouse"; mart-layer filters duplicate the contract
-- per-mart and drift over time. Bronze is preserved as-is so future
-- universe expansions (e.g. S&P 500 build) are a seed update, not a
-- backfill rerun.
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
    -- Universe-filtered source. INNER JOIN to sp100_company_sector by cik
    -- restricts the hub to the 107 seed CIKs. Any CIK present in Bronze
    -- but absent from the seed (the 8 Audit 1 A1.2 orphans) is dropped
    -- here before hash computation, so it never enters the warehouse.
    SELECT DISTINCT s.cik
    FROM {{ ref('stg_sec_edgar__companyfacts') }} s
    INNER JOIN {{ ref('sp100_company_sector') }} u
        ON u.cik = s.cik
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

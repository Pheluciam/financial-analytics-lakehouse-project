-- Staging model: SEC EDGAR companyfacts RAW (full-JSON-as-text) source pass-through.
--
-- Phase 2 session 2 deliverable. The companion to stg_sec_edgar__companyfacts.sql —
-- both staging models read the same physical S3 files via two different
-- Bronze Athena tables. This one exposes the full JSON body as a single
-- text column so the intermediate layer can json_extract_* against it for
-- the heterogeneous XBRL concept extraction. The other staging model exposes
-- the typed cover-page columns (entity_name).
--
-- Materialization: view (per dbt_project.yml staging default — no S3 writes,
-- recompute on every read against the Bronze JSON files).
--
-- Walkthrough: DBT_PIPELINE.md section 7.

WITH source AS (
    SELECT * FROM {{ source('bronze', 'sec_edgar_companyfacts_raw') }}
),

renamed AS (
    SELECT
        -- 10-digit zero-padded CIK from the Hive-style partition key
        cik,

        -- extract_date arrives as a string from partition projection
        -- (Athena's type=date partition projection emits string values
        -- in the configured yyyy-MM-dd format). Cast to real DATE here
        -- so downstream intermediate/warehouse models get a typed column.
        CAST(extract_date AS DATE) AS extract_date,

        -- Full JSON file body as text. The intermediate model uses
        -- json_extract_scalar(json_text, '$.facts.us-gaap.Revenues.units.USD[0].val')
        -- (and similar) to pull XBRL concept values out of the nested
        -- structure.
        json_text
    FROM source
)

SELECT * FROM renamed

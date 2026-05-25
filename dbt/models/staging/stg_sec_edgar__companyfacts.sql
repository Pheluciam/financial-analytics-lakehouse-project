-- Staging model: SEC EDGAR companyfacts source pass-through.
--
-- Phase 2 session 1 minimum-viable scope: rename + retype only. The
-- JSON heterogeneity work (XBRL canonical-concept reconciliation —
-- Revenues / SalesRevenueNet / Revenue collapsing to a single canonical
-- concept) belongs in intermediate, not here. Staging's job is making
-- Bronze accessible as a clean, well-typed dbt model — nothing more.
--
-- Materialization: view (per dbt_project.yml staging default — no S3
-- writes, recompute on every read against the Bronze JSON files).
--
-- Walkthrough: DBT_PIPELINE.md.

WITH source AS (
    SELECT * FROM {{ source('bronze', 'sec_edgar_companyfacts') }}
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

        -- entityname is the openx JsonSerDe-mapped column name from
        -- the JSON entityName field. Rename to snake_case for project
        -- consistency. NULL-safe — Bronze DDL has ignore.malformed.json
        -- = false so any row with a missing entityName fails fast at
        -- extract time, not here.
        entityname AS entity_name
    FROM source
)

SELECT * FROM renamed

-- dbt/models/business_vault/dim_as_of_dates.sql
--
-- Business Vault as-of-dates spine — the input to every PIT and Bridge
-- in the project. Defines the list of snapshot timestamps the canonical
-- DV2.0 query-helpers resolve "what was visible at" for.
--
-- Cardinality lock (LEARNINGS Risk 21, 2026-05-29). 10 rows = fiscal
-- year-end timestamps spanning 2016-12-31 through 2025-12-31. Picked
-- over quarter-end (~38 rows → 3.4M-row PIT) and current-only (1 row →
-- no multi-snapshot demonstration). Fiscal-year-end matches the natural
-- mart-time grain for Phase 4's mart_pl_trend (annual P&L over 10 years)
-- and mart_peer_benchmark (annual peer comparison) consumption.
--
-- Temporal anchor note (LEARNINGS Risk 23, 2026-05-29). These dates are
-- consumed by pit_link_filing_concept_period and bridge_company_concept_period
-- against the SEC filing's filed_date (from sat_filing_metadata) — NOT
-- against load_datetime. Project-specific deviation: load_datetime here
-- captures ingestion-time (dbt-run wall clock = May 2026 for every row),
-- not observation-time. Filing-date filtering preserves the canonical
-- PIT/Bridge multi-snapshot mechanic while resolving meaningful data
-- across the 10-year demonstrative horizon.
--
-- Materialization: plain table (Iceberg/Parquet) — the list is static
-- per project lifecycle; every dbt run rebuilds cheaply. Layer defaults
-- in dbt_project.yml business_vault block.
--
-- Walkthrough: DBT_PIPELINE.md section 8.22.

WITH year_ends AS (
    SELECT * FROM (VALUES
        (DATE '2016-12-31'),
        (DATE '2017-12-31'),
        (DATE '2018-12-31'),
        (DATE '2019-12-31'),
        (DATE '2020-12-31'),
        (DATE '2021-12-31'),
        (DATE '2022-12-31'),
        (DATE '2023-12-31'),
        (DATE '2024-12-31'),
        (DATE '2025-12-31')
    ) AS t(as_of_date)
)

SELECT
    as_of_date,
    CAST(as_of_date AS timestamp(6)) AS as_of_datetime,
    EXTRACT(YEAR FROM as_of_date) AS fiscal_year_end,
    CAST(current_timestamp AT TIME ZONE 'UTC' AS timestamp(6)) AS load_datetime,
    'business_vault.dim_as_of_dates' AS record_source
FROM year_ends

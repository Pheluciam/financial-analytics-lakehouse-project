-- dbt/models/warehouse/sat_filing_metadata.sql
--
-- Warehouse-layer Data Vault 2.0 satellite model — first satellite in the
-- project. Parent = hub_filing (accession_number business key). Carries
-- 2 filing-level descriptive attributes (form_type, filed_date) observed
-- in the SEC EDGAR companyfacts JSON. One row per filing — 1:1 cardinality
-- with hub_filing on first load.
--
-- Scope note (LEARNINGS Risk 12, 2026-05-28). The initial session 6
-- design carried 6 payload attributes including period_start_date,
-- period_end_date, fiscal_year, fiscal_period — but those are
-- per-period-instance attributes, not per-filing. A single 10-K
-- filing's accession_number appears across multiple period-instance
-- array entries inside each concept's units.USD array (comparatives:
-- current FY + 2 prior FYs in 10-K; current Q + YTD + prior-year same
-- in 10-Q). Per-instance attributes break the satellite's 1:1
-- parent-coverage-parity invariant. Trimmed scope at first-dbt-run-time
-- to the 2 truly filing-level attributes: form_type and filed_date.
-- The period/fiscal attributes belong on a future model class
-- (hub_period + link_filing_period, OR baked into sat_concept_value).
--
-- Hand-rolled per the Phase 2 session 3 close-amend lock — AutomateDV
-- does not officially support dbt-athena (LEARNINGS Risk 1, 2026-05-28),
-- so every DV2.0 model in this project is written in plain dbt-athena
-- SQL with no third-party DV2.0 macros. The SCD-2 insert-on-change
-- mechanic below is the hand-rolled equivalent of AutomateDV's sat macro
-- output for a standard non-multi-active satellite.
--
-- SCD-2 insert-on-change semantics (LEARNINGS Risk 9, 2026-05-28).
-- The natural DV2.0 satellite PK is (parent hash key, load_datetime).
-- Re-seeing an unchanged payload on a later extract must NOT insert a
-- new row; re-seeing a CHANGED payload must insert a new row with a new
-- load_datetime, preserving the prior row for audit lineage. The
-- source-side filter pattern that worked for hubs and links (NOT IN on
-- the model's own hash key) is wrong for satellites — it would exclude
-- every already-seen parent including parents whose payload genuinely
-- changed. The satellite filter is a NOT EXISTS anti-join against the
-- latest stored hashdiff per parent.
--
-- hashdiff function chain (LEARNINGS Risk 8, 2026-05-28). SHA-256 over
-- a COALESCE-sentinel-protected concat of the payload columns. Trino's
-- concat operator returns NULL on any NULL input — without COALESCE,
-- a single NULL payload column would resolve the whole hashdiff to NULL,
-- defeating change detection since NULL = NULL is false. Sentinel '^^'
-- is the AutomateDV ecosystem default. form_type and filed_date are
-- both reliably populated in companyfacts JSON, but the COALESCE pattern
-- is applied as a defensive standard since it's the project convention
-- for every future satellite hashdiff.
--
-- sat_filing_metadata_hk (LEARNINGS Risk 10, 2026-05-28). Dedicated
-- single-column satellite hash key over (hub_filing_hk || '||' ||
-- load_datetime) — keeps the warehouse-layer surface visually
-- consistent (every hub/link/sat carries a single-column hash key as
-- unique_key). The composite natural PK (hub_filing_hk, load_datetime)
-- is enforced at test time via dbt_utils.unique_combination_of_columns
-- in _models.yml, not at runtime via the unique_key list.
--
-- Source DISTINCT (LEARNINGS Risk 11, 2026-05-28). Every filing's
-- per-concept array entry in the companyfacts JSON carries identical
-- form_type and filed_date (filing-level metadata). Same accn appears
-- across all 8 in-scope concepts AND across multiple period instances
-- per concept; DISTINCT applied to (accession_number, form_type,
-- filed_date) tuple collapses to one row per filing.
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
    unique_key='sat_filing_metadata_hk'
  )
}}

{% set concepts = [
    'Revenues',
    'SalesRevenueNet',
    'RevenueFromContractWithCustomerExcludingAssessedTax',
    'RevenueFromContractWithCustomerIncludingAssessedTax',
    'NetIncomeLoss',
    'OperatingIncomeLoss',
    'GrossProfit',
    'CostOfRevenue',
    'Assets',
    'Liabilities',
    'StockholdersEquity',
    'CashAndCashEquivalentsAtCarryingValue',
    'NetCashProvidedByUsedInOperatingActivities'
] %}

WITH source AS (
    SELECT * FROM {{ ref('stg_sec_edgar__companyfacts_raw') }}
),

-- Per-concept UNNEST. Projects the parent business key (accession_number)
-- plus the 2 filing-level payload attributes. UNION ALL across the 8
-- in-scope concepts gives the full filing-metadata surface for the S&P
-- 100 universe. Identical UNNEST shape as hub_filing and
-- link_company_filing — only the projection list differs.
all_filing_attributes AS (
    {% for concept in concepts %}
    SELECT
        json_extract_scalar(period_json, '$.accn') AS accession_number,
        json_extract_scalar(period_json, '$.form') AS form_type,
        TRY_CAST(json_extract_scalar(period_json, '$.filed') AS DATE) AS filed_date
    FROM source
    CROSS JOIN UNNEST(
        CAST(
            json_extract(
                json_text,
                '$.facts["us-gaap"].{{ concept }}.units.USD'
            ) AS ARRAY(JSON)
        )
    ) AS t(period_json)
    {% if not loop.last %}
    UNION ALL
    {% endif %}
    {% endfor %}
),

-- DISTINCT collapse per Risk 11. Form_type and filed_date are
-- filing-level — every period-instance array entry across every
-- concept carries identical values for the same accn. DISTINCT
-- collapses the cross-product of (8 concepts) × (N period instances
-- per concept) down to one row per filing.
distinct_filings AS (
    SELECT DISTINCT
        accession_number,
        form_type,
        filed_date
    FROM all_filing_attributes
    WHERE accession_number IS NOT NULL
),

-- Compute hub_filing_hk (parent FK) + load_datetime + record_source
-- alongside the payload. Single load_datetime expression evaluated
-- once per query so every row in this batch shares it — DV2.0
-- contract: a "batch" of changes lands with one consistent LDTS.
enriched AS (
    SELECT
        to_hex(sha256(to_utf8(CAST(accession_number AS varchar)))) AS hub_filing_hk,
        accession_number,
        form_type,
        filed_date,
        CAST(current_timestamp AT TIME ZONE 'UTC' AS timestamp(6)) AS load_datetime,
        'sec_edgar.companyfacts' AS record_source
    FROM distinct_filings
),

-- hashdiff over COALESCE-sentinel-protected payload concat. SHA-256
-- chain identical to every other hash in the project (Risk 4). '^^'
-- sentinel + '||' delimiter combination is the AutomateDV ecosystem
-- default — neither character pair appears in any real attribute
-- value. Order of columns in the concat is part of the contract:
-- changing the order would change every hashdiff and re-insert every
-- row on next load.
hashed AS (
    SELECT
        to_hex(sha256(to_utf8(
            CAST(hub_filing_hk AS varchar) || '||' ||
            CAST(load_datetime AS varchar)
        ))) AS sat_filing_metadata_hk,
        to_hex(sha256(to_utf8(
            COALESCE(CAST(form_type AS varchar), '^^') || '||' ||
            COALESCE(CAST(filed_date AS varchar), '^^')
        ))) AS hashdiff,
        hub_filing_hk,
        accession_number,
        form_type,
        filed_date,
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
-- engine-level merge then inserts the new SCD-2 row with the new
-- load_datetime, preserving every prior row for audit lineage.
WHERE NOT EXISTS (
    SELECT 1
    FROM (
        SELECT
            hub_filing_hk,
            hashdiff,
            ROW_NUMBER() OVER (
                PARTITION BY hub_filing_hk
                ORDER BY load_datetime DESC
            ) AS rn
        FROM {{ this }}
    ) latest
    WHERE latest.hub_filing_hk = inbound.hub_filing_hk
      AND latest.hashdiff = inbound.hashdiff
      AND latest.rn = 1
)
{% endif %}

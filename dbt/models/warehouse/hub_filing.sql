-- dbt/models/warehouse/hub_filing.sql
--
-- Warehouse-layer Data Vault 2.0 hub model — second hub in the project.
-- Records the immutable first-observed instance of each unique SEC filing
-- (business key = accession_number) across the SEC EDGAR source.
--
-- Hand-rolled per the Phase 2 session 3 close-amend lock — AutomateDV
-- does not officially support dbt-athena (LEARNINGS Risk 1, 2026-05-28),
-- so every DV2.0 model in this project is written in plain dbt-athena
-- SQL with no third-party DV2.0 macros. Mirrors hub_company structurally;
-- only the source path + UNNEST pattern + business-key column differ.
--
-- Source: stg_sec_edgar__companyfacts_raw (full-JSON-as-text staging
-- model). Honors the session-4 lock that DV2.0 hubs source from the
-- rawest layer where the business key first appears (LEARNINGS Risk 7,
-- 2026-05-28). The model body Jinja-loops the same 8 in-scope XBRL
-- concepts as int_sec_edgar__concepts, UNNESTs the per-period arrays,
-- and projects accn DISTINCT. For the S&P 100 universe every meaningful
-- 10-K / 10-Q reports at least one of the 8 concepts so accession-number
-- coverage is universal in practice. Submissions-endpoint Phase 1
-- extract extension explicitly rejected at the forward-verify pass —
-- would have un-frozen Bronze mid-project for a marginal coverage gain.
--
-- Hash key: SHA-256 of the business key (accession_number). Function
-- chain identical to hub_company: to_hex(sha256(to_utf8(CAST(<bk> AS
-- varchar)))). The defensive CAST guards against future staging-side
-- type changes.
--
-- Insert-only semantics: same source-side is_incremental filter
-- pattern as hub_company. Re-seeing an already-loaded accession_number
-- on a subsequent extract excludes it from the source SELECT before
-- the engine reaches the merge — load_datetime + record_source on the
-- original row are immutable. unique_key acts as a belt-and-braces
-- engine-level safety net.
--
-- Materialization defaults (incremental + iceberg + parquet +
-- on_schema_change=ignore) live in dbt_project.yml under the warehouse
-- block. Only the per-model unique_key is set here.
--
-- Walkthrough: DBT_PIPELINE.md section 8.

{{
  config(
    unique_key='hub_filing_hk'
  )
}}

{% set concepts = [
    'Revenues',
    'SalesRevenueNet',
    'RevenueFromContractWithCustomerExcludingAssessedTax',
    'RevenueFromContractWithCustomerIncludingAssessedTax',
    'InterestAndDividendIncomeOperating',
    'NetIncomeLoss',
    'OperatingIncomeLoss',
    'GrossProfit',
    'CostOfRevenue',
    'CostOfGoodsAndServicesSold',
    'CostOfGoodsSold',
    'CostOfServices',
    'Assets',
    'Liabilities',
    'LiabilitiesAndStockholdersEquity',
    'StockholdersEquity',
    'StockholdersEquityIncludingPortionAttributableToNoncontrollingInterest',
    'MinorityInterest',
    'CashAndCashEquivalentsAtCarryingValue',
    'CashCashEquivalentsRestrictedCashAndRestrictedCashEquivalents',
    'NetCashProvidedByUsedInOperatingActivities'
] %}

WITH source AS (
    -- Universe filter (Phase 5 session 4 Fix-all, 2026-06-01). INNER JOIN
    -- to sp100_company_sector seed scopes the warehouse to the 107 S&P 100
    -- CIKs. Mirrors hub_company.sql's universe contract. Drops 8 Bronze
    -- orphan CIKs (AIG/CVS/GD/LMT/MET/PLTR/SPG/UBER) — their accession
    -- numbers never enter hub_filing so the downstream link/sat FK
    -- closure to hub_filing remains intact.
    SELECT s.*
    FROM {{ ref('stg_sec_edgar__companyfacts_raw') }} s
    INNER JOIN {{ ref('sp100_company_sector') }} u ON u.cik = s.cik
),

-- Per-concept UNNEST over the companyfacts JSON. Each concept's
-- units.USD array is flattened; we project only the accn field
-- since hub_filing only needs the business key. UNION ALL across
-- the 8 concepts gives the full accession-number surface for the
-- S&P 100 universe.
all_accessions AS (
    {% for concept in concepts %}
    SELECT
        json_extract_scalar(period_json, '$.accn') AS accession_number
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

distinct_accessions AS (
    SELECT DISTINCT accession_number
    FROM all_accessions
    WHERE accession_number IS NOT NULL
),

hashed AS (
    SELECT
        to_hex(sha256(to_utf8(CAST(accession_number AS varchar)))) AS hub_filing_hk,
        accession_number,
        CAST(current_timestamp AT TIME ZONE 'UTC' AS timestamp(6)) AS load_datetime,
        'sec_edgar.companyfacts' AS record_source
    FROM distinct_accessions
)

SELECT * FROM hashed
{% if is_incremental() %}
WHERE hub_filing_hk NOT IN (SELECT hub_filing_hk FROM {{ this }})
{% endif %}

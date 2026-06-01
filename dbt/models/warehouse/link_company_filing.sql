-- dbt/models/warehouse/link_company_filing.sql
--
-- Warehouse-layer Data Vault 2.0 link model — first link in the project.
-- Associates hub_company (cik business key) with hub_filing
-- (accession_number business key). One row per unique (cik,
-- accession_number) pair observed in the SEC EDGAR companyfacts JSON.
--
-- Hand-rolled per the Phase 2 session 3 close-amend lock (LEARNINGS
-- Risk 1, 2026-05-28). AutomateDV does not support dbt-athena; the
-- composite-hash construction below is the hand-rolled equivalent of
-- AutomateDV's t_link macro output for a two-hub link.
--
-- Composite hash key construction (LEARNINGS Risk 6, 2026-05-28).
-- The '||' delimiter is the AutomateDV ecosystem default for composite
-- key concatenation; picked over dbt_utils.generate_surrogate_key's
-- '-' delimiter which has a documented collision-on-hyphenated-inputs
-- failure mode (dbt-utils issue #1015). SEC EDGAR accession numbers
-- literally contain hyphens in positions 11 and 14, so '-' as a
-- delimiter would not be hash-safe here; '||' never appears in either
-- business-key value.
--
-- Insert-only semantics: same source-side is_incremental filter pattern
-- as hubs. Scalefree confirms links are pure append-only records of
-- every relationship ever observed — re-seeing the same (cik,
-- accession_number) pair on a later extract must NOT update
-- load_datetime + record_source. unique_key is the engine-level
-- belt-and-braces safety net.
--
-- Source: stg_sec_edgar__companyfacts_raw, via the same Jinja-loop
-- UNNEST pattern as hub_filing. Each (cik, accession_number) pair is
-- the natural cardinal unit of the relationship — one filing belongs
-- to exactly one filer; one filer files many filings.
--
-- Materialization defaults (incremental + iceberg + parquet +
-- on_schema_change=ignore) live in dbt_project.yml under the warehouse
-- block. Only the per-model unique_key is set here.
--
-- Walkthrough: DBT_PIPELINE.md section 8.

{{
  config(
    unique_key='link_company_filing_hk'
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
    -- CIKs. Mirrors hub_company.sql's universe contract — without this
    -- filter, orphan-CIK rows would carry hub_company_hk values not
    -- present in the universe-scoped hub_company, breaking the link's
    -- relationships test.
    SELECT s.*
    FROM {{ ref('stg_sec_edgar__companyfacts_raw') }} s
    INNER JOIN {{ ref('sp100_company_sector') }} u ON u.cik = s.cik
),

-- Per-concept UNNEST — cik comes from the partition key on source,
-- accession_number from the per-period accn field. Both projected;
-- DISTINCT applied downstream because the same (cik, accn) pair
-- repeats across every concept reported in that filing.
all_pairs AS (
    {% for concept in concepts %}
    SELECT
        cik,
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

distinct_pairs AS (
    SELECT DISTINCT cik, accession_number
    FROM all_pairs
    WHERE accession_number IS NOT NULL
),

-- Composite hash construction. The '||' delimiter is locked at
-- LEARNINGS Risk 6 (2026-05-28). Per-column CAST AS varchar guards
-- against future staging-side type changes silently breaking the hash.
-- Each FK hash uses the same single-key chain as its parent hub so
-- FK joins remain valid by construction.
hashed AS (
    SELECT
        to_hex(sha256(to_utf8(
            CAST(cik AS varchar) || '||' || CAST(accession_number AS varchar)
        ))) AS link_company_filing_hk,
        to_hex(sha256(to_utf8(CAST(cik AS varchar)))) AS hub_company_hk,
        to_hex(sha256(to_utf8(CAST(accession_number AS varchar)))) AS hub_filing_hk,
        cik,
        accession_number,
        CAST(current_timestamp AT TIME ZONE 'UTC' AS timestamp(6)) AS load_datetime,
        'sec_edgar.companyfacts' AS record_source
    FROM distinct_pairs
)

SELECT * FROM hashed
{% if is_incremental() %}
WHERE link_company_filing_hk NOT IN (SELECT link_company_filing_hk FROM {{ this }})
{% endif %}

-- Intermediate model: SEC EDGAR XBRL concept extraction (long-format).
--
-- Phase 2 session 2 deliverable — first intermediate model. Pulls a fixed
-- list of XBRL concept tag names out of the heterogeneous facts.us-gaap
-- nested structure in the Bronze raw-text JSON. One row per (cik,
-- concept_name, period) triple. Output is the long-format raw concept panel
-- that the canonical-concept reconciliation model (int_sec_edgar__concepts_canonical)
-- builds on top of, and which the Data Vault 2.0 satellites in the warehouse
-- layer ultimately consume.
--
-- Scope: 8 in-scope XBRL tag names, USD unit only. The 4 revenue tag variants
-- (Revenues, SalesRevenueNet, RevenueFromContractWithCustomerExcludingAssessedTax,
-- RevenueFromContractWithCustomerIncludingAssessedTax) all surface here as
-- distinct rows; the canonical-concept reconciliation model collapses them
-- to a single canonical 'revenue' name via the canonical_concepts_dictionary
-- seed. The other 4 concepts (NetIncomeLoss, Assets, Liabilities,
-- StockholdersEquity) are single canonical tags in US-GAAP for the S&P 100 —
-- they pass through to canonical names as identity mappings.
--
-- Pattern: Jinja for-loop UNION ALL over the concept list, with CROSS JOIN
-- UNNEST on json_extract → ARRAY(JSON) to flatten each concept's per-period
-- entries into rows. Companies that don't report a given concept naturally
-- contribute zero rows for that concept (UNNEST of a NULL array returns no
-- rows per Athena docs). NULLs are not synthesized for missing concepts.
--
-- Materialization: view (per dbt_project.yml intermediate default — recompute
-- on every read; cheap because all the heavy lifting is json_extract over a
-- view chain, and the raw Bronze JSON is the only scan).
--
-- Walkthrough: DBT_PIPELINE.md section 7.

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

extracted AS (
    {% for concept in concepts %}
    -- Per-concept extraction. json_extract returns the units.USD array as
    -- a JSON value; CAST to ARRAY(JSON) makes it iterable via UNNEST.
    -- Bracket notation '$.facts["us-gaap"]' is required because "us-gaap"
    -- contains a hyphen (dot notation would fail).
    SELECT
        cik,
        extract_date,
        '{{ concept }}' AS concept_name,
        'USD' AS unit,
        -- Period start date — the calendar date the period begins.
        -- Populated for flow concepts (income statement, cash flow);
        -- NULL for balance-sheet point-in-time concepts (Assets,
        -- Liabilities, StockholdersEquity) because SEC EDGAR omits
        -- start for instant-period facts. TRY_CAST handles both cases.
        TRY_CAST(json_extract_scalar(period_json, '$.start') AS DATE)
            AS period_start_date,
        -- Period end date — the calendar date the reported value applies to
        TRY_CAST(json_extract_scalar(period_json, '$.end') AS DATE)
            AS period_end_date,
        -- Form type: 10-K (annual), 10-Q (quarterly), 10-K/A (amended), etc.
        json_extract_scalar(period_json, '$.form') AS period_form_type,
        -- Fiscal year as reported by the company (may not match calendar year)
        TRY_CAST(json_extract_scalar(period_json, '$.fy') AS INTEGER)
            AS period_fiscal_year,
        -- Fiscal period code: FY = full year, Q1-Q3 = quarters, Q4 implied
        -- from FY minus Q1+Q2+Q3 by convention
        json_extract_scalar(period_json, '$.fp') AS period_fiscal_period,
        -- The actual reported value. DECIMAL(28,2) handles values up to
        -- ~10^26 — comfortably above Apple's ~$400B annual revenue scale.
        -- TRY_CAST guards against any malformed numeric in the source JSON.
        TRY_CAST(json_extract_scalar(period_json, '$.val') AS DECIMAL(28,2))
            AS value
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
)

SELECT * FROM extracted

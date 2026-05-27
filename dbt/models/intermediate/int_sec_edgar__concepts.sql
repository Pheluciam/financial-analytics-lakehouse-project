-- Intermediate model: SEC EDGAR XBRL concept extraction (long-format).
--
-- Phase 2 session 2 deliverable — first intermediate model. Pulls a fixed
-- shortlist of canonical-ish XBRL concepts out of the heterogeneous
-- facts.us-gaap nested structure in the Bronze raw-text JSON. One row per
-- (cik, concept_name, period) triple. Output is the long-format concept
-- panel that downstream models (canonical-concept reconciliation in a later
-- intermediate, then Data Vault 2.0 satellites in the warehouse layer)
-- build on top of.
--
-- Scope this session: 5 universally-reported concepts across the S&P 100,
-- USD unit only. The canonical-concept reconciliation step (collapsing
-- Revenues / SalesRevenueNet / Revenue → "revenue") is the NEXT intermediate
-- model — see DBT_PIPELINE.md section 7 for the full pipeline plan.
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
    'NetIncomeLoss',
    'Assets',
    'Liabilities',
    'StockholdersEquity'
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

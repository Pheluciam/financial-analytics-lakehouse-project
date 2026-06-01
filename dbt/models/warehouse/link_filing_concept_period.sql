-- dbt/models/warehouse/link_filing_concept_period.sql
--
-- Warehouse-layer Data Vault 2.0 link model — second link in the project,
-- 3-way standard link. Associates hub_company (cik) + hub_filing
-- (accession_number) + hub_concept (canonical_concept) with the per-period
-- observation grain (period_start_date, period_end_date, fiscal_year,
-- fiscal_period as descriptive link-level payload). One row per unique
-- (cik, accession_number, canonical_concept, period_start_date,
-- period_end_date, fiscal_year, fiscal_period) tuple observed in the SEC
-- EDGAR companyfacts JSON.
--
-- Hand-rolled per the Phase 2 session 3 close-amend lock (LEARNINGS Risk
-- 1, 2026-05-28). Mirrors link_company_filing structurally on the
-- composite-hash construction; only the participating hubs + the
-- descriptive link-level payload differ.
--
-- Standard link, NOT non-historized (LEARNINGS Risk 15, 2026-05-28).
-- Session 8 forward-verify pass cardinality probe 4 showed 9,335 (cik,
-- canonical_concept, period_end_date) groups with value disagreement
-- (31% of 29,815 groups) — but inspection revealed the disagreement
-- comes from period-grain ambiguity (Q3 vs YTD same end-date),
-- multi-filing same-period reporting, canonical-collapse double-
-- projection, and only a subset of true restatements. When
-- accession_number is added to the grain, each (cik, accession_number,
-- canonical_concept, period_*) tuple is unique-per-filing in SEC
-- reporting semantics. Restatements appear as NEW link rows because
-- they carry NEW accession_numbers — standard link captures this
-- naturally without needing the non-historized-link grain-shift pattern.
--
-- Period attributes as link-level payload, NOT separate hub_period
-- (LEARNINGS Risk 14, 2026-05-28). Session 8 forward-verify probe 3
-- showed 10,974 distinct period instances — transactional-grain
-- territory, not reference-hub territory. hub_period as a separate
-- model would be structurally redundant with the link's natural grain.
-- period_start_date / period_end_date / fiscal_year / fiscal_period
-- live here as descriptive payload on each link row.
--
-- DISTINCT collapse at post-canonical grain (LEARNINGS Risk 16,
-- 2026-05-28). The canonical-concept dictionary collapses 4 revenue
-- alias raw tags into canonical 'revenue'. Session 8 probe 2 showed
-- 93,869 total rows vs 87,928 distinct (cik, canonical_concept,
-- period_*) tuples — a 5,941-row gap from filings dual-reporting under
-- multiple revenue alias tags (common during ASC 606 transition years).
-- DISTINCT applied to the natural cardinal tuple BEFORE composite-hash
-- computation collapses these to one link row per genuine observation.
--
-- Composite hash key construction (LEARNINGS Risk 6, 2026-05-28). The
-- '||' delimiter is the AutomateDV ecosystem default for composite key
-- concatenation; never '-' (defeats dbt_utils.generate_surrogate_key
-- collision-on-hyphenated-inputs failure mode that bites accession
-- numbers). 7-column composite hash includes BOTH the parent business
-- keys (cik, accession_number, canonical_concept) AND the link-level
-- payload (period_start, period_end, fy, fp) — without the payload in
-- the hash, two genuinely-distinct observations sharing the same
-- (cik, accn, canonical) but different period instances would collide
-- to the same link hash. COALESCE-to-'^^' sentinel on period_start_date
-- (NULL for balance-sheet instant-period concepts) defends against
-- Trino's concat NULL propagation (LEARNINGS Risk 8).
--
-- Insert-only semantics: same source-side is_incremental filter pattern
-- as hubs + link_company_filing. NOT IN on link_filing_concept_period_hk.
-- unique_key is the engine-level belt-and-braces safety net.
--
-- Source: stg_sec_edgar__companyfacts_raw via the same Jinja-loop
-- UNNEST pattern as hub_filing + link_company_filing + sat_filing_metadata,
-- JOINed to canonical_concepts_dictionary inside the model body so the
-- canonical_concept column is available for the hash. Self-contained —
-- doesn't depend on int_sec_edgar__concepts_canonical exposing
-- accession_number (it doesn't; intermediate layer drops accn during
-- UNNEST).
--
-- Materialization defaults (incremental + iceberg + parquet +
-- on_schema_change=ignore) live in dbt_project.yml under the warehouse
-- block. Only the per-model unique_key is set here.
--
-- Walkthrough: DBT_PIPELINE.md section 8.

{{
  config(
    unique_key='link_filing_concept_period_hk'
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
    -- filter, orphan-CIK rows propagate ~15k rows with hub_company_hk
    -- values absent from hub_company, breaking the relationships test
    -- (Audit 1 A1.5 surfaced this orphan-propagation pattern across all
    -- 4 marts pre-Fix).
    SELECT s.*
    FROM {{ ref('stg_sec_edgar__companyfacts_raw') }} s
    INNER JOIN {{ ref('sp100_company_sector') }} u ON u.cik = s.cik
),

canonical_dict AS (
    SELECT concept_name, canonical_concept
    FROM {{ ref('canonical_concepts_dictionary') }}
),

-- Per-concept UNNEST. Projects cik (partition key on source),
-- accession_number + form_type via $.accn / $.form, and the full
-- period-instance tuple. concept_name attached as a literal per the
-- Jinja loop so the downstream JOIN to canonical_dict can map raw tag
-- → canonical. UNION ALL across 8 in-scope concepts.
all_observations AS (
    {% for concept in concepts %}
    SELECT
        cik,
        json_extract_scalar(period_json, '$.accn') AS accession_number,
        '{{ concept }}' AS concept_name,
        TRY_CAST(json_extract_scalar(period_json, '$.start') AS DATE) AS period_start_date,
        TRY_CAST(json_extract_scalar(period_json, '$.end') AS DATE) AS period_end_date,
        TRY_CAST(json_extract_scalar(period_json, '$.fy') AS INTEGER) AS fiscal_year,
        json_extract_scalar(period_json, '$.fp') AS fiscal_period
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

-- Join to canonical dictionary, adding canonical_concept column. INNER
-- JOIN by design — any raw tag not in the dictionary is excluded
-- (matches the int_sec_edgar__concepts_canonical contract).
canonical_observations AS (
    SELECT
        o.cik,
        o.accession_number,
        d.canonical_concept,
        o.period_start_date,
        o.period_end_date,
        o.fiscal_year,
        o.fiscal_period
    FROM all_observations o
    INNER JOIN canonical_dict d
        ON o.concept_name = d.concept_name
    WHERE o.accession_number IS NOT NULL
),

-- DISTINCT collapse at the post-canonical natural cardinal tuple per
-- Risk 16. Filings dual-reporting the same period under multiple
-- revenue alias tags produce duplicate-canonical rows; DISTINCT here
-- collapses them to one link row per genuine observation. Expected
-- collapse: ~93,869 pre-DISTINCT → ~87,928 + accession refinement
-- post-DISTINCT (probe 2 result).
distinct_observations AS (
    SELECT DISTINCT
        cik,
        accession_number,
        canonical_concept,
        period_start_date,
        period_end_date,
        fiscal_year,
        fiscal_period
    FROM canonical_observations
),

-- Composite hash construction. 7-column composite including period
-- payload because period attributes are part of the link grain (without
-- them the hash would collide across genuinely-distinct observations
-- for the same filing × concept). FK hash columns computed via the
-- single-key chain matching each parent hub so FK joins remain valid
-- by construction (hub_company.hub_company_hk, hub_filing.hub_filing_hk,
-- hub_concept.hub_concept_hk).
hashed AS (
    SELECT
        to_hex(sha256(to_utf8(
            CAST(cik AS varchar) || '||' ||
            CAST(accession_number AS varchar) || '||' ||
            CAST(canonical_concept AS varchar) || '||' ||
            COALESCE(CAST(period_start_date AS varchar), '^^') || '||' ||
            CAST(period_end_date AS varchar) || '||' ||
            COALESCE(CAST(fiscal_year AS varchar), '^^') || '||' ||
            COALESCE(fiscal_period, '^^')
        ))) AS link_filing_concept_period_hk,
        to_hex(sha256(to_utf8(CAST(cik AS varchar)))) AS hub_company_hk,
        to_hex(sha256(to_utf8(CAST(accession_number AS varchar)))) AS hub_filing_hk,
        to_hex(sha256(to_utf8(CAST(canonical_concept AS varchar)))) AS hub_concept_hk,
        cik,
        accession_number,
        canonical_concept,
        period_start_date,
        period_end_date,
        fiscal_year,
        fiscal_period,
        CAST(current_timestamp AT TIME ZONE 'UTC' AS timestamp(6)) AS load_datetime,
        'sec_edgar.companyfacts' AS record_source
    FROM distinct_observations
)

SELECT * FROM hashed
{% if is_incremental() %}
WHERE link_filing_concept_period_hk NOT IN (
    SELECT link_filing_concept_period_hk FROM {{ this }}
)
{% endif %}

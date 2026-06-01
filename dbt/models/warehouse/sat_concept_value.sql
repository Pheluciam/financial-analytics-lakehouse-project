-- dbt/models/warehouse/sat_concept_value.sql
--
-- Warehouse-layer Data Vault 2.0 satellite model — third satellite in
-- the project. Parent = link_filing_concept_period (the 3-way standard
-- link associating hub_company + hub_filing + hub_concept with the
-- per-period observation grain). Carries 2 payload attributes: value
-- (the actual XBRL fact value) and unit (always 'USD' within current
-- scope). 1:1 cardinality with the link parent on first load — every
-- link observation has exactly one sat row when no history has
-- accumulated.
--
-- The value satellite. This is the model that holds the actual
-- numerical SEC EDGAR financial data — Apple's $383.3B FY2023 revenue,
-- Microsoft's $211.9B, etc. Every downstream Gold mart in Phase 4
-- (mart_pl_trend, mart_peer_benchmark, mart_financial_health,
-- mart_growth_forecast) joins through link_filing_concept_period to
-- sat_concept_value to get the fact values.
--
-- Hand-rolled per Risk 1 (2026-05-28). Inherits the satellite pattern
-- locked at sessions 6 + 7 from sat_filing_metadata + sat_company_metadata:
-- SCD-2 NOT EXISTS anti-join on latest-hashdiff-per-parent (Risk 9),
-- COALESCE-sentinel hashdiff (Risk 8), dedicated single-column sat hash
-- key with composite natural PK enforced at test time (Risk 10).
--
-- Source-side strategy. Same UNNEST + JOIN-to-canonical-dict chain as
-- link_filing_concept_period (Risk 11 + Risk 16 carry-forward — DISTINCT
-- at the post-canonical natural cardinal tuple). Projects value + unit
-- alongside the link-grain columns. The same composite-hash chain as
-- link_filing_concept_period produces the FK link_filing_concept_period_hk
-- — by construction the sat's FK matches the link's PK because both
-- compute the same hash over the same 7-column composite.
--
-- Value disagreement collapse (Risk 16 sub-decision, RESOLVED Risk 45
-- + Risk 47 at Phase 4 session 2, 2026-05-30). When canonical-collapse
-- produces multiple rows for the same (cik, accession, canonical,
-- period) tuple with different actual reported values (the 5,941-row
-- gap in probe 2 — typically two revenue alias tags reporting different
-- numbers due to ASC 606 timing), pick MAX(value) — the analyst-correct
-- headline number — with the canonical_concept_tag_preference seed as
-- a deterministic tie-breaker between rows of equal value. ROW_NUMBER()
-- OVER (PARTITION BY natural cardinal tuple ORDER BY value DESC,
-- preference_rank ASC) keeps rn = 1. value DESC primary aligns with
-- analyst convention "company's publicly-announced top-line revenue is
-- the LARGEST reported figure across XBRL tag aliases for the same
-- period" — companies during ASC 606 transition often report a legacy
-- tag like Revenues alongside the new RevenueFromContractWithCustomer*
-- tag, and the legacy tag may carry a fractional value (Apple FY2019
-- Revenues = $64B vs RevenueFromContractWithCustomerExcludingAssessedTax
-- = $260B). preference_rank ASC secondary is used only for the
-- degenerate case where multiple tags happen to report the SAME value
-- — preserves auditability + determinism without driving the
-- analyst-facing selection. v1 of this fix (Risk 45, shipped earlier
-- this session) used preference_rank ASC PRIMARY; v1 surfaced the
-- ASC-606-transition antipattern in the PBI smoke test (Apple FY2019
-- rendered at $64B, WORSE than the original MIN=$70B) — banked as
-- Risk 47 + flipped to the present (v2) shape. Unit collapse via
-- MIN(unit) preserved — trivially returns 'USD' since staging filters
-- to USD-only.
--
-- hashdiff function chain (Risk 8). SHA-256 over COALESCE-sentinel-
-- protected concat of the 2 payload columns. value is reliably populated
-- (TRY_CAST filter at staging would have dropped malformed numerics);
-- unit is constant 'USD' at this scope; COALESCE pattern still applied
-- as defensive project standard. '||' delimiter between sentinels-or-
-- values inside the concat (Risk 6).
--
-- sat_concept_value_hk (Risk 10). Dedicated single-column satellite
-- hash key over (link_filing_concept_period_hk || '||' || load_datetime).
-- Keeps the hub/link/sat surface visually consistent (every warehouse-
-- layer model has one column named <class>_<entity>_hk that's its
-- single-column unique_key). Composite natural PK
-- (link_filing_concept_period_hk, load_datetime) enforced at test time
-- via dbt_utils.unique_combination_of_columns in _models.yml.
--
-- SCD-2 mechanic. Restatements in SEC XBRL typically come via NEW
-- accession_numbers (10-K/A amends original 10-K) — those produce NEW
-- link rows naturally because the composite link hash includes
-- accession_number. So the same-accession SCD-2 anti-join fires only on
-- the rare case where the SAME accession's facts get re-extracted with
-- a different value across extract_dates. Within current Bronze, the
-- 2-extract-dates / 1-duplicate-CIK case from session 7 gives the SCD-2
-- mechanic exactly 1 chance to fire on this load (and only if Apple's
-- 0000320193 wasn't the duplicate — Phil's session 7 probe didn't
-- name which CIK was extracted twice). The contract is valid regardless.
--
-- Materialization defaults (incremental + iceberg + parquet +
-- on_schema_change=ignore) live in dbt_project.yml under the warehouse
-- block. on_schema_change=ignore is MANDATORY for satellites per Risk 2
-- (Iceberg merge + on_schema_change=sync_all_columns has a known
-- duplicate-insertion bug in dbt-glue issue #571). Only the per-model
-- unique_key is set here.
--
-- Walkthrough: DBT_PIPELINE.md section 8.

{{
  config(
    unique_key='sat_concept_value_hk'
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
    -- CIKs. Mirrors hub_company.sql's universe contract — sat rows align
    -- with the universe-scoped link_filing_concept_period set, preserving
    -- FK closure on every relationships test downstream.
    SELECT s.*
    FROM {{ ref('stg_sec_edgar__companyfacts_raw') }} s
    INNER JOIN {{ ref('sp100_company_sector') }} u ON u.cik = s.cik
),

canonical_dict AS (
    SELECT concept_name, canonical_concept
    FROM {{ ref('canonical_concepts_dictionary') }}
),

-- Risk 45 resolution (Phase 4 session 2, 2026-05-30) + Risk 59 collapse_rule
-- override (Phase 5 session 4, 2026-06-01). Per-canonical ordered tag
-- preference list + collapse-rule override. INNER JOIN below in
-- preference_ranked enforces that every mapped tag in
-- canonical_concepts_dictionary has both a preference_rank and a
-- collapse_rule — a missing row drops the observation and surfaces as a
-- config gap downstream. Seed columns: canonical_concept, concept_name,
-- preference_rank (smallint, 1 = most-preferred), collapse_rule (varchar,
-- 'value_desc' or 'preference_rank_asc').
tag_preference AS (
    SELECT canonical_concept, concept_name, preference_rank, collapse_rule
    FROM {{ ref('canonical_concept_tag_preference') }}
),

-- Per-concept UNNEST — same shape as link_filing_concept_period but
-- additionally projects value + unit alongside the link-grain columns.
-- DECIMAL(28,2) for value handles ~$10^26 (comfortably above Apple's
-- ~$400B annual revenue scale); TRY_CAST guards against malformed
-- numerics in source JSON.
all_observations AS (
    {% for concept in concepts %}
    SELECT
        cik,
        json_extract_scalar(period_json, '$.accn') AS accession_number,
        '{{ concept }}' AS concept_name,
        TRY_CAST(json_extract_scalar(period_json, '$.start') AS DATE) AS period_start_date,
        TRY_CAST(json_extract_scalar(period_json, '$.end') AS DATE) AS period_end_date,
        TRY_CAST(json_extract_scalar(period_json, '$.fy') AS INTEGER) AS fiscal_year,
        json_extract_scalar(period_json, '$.fp') AS fiscal_period,
        TRY_CAST(json_extract_scalar(period_json, '$.val') AS DECIMAL(28,2)) AS value,
        'USD' AS unit
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

-- Canonical-mapped observations. concept_name retained (in contrast to
-- the pre-Risk-45 shape) so the downstream preferred-tag join can run
-- on the original source tag. concept_name is NOT projected to the
-- final mart-facing surface — dropped at collapsed_observations.
canonical_observations AS (
    SELECT
        o.cik,
        o.accession_number,
        o.concept_name,
        d.canonical_concept,
        o.period_start_date,
        o.period_end_date,
        o.fiscal_year,
        o.fiscal_period,
        o.value,
        o.unit
    FROM all_observations o
    INNER JOIN canonical_dict d
        ON o.concept_name = d.concept_name
    WHERE o.accession_number IS NOT NULL
      AND o.value IS NOT NULL
),

-- Attach preference_rank from the seed. INNER JOIN intentional — a
-- canonical-mapped tag with no preference_rank entry should fail loudly
-- as a missing-config signal rather than silently fall through.
preference_ranked AS (
    SELECT
        co.cik,
        co.accession_number,
        co.canonical_concept,
        co.period_start_date,
        co.period_end_date,
        co.fiscal_year,
        co.fiscal_period,
        co.value,
        co.unit,
        tp.preference_rank,
        tp.collapse_rule
    FROM canonical_observations co
    INNER JOIN tag_preference tp
        ON tp.canonical_concept = co.canonical_concept
        AND tp.concept_name = co.concept_name
),

-- Value disagreement collapse (Risk 45 + Risk 47 + Risk 59 resolution).
-- ROW_NUMBER over the natural cardinal tuple. ORDER BY dispatches on the
-- per-canonical collapse_rule from the seed:
--   - collapse_rule = 'value_desc' (Risk 47 default for revenue and most
--     other canonicals): largest value wins (analyst-correct headline),
--     preference_rank ASC is the deterministic tertiary tie-breaker
--     between equal values.
--   - collapse_rule = 'preference_rank_asc' (Risk 59 override for
--     cash_and_equivalents): preference_rank 1 wins regardless of value.
--     Bare CashAndCashEquivalentsAtCarryingValue (rank 1) beats the
--     Restricted superset variant (rank 2) when both are filed — heals
--     16 RESTRICTED_ONLY CIKs (banks + 4 non-banks) via fallback to
--     Restricted when bare is absent, without inflating the 45
--     RESTRICTED_LARGER CIKs by the restricted-cash component.
-- preference_rank ASC also appears as the universal tertiary tie-breaker
-- so the ORDER BY is total even when two CASE branches both return NULL.
-- See LEARNINGS Risk 47 (v1→v2 flip) and Risk 59 (collapse_rule override)
-- for the diagnosis loops.
collapsed_observations AS (
    SELECT
        cik,
        accession_number,
        canonical_concept,
        period_start_date,
        period_end_date,
        fiscal_year,
        fiscal_period,
        value,
        unit
    FROM (
        SELECT
            pr.*,
            ROW_NUMBER() OVER (
                PARTITION BY
                    pr.cik,
                    pr.accession_number,
                    pr.canonical_concept,
                    pr.period_start_date,
                    pr.period_end_date,
                    pr.fiscal_year,
                    pr.fiscal_period
                ORDER BY
                    CASE WHEN pr.collapse_rule = 'preference_rank_asc' THEN pr.preference_rank END ASC,
                    CASE WHEN pr.collapse_rule = 'value_desc'          THEN pr.value          END DESC,
                    pr.preference_rank ASC
            ) AS rn
        FROM preference_ranked pr
    ) ranked
    WHERE rn = 1
),

-- Compute parent link FK (link_filing_concept_period_hk) — same 7-column
-- composite hash chain as link_filing_concept_period so FK = link PK by
-- construction. Plus load_datetime + record_source.
enriched AS (
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
        cik,
        accession_number,
        canonical_concept,
        period_start_date,
        period_end_date,
        fiscal_year,
        fiscal_period,
        value,
        unit,
        CAST(current_timestamp AT TIME ZONE 'UTC' AS timestamp(6)) AS load_datetime,
        'sec_edgar.companyfacts' AS record_source
    FROM collapsed_observations
),

-- sat_concept_value_hk + hashdiff. Both follow the chained-hash project
-- standard (Risk 4 single-key SHA-256 chain). hashdiff over value + unit
-- with COALESCE-sentinel protection (Risk 8) and '||' delimiter (Risk 6).
hashed AS (
    SELECT
        to_hex(sha256(to_utf8(
            CAST(link_filing_concept_period_hk AS varchar) || '||' ||
            CAST(load_datetime AS varchar)
        ))) AS sat_concept_value_hk,
        to_hex(sha256(to_utf8(
            COALESCE(CAST(value AS varchar), '^^') || '||' ||
            COALESCE(CAST(unit AS varchar), '^^')
        ))) AS hashdiff,
        link_filing_concept_period_hk,
        cik,
        accession_number,
        canonical_concept,
        period_start_date,
        period_end_date,
        fiscal_year,
        fiscal_period,
        value,
        unit,
        load_datetime,
        record_source
    FROM enriched
)

SELECT * FROM hashed inbound
{% if is_incremental() %}
-- SCD-2 insert-on-change anti-join filter (Risk 9). Window function
-- picks each parent's latest stored row; NOT EXISTS excludes inbound
-- rows whose hashdiff matches the latest stored hashdiff for the same
-- parent. Inbound rows pass through to merge if (a) no existing row
-- for that parent OR (b) hashdiff differs from latest.
WHERE NOT EXISTS (
    SELECT 1
    FROM (
        SELECT
            link_filing_concept_period_hk,
            hashdiff,
            ROW_NUMBER() OVER (
                PARTITION BY link_filing_concept_period_hk
                ORDER BY load_datetime DESC
            ) AS rn
        FROM {{ this }}
    ) latest
    WHERE latest.link_filing_concept_period_hk = inbound.link_filing_concept_period_hk
      AND latest.hashdiff = inbound.hashdiff
      AND latest.rn = 1
)
{% endif %}

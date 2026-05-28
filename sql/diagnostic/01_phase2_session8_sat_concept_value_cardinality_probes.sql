-- sql/diagnostic/01_phase2_session8_sat_concept_value_cardinality_probes.sql
--
-- Phase 2 session 8 — empirical four-aggregate cardinality probes against
-- actual Bronze (via the intermediate canonical view) BEFORE writing any
-- sat_concept_value warehouse code. Carry-forward from Risk 13 (banked
-- 2026-05-28, Phase 2 session 7 forward-verify pass): every satellite
-- forward-verify pass includes an empirical cardinality probe against
-- actual data, not just function-chain doc-verify against authoritative
-- sources. Each probe earns its keep at design time, not first-run time.
--
-- Standalone re-runnable artefact — paste each query into Athena Query
-- Editor one at a time under workgroup wg_financial_analytics signed in
-- as phil-admin, region us-east-1.
--
-- Architectural context for the design call. Two candidates for the
-- period/fiscal attribute home on sat_concept_value were surfaced at the
-- session 8 kickoff: (a) hub_period + link_filing_period split (textbook
-- DV2.0 temporal-grain decomposition), (b) period attributes baked into
-- sat_concept_value as a multi-active satellite payload. The session 8
-- doc-verify pass (against scalefree.com/blog/data-vault/
-- multi-temporality-in-data-vault-2-0-part-1 + scalefree.com/blog/
-- modeling/the-value-of-non-historized-links) refined Option A's intent:
-- the canonical DV2.0 idiom for transactional observation data at source
-- granularity is the non-historized link pattern — period attributes
-- live as descriptive payload on the link itself, not on a separate
-- hub_period. hub_period only earns its keep if the period IS itself an
-- enterprise-wide reference entity (a fiscal calendar table). These
-- probes answer that question empirically.

----------------------------------------------------------------------
-- Probe 1 — hub_concept business-key cardinality.
--
-- Confirms the canonical hub_concept row-count expectation and that no
-- rogue concept tags survived canonical reconciliation. The 8 in-scope
-- raw XBRL tags collapse to fewer canonical concepts via the
-- canonical_concepts_dictionary seed (4 revenue alias tags → 1 canonical
-- 'revenue'; the other 4 in-scope tags map identity-style).
--
-- Result (2026-05-28, run by Phil):
--   total_rows                  = 93,869
--   distinct_canonical_concepts = 5
--   distinct_business_areas     = 2
--   canonical_concepts_seen     = [net_income, stockholders_equity,
--                                  liabilities, assets, revenue]
--
-- Implication: hub_concept lands at 5 rows. Small reference hub —
-- structurally correct as a separate DV2.0 hub even though small, since
-- canonical_concept is the natural BK that nhl_filing_concept_period
-- and any future concept-keyed satellites will FK to.
----------------------------------------------------------------------

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT canonical_concept) AS distinct_canonical_concepts,
    COUNT(DISTINCT business_area) AS distinct_business_areas,
    ARRAY_AGG(DISTINCT canonical_concept) AS canonical_concepts_seen
FROM financial_analytics_silver.int_sec_edgar__concepts_canonical;


----------------------------------------------------------------------
-- Probe 2 — nhl_filing_concept_period row count + parent grain check.
--
-- The four-aggregate signature (Risk 13 carry-forward) for the
-- non-historized link's first-load row count. extract_date count
-- surfaces whether Bronze cardinality drift (one CIK extracted on two
-- different dates) propagates into the canonical layer.
--
-- NOTE: the original probe-2 query used (cik || form_type) as the
-- "distinct filings" metric — misleading label, since that gave (cik,
-- form_type) pair count not distinct accession count. Corrected here to
-- use accession_number — but accession_number is not projected by
-- int_sec_edgar__concepts_canonical (only carried at the raw concepts
-- layer). For the corrected metric, source from int_sec_edgar__concepts
-- which projects (cik, concept_name, period_*) but not accession_number
-- either; OR re-derive via the staging UNNEST. The original run gave
-- 316 (cik × form_type) pairs — informative as form-type coverage but
-- not the distinct-filing count (which would land at ~6,551 = hub_filing
-- row count). Banked for the future refactor.
--
-- Result (2026-05-28, run by Phil, with original misleading "filings"
-- metric):
--   total_observation_rows     = 93,869
--   distinct_filings_seen      = 316     (actually = distinct (cik,
--                                          form_type) pairs)
--   distinct_extract_dates     = 2       (Bronze drift confirmed)
--   distinct_observation_tuples= 87,928
--
-- Implication: 5,941-row gap between total (93,869) and distinct
-- observation tuples (87,928) — canonical-revenue duplication. Filings
-- reporting the same period under both Revenues AND
-- RevenueFromContractWithCustomerExcludingAssessedTax produce two rows
-- in the canonical view with identical (cik, canonical_concept,
-- period_start, period_end, fy, fp). Design decision: sat_concept_value
-- parent grain at canonical-concept-and-period-instance (DISTINCT-
-- collapsed) — audit lineage to the raw tag survives in the staging
-- layer. nhl_filing_concept_period first-load row count = ~87,928 (an
-- estimate; the link includes accession_number which isn't in the
-- canonical view, so the actual nhl cardinality is computed from the
-- raw concepts layer + canonical dictionary join — minor refinement at
-- the design-call lockdown).
----------------------------------------------------------------------

SELECT
    COUNT(*) AS total_observation_rows,
    COUNT(DISTINCT cik || '|' || COALESCE(period_form_type, '^^'))
        AS distinct_cik_form_type_pairs,
    COUNT(DISTINCT extract_date) AS distinct_extract_dates,
    COUNT(DISTINCT
        cik || '|' ||
        canonical_concept || '|' ||
        COALESCE(CAST(period_start_date AS varchar), '^^') || '|' ||
        CAST(period_end_date AS varchar) || '|' ||
        COALESCE(CAST(period_fiscal_year AS varchar), '^^') || '|' ||
        COALESCE(period_fiscal_period, '^^')
    ) AS distinct_observation_tuples
FROM financial_analytics_silver.int_sec_edgar__concepts_canonical;


----------------------------------------------------------------------
-- Probe 3 — candidate hub_period business-key cardinality.
--
-- Deciding factor on whether hub_period earns its keep as a reference
-- hub or whether period attributes should live as descriptive payload
-- on nhl_filing_concept_period. If distinct period instances are in
-- the hundreds → hub_period is a small reference table and may be
-- worth modeling. If tens of thousands → the period instance is
-- essentially a per-filing artefact and belongs as link payload.
--
-- Result (2026-05-28, run by Phil):
--   distinct_period_instances       = 10,974
--   distinct_period_end_dates_only  = 972
--   distinct_fiscal_period_codes    = 6
--
-- Implication: hub_period DOES NOT earn its keep. 10,974 distinct period
-- instances is transactional-grain territory, not reference-hub
-- territory (a true reference-style fiscal-calendar hub would land at
-- ~40-50 rows = 10 years × ~4-6 fiscal-period codes). 972 distinct
-- period_end_dates and 6 distinct fiscal_period codes confirm the
-- granularity comes from the (period_start × period_end × fy × fp)
-- combination, not any single column. Adding hub_period just to satisfy
-- 1:1-sat aesthetics would add a structurally-redundant model.
-- DECISION: period attributes live as descriptive payload on
-- link_filing_concept_period (revised from NHL → standard link by
-- probe 4 — see below).
----------------------------------------------------------------------

SELECT
    COUNT(DISTINCT
        COALESCE(CAST(period_start_date AS varchar), '^^') || '|' ||
        CAST(period_end_date AS varchar) || '|' ||
        COALESCE(CAST(period_fiscal_year AS varchar), '^^') || '|' ||
        COALESCE(period_fiscal_period, '^^')
    ) AS distinct_period_instances,
    COUNT(DISTINCT period_end_date) AS distinct_period_end_dates_only,
    COUNT(DISTINCT period_fiscal_period) AS distinct_fiscal_period_codes
FROM financial_analytics_silver.int_sec_edgar__concepts_canonical;


----------------------------------------------------------------------
-- Probe 4 — restatement evidence check.
--
-- Confirms whether any (cik, canonical_concept, period_end_date) groups
-- have multiple distinct values in Bronze across extract_dates — proves
-- the SCD-2 sat_concept_value earns its keep, OR confirms restatements
-- are unobserved within current Bronze scope. Either result is
-- design-informing; the SCD-2 contract is correct for the future even
-- if no restatements have landed yet.
--
-- Result (2026-05-28, run by Phil):
--   total_observation_groups        = 29,815
--   groups_with_value_disagreement  = 9,335   (~31% of groups)
--   max_distinct_values_for_any_group = 10
--
-- Implication: the (cik, canonical_concept, period_end_date) tuple is
-- NOT a unique observation grain. The 9,335-group disagreement is a
-- mix of (a) period-grain ambiguity (same period_end matches 3-month
-- Q3 + 9-month YTD with different values), (b) multi-filing same-period
-- reporting (Q1 standalone + 10-K including Q1 + 10-K/A restated Q1),
-- (c) canonical-collapse double-projection (Revenues +
-- RevenueFromContractWithCustomer... reporting the same period with
-- slightly different values due to ASC 606 reclassification timing),
-- and (d) a subset of true restatements. Restatements come via NEW
-- accession_numbers, NOT same-accession value drift across extracts.
--
-- DECISION (Risk 16 candidate): link_filing_concept_period is a
-- STANDARD link, not a non-historized link. The unique observation
-- grain is (cik, accession_number, canonical_concept, period_start,
-- period_end, fy, fp) — each tuple is unique-per-filing by SEC
-- reporting semantics. Restatements naturally appear as NEW link rows
-- because they carry NEW accession_numbers; SCD-2 sat_concept_value
-- fires only on the rare same-accession value drift across extracts
-- (1 chance within current Bronze per the session 7 duplicate-extract
-- CIK). The non-historized link idiom is for relationship triples that
-- repeat with different transaction values (sales transactions per
-- customer-store-product) — SEC XBRL doesn't fit that pattern.
----------------------------------------------------------------------

WITH grouped AS (
    SELECT
        cik,
        canonical_concept,
        period_end_date,
        COUNT(DISTINCT value) AS distinct_values
    FROM financial_analytics_silver.int_sec_edgar__concepts_canonical
    WHERE value IS NOT NULL
    GROUP BY cik, canonical_concept, period_end_date
)
SELECT
    COUNT(*) AS total_observation_groups,
    SUM(CASE WHEN distinct_values > 1 THEN 1 ELSE 0 END)
        AS groups_with_value_disagreement,
    MAX(distinct_values) AS max_distinct_values_for_any_group
FROM grouped;

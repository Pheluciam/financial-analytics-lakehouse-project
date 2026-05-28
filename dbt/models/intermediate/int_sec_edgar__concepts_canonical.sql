-- Intermediate model: canonical-concept reconciliation.
--
-- Phase 2 session 3 deliverable. Reads the long-format raw concept panel
-- (int_sec_edgar__concepts) and joins to the canonical_concepts_dictionary
-- seed to add a canonical_concept column. The seed maps the 4 revenue
-- alias XBRL tag names (Revenues / SalesRevenueNet /
-- RevenueFromContractWithCustomerExcludingAssessedTax /
-- RevenueFromContractWithCustomerIncludingAssessedTax) to canonical
-- 'revenue', and identity-maps the other 4 in-scope concepts.
--
-- Why this layer exists. SEC XBRL filings use heterogeneous tag names for
-- the same underlying business concept — Apple, for example, reported
-- revenue under the bare Revenues tag through FY2018 then switched to
-- RevenueFromContractWithCustomerExcludingAssessedTax on ASC 606 adoption
-- in FY2019, per FASB's Revenue from Contracts with Customers Taxonomy
-- Implementation Guide. Downstream consumers (warehouse-layer satellites,
-- Gold marts, Power BI) want continuous time-series data keyed on a stable
-- canonical name. This model performs that semantic collapse via a
-- seed-driven lookup — no logic embedded in the model, the dictionary is
-- a version-controlled CSV.
--
-- INNER JOIN to the seed by design. Any concept_name not in the dictionary
-- is excluded from the output — this is the contract that ensures every
-- canonical_concept downstream is one of the curated set. To introduce a
-- new concept: add a row to the seed CSV AND add the tag to the concept
-- list in int_sec_edgar__concepts.sql; both ends extend together.
--
-- Materialization: view (per dbt_project.yml intermediate default).
--
-- Walkthrough: DBT_PIPELINE.md section 7.

WITH raw_panel AS (
    SELECT * FROM {{ ref('int_sec_edgar__concepts') }}
),

canonical_dictionary AS (
    SELECT
        concept_name,
        canonical_concept,
        business_area
    FROM {{ ref('canonical_concepts_dictionary') }}
),

canonical AS (
    SELECT
        r.cik,
        r.extract_date,
        r.concept_name,
        d.canonical_concept,
        d.business_area,
        r.unit,
        r.period_start_date,
        r.period_end_date,
        r.period_form_type,
        r.period_fiscal_year,
        r.period_fiscal_period,
        r.value
    FROM raw_panel r
    INNER JOIN canonical_dictionary d
        ON r.concept_name = d.concept_name
)

SELECT * FROM canonical

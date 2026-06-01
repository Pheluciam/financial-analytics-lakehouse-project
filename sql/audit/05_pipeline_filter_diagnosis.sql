-- sql/audit/05_pipeline_filter_diagnosis.sql
--
-- Phase 5 audit 4 of 10 — mart-pipeline filter diagnosis.
--
-- Goal: identify the root cause for the 22 RECENT_PIPELINE_BUG cells +
-- SPGI's total mart_financial_health FY2024 absence. AUDIT_FINDINGS.md
-- A3.10 + A3.11 classified these cells as "sat has rows at the FY2024
-- reporting window but the mart isn't surfacing them." The filter chain
-- in mart_financial_health.sql is the leading hypothesis:
--   line 138  — bridge filter: WHERE b.fiscal_period = 'FY'
--   line 190  — sat filter:    AND year(scv.period_end_date) IN
--                                  (scv.fiscal_year, scv.fiscal_year + 1)
--   lines 191-194 — Risk 48 conditional span filter:
--                   AND (canonical IN balance-sheet
--                        OR date_diff('day', period_start, period_end)
--                            BETWEEN 350 AND 380)
--
-- SPGI is the canonical test case. AUDIT_FINDINGS.md A3.11 found SPGI is
-- the ONLY CIK in the universe with <5 sat rows at (fiscal_year=2024,
-- fiscal_period='FY'). All 106 other CIKs have 5+ rows at that coordinate.
-- Whatever filter mechanism drops SPGI is likely dropping the same
-- canonicals for other CIKs at the same diagnostic surface.
--
-- Operating principle (locked Phase 5 session 2): no fixes during audit.
-- This file investigates only. Fix-all batches every fix at the end.
--
-- =============================================================================
-- SCHEMA REFERENCE — every column used in this file, ground-truthed against
-- the dbt model source SQL on 2026-06-01. Update when models change.
-- =============================================================================
--
-- financial_analytics_silver.stg_sec_edgar__companyfacts_raw       (view)
--   src: dbt/models/staging/stg_sec_edgar__companyfacts_raw.sql
--   cols: cik (string, 10-digit zero-padded),
--         extract_date (DATE),
--         json_text (string — full minified JSON file body)
--   NOTE: accession_number is NOT a column here; it lives inside json_text
--         at JSON path $.facts.us-gaap.<concept>.units.USD[i].accn and is
--         only extracted by sat_concept_value via json_extract_scalar.
--
-- financial_analytics_silver.sat_concept_value                     (iceberg sat)
--   src: dbt/models/warehouse/sat_concept_value.sql
--   cols (final SELECT): sat_concept_value_hk, hashdiff,
--         link_filing_concept_period_hk, cik, accession_number,
--         canonical_concept, period_start_date, period_end_date,
--         fiscal_year (INTEGER), fiscal_period (varchar),
--         value (DECIMAL(28,2)), unit, load_datetime, record_source
--
-- financial_analytics_silver.link_filing_concept_period            (iceberg link)
--   src: dbt/models/warehouse/link_filing_concept_period.sql
--   cols (final SELECT): link_filing_concept_period_hk, hub_company_hk,
--         hub_filing_hk, hub_concept_hk, cik, accession_number,
--         canonical_concept, period_start_date, period_end_date,
--         fiscal_year, fiscal_period, load_datetime, record_source
--
-- financial_analytics_silver.bridge_company_concept_period         (iceberg table)
--   src: dbt/models/business_vault/bridge_company_concept_period.sql
--   cols: bridge_company_concept_period_hk, hub_company_hk, hub_filing_hk,
--         hub_concept_hk, link_company_filing_hk,
--         link_filing_concept_period_hk, period_end_date, fiscal_year,
--         fiscal_period, as_of_date, load_datetime, record_source
--   NOTE: cik is NOT denormalized here. Filter via hub_company subquery
--         on hub_company_hk.
--
-- financial_analytics_silver.hub_company                           (iceberg hub)
--   src: dbt/models/warehouse/hub_company.sql
--   cols: hub_company_hk, cik, load_datetime, record_source
--
-- financial_analytics_silver.mart_financial_health                 (iceberg table)
--   src: dbt/models/marts/mart_financial_health.sql
--   cols: mart_financial_health_hk, cik, entity_name, as_of_date,
--         fiscal_year, period_end_date, revenue, gross_profit,
--         operating_income, net_income, assets, liabilities,
--         stockholders_equity, cash_and_equivalents, operating_cash_flow,
--         gross_margin, operating_margin, net_margin, return_on_assets,
--         return_on_equity, debt_to_equity, operating_cf_margin,
--         cash_to_assets, load_datetime, record_source
--   NOTE: fiscal_period is NOT a column on the mart — it is filtered to
--         'FY' at the bridge spine (mart_financial_health.sql line 138)
--         and not projected through.
--
-- =============================================================================
-- SPGI BUSINESS KEY — anchor for every query below
-- =============================================================================
-- cik = '0000064040' (S&P Global Inc., Financials sector)
-- Source-of-truth: dbt/seeds/sp100_company_sector.csv row 24.
--
-- =============================================================================
-- EXECUTION
-- =============================================================================
-- Athena Console, signed in as phil-admin, workgroup wg_financial_analytics,
-- us-east-1. One query at a time (Athena Console single-statement-per-Run).
-- =============================================================================


-- =============================================================================
-- A4.1 — SPGI complete trace at FY2024
-- =============================================================================
-- Walk the pipeline layer-by-layer following SPGI's FY2024 data. Reading
-- top-down (Bronze → sat → link → bridge → mart). The first layer where
-- SPGI's FY2024 row count materially drops vs the 106 other CIKs is
-- where the filter bug lives.
--
-- After A4.1.a-e land, A4.2-A4.5 are authored to extend the diagnosis
-- to the 22 RECENT_PIPELINE_BUG cells across the universe.


-- =====================================================
-- A4.1.a — SPGI presence in Bronze staging view.
-- =====================================================
-- Grain at this layer: one row per (cik, extract_date) where the JSON
-- file exists on S3.
--
-- Expected: bronze_row_count >= 1. SPGI was one of the 15 backfilled
-- CIKs this session (PROJECT_CONTEXT session 2026-06-01 log) — the
-- 2026-06-01 extract_date partition should hold one SPGI row.
--
-- Pass criterion: bronze_row_count >= 1. If 0, the backfill never
-- delivered SPGI to S3 and A4.1.b-e are moot until extract is re-run.
SELECT cik,
       COUNT(*) AS bronze_row_count,
       MIN(extract_date) AS first_extract_date,
       MAX(extract_date) AS latest_extract_date
FROM financial_analytics_silver.stg_sec_edgar__companyfacts_raw
WHERE cik = '0000064040'
GROUP BY cik;


-- =====================================================
-- A4.1.b — SPGI rows in sat_concept_value at fiscal_year = 2024,
--          BROKEN OUT by every fiscal_period code SPGI files under.
-- =====================================================
-- SEC EDGAR DERA-documented fiscal_period codes: 'FY' (annual 10-K),
-- 'Q1','Q2','Q3' (quarterly 10-Q), 'CY' (calendar year — used by some
-- filers whose fiscal year matches calendar year), 'H1'/'H2' (rare,
-- semi-annual). NOT trusting training to enumerate all codes — that's
-- exactly what this query investigates. No fp filter = we see whatever
-- codes SPGI actually files under.
--
-- The mart filter at mart_financial_health.sql line 138 drops everything
-- except fp='FY'. So:
--
--   fp='FY' rows >= 5     → SPGI does file FY-period; mart drop is NOT
--                          at line 138. Move to A4.1.c.
--   fp='FY' rows == 0,
--   fp='CY' or 'Q4' > 0  → SPGI files under a non-FY annual code.
--                          Mart filter at line 138 needs broadening.
--   fp='FY' rows 1-4
--   (partial)            → some canonicals file under FY, others elsewhere.
--                          Need per-canonical break (A4.2 follow-up).
--
-- distinct_canonicals reveals which of the 9 in-scope canonicals SPGI
-- actually files. MIN/MAX of period_end_date tells us the calendar window
-- SPGI's FY2024 period covers — SPGI fiscal year-end is calendar Dec 31
-- per their 10-K (verified externally), so period_end_date should be
-- 2024-12-31 for SPGI's FY2024.
SELECT fiscal_period,
       COUNT(*) AS row_count,
       COUNT(DISTINCT canonical_concept) AS distinct_canonicals,
       MIN(period_end_date) AS min_period_end,
       MAX(period_end_date) AS max_period_end
FROM financial_analytics_silver.sat_concept_value
WHERE cik = '0000064040'
  AND fiscal_year = 2024
GROUP BY fiscal_period
ORDER BY fiscal_period;


-- =====================================================
-- A4.1.c — SPGI rows in link_filing_concept_period at fiscal_year = 2024,
--          BROKEN OUT by fiscal_period.
-- =====================================================
-- Expected: same shape as A4.1.b (link and sat are 1:1 on first load,
-- per Risk 1 SCD-2 contract — sat NOT EXISTS anti-join only fires on
-- repeat extracts of the same accession with different values, which
-- hasn't happened yet in the current Bronze).
--
-- If link row count differs from sat row count at any fiscal_period,
-- that's a link-sat divergence to flag.
SELECT fiscal_period,
       COUNT(*) AS row_count,
       COUNT(DISTINCT canonical_concept) AS distinct_canonicals,
       MIN(period_end_date) AS min_period_end,
       MAX(period_end_date) AS max_period_end
FROM financial_analytics_silver.link_filing_concept_period
WHERE cik = '0000064040'
  AND fiscal_year = 2024
GROUP BY fiscal_period
ORDER BY fiscal_period;


-- =====================================================
-- A4.1.d — SPGI rows in bridge_company_concept_period at fiscal_year = 2024,
--          BROKEN OUT by fiscal_period, at the LATEST as_of_date snapshot.
-- =====================================================
-- bridge does NOT carry cik directly — filter via hub_company subquery
-- on hub_company_hk. Bridge IS keyed by as_of_date — pin to MAX(as_of_date)
-- so the comparison vs mart_financial_health is apples-to-apples (mart
-- consumers also look at latest snapshot).
--
-- Bridge is built directly from link with a filed_date <= as_of_date
-- visibility filter (bridge model line 123). If row count at latest
-- as_of_date drops vs A4.1.c, SPGI's 10-K filed_date is later than the
-- latest as_of_date in dim_as_of_dates. Unlikely (SPGI's FY2024 10-K
-- filed Feb 2025) but possible if dim_as_of_dates max is < Feb 2025.
WITH spgi_hub AS (
    SELECT hub_company_hk
    FROM financial_analytics_silver.hub_company
    WHERE cik = '0000064040'
),
bridge_latest_aod AS (
    SELECT MAX(as_of_date) AS d
    FROM financial_analytics_silver.bridge_company_concept_period
)
SELECT b.fiscal_period,
       COUNT(*) AS row_count,
       COUNT(DISTINCT b.link_filing_concept_period_hk) AS distinct_links,
       MIN(b.period_end_date) AS min_period_end,
       MAX(b.period_end_date) AS max_period_end
FROM financial_analytics_silver.bridge_company_concept_period b
INNER JOIN spgi_hub h ON h.hub_company_hk = b.hub_company_hk
WHERE b.fiscal_year = 2024
  AND b.as_of_date = (SELECT d FROM bridge_latest_aod)
GROUP BY b.fiscal_period
ORDER BY b.fiscal_period;


-- =====================================================
-- A4.1.e — SPGI rows in mart_financial_health, all fiscal_years.
-- =====================================================
-- The mart applies fiscal_period='FY' at the bridge_fy CTE
-- (mart_financial_health.sql line 138), so the mart output carries no
-- fiscal_period column. We compare row presence per fiscal_year to
-- determine:
--   (a) which years SPGI lands in the mart at all;
--   (b) whether FY2024 is the only missing year or part of a pattern.
--
-- Expected outcomes:
--   - row_count > 0 for some years      → SPGI does land in mart for
--                                          those years; FY2024 drop is
--                                          year-specific.
--   - row_count == 0 for every year     → SPGI's filter incompatibility
--                                          is chronic — multi-year fix
--                                          will heal historical too.
SELECT m.fiscal_year,
       COUNT(*) AS row_count,
       MIN(m.as_of_date) AS first_as_of_date,
       MAX(m.as_of_date) AS latest_as_of_date,
       MAX(m.revenue) AS sample_revenue,
       MAX(m.net_income) AS sample_net_income
FROM financial_analytics_silver.mart_financial_health m
WHERE m.cik = '0000064040'
GROUP BY m.fiscal_year
ORDER BY m.fiscal_year DESC;


-- =============================================================================
-- A4.2 / A4.3 / A4.4 / A4.5 — TO BE AUTHORED after A4.1 results land.
-- =============================================================================
-- A4.2 scope depends on which layer A4.1 identifies as the failure point.
--   Hypothesis A (fp filter): generalise A4.1.b across the 22 RECENT_
--     PIPELINE_BUG cells — count rows per fiscal_period across the cohort,
--     identify the non-'FY' codes the cells file under.
--   Hypothesis B (period span filter): test the date_diff BETWEEN 350 AND
--     380 boundary on the cohort, find filers using non-365-day fiscal
--     years (52/53-week retailers like Apple — though Apple's FY2024
--     does land in the mart, so this is the less likely hypothesis).
--   Hypothesis C (year(period_end) match filter): test fiscal-year vs
--     calendar-year-end alignment for the cohort.
--
-- A4.3 (passing-vs-failing fiscal_period distribution comparison),
-- A4.4 (root-cause categorisation), and A4.5 (minimal fix proposal)
-- queue after A4.2.
--
-- Operating principle reminder: A4.2-A4.5 are authored only after A4.1
-- evidence narrows the hypothesis space. Speculating the queries now
-- would scope-creep the audit. Stay in A4.1.

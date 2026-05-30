-- dbt/models/marts/mart_financial_health.sql
--
-- Gold-layer Financial Health mart — THIRD mart in the project, shipped
-- at Phase 4 session 3. Per-company annual ratios spanning the income
-- statement, balance sheet, and cash flow statement. Consumed downstream
-- by Power BI Desktop via the Amazon Athena ODBC v2 driver + Windows
-- System DSN "FinancialAnalyticsAthena" (Risk 39 prerequisite shipped
-- at Phase 4 session 1 kickoff).
--
-- THE RATIOS MART. Phase 4's third mart — the "how healthy is the
-- business" lens. Same 5-step BV+RV equi-join chain as mart_pl_trend +
-- mart_peer_benchmark, but the trailing CTE shape is fundamentally
-- different: instead of one row per (company, fiscal_year, canonical),
-- this mart is one row per (company, fiscal_year) and pivots the
-- canonical values onto a single row as multi-canonical columns. The
-- ratios are then derived COLUMN expressions over the pivoted base.
-- Cousin marts: mart_pl_trend (income statement trend), mart_peer_benchmark
-- (cross-company peer benchmarking), mart_growth_forecast (forecasts —
-- session 4).
--
-- Grain. Composite (cik, as_of_date, fiscal_year) — DIFFERENT from the
-- two prior marts. mart_pl_trend and mart_peer_benchmark carry
-- canonical_concept in the grain because each row's value column is a
-- single canonical's reported value. mart_financial_health PIVOTS the
-- canonical values onto a single row (revenue, gross_profit,
-- operating_income, net_income, assets, liabilities, stockholders_equity,
-- cash_and_equivalents, operating_cash_flow are all COLUMNS), so each
-- row carries one fiscal-year snapshot per company across all in-scope
-- canonicals + derived ratios. as_of_date retained in the grain (same
-- BV-architectural rationale as the prior 2 marts).
--
-- Canonical concept filter. WHERE canonical_concept IN ('revenue',
-- 'gross_profit', 'operating_income', 'net_income', 'assets',
-- 'liabilities', 'stockholders_equity', 'cash_and_equivalents',
-- 'operating_cash_flow'). 9 canonicals span income statement (5),
-- balance sheet (3), cash flow statement (1) — the surface area needed
-- to compute the 8 ratios projected below. The Phase 4 session 3
-- canonical seed expansion (OperatingIncomeLoss, GrossProfit,
-- CostOfRevenue, CashAndCashEquivalentsAtCarryingValue,
-- NetCashProvidedByUsedInOperatingActivities) is what makes this mart
-- possible — pre-session-3, canonical_concepts_dictionary only covered
-- revenue + net_income + assets + liabilities + stockholders_equity.
-- CostOfRevenue is seeded for completeness but not consumed here
-- (gross_profit / revenue gives gross margin directly).
--
-- Annual filter. WHERE fiscal_period = 'FY' (same rationale as
-- mart_pl_trend + mart_peer_benchmark — analyst-conventional annual
-- snapshot view).
--
-- Derived ratios. 8 ratios projected as columns:
--   gross_margin            = gross_profit / revenue
--   operating_margin        = operating_income / revenue
--   net_margin              = net_income / revenue
--   return_on_assets        = net_income / assets
--   return_on_equity        = net_income / stockholders_equity
--   debt_to_equity          = liabilities / stockholders_equity
--   operating_cf_margin     = operating_cash_flow / revenue
--   cash_to_assets          = cash_and_equivalents / assets
-- NULLIF guards every denominator — a zero or NULL denominator produces
-- a NULL ratio rather than a divide-by-zero error. Some companies don't
-- report all canonicals (banks rarely report GrossProfit, REITs rarely
-- report OperatingCashFlow under this tag) — NULL ratios surface that
-- gap honestly rather than silently filling zero. PBI consumers handle
-- NULL via filter or aggregation defaults.
--
-- Caveat on debt_to_equity. The classic Debt-to-Equity ratio uses
-- LongTermDebt + ShortTermDebt as the numerator, not total Liabilities.
-- This mart's debt_to_equity is the simpler liabilities/equity
-- approximation — what some literature calls the "leverage ratio." A
-- separate true LongTermDebt-based debt_to_equity is a deferred future
-- enhancement when LongTermDebt + ShortTermDebt canonicals land in
-- canonical_concepts_dictionary. Documented for PBI consumers.
--
-- SEC income-statement comparatives dedup (LEARNINGS Risk 42 carry-
-- forward). Same ROW_NUMBER() OVER (PARTITION BY mart grain + canonical
-- ORDER BY accession_number DESC) dedup mechanic applied in the deduped
-- CTE — keeps the latest filing's value per (cik, as_of_date, fiscal_year,
-- canonical_concept) tuple. Dedup runs PER CANONICAL because the pivot
-- step needs one value per (grain, canonical), not one row per (grain).
-- The pivot then collapses on (cik, as_of_date, fiscal_year, period_end_date)
-- and emits MAX(CASE WHEN canonical = X THEN value END) for each in-
-- scope canonical.
--
-- Risk 48 intra-accession period-chunk filter — per-concept-type
-- conditional, carry-forward from mart_peer_benchmark. Balance-sheet
-- canonicals (assets, liabilities, stockholders_equity,
-- cash_and_equivalents) report as point-in-time observations with
-- period_start_date NULL or = period_end_date, so the IS span filter
-- (350-380 days) MUST be conditional or the entire balance-sheet
-- surface drops. Conditional structure: IF canonical IN (5 IS + CF
-- canonicals) THEN span filter applies; ELSE (4 BS canonicals) only
-- the year(period_end) ∈ (fy, fy+1) filter applies.
--
-- Surrogate PK. mart_financial_health_hk = SHA-256 over the 3-column
-- composite grain (cik || '||' || as_of_date || '||' || fiscal_year),
-- matching the hash-chain convention of the prior 2 marts.
--
-- Entity descriptor. entity_name from sat_company_metadata — consistent
-- with the prior 2 marts.
--
-- JOIN topology. Identical 5-step equi-join chain over BV + RV as the
-- prior 2 marts, then a pivot + ratios CTE chain:
--   1. bridge_company_concept_period (base) — filter to fiscal_period = 'FY'
--   2. → pit_link_filing_concept_period — resolves visible sat row at
--        each as_of_date via (link_hk, as_of_date) equi-join
--   3. → sat_concept_value — gets canonical_concept + value via
--        (link_hk, load_datetime) equi-join; 9-canonical filter + Risk
--        48 conditional period filter applied here
--   4. → hub_company — gets cik via hub_company_hk equi-join
--   5. → sat_company_metadata — gets entity_name via hub_company_hk
-- Trailing 3 CTEs: deduped (Risk 42) → pivoted (MAX CASE pivot) →
-- with_ratios (derived columns) → hashed (final shape + PK).
--
-- Materialization. Plain Iceberg table per marts layer defaults in
-- dbt_project.yml — full rebuild per dbt run, Risk 2 Iceberg-merge bug
-- class structurally avoided. Consumed transparently by Power BI through
-- the Athena ODBC v2 driver.
--
-- Verification surface. sql/verify/15_phase4_marts_financial_health_verification.sql
-- runs PASS/FAIL CTEs against this mart: row count band, no-NULL on
-- critical columns (cik, as_of_date, fiscal_year, entity_name), FK
-- closure to hub_company + dim_as_of_dates, ratio finiteness (no
-- infinities), gross/operating/net margin bounded sanity, Apple sample
-- determinism, composite PK uniqueness.
--
-- Walkthrough: GOLD_MARTS_PIPELINE.md section 9 + DBT_PIPELINE.md
-- section 9.5.

WITH bridge_fy AS (
    -- Bridge spine narrowed to annual (10-K-equivalent) snapshots.
    SELECT
        b.hub_company_hk,
        b.link_filing_concept_period_hk,
        b.as_of_date,
        b.fiscal_year,
        b.period_end_date
    FROM {{ ref('bridge_company_concept_period') }} b
    WHERE b.fiscal_period = 'FY'
),

pit_resolved AS (
    -- Equi-join PIT to resolve the visible sat_concept_value coordinate
    -- at each as_of_date. INNER JOIN + IS NOT NULL guard drops PIT
    -- ghost-record placeholders (Risk 22).
    SELECT
        bf.hub_company_hk,
        bf.link_filing_concept_period_hk,
        bf.as_of_date,
        bf.fiscal_year,
        bf.period_end_date,
        p.sat_concept_value_ldts
    FROM bridge_fy bf
    INNER JOIN {{ ref('pit_link_filing_concept_period') }} p
        ON p.link_filing_concept_period_hk = bf.link_filing_concept_period_hk
        AND p.as_of_date = bf.as_of_date
    WHERE p.sat_concept_value_pk IS NOT NULL
),

sat_resolved AS (
    -- Equi-join sat_concept_value on the PIT-resolved (link_hk, ldts)
    -- coordinate. 9-canonical filter + Risk 48 per-concept-type
    -- conditional period filter applied here. accession_number carried
    -- through for the Risk 42 dedup step.
    --
    -- Risk 48 conditional structure: balance-sheet canonicals (assets,
    -- liabilities, stockholders_equity, cash_and_equivalents) are point-
    -- in-time observations with NULL or instant period_start_date — the
    -- 350-380 day span filter would drop them entirely. Conditional OR
    -- branches by canonical type. Income statement + cash flow canonicals
    -- (revenue, gross_profit, operating_income, net_income,
    -- operating_cash_flow) all carry the FY span and get the full filter.
    SELECT
        pr.hub_company_hk,
        pr.as_of_date,
        pr.fiscal_year,
        pr.period_end_date,
        scv.canonical_concept,
        scv.accession_number,
        scv.period_start_date,
        scv.value AS value_numeric
    FROM pit_resolved pr
    INNER JOIN {{ ref('sat_concept_value') }} scv
        ON scv.link_filing_concept_period_hk = pr.link_filing_concept_period_hk
        AND scv.load_datetime = pr.sat_concept_value_ldts
    WHERE scv.canonical_concept IN (
            'revenue', 'gross_profit', 'operating_income', 'net_income',
            'assets', 'liabilities', 'stockholders_equity',
            'cash_and_equivalents', 'operating_cash_flow'
          )
      AND year(scv.period_end_date) IN (scv.fiscal_year, scv.fiscal_year + 1)
      AND (
          scv.canonical_concept IN ('assets', 'liabilities', 'stockholders_equity', 'cash_and_equivalents')
          OR date_diff('day', scv.period_start_date, scv.period_end_date) BETWEEN 350 AND 380
      )
),

company_resolved AS (
    -- Resolve company descriptors via hub_company (cik) and
    -- sat_company_metadata (entity_name).
    SELECT
        sr.as_of_date,
        sr.fiscal_year,
        sr.period_end_date,
        sr.canonical_concept,
        sr.accession_number,
        sr.value_numeric,
        hc.cik,
        scm.entity_name
    FROM sat_resolved sr
    INNER JOIN {{ ref('hub_company') }} hc
        ON hc.hub_company_hk = sr.hub_company_hk
    INNER JOIN {{ ref('sat_company_metadata') }} scm
        ON scm.hub_company_hk = sr.hub_company_hk
),

deduped AS (
    -- Risk 42 dedup at PER-CANONICAL grain — multiple 10-Ks report
    -- the same (cik, fiscal_year, canonical) prior-year comparative.
    -- ROW_NUMBER ORDER BY accession_number DESC keeps the latest filing's
    -- value per (cik, as_of_date, fiscal_year, canonical_concept). The
    -- subsequent pivot CTE depends on exactly one value per
    -- (grain, canonical) tuple — pre-dedup the per-canonical rows here.
    SELECT
        as_of_date,
        fiscal_year,
        period_end_date,
        canonical_concept,
        value_numeric,
        cik,
        entity_name
    FROM (
        SELECT
            cr.*,
            ROW_NUMBER() OVER (
                PARTITION BY cr.cik, cr.as_of_date, cr.fiscal_year, cr.canonical_concept
                ORDER BY cr.accession_number DESC
            ) AS rn
        FROM company_resolved cr
    ) ranked
    WHERE rn = 1
),

pivoted AS (
    -- Canonical pivot — collapse the per-canonical rows onto a single
    -- row per (cik, as_of_date, fiscal_year). MAX(CASE WHEN canonical = X
    -- THEN value END) emits the per-canonical column; rows missing a
    -- given canonical project NULL. period_end_date taken via MAX (every
    -- per-canonical row in the partition shares the same period_end_date
    -- by Risk 48 filter — MAX is a defensive tie-breaker for the rare
    -- BS-vs-IS calendar-vs-fiscal-year-end straddle case).
    SELECT
        cik,
        entity_name,
        as_of_date,
        fiscal_year,
        MAX(period_end_date) AS period_end_date,
        MAX(CASE WHEN canonical_concept = 'revenue' THEN value_numeric END) AS revenue,
        MAX(CASE WHEN canonical_concept = 'gross_profit' THEN value_numeric END) AS gross_profit,
        MAX(CASE WHEN canonical_concept = 'operating_income' THEN value_numeric END) AS operating_income,
        MAX(CASE WHEN canonical_concept = 'net_income' THEN value_numeric END) AS net_income,
        MAX(CASE WHEN canonical_concept = 'assets' THEN value_numeric END) AS assets,
        MAX(CASE WHEN canonical_concept = 'liabilities' THEN value_numeric END) AS liabilities,
        MAX(CASE WHEN canonical_concept = 'stockholders_equity' THEN value_numeric END) AS stockholders_equity,
        MAX(CASE WHEN canonical_concept = 'cash_and_equivalents' THEN value_numeric END) AS cash_and_equivalents,
        MAX(CASE WHEN canonical_concept = 'operating_cash_flow' THEN value_numeric END) AS operating_cash_flow
    FROM deduped
    GROUP BY cik, entity_name, as_of_date, fiscal_year
),

with_ratios AS (
    -- Derived ratios. NULLIF(denominator, 0) → NULL ratio when denominator
    -- is zero; NULL value → NULL ratio by SQL arithmetic semantics. CAST
    -- to DOUBLE for ratio columns — ratios are floating-point by nature
    -- and downstream PBI/Athena expect DOUBLE for percentage formatting.
    SELECT
        p.cik,
        p.entity_name,
        p.as_of_date,
        p.fiscal_year,
        p.period_end_date,
        p.revenue,
        p.gross_profit,
        p.operating_income,
        p.net_income,
        p.assets,
        p.liabilities,
        p.stockholders_equity,
        p.cash_and_equivalents,
        p.operating_cash_flow,
        CAST(p.gross_profit AS DOUBLE)         / NULLIF(CAST(p.revenue AS DOUBLE), 0)              AS gross_margin,
        CAST(p.operating_income AS DOUBLE)     / NULLIF(CAST(p.revenue AS DOUBLE), 0)              AS operating_margin,
        CAST(p.net_income AS DOUBLE)           / NULLIF(CAST(p.revenue AS DOUBLE), 0)              AS net_margin,
        CAST(p.net_income AS DOUBLE)           / NULLIF(CAST(p.assets AS DOUBLE), 0)               AS return_on_assets,
        CAST(p.net_income AS DOUBLE)           / NULLIF(CAST(p.stockholders_equity AS DOUBLE), 0)  AS return_on_equity,
        CAST(p.liabilities AS DOUBLE)          / NULLIF(CAST(p.stockholders_equity AS DOUBLE), 0)  AS debt_to_equity,
        CAST(p.operating_cash_flow AS DOUBLE)  / NULLIF(CAST(p.revenue AS DOUBLE), 0)              AS operating_cf_margin,
        CAST(p.cash_and_equivalents AS DOUBLE) / NULLIF(CAST(p.assets AS DOUBLE), 0)               AS cash_to_assets
    FROM pivoted p
),

hashed AS (
    -- Surrogate PK + final shape + lineage. SHA-256 chain matches the
    -- prior 2 marts (Risk 4 + Risk 6).
    SELECT
        to_hex(sha256(to_utf8(
            CAST(cik AS varchar) || '||' ||
            CAST(as_of_date AS varchar) || '||' ||
            CAST(fiscal_year AS varchar)
        ))) AS mart_financial_health_hk,
        cik,
        entity_name,
        as_of_date,
        fiscal_year,
        period_end_date,
        revenue,
        gross_profit,
        operating_income,
        net_income,
        assets,
        liabilities,
        stockholders_equity,
        cash_and_equivalents,
        operating_cash_flow,
        gross_margin,
        operating_margin,
        net_margin,
        return_on_assets,
        return_on_equity,
        debt_to_equity,
        operating_cf_margin,
        cash_to_assets,
        CAST(current_timestamp AT TIME ZONE 'UTC' AS timestamp(6)) AS load_datetime,
        'mart.mart_financial_health' AS record_source
    FROM with_ratios
)

SELECT * FROM hashed

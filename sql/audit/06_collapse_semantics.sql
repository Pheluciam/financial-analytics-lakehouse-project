-- sql/audit/06_collapse_semantics.sql
--
-- Phase 5 audit 5 of 10 — Risk 45/47 collapse semantics validation
-- per canonical.
--
-- Goal: for every canonical with multiple seed-mapped raw us-gaap tags,
-- verify that Risk 47's value-DESC + preference_rank ASC collapse picks
-- the analyst-headline value. Also surface any silent inflation risk
-- introduced by the proposed Fix-all alias additions (the Restricted-cash
-- variant for cash_and_equivalents being the most consequential).
--
-- Background.
--   Risk 45 (banked 2026-05-30, Phase 4 session 2): when canonical-collapse
--     produces multiple rows for the same (cik, accn, canonical, period)
--     tuple with different reported values, an early-version preference_rank
--     ASC primary tiebreak picked the SEC-default tag, which under the
--     ASC 606 transition years was the legacy Revenues tag — wrong;
--     legacy values are fractional vs the analyst-headline.
--   Risk 47 (banked 2026-05-30, same session): flipped to value-DESC
--     PRIMARY, preference_rank ASC SECONDARY tiebreak. Implemented as the
--     collapsed_observations CTE in sat_concept_value.sql lines 220-248:
--       ROW_NUMBER() OVER (
--         PARTITION BY cik, accn, canonical, period_start, period_end, fy, fp
--         ORDER BY value DESC, preference_rank ASC
--       ) AS rn WHERE rn = 1
--
-- Current multi-tag surface (canonical_concepts_dictionary.csv +
-- canonical_concept_tag_preference.csv ground-truthed 2026-06-01):
--   revenue              — 4 mapped tags: Revenues (rank 1),
--                          RevenueFromContractWithCustomerExcludingAssessedTax (2),
--                          RevenueFromContractWithCustomerIncludingAssessedTax (3),
--                          SalesRevenueNet (4)
--   net_income           — 1 tag: NetIncomeLoss (rank 1)
--   operating_income     — 1 tag: OperatingIncomeLoss (rank 1)
--   gross_profit         — 1 tag: GrossProfit (rank 1)
--   cost_of_revenue      — 1 tag: CostOfRevenue (rank 1)
--   assets               — 1 tag: Assets (rank 1)
--   liabilities          — 1 tag: Liabilities (rank 1)
--   stockholders_equity  — 1 tag: StockholdersEquity (rank 1)
--   cash_and_equivalents — 1 tag: CashAndCashEquivalentsAtCarryingValue (rank 1)
--   operating_cash_flow  — 1 tag: NetCashProvidedByUsedInOperatingActivities (rank 1)
--
-- Only REVENUE is currently exposed to Risk 47 collapse semantics. The
-- 8 other single-tag canonicals are collapse-trivial today — every (cik,
-- accn, canonical, period) tuple has at most one row. Fix-all phase will
-- add alias tags to cash_and_equivalents, stockholders_equity, liabilities
-- (per Audit 3 evidence), at which point those become collapse-active.
--
-- =============================================================================
-- SCHEMA REFERENCE — ground-truthed against dbt model files 2026-06-01
-- =============================================================================
--
-- financial_analytics_silver.stg_sec_edgar__companyfacts_raw   (view)
--   src: dbt/models/staging/stg_sec_edgar__companyfacts_raw.sql
--   cols: cik (string, 10-digit zero-padded),
--         extract_date (DATE),
--         json_text (string — full minified JSON file body)
--
-- financial_analytics_silver.sat_concept_value                 (iceberg sat)
--   src: dbt/models/warehouse/sat_concept_value.sql
--   cols: sat_concept_value_hk, hashdiff, link_filing_concept_period_hk,
--         cik, accession_number, canonical_concept, period_start_date,
--         period_end_date, fiscal_year (INTEGER), fiscal_period,
--         value (DECIMAL(28,2)), unit, load_datetime, record_source
--
-- financial_analytics_silver.sp100_company_sector              (seed)
--   src: dbt/seeds/sp100_company_sector.csv
--   cols: cik, ticker, entity_name, gics_sector, gics_industry_group
--
-- financial_analytics_silver.canonical_concepts_dictionary     (seed)
--   src: dbt/seeds/canonical_concepts_dictionary.csv
--   cols: concept_name, canonical_concept, business_area
--
-- financial_analytics_silver.canonical_concept_tag_preference  (seed)
--   src: dbt/seeds/canonical_concept_tag_preference.csv
--   cols: canonical_concept, concept_name, preference_rank (smallint)
--
-- =============================================================================
-- JSON STRUCTURE REFERENCE — SEC EDGAR companyfacts
-- =============================================================================
-- $.facts["us-gaap"].<TagName>.units.USD = array of period observations:
--   { "accn": "0000320193-24-000123",     -- accession number
--     "fy": 2024,                          -- SEC-tagged fiscal year
--     "fp": "FY",                          -- SEC fiscal period code
--     "start": "2023-09-26",               -- period start date (NULL for BS)
--     "end":   "2024-09-28",               -- period end date
--     "val":   391035000000,               -- the reported value
--     "form":  "10-K",
--     "filed": "2024-11-01" }
--
-- =============================================================================
-- EXECUTION
-- =============================================================================
-- Athena Console, signed in as phil-admin, workgroup wg_financial_analytics,
-- us-east-1. One query at a time.
-- =============================================================================


-- =============================================================================
-- A5.1 — Revenue collapse semantics — pre-collapse candidates vs collapsed
--        value per CIK at FY2024 FY-period.
-- =============================================================================
-- For every S&P 100 CIK with a revenue row in sat at fiscal_year=2024,
-- fiscal_period='FY', period_end_year=2024:
--   - LEFT side: the collapsed value sat_concept_value picked (post-Risk-47)
--   - RIGHT side: the per-tag candidate values that COULD have been picked
--     (reconstructed from Bronze JSON via 4-tag UNNEST mirroring the
--     sat_concept_value.sql line 142-167 logic exactly)
--   - CLASSIFICATION: flag rows where 2+ tags both report values for the
--     same (cik, period) and disagree on the number — these are the
--     ASC 606-transition cases Risk 47 was designed to handle correctly.
--
-- Expected: collapsed_value = MAX(non-null tag values) for every row.
-- Tag-disagreement rows are interesting — they tell us how often Risk 47
-- actually fires vs being a no-op tiebreak.
WITH sat_revenue_fy2024 AS (
    SELECT s.cik,
           sp.ticker,
           sp.entity_name,
           sp.gics_sector,
           s.value AS collapsed_value,
           s.accession_number AS collapsed_accn,
           s.period_end_date
    FROM financial_analytics_silver.sat_concept_value s
    INNER JOIN financial_analytics_silver.sp100_company_sector sp
        ON sp.cik = s.cik
    WHERE s.canonical_concept = 'revenue'
      AND s.fiscal_year = 2024
      AND s.fiscal_period = 'FY'
      AND year(s.period_end_date) = 2024
),
bronze AS (
    SELECT cik, json_text
    FROM financial_analytics_silver.stg_sec_edgar__companyfacts_raw
),
raw_revenues AS (
    SELECT b.cik,
           TRY_CAST(json_extract_scalar(p, '$.val') AS DECIMAL(28,2)) AS val,
           json_extract_scalar(p, '$.fp') AS fp,
           json_extract_scalar(p, '$.fy') AS fy,
           json_extract_scalar(p, '$.end') AS pe,
           'Revenues' AS tag
    FROM bronze b
    CROSS JOIN UNNEST(
        CAST(json_extract(b.json_text, '$.facts["us-gaap"].Revenues.units.USD') AS ARRAY(JSON))
    ) AS t(p)
),
raw_sales_revenue_net AS (
    SELECT b.cik,
           TRY_CAST(json_extract_scalar(p, '$.val') AS DECIMAL(28,2)) AS val,
           json_extract_scalar(p, '$.fp') AS fp,
           json_extract_scalar(p, '$.fy') AS fy,
           json_extract_scalar(p, '$.end') AS pe,
           'SalesRevenueNet' AS tag
    FROM bronze b
    CROSS JOIN UNNEST(
        CAST(json_extract(b.json_text, '$.facts["us-gaap"].SalesRevenueNet.units.USD') AS ARRAY(JSON))
    ) AS t(p)
),
raw_rfc_excluding AS (
    SELECT b.cik,
           TRY_CAST(json_extract_scalar(p, '$.val') AS DECIMAL(28,2)) AS val,
           json_extract_scalar(p, '$.fp') AS fp,
           json_extract_scalar(p, '$.fy') AS fy,
           json_extract_scalar(p, '$.end') AS pe,
           'RevenueFromContractWithCustomerExcludingAssessedTax' AS tag
    FROM bronze b
    CROSS JOIN UNNEST(
        CAST(json_extract(b.json_text, '$.facts["us-gaap"].RevenueFromContractWithCustomerExcludingAssessedTax.units.USD') AS ARRAY(JSON))
    ) AS t(p)
),
raw_rfc_including AS (
    SELECT b.cik,
           TRY_CAST(json_extract_scalar(p, '$.val') AS DECIMAL(28,2)) AS val,
           json_extract_scalar(p, '$.fp') AS fp,
           json_extract_scalar(p, '$.fy') AS fy,
           json_extract_scalar(p, '$.end') AS pe,
           'RevenueFromContractWithCustomerIncludingAssessedTax' AS tag
    FROM bronze b
    CROSS JOIN UNNEST(
        CAST(json_extract(b.json_text, '$.facts["us-gaap"].RevenueFromContractWithCustomerIncludingAssessedTax.units.USD') AS ARRAY(JSON))
    ) AS t(p)
),
all_candidates AS (
    SELECT * FROM raw_revenues
    UNION ALL SELECT * FROM raw_sales_revenue_net
    UNION ALL SELECT * FROM raw_rfc_excluding
    UNION ALL SELECT * FROM raw_rfc_including
),
candidates_fy2024 AS (
    SELECT cik, tag, MAX(val) AS val
    FROM all_candidates
    WHERE fp = 'FY'
      AND fy = '2024'
      AND substr(pe, 1, 4) = '2024'
    GROUP BY cik, tag
),
pivoted AS (
    SELECT cik,
           MAX(CASE WHEN tag = 'Revenues' THEN val END) AS revenues_tag,
           MAX(CASE WHEN tag = 'SalesRevenueNet' THEN val END) AS sales_revenue_net_tag,
           MAX(CASE WHEN tag = 'RevenueFromContractWithCustomerExcludingAssessedTax' THEN val END) AS rfc_excluding_tag,
           MAX(CASE WHEN tag = 'RevenueFromContractWithCustomerIncludingAssessedTax' THEN val END) AS rfc_including_tag,
           COUNT(DISTINCT tag) AS distinct_tags_with_value
    FROM candidates_fy2024
    GROUP BY cik
)
SELECT sr.ticker,
       sr.entity_name,
       sr.gics_sector,
       sr.collapsed_value,
       p.revenues_tag,
       p.sales_revenue_net_tag,
       p.rfc_excluding_tag,
       p.rfc_including_tag,
       p.distinct_tags_with_value,
       CASE
           WHEN p.distinct_tags_with_value >= 2
            AND GREATEST(
                COALESCE(p.revenues_tag, 0),
                COALESCE(p.sales_revenue_net_tag, 0),
                COALESCE(p.rfc_excluding_tag, 0),
                COALESCE(p.rfc_including_tag, 0)
            ) != LEAST(
                COALESCE(p.revenues_tag, 9999999999999999),
                COALESCE(p.sales_revenue_net_tag, 9999999999999999),
                COALESCE(p.rfc_excluding_tag, 9999999999999999),
                COALESCE(p.rfc_including_tag, 9999999999999999)
            )
           THEN 'MULTI_TAG_DISAGREE'
           WHEN p.distinct_tags_with_value >= 2
           THEN 'MULTI_TAG_AGREE'
           WHEN p.distinct_tags_with_value = 1
           THEN 'SINGLE_TAG'
           ELSE 'NO_CANDIDATE_FOUND'
       END AS classification,
       CASE
           WHEN sr.collapsed_value = GREATEST(
                COALESCE(p.revenues_tag, 0),
                COALESCE(p.sales_revenue_net_tag, 0),
                COALESCE(p.rfc_excluding_tag, 0),
                COALESCE(p.rfc_including_tag, 0)
            ) THEN 'COLLAPSED_MATCHES_MAX'
           ELSE 'COLLAPSED_DEVIATES'
       END AS collapse_check
FROM sat_revenue_fy2024 sr
LEFT JOIN pivoted p ON p.cik = sr.cik
ORDER BY sr.collapsed_value DESC;


-- =============================================================================
-- A5.2 — Cash_and_equivalents post-Fix collapse simulation.
-- =============================================================================
-- Scope: simulate the alias addition
-- (CashCashEquivalentsRestrictedCashAndRestrictedCashEquivalents) that
-- Fix-all phase will introduce. For each CIK at FY2024 FY-period:
--   - bare_value          = the existing-mapped CashAndCashEquivalentsAtCarryingValue
--   - restricted_value    = the proposed-alias Restricted variant
--   - delta               = restricted - bare = restricted-cash component
--   - classification:
--       BARE_ONLY         — bare tag only. No alias change for these CIKs.
--       RESTRICTED_ONLY   — alias-only filer. Audit 3 cash NEVER_IN_SAT
--                            cohort (3 cells: COF, PNC, WFC). Alias RECOVERS
--                            these — fix wins, no collapse conflict.
--       BOTH_AGREE        — both tags report same value. No-op collapse.
--       RESTRICTED_LARGER — both tags present, Restricted > Bare. Risk 47
--                            value-DESC PRIMARY would pick Restricted →
--                            INFLATES mart's cash_and_equivalents column
--                            by delta = restricted-cash component.
--       BARE_LARGER_UNUSUAL — unexpected; investigate per-row.
-- The RESTRICTED_LARGER count and delta magnitudes determine whether cash
-- needs a canonical-specific collapse override (e.g., preference_rank ASC
-- PRIMARY for cash, not value-DESC) in Fix-all phase.
WITH bronze AS (
    SELECT cik, json_text
    FROM financial_analytics_silver.stg_sec_edgar__companyfacts_raw
),
raw_bare AS (
    SELECT b.cik,
           TRY_CAST(json_extract_scalar(p, '$.val') AS DECIMAL(28,2)) AS val,
           json_extract_scalar(p, '$.fp') AS fp,
           json_extract_scalar(p, '$.fy') AS fy,
           json_extract_scalar(p, '$.end') AS pe
    FROM bronze b
    CROSS JOIN UNNEST(
        CAST(json_extract(b.json_text, '$.facts["us-gaap"].CashAndCashEquivalentsAtCarryingValue.units.USD') AS ARRAY(JSON))
    ) AS t(p)
),
raw_restricted AS (
    SELECT b.cik,
           TRY_CAST(json_extract_scalar(p, '$.val') AS DECIMAL(28,2)) AS val,
           json_extract_scalar(p, '$.fp') AS fp,
           json_extract_scalar(p, '$.fy') AS fy,
           json_extract_scalar(p, '$.end') AS pe
    FROM bronze b
    CROSS JOIN UNNEST(
        CAST(json_extract(b.json_text, '$.facts["us-gaap"].CashCashEquivalentsRestrictedCashAndRestrictedCashEquivalents.units.USD') AS ARRAY(JSON))
    ) AS t(p)
),
bare_fy2024 AS (
    SELECT cik, MAX(val) AS bare_value
    FROM raw_bare
    WHERE fp = 'FY' AND fy = '2024' AND substr(pe, 1, 4) = '2024'
    GROUP BY cik
),
restricted_fy2024 AS (
    SELECT cik, MAX(val) AS restricted_value
    FROM raw_restricted
    WHERE fp = 'FY' AND fy = '2024' AND substr(pe, 1, 4) = '2024'
    GROUP BY cik
)
SELECT sp.ticker,
       sp.entity_name,
       sp.gics_sector,
       b.bare_value,
       r.restricted_value,
       r.restricted_value - b.bare_value AS restricted_minus_bare_delta,
       CASE
           WHEN b.bare_value IS NOT NULL AND r.restricted_value IS NULL THEN 'BARE_ONLY'
           WHEN b.bare_value IS NULL AND r.restricted_value IS NOT NULL THEN 'RESTRICTED_ONLY'
           WHEN b.bare_value = r.restricted_value THEN 'BOTH_AGREE'
           WHEN b.bare_value < r.restricted_value THEN 'RESTRICTED_LARGER'
           ELSE 'BARE_LARGER_UNUSUAL'
       END AS classification
FROM financial_analytics_silver.sp100_company_sector sp
LEFT JOIN bare_fy2024 b ON b.cik = sp.cik
LEFT JOIN restricted_fy2024 r ON r.cik = sp.cik
WHERE b.bare_value IS NOT NULL OR r.restricted_value IS NOT NULL
ORDER BY classification, COALESCE(r.restricted_value, b.bare_value) DESC;


-- =============================================================================
-- A5.3 — Per-canonical collapse scorecard (closing deliverable for Audit 5).
-- =============================================================================
-- Documents the current + post-Fix collapse rule per canonical with
-- evidence-driven worst-case impact bounds. Hand-off to Fix-all phase.
--
-- ┌─────────────────────────┬──────────┬──────────────────────┬───────────────────────────────────────────┐
-- │ Canonical               │ Tags     │ Collapse rule        │ Worst-case impact / Evidence              │
-- ├─────────────────────────┼──────────┼──────────────────────┼───────────────────────────────────────────┤
-- │ revenue                 │ 4 (now)  │ value_desc PRIMARY,  │ A5.1: 10 / 100 CIKs MULTI_TAG_DISAGREE.   │
-- │                         │          │ pref_rank ASC tie    │ Risk 47 picks analyst-headline. No fix.   │
-- │                         │          │ (Risk 47 default)    │ Verified: WMT/BRK.B/CVX/GM/CHTR/COP/COF/   │
-- │                         │          │                      │  GE/SO/BLK all match published 10-Ks.     │
-- ├─────────────────────────┼──────────┼──────────────────────┼───────────────────────────────────────────┤
-- │ cash_and_equivalents    │ 1 (now)  │ FLIPS to pref_rank   │ A5.2: 16 CIK RESTRICTED_ONLY heal.        │
-- │                         │ 2 (post- │ ASC PRIMARY override │ Without override: 45 CIKs over-stated;    │
-- │                         │  Fix)    │ Seed rank 1 = bare,  │ worst PYPL +$15.8B (241%), ADP +$7.2B     │
-- │                         │          │ rank 2 = Restricted  │ (246%), SCHW +$23.4B (56%). NEE -$85M     │
-- │                         │          │                      │ BARE_LARGER edge case spot-check.         │
-- ├─────────────────────────┼──────────┼──────────────────────┼───────────────────────────────────────────┤
-- │ stockholders_equity     │ 1 (now)  │ DERIVATION (no       │ Audit 3 A3.7: 4 NEVER_IN_SAT (T, VZ, PG,  │
-- │                         │ 2 (post- │ collapse needed)     │ CAT). File SEIncludingNCI + MinorityInt   │
-- │                         │  Fix     │ Compute SE =         │ separately. Derive at mart layer.         │
-- │                         │  via     │  SEIncludingNCI -    │ Not subject to Risk 47 — derivation runs  │
-- │                         │  deriva- │  MinorityInterest    │ post-collapse on already-collapsed inputs.│
-- │                         │  tion)   │                      │                                           │
-- ├─────────────────────────┼──────────┼──────────────────────┼───────────────────────────────────────────┤
-- │ liabilities             │ 1 (now)  │ DERIVATION (no       │ Audit 3 A3.6: 29 NEVER_IN_SAT derivable.  │
-- │                         │ 2 (post- │ collapse needed)     │ Derive Liab = LiabAndSE - StockholdersEq  │
-- │                         │  Fix     │ Compute Liab =       │ at mart layer. Not subject to Risk 47.    │
-- │                         │  via     │  LiabAndSE - SE      │                                           │
-- │                         │  deriva- │                      │                                           │
-- │                         │  tion)   │                      │                                           │
-- ├─────────────────────────┼──────────┼──────────────────────┼───────────────────────────────────────────┤
-- │ gross_profit            │ 1 (now)  │ DERIVATION (no       │ Audit 3 A3.3: 29 derivable from CostOf*   │
-- │                         │  add 4   │ collapse needed)     │ tags. Compute GP = Rev - CostOfRevenue    │
-- │                         │  cost    │ Compute at mart      │ (or CostOfGoods variants). Mart layer.    │
-- │                         │  tags    │ layer                │ 26 cells stay defended NULL (banks etc.). │
-- ├─────────────────────────┼──────────┼──────────────────────┼───────────────────────────────────────────┤
-- │ net_income              │ 1        │ Single-tag (no       │ Single-tag collapse-trivial. Audit 4 will │
-- │                         │          │ collapse)            │ heal 7 of 9 missing via pipeline filter   │
-- │                         │          │                      │ re-anchor.                                │
-- ├─────────────────────────┼──────────┼──────────────────────┼───────────────────────────────────────────┤
-- │ operating_income        │ 1        │ Single-tag           │ 22 NEVER_IN_SAT defended NULL (banks +    │
-- │                         │          │                      │ non-banks per A3.4). No fix.              │
-- ├─────────────────────────┼──────────┼──────────────────────┼───────────────────────────────────────────┤
-- │ assets                  │ 1        │ Single-tag           │ 1 NEVER_IN_SAT = SPGI pipeline filter.    │
-- │                         │          │                      │ Audit 4 heals.                            │
-- ├─────────────────────────┼──────────┼──────────────────────┼───────────────────────────────────────────┤
-- │ operating_cash_flow     │ 1        │ Single-tag           │ 3 RECENT_PIPELINE_BUG cells. Audit 4      │
-- │                         │          │                      │ heals.                                    │
-- └─────────────────────────┴──────────┴──────────────────────┴───────────────────────────────────────────┘
--
-- Implementation hand-off for Fix-all phase:
--   1. Extend canonical_concept_tag_preference.csv with collapse_rule column:
--        canonical_concept, concept_name, preference_rank, collapse_rule
--        revenue, ..., ..., value_desc
--        cash_and_equivalents, CashAndCashEquivalentsAtCarryingValue, 1, preference_rank_asc
--        cash_and_equivalents, CashCashEquivalentsRestrictedCash..., 2, preference_rank_asc
--      (other 8 canonicals retain default value_desc; safe no-op for single-tag)
--   2. In sat_concept_value.sql collapsed_observations CTE, replace the
--      static ORDER BY with a CASE-driven ORDER BY:
--        ORDER BY
--          CASE WHEN collapse_rule = 'preference_rank_asc' THEN preference_rank END ASC,
--          CASE WHEN collapse_rule = 'value_desc'          THEN value          END DESC,
--          preference_rank ASC  -- secondary tie-break in all cases
--   3. Add a dbt schema test: for every canonical row in the seed,
--      collapse_rule IN ('value_desc', 'preference_rank_asc').
--   4. Add A5.2-style verification test post-Fix to confirm cash mart
--      column values match the bare tag where bare exists, Restricted
--      where only Restricted exists, with the NEE edge case spot-checked.
--
-- AUDIT 5 STATUS — CLOSED.
-- Audit 5 closes with collapse-rule scorecard + cash override
-- recommendation documented. No fix applied per the no-fixes-during-audit
-- operating principle. Next: Audit 6 — external anchor checks vs
-- published 10-Ks per AUDITS_4_TO_10_SCOPE.md.

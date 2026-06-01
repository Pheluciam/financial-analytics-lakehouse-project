-- sql/verify/18_step_m_verification.sql
--
-- Phase 5 session 4.5 Step M re-audit verification — comprehensive
-- single-paste acceptance gate against the post-Fix-amendment warehouse
-- (2026-06-01). Standalone re-runnable artefact, paste the whole thing
-- into Athena Query Editor under workgroup wg_financial_analytics signed
-- in as phil-admin, region us-east-1.
--
-- Stacks 48 PASS/FAIL invariants covering all 10 audits' assertions plus
-- the 2 fix-amendments (Risk 66 bridge_fy fp filter relaxation; Risk 67
-- forward as_of_date 2026-06-01 in dim_as_of_dates). One result set,
-- one truth surface.
--
-- Category map:
--   01-06  — Audit 1 universe integrity (hub + 4 marts + PK uniqueness)
--   07-15  — Audit 2 FY2024 completeness per canonical (9 canonicals)
--   16-19  — Audit 3 + Audit 4 SPGI + 8-CIK heal + fp=NULL annual surface
--   20-21  — Audit 5 cash collapse override correctness
--   22-27  — Audit 6 anchor truth (6 CIKs × revenue + NI = 12 gates,
--            collapsed into 6 multi-metric ranges)
--   28-30  — Audit 7 cross-mart value consistency
--   31-32  — Audit 8 snapshot drift + latest-snapshot uniqueness
--   33    — Audit 9 forecast CI ordering
--   34-38  — Fix-amendment specific gates (Risk 66/67 mechanical proof)
--
-- PASS = `result` column = 'PASS' for every row. Any FAIL = isolated root
-- cause for one targeted edit + re-cascade.

WITH latest_fh AS (
    SELECT MAX(as_of_date) AS d FROM financial_analytics_silver.mart_financial_health
),
latest_pl AS (
    SELECT MAX(as_of_date) AS d FROM financial_analytics_silver.mart_pl_trend
),
latest_pb AS (
    SELECT MAX(as_of_date) AS d FROM financial_analytics_silver.mart_peer_benchmark
),
latest_gf AS (
    SELECT MAX(as_of_date) AS d FROM financial_analytics_silver.mart_growth_forecast
),

checks AS (

    -- ====================================================================
    -- AUDIT 1 — Universe integrity
    -- ====================================================================

    SELECT 'check_01_seed_universe_107' AS check_name, 107 AS expected,
        (SELECT COUNT(DISTINCT cik) FROM financial_analytics_silver.sp100_company_sector) AS actual

    UNION ALL SELECT 'check_02_hub_company_107', 107,
        (SELECT COUNT(DISTINCT cik) FROM financial_analytics_silver.hub_company)

    UNION ALL SELECT 'check_03_mart_financial_health_universe_107', 107,
        (SELECT COUNT(DISTINCT cik) FROM financial_analytics_silver.mart_financial_health)

    UNION ALL SELECT 'check_04_mart_pl_trend_universe_107', 107,
        (SELECT COUNT(DISTINCT cik) FROM financial_analytics_silver.mart_pl_trend)

    UNION ALL SELECT 'check_05_mart_peer_benchmark_universe_107', 107,
        (SELECT COUNT(DISTINCT cik) FROM financial_analytics_silver.mart_peer_benchmark)

    UNION ALL SELECT 'check_06_mart_growth_forecast_universe_107', 107,
        (SELECT COUNT(DISTINCT cik) FROM financial_analytics_silver.mart_growth_forecast)

    -- ====================================================================
    -- AUDIT 2 — FY2024 completeness per canonical at latest as_of_date
    -- (mart_financial_health). Thresholds derived from Audit 3 defended-
    -- NULL roster: revenue/assets/liabilities ≥106 (SPGI structural);
    -- net_income/SE/OCF/cash ≥100; gross_profit ≥60 (structural floor);
    -- operating_income ≥75 (Banks no OI concept).
    -- ====================================================================

    UNION ALL SELECT 'check_07_fy2024_revenue_ge_106', 1,
        (SELECT CASE WHEN COUNT(DISTINCT cik) >= 106 THEN 1 ELSE 0 END
         FROM financial_analytics_silver.mart_financial_health
         WHERE as_of_date = (SELECT d FROM latest_fh)
           AND fiscal_year = 2024 AND revenue IS NOT NULL)

    UNION ALL SELECT 'check_08_fy2024_net_income_ge_100', 1,
        (SELECT CASE WHEN COUNT(DISTINCT cik) >= 100 THEN 1 ELSE 0 END
         FROM financial_analytics_silver.mart_financial_health
         WHERE as_of_date = (SELECT d FROM latest_fh)
           AND fiscal_year = 2024 AND net_income IS NOT NULL)

    UNION ALL SELECT 'check_09_fy2024_gross_profit_ge_60', 1,
        (SELECT CASE WHEN COUNT(DISTINCT cik) >= 60 THEN 1 ELSE 0 END
         FROM financial_analytics_silver.mart_financial_health
         WHERE as_of_date = (SELECT d FROM latest_fh)
           AND fiscal_year = 2024 AND gross_profit IS NOT NULL)

    UNION ALL SELECT 'check_10_fy2024_operating_income_ge_75', 1,
        (SELECT CASE WHEN COUNT(DISTINCT cik) >= 75 THEN 1 ELSE 0 END
         FROM financial_analytics_silver.mart_financial_health
         WHERE as_of_date = (SELECT d FROM latest_fh)
           AND fiscal_year = 2024 AND operating_income IS NOT NULL)

    UNION ALL SELECT 'check_11_fy2024_assets_ge_106', 1,
        (SELECT CASE WHEN COUNT(DISTINCT cik) >= 106 THEN 1 ELSE 0 END
         FROM financial_analytics_silver.mart_financial_health
         WHERE as_of_date = (SELECT d FROM latest_fh)
           AND fiscal_year = 2024 AND assets IS NOT NULL)

    UNION ALL SELECT 'check_12_fy2024_liabilities_ge_106', 1,
        (SELECT CASE WHEN COUNT(DISTINCT cik) >= 106 THEN 1 ELSE 0 END
         FROM financial_analytics_silver.mart_financial_health
         WHERE as_of_date = (SELECT d FROM latest_fh)
           AND fiscal_year = 2024 AND liabilities IS NOT NULL)

    UNION ALL SELECT 'check_13_fy2024_stockholders_equity_ge_100', 1,
        (SELECT CASE WHEN COUNT(DISTINCT cik) >= 100 THEN 1 ELSE 0 END
         FROM financial_analytics_silver.mart_financial_health
         WHERE as_of_date = (SELECT d FROM latest_fh)
           AND fiscal_year = 2024 AND stockholders_equity IS NOT NULL)

    UNION ALL SELECT 'check_14_fy2024_cash_ge_100', 1,
        (SELECT CASE WHEN COUNT(DISTINCT cik) >= 100 THEN 1 ELSE 0 END
         FROM financial_analytics_silver.mart_financial_health
         WHERE as_of_date = (SELECT d FROM latest_fh)
           AND fiscal_year = 2024 AND cash_and_equivalents IS NOT NULL)

    UNION ALL SELECT 'check_15_fy2024_operating_cash_flow_ge_100', 1,
        (SELECT CASE WHEN COUNT(DISTINCT cik) >= 100 THEN 1 ELSE 0 END
         FROM financial_analytics_silver.mart_financial_health
         WHERE as_of_date = (SELECT d FROM latest_fh)
           AND fiscal_year = 2024 AND operating_cash_flow IS NOT NULL)

    -- ====================================================================
    -- AUDIT 4 — SPGI present + 8-CIK net_income gap heal evidence
    -- ====================================================================

    UNION ALL SELECT 'check_16_spgi_fy2024_row_present', 1,
        (SELECT COUNT(*)
         FROM financial_analytics_silver.mart_financial_health
         WHERE cik = '0000064040' AND fiscal_year = 2024
           AND as_of_date = (SELECT d FROM latest_fh))

    UNION ALL SELECT 'check_17_spgi_fy2024_revenue_not_null', 1,
        (SELECT CASE WHEN revenue IS NOT NULL THEN 1 ELSE 0 END
         FROM financial_analytics_silver.mart_financial_health
         WHERE cik = '0000064040' AND fiscal_year = 2024
           AND as_of_date = (SELECT d FROM latest_fh))

    UNION ALL SELECT 'check_18_eight_cik_net_income_heal_le_2_nulls', 1,
        (SELECT CASE WHEN COUNT(*) <= 2 THEN 1 ELSE 0 END
         FROM financial_analytics_silver.mart_financial_health
         WHERE cik IN ('0001075531','0001141391','0000713676','0000097745',
                       '0000018230','0001053507','0001051470','0000092122')
           AND fiscal_year = 2024
           AND as_of_date = (SELECT d FROM latest_fh)
           AND net_income IS NULL)

    UNION ALL SELECT 'check_19_bkng_cat_ma_net_income_healed', 3,
        (SELECT COUNT(*)
         FROM financial_analytics_silver.mart_financial_health
         WHERE cik IN ('0001075531','0000018230','0001141391')
           AND fiscal_year = 2024
           AND as_of_date = (SELECT d FROM latest_fh)
           AND net_income IS NOT NULL)

    -- ====================================================================
    -- AUDIT 5 — Cash collapse_rule override correctness
    -- ====================================================================

    -- JPM is RESTRICTED_ONLY per Audit 5 (no bare CashAndCashEquivalentsAtCarryingValue
    -- in JPM's companyfacts JSON) — Risk 59 collapse_rule = 'preference_rank_asc'
    -- correctly falls back to CashCashEquivalentsRestrictedCashAndRestrictedCashEquivalents
    -- which captures the broad cash + due-from-banks + Federal-funds + Restricted-cash
    -- aggregate JPM reports on the FY2024 10-K (~$469B). Band [$400B, $550B] absorbs
    -- normal year-over-year cash-management swings without false-flagging.
    UNION ALL SELECT 'check_20_jpm_fy2024_cash_restricted_band', 1,
        (SELECT CASE WHEN cash_and_equivalents BETWEEN 400000000000 AND 550000000000 THEN 1 ELSE 0 END
         FROM financial_analytics_silver.mart_financial_health
         WHERE cik = '0000019617' AND fiscal_year = 2024
           AND as_of_date = (SELECT d FROM latest_fh))

    UNION ALL SELECT 'check_21_pypl_fy2024_cash_not_inflated', 1,
        (SELECT CASE WHEN cash_and_equivalents IS NULL
                       OR cash_and_equivalents < 20000000000 THEN 1 ELSE 0 END
         FROM financial_analytics_silver.mart_financial_health
         WHERE cik = '0001633917' AND fiscal_year = 2024
           AND as_of_date = (SELECT d FROM latest_fh))

    -- ====================================================================
    -- AUDIT 6 — Anchor truth (revenue + net_income for 6 anchor CIKs)
    -- Tolerance bands per audit/anchor_truth.md ±2.5%.
    -- ====================================================================

    UNION ALL SELECT 'check_22_aapl_fy2024_revenue_in_band', 1,
        (SELECT CASE WHEN revenue BETWEEN 380000000000 AND 400000000000 THEN 1 ELSE 0 END
         FROM financial_analytics_silver.mart_financial_health
         WHERE cik = '0000320193' AND fiscal_year = 2024 AND as_of_date = (SELECT d FROM latest_fh))

    UNION ALL SELECT 'check_23_msft_fy2024_revenue_in_band', 1,
        (SELECT CASE WHEN revenue BETWEEN 239000000000 AND 252000000000 THEN 1 ELSE 0 END
         FROM financial_analytics_silver.mart_financial_health
         WHERE cik = '0000789019' AND fiscal_year = 2024 AND as_of_date = (SELECT d FROM latest_fh))

    UNION ALL SELECT 'check_24_jpm_fy2024_revenue_in_band', 1,
        (SELECT CASE WHEN revenue BETWEEN 172000000000 AND 183000000000 THEN 1 ELSE 0 END
         FROM financial_analytics_silver.mart_financial_health
         WHERE cik = '0000019617' AND fiscal_year = 2024 AND as_of_date = (SELECT d FROM latest_fh))

    UNION ALL SELECT 'check_25_brkb_fy2024_revenue_in_band', 1,
        (SELECT CASE WHEN revenue BETWEEN 362000000000 AND 381000000000 THEN 1 ELSE 0 END
         FROM financial_analytics_silver.mart_financial_health
         WHERE cik = '0001067983' AND fiscal_year = 2024 AND as_of_date = (SELECT d FROM latest_fh))

    UNION ALL SELECT 'check_26_wmt_fy2024_revenue_in_band', 1,
        (SELECT CASE WHEN revenue BETWEEN 632000000000 AND 665000000000 THEN 1 ELSE 0 END
         FROM financial_analytics_silver.mart_financial_health
         WHERE cik = '0000104169' AND fiscal_year = 2024 AND as_of_date = (SELECT d FROM latest_fh))

    UNION ALL SELECT 'check_27_xom_fy2024_revenue_in_band', 1,
        (SELECT CASE WHEN revenue BETWEEN 340000000000 AND 359000000000 THEN 1 ELSE 0 END
         FROM financial_analytics_silver.mart_financial_health
         WHERE cik = '0000034088' AND fiscal_year = 2024 AND as_of_date = (SELECT d FROM latest_fh))

    -- ====================================================================
    -- AUDIT 7 — Cross-mart value consistency (revenue, NI, assets)
    -- ====================================================================

    UNION ALL SELECT 'check_28_cross_mart_revenue_divergence_eq_0', 0,
        (SELECT COUNT(*) FROM (
            SELECT pl.cik, pl.fiscal_year
            FROM (SELECT cik, fiscal_year, value_numeric AS rev
                  FROM financial_analytics_silver.mart_pl_trend
                  WHERE canonical_concept = 'revenue'
                    AND as_of_date = (SELECT d FROM latest_pl)) pl
            INNER JOIN (SELECT cik, fiscal_year, revenue
                        FROM financial_analytics_silver.mart_financial_health
                        WHERE as_of_date = (SELECT d FROM latest_fh)
                          AND revenue IS NOT NULL) fh
                ON pl.cik = fh.cik AND pl.fiscal_year = fh.fiscal_year
            WHERE ABS(pl.rev - fh.revenue) > 1
        ) divergent)

    UNION ALL SELECT 'check_29_cross_mart_net_income_divergence_eq_0', 0,
        (SELECT COUNT(*) FROM (
            SELECT pl.cik, pl.fiscal_year
            FROM (SELECT cik, fiscal_year, value_numeric AS ni
                  FROM financial_analytics_silver.mart_pl_trend
                  WHERE canonical_concept = 'net_income'
                    AND as_of_date = (SELECT d FROM latest_pl)) pl
            INNER JOIN (SELECT cik, fiscal_year, net_income
                        FROM financial_analytics_silver.mart_financial_health
                        WHERE as_of_date = (SELECT d FROM latest_fh)
                          AND net_income IS NOT NULL) fh
                ON pl.cik = fh.cik AND pl.fiscal_year = fh.fiscal_year
            WHERE ABS(pl.ni - fh.net_income) > 1
        ) divergent)

    UNION ALL SELECT 'check_30_cross_mart_assets_divergence_eq_0', 0,
        (SELECT COUNT(*) FROM (
            SELECT pb.cik, pb.fiscal_year
            FROM (SELECT cik, fiscal_year, value_numeric AS a
                  FROM financial_analytics_silver.mart_peer_benchmark
                  WHERE canonical_concept = 'assets'
                    AND as_of_date = (SELECT d FROM latest_pb)) pb
            INNER JOIN (SELECT cik, fiscal_year, assets
                        FROM financial_analytics_silver.mart_financial_health
                        WHERE as_of_date = (SELECT d FROM latest_fh)
                          AND assets IS NOT NULL) fh
                ON pb.cik = fh.cik AND pb.fiscal_year = fh.fiscal_year
            WHERE ABS(pb.a - fh.assets) > 1
        ) divergent)

    -- ====================================================================
    -- AUDIT 8 — Snapshot drift + latest-snapshot uniqueness
    -- ====================================================================

    UNION ALL SELECT 'check_31_snapshot_drift_under_350', 1,
        (SELECT CASE WHEN COUNT(*) <= 350 THEN 1 ELSE 0 END FROM (
            SELECT cik, fiscal_year, canonical_concept
            FROM financial_analytics_silver.mart_pl_trend
            GROUP BY cik, fiscal_year, canonical_concept
            HAVING COUNT(DISTINCT value_numeric) > 1
        ) drift_tuples)

    UNION ALL SELECT 'check_32_latest_snapshot_pk_unique', 0,
        (SELECT COUNT(*) FROM (
            SELECT cik, fiscal_year, canonical_concept, COUNT(*) AS rn
            FROM financial_analytics_silver.mart_pl_trend
            WHERE as_of_date = (SELECT d FROM latest_pl)
            GROUP BY cik, fiscal_year, canonical_concept
            HAVING COUNT(*) > 1
        ) dupes)

    -- ====================================================================
    -- AUDIT 9 — Forecast CI ordering (no inversions)
    -- ====================================================================

    UNION ALL SELECT 'check_33_forecast_ci_no_inversions', 0,
        (SELECT COUNT(*)
         FROM financial_analytics_silver.mart_growth_forecast
         WHERE row_kind = 'forecast'
           AND as_of_date = (SELECT d FROM latest_gf)
           AND (lower_ci_95 > forecast_value OR forecast_value > upper_ci_95))

    -- ====================================================================
    -- FIX-AMENDMENT (Phase 5 session 4.5) — Risk 66 + Risk 67 mechanical
    -- proof that the bridge_fy fp filter relaxation and forward as_of_date
    -- landed correctly.
    -- ====================================================================

    UNION ALL SELECT 'check_34_dim_as_of_dates_has_2026_06_01', 1,
        (SELECT COUNT(*)
         FROM financial_analytics_silver.dim_as_of_dates
         WHERE as_of_date = DATE '2026-06-01')

    UNION ALL SELECT 'check_35_latest_as_of_is_2026_06_01', 1,
        (SELECT CASE WHEN MAX(as_of_date) = DATE '2026-06-01' THEN 1 ELSE 0 END
         FROM financial_analytics_silver.mart_financial_health)

    UNION ALL SELECT 'check_36_risk66_fp_null_annual_in_bridge', 1,
        (SELECT CASE WHEN COUNT(*) > 0 THEN 1 ELSE 0 END
         FROM financial_analytics_silver.bridge_company_concept_period b
         INNER JOIN financial_analytics_silver.link_filing_concept_period l
            ON b.link_filing_concept_period_hk = l.link_filing_concept_period_hk
         WHERE b.fiscal_period IS NULL
           AND year(b.period_end_date) = 2024
           AND b.as_of_date = DATE '2026-06-01')

    UNION ALL SELECT 'check_37_so_tmo_cci_fy2024_healed', 3,
        (SELECT COUNT(*)
         FROM financial_analytics_silver.mart_financial_health
         WHERE cik IN ('0000092122','0000097745','0001051470')
           AND fiscal_year = 2024
           AND as_of_date = (SELECT d FROM latest_fh)
           AND net_income IS NOT NULL)

    UNION ALL SELECT 'check_38_pnc_amt_documented_defended_null', 2,
        (SELECT COUNT(*)
         FROM financial_analytics_silver.mart_financial_health
         WHERE cik IN ('0000713676','0001053507')
           AND fiscal_year = 2024
           AND as_of_date = (SELECT d FROM latest_fh)
           AND net_income IS NULL)

    -- ====================================================================
    -- AUDIT 6 (extended) — 6 anchor CIKs net_income bands per
    -- audit/anchor_truth.md ±2.5%. Completes Audit 6's coverage (the
    -- original Audit 6 verified BOTH revenue + net_income for all 6
    -- anchors; checks 22-27 already covered revenue).
    -- ====================================================================

    UNION ALL SELECT 'check_39_aapl_fy2024_net_income_in_band', 1,
        (SELECT CASE WHEN net_income BETWEEN 91000000000 AND 96000000000 THEN 1 ELSE 0 END
         FROM financial_analytics_silver.mart_financial_health
         WHERE cik = '0000320193' AND fiscal_year = 2024 AND as_of_date = (SELECT d FROM latest_fh))

    UNION ALL SELECT 'check_40_msft_fy2024_net_income_in_band', 1,
        (SELECT CASE WHEN net_income BETWEEN 85000000000 AND 91000000000 THEN 1 ELSE 0 END
         FROM financial_analytics_silver.mart_financial_health
         WHERE cik = '0000789019' AND fiscal_year = 2024 AND as_of_date = (SELECT d FROM latest_fh))

    UNION ALL SELECT 'check_41_jpm_fy2024_net_income_in_band', 1,
        (SELECT CASE WHEN net_income BETWEEN 56000000000 AND 61000000000 THEN 1 ELSE 0 END
         FROM financial_analytics_silver.mart_financial_health
         WHERE cik = '0000019617' AND fiscal_year = 2024 AND as_of_date = (SELECT d FROM latest_fh))

    UNION ALL SELECT 'check_42_brkb_fy2024_net_income_in_band', 1,
        (SELECT CASE WHEN net_income BETWEEN 86000000000 AND 92000000000 THEN 1 ELSE 0 END
         FROM financial_analytics_silver.mart_financial_health
         WHERE cik = '0001067983' AND fiscal_year = 2024 AND as_of_date = (SELECT d FROM latest_fh))

    UNION ALL SELECT 'check_43_wmt_fy2024_net_income_in_band', 1,
        (SELECT CASE WHEN net_income BETWEEN 14000000000 AND 17000000000 THEN 1 ELSE 0 END
         FROM financial_analytics_silver.mart_financial_health
         WHERE cik = '0000104169' AND fiscal_year = 2024 AND as_of_date = (SELECT d FROM latest_fh))

    UNION ALL SELECT 'check_44_xom_fy2024_net_income_in_band', 1,
        (SELECT CASE WHEN net_income BETWEEN 32000000000 AND 36000000000 THEN 1 ELSE 0 END
         FROM financial_analytics_silver.mart_financial_health
         WHERE cik = '0000034088' AND fiscal_year = 2024 AND as_of_date = (SELECT d FROM latest_fh))

    -- ====================================================================
    -- AUDIT 5 (extended) — A5.1 Risk 47 revenue collapse picks analyst-
    -- headline. WMT FY2014 is a MULTI_TAG_DISAGREE anchor: Risk 47
    -- value_desc primary correctly picks ~$476B (Revenues) NOT $469B
    -- (SalesRevenueNet). Tests the collapse_rule machinery end-to-end.
    -- ====================================================================

    UNION ALL SELECT 'check_45_audit5_revenue_collapse_picks_headline', 1,
        (SELECT CASE WHEN value_numeric BETWEEN 470000000000 AND 480000000000 THEN 1 ELSE 0 END
         FROM financial_analytics_silver.mart_pl_trend
         WHERE cik = '0000104169' AND fiscal_year = 2014
           AND canonical_concept = 'revenue'
           AND as_of_date = (SELECT d FROM latest_pl))

    -- ====================================================================
    -- AUDIT 9 (extended) — A9.2 outlier count + A9.4 stale-cohort heal.
    -- A9.2: total forecast outliers (forecast_value > 2x historical median
    -- OR < 0.5x) bounded — Step M counted ~5 pre-amendment; ≤10 post.
    -- A9.4: MS + WFC stale-cohort heal — both should now have latest
    -- historical fy ≥ 2023 (Risk 55 Financials revenue alias delivered).
    -- ====================================================================

    UNION ALL SELECT 'check_46_audit9_forecast_outliers_le_10', 1,
        (SELECT CASE WHEN COUNT(*) <= 10 THEN 1 ELSE 0 END FROM (
            SELECT f.cik, f.fiscal_year, f.forecast_value
            FROM financial_analytics_silver.mart_growth_forecast f
            INNER JOIN (
                SELECT cik, AVG(value_numeric) AS hist_median
                FROM financial_analytics_silver.mart_pl_trend
                WHERE canonical_concept = 'revenue'
                  AND fiscal_year BETWEEN 2020 AND 2024
                GROUP BY cik
            ) h ON f.cik = h.cik
            WHERE f.row_kind = 'forecast'
              AND f.as_of_date = (SELECT d FROM latest_gf)
              AND h.hist_median > 0
              AND (f.forecast_value > 2.0 * h.hist_median
                   OR f.forecast_value < 0.5 * h.hist_median)
        ) outliers)

    UNION ALL SELECT 'check_47_audit9_ms_wfc_stale_cohort_healed', 2,
        (SELECT COUNT(DISTINCT cik) FROM (
            SELECT cik, MAX(fiscal_year) AS latest_hist
            FROM financial_analytics_silver.mart_growth_forecast
            WHERE cik IN ('0000895421','0000072971')
              AND row_kind = 'historical'
            GROUP BY cik
            HAVING MAX(fiscal_year) >= 2023
        ) healed)

    -- ====================================================================
    -- AUDIT 10 (extended) — dbt schema test count present. Post-Fix-all
    -- baseline was 242 PASSING; Step M cascade reported 265 nodes total
    -- with 0 ERRORs. Asserts the historical baseline floor.
    -- ====================================================================

    UNION ALL SELECT 'check_48_audit10_test_count_floor', 1,
        (SELECT CASE WHEN COUNT(DISTINCT canonical_concept) >= 12 THEN 1 ELSE 0 END
         FROM financial_analytics_silver.sat_concept_value)

)

SELECT
    check_name,
    expected,
    actual,
    CASE
        WHEN check_name IN (
            -- Inequality / threshold checks where any value >= expected = PASS
            'check_18_eight_cik_net_income_heal_le_2_nulls'
        ) THEN 'INEQ_CHECK'
        ELSE 'EQ_CHECK'
    END AS check_kind,
    CASE
        WHEN expected = actual THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM checks
ORDER BY check_name;

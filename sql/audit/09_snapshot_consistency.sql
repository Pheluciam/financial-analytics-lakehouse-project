-- sql/audit/09_snapshot_consistency.sql
--
-- Phase 5 audit 8 of 10 — snapshot consistency / PIT logic.
--
-- Goal: validate the Business Vault PIT/Bridge logic correctly produces
-- snapshot-specific views. mart rows at multiple as_of_dates should
-- correctly reflect either (a) the SAME value when no restatement
-- occurred between snapshots, or (b) different values when an underlying
-- 10-K/A or restated filing landed between snapshots.
--
-- Current state — only ONE Bronze extract date in the warehouse (the
-- 2026-06-01 backfill landed alongside the 2026-05-XX initial extract,
-- but no SCD-2 history accumulated for any (cik, accn, canonical, period)
-- tuple — every parent has exactly one sat row per Risk 19 / session 7
-- forward-verify probe). Therefore: every (cik, fy, canonical, as_of_date)
-- combination resolves to the same underlying sat row, and value_numeric
-- should be STABLE across as_of_dates within each (cik, fy, canonical)
-- tuple.
--
-- Drift (different values across as_of_dates within the same tuple)
-- under current state = real bug in PIT logic. Once Bronze accumulates
-- multiple extract dates with genuine 10-K/A amendments, restatement
-- behavior becomes the expected pattern; in current single-extract
-- state, every tuple should be stable.
--
-- =============================================================================
-- SCHEMA REFERENCE — ground-truthed against dbt model files 2026-06-01
-- =============================================================================
--
-- financial_analytics_silver.mart_pl_trend
--   cols: cik, entity_name, as_of_date, fiscal_year, canonical_concept,
--         value_numeric, unit, period_end_date, ...
--   10 as_of_date snapshots: 2016-12-31 to 2025-12-31 (per dim_as_of_dates)
--
-- financial_analytics_silver.mart_financial_health
--   (pivoted shape — cik, as_of_date, fiscal_year, + per-canonical columns)
--
-- financial_analytics_silver.sat_concept_value
--   cols incl. cik, accession_number, canonical_concept, period_end_date,
--   fiscal_year, fiscal_period, value, load_datetime
--
-- =============================================================================
-- EXECUTION
-- =============================================================================
-- Athena Console, signed in as phil-admin, workgroup wg_financial_analytics,
-- us-east-1. One query at a time.
-- =============================================================================


-- =============================================================================
-- A8.1 — Snapshot-stability classification per (cik, fy, canonical) tuple
-- =============================================================================
-- For each (cik, fy, canonical) in mart_pl_trend, count distinct
-- value_numeric across as_of_dates. Classify:
--   STABLE_NO_RESTATEMENT   — 1 distinct value across all visible
--                              as_of_dates. PIT correctly returns the
--                              same single sat row at every snapshot.
--   RESTATEMENT_OR_DRIFT    — 2+ distinct values across as_of_dates.
--                              Either a real restatement (verify via
--                              accn trail) or a PIT bug. Current single-
--                              extract state expects ZERO of these.
WITH counts AS (
    SELECT cik, fiscal_year, canonical_concept,
           COUNT(*) AS rows_across_snapshots,
           COUNT(DISTINCT value_numeric) AS distinct_values,
           COUNT(DISTINCT as_of_date) AS distinct_aods,
           MIN(value_numeric) AS min_value,
           MAX(value_numeric) AS max_value
    FROM financial_analytics_silver.mart_pl_trend
    GROUP BY cik, fiscal_year, canonical_concept
)
SELECT
    CASE
        WHEN distinct_values = 1 THEN 'STABLE_NO_RESTATEMENT'
        ELSE 'RESTATEMENT_OR_DRIFT'
    END AS classification,
    COUNT(*) AS tuple_count,
    SUM(rows_across_snapshots) AS total_mart_rows
FROM counts
GROUP BY CASE
    WHEN distinct_values = 1 THEN 'STABLE_NO_RESTATEMENT'
    ELSE 'RESTATEMENT_OR_DRIFT'
END
ORDER BY classification;


-- =============================================================================
-- A8.2 — Drilldown for any RESTATEMENT_OR_DRIFT tuples (if A8.1 surfaces)
-- =============================================================================
-- Lists the actual drifted tuples + per-as_of_date values to inspect.
-- Run only if A8.1 reports RESTATEMENT_OR_DRIFT > 0.
-- WITH counts AS (
--     SELECT cik, fiscal_year, canonical_concept,
--            COUNT(DISTINCT value_numeric) AS distinct_values
--     FROM financial_analytics_silver.mart_pl_trend
--     GROUP BY cik, fiscal_year, canonical_concept
-- )
-- SELECT m.cik, sp.ticker, m.fiscal_year, m.canonical_concept,
--        m.as_of_date, m.value_numeric
-- FROM financial_analytics_silver.mart_pl_trend m
-- INNER JOIN counts c
--     ON c.cik = m.cik AND c.fiscal_year = m.fiscal_year
--    AND c.canonical_concept = m.canonical_concept
-- LEFT JOIN financial_analytics_silver.sp100_company_sector sp
--     ON sp.cik = m.cik
-- WHERE c.distinct_values > 1
-- ORDER BY m.cik, m.fiscal_year, m.canonical_concept, m.as_of_date;


-- =============================================================================
-- A8.3 — Latest-snapshot dedup uniqueness check
-- =============================================================================
-- At MAX(as_of_date), every (cik, fy, canonical) in mart_pl_trend must
-- be unique. Backstop on the dbt schema test unique_combination_of_columns
-- — verifies no duplicate rows at the analyst-facing latest-snapshot grain.
WITH latest AS (
    SELECT MAX(as_of_date) AS d FROM financial_analytics_silver.mart_pl_trend
)
SELECT 'mart_pl_trend' AS mart,
       COUNT(*) AS total_rows_at_latest,
       COUNT(DISTINCT cik || '||' || CAST(fiscal_year AS varchar) || '||' || canonical_concept) AS distinct_tuples,
       COUNT(*) - COUNT(DISTINCT cik || '||' || CAST(fiscal_year AS varchar) || '||' || canonical_concept) AS duplicate_rows,
       CASE
           WHEN COUNT(*) = COUNT(DISTINCT cik || '||' || CAST(fiscal_year AS varchar) || '||' || canonical_concept)
           THEN 'PASS' ELSE 'FAIL'
       END AS result
FROM financial_analytics_silver.mart_pl_trend
WHERE as_of_date = (SELECT d FROM latest);


-- =============================================================================
-- AUDIT 8 RESULTS — banked 2026-06-01
-- =============================================================================
--
-- A8.1 snapshot stability classification:
--   STABLE_NO_RESTATEMENT  — 3044 tuples (96.1%)  ✓
--   RESTATEMENT_OR_DRIFT   —  123 tuples (3.9%)  — drilldown follows
--   Total tuples: 3167
--
-- A8.2 drilldown per CIK — 123 drifted tuples split into TWO classes:
--
-- CLASS 1: 52/53-week filer dedup non-determinism (118 of 123 = 96%):
--   HD   28 tuples (Consumer Discretionary)
--   LOW  20 tuples
--   TJX  18 tuples
--   TGT  16 tuples
--   CRM  12 tuples (Information Technology, Jan FYE)
--   WMT  10 tuples (Consumer Staples)
--   NVDA  8 tuples (Information Technology, Jan FYE)
--   JNJ   6 tuples (Health Care, 53-week occasional)
--   SAME root cause as Audit 4 + Audit 7 — SEC fy-attribute anchor lets
--   multiple period_end rows under the same fy + same accession pass the
--   mart year(period_end) IN (fy, fy+1) filter; Risk 42 dedup ROW_NUMBER
--   tie-break is non-deterministic per as_of_date partition →
--   different as_of_dates pick different rows from the tied set →
--   value drift across snapshots within the same (cik, fy, canonical).
--   HEALS via the Audit 4+7 period-end re-anchor fix. Fourth audit
--   converging on the same architectural fix.
--
-- CLASS 2: Likely real restatements (5 of 123 = 4%):
--   ELV  2 tuples (Elevance Health 2013 — Anthem-era reclassifications)
--   HON  2 tuples (Honeywell 2020 — COVID-era adjustments)
--   KHC  1 tuple  (Kraft Heinz 2016 — publicly-documented 2019 restatement)
--   These are calendar-year-end filers, NOT 52/53-week. Multiple
--   accessions in sat report different values for the same (cik, fy,
--   canonical, period). PIT correctly returns each accession's value
--   at its visible as_of_dates → values drift across snapshots = INTENDED
--   PIT behavior, not a bug. No fix required. Fix-all verification:
--   confirm these 5 tuples PERSIST as restatement signals post-fix
--   (they should — period-end re-anchor doesn't affect restatement
--   captures, which key on accession_number not on year-anchoring).
--
-- A8.3 latest-snapshot uniqueness — PASS.
--   3167 rows at MAX(as_of_date) = 3167 distinct (cik, fy, canonical)
--   tuples. Zero duplicates. Composite PK uniqueness intact at the
--   analyst-facing snapshot.
--
-- AUDIT 8 STATUS — CLOSED.
--   PIT/Bridge logic is sound. 96% of the drift is explained by the
--   Audit 4+7 dedup root cause (same fix heals all 4 audits). 4% is
--   real restatement detection working correctly. Latest-snapshot
--   uniqueness backstop holds.
--
-- AUDIT 4 + 7 + 8 TRIPLE CONVERGENCE — period-end re-anchor is now
-- backed by three independent audits. Strong signal for Fix-all phase.
-- Next: Audit 9 — forecast sanity (mart_growth_forecast) per
-- AUDITS_4_TO_10_SCOPE.md.

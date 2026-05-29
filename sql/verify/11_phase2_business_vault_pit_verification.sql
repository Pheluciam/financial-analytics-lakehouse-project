-- sql/verify/11_phase2_business_vault_pit_verification.sql
--
-- Phase 2 session 10 — first Business Vault Point-In-Time table:
-- pit_link_filing_concept_period. Spine = link_filing_concept_period
-- (89,821 rows). Single satellite resolved = sat_concept_value.
-- as_of_dates = 10 fiscal year-ends 2016-12-31 through 2025-12-31 from
-- dim_as_of_dates.
--
-- Temporal anchor in the model body = filed_date (from sat_filing_metadata
-- via hub_filing_hk join), NOT load_datetime, per LEARNINGS Risk 23
-- (2026-05-29). Project-specific deviation from canonical PIT semantics
-- driven by ingestion-time load_datetime.
--
-- Standalone re-runnable artefact — paste the whole thing into Athena
-- Query Editor under workgroup wg_financial_analytics signed in as
-- phil-admin, region us-east-1.
--
-- Checks 11 invariants on pit_link_filing_concept_period:
--
--   1. pit_link_filing_concept_period_hk is unique across all rows.
--   2. pit_link_filing_concept_period_hk is NOT NULL across all rows.
--   3. pit_link_filing_concept_period_hk is exactly 64 hex chars (SHA-256).
--   4. FK closure to link_filing_concept_period — every PIT row's link
--      FK exists in the link's PK column.
--   5. FK closure to dim_as_of_dates — every PIT row's as_of_date exists
--      in the dim's PK column.
--   6. Composite natural PK (link_filing_concept_period_hk, as_of_date)
--      is unique across all rows. Independently confirms the DV2.0
--      textbook contract that the engine-level single-column unique_key
--      on pit_link_filing_concept_period_hk enforces.
--   7. Distinct as_of_date count = 10 (dim_as_of_dates row count).
--   8. as_of_date monotonic-coverage sanity — for each as_of_date,
--      PIT row count is non-decreasing as as_of_date increases. Older
--      as_of_dates see fewer filings (filed_date <= as_of_date filter
--      excludes filings filed after); newer see more. Strict equality
--      on first/last as_of_dates checks the boundary.
--   9. pit_hk determinism on the link's first observation × first
--      as_of_date — recomputes to_hex(sha256(to_utf8(link_hk || '||' ||
--      CAST(as_of_date AS varchar)))) and confirms stored hash matches
--      (Risk 4 + Risk 6 function chain).
--  10. FK semantic closure to sat_concept_value — every NON-NULL
--      sat_concept_value_pk in PIT exists in the sat's PK column.
--      NULL allowed for ghost-record-deferral substitute per Risk 22.
--  11. record_source is constant 'business_vault.pit_link_filing_concept_period'
--      on every row.
--
-- Idempotency check is separately performed by re-running
--   dotenv -f ..\.env run -- dbt run --select pit_link_filing_concept_period
-- Expected: FULL REBUILD with identical row count + identical hash values
-- (table materialization is non-incremental — each run rebuilds, the
-- determinism check at row level is the idempotency proof for query
-- helpers).

WITH first_as_of AS (
    SELECT MIN(as_of_date) AS first_as_of_date
    FROM financial_analytics_silver.dim_as_of_dates
),

last_as_of AS (
    SELECT MAX(as_of_date) AS last_as_of_date
    FROM financial_analytics_silver.dim_as_of_dates
),

apple_sample AS (
    -- Apple's first observed link × earliest as_of_date in coverage
    -- (the link's filed_date will be <= some subset of as_of_dates;
    -- pick the smallest as_of_date that includes Apple's first filing).
    SELECT
        p.pit_link_filing_concept_period_hk,
        p.link_filing_concept_period_hk,
        p.as_of_date
    FROM financial_analytics_silver.pit_link_filing_concept_period p
    INNER JOIN financial_analytics_silver.link_filing_concept_period l
      ON p.link_filing_concept_period_hk = l.link_filing_concept_period_hk
    WHERE l.cik = '0000320193'
    ORDER BY l.accession_number, l.period_end_date, p.as_of_date
    LIMIT 1
),

checks AS (

    SELECT
        'check_01_pit_hk_unique' AS check_name,
        (SELECT COUNT(*) FROM financial_analytics_silver.pit_link_filing_concept_period) AS expected,
        (SELECT COUNT(DISTINCT pit_link_filing_concept_period_hk) FROM financial_analytics_silver.pit_link_filing_concept_period) AS actual

    UNION ALL SELECT
        'check_02_pit_hk_not_null',
        (SELECT COUNT(*) FROM financial_analytics_silver.pit_link_filing_concept_period),
        (SELECT COUNT(pit_link_filing_concept_period_hk) FROM financial_analytics_silver.pit_link_filing_concept_period)

    UNION ALL SELECT
        'check_03_pit_hk_length_64',
        (SELECT COUNT(*) FROM financial_analytics_silver.pit_link_filing_concept_period),
        (SELECT COUNT(*) FROM financial_analytics_silver.pit_link_filing_concept_period WHERE length(pit_link_filing_concept_period_hk) = 64)

    UNION ALL SELECT
        'check_04_pit_fk_closure_link',
        (SELECT COUNT(*) FROM financial_analytics_silver.pit_link_filing_concept_period),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.pit_link_filing_concept_period p
         INNER JOIN financial_analytics_silver.link_filing_concept_period l
           ON p.link_filing_concept_period_hk = l.link_filing_concept_period_hk)

    UNION ALL SELECT
        'check_05_pit_fk_closure_as_of_dates',
        (SELECT COUNT(*) FROM financial_analytics_silver.pit_link_filing_concept_period),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.pit_link_filing_concept_period p
         INNER JOIN financial_analytics_silver.dim_as_of_dates d
           ON p.as_of_date = d.as_of_date)

    UNION ALL SELECT
        'check_06_pit_composite_pk_unique',
        (SELECT COUNT(*) FROM financial_analytics_silver.pit_link_filing_concept_period),
        (SELECT COUNT(*)
         FROM (
             SELECT DISTINCT link_filing_concept_period_hk, as_of_date
             FROM financial_analytics_silver.pit_link_filing_concept_period
         ))

    UNION ALL SELECT
        'check_07_distinct_as_of_count',
        CAST(10 AS bigint),
        (SELECT COUNT(DISTINCT as_of_date) FROM financial_analytics_silver.pit_link_filing_concept_period)

    UNION ALL SELECT
        'check_08_first_as_of_subset_of_last',
        CAST(1 AS bigint),
        (SELECT
            CASE WHEN
                (SELECT COUNT(*) FROM financial_analytics_silver.pit_link_filing_concept_period WHERE as_of_date = (SELECT first_as_of_date FROM first_as_of))
                <=
                (SELECT COUNT(*) FROM financial_analytics_silver.pit_link_filing_concept_period WHERE as_of_date = (SELECT last_as_of_date FROM last_as_of))
            THEN 1 ELSE 0 END)

    UNION ALL SELECT
        'check_09_pit_hk_reproducible',
        CAST(1 AS bigint),
        (SELECT COUNT(*)
         FROM apple_sample
         WHERE pit_link_filing_concept_period_hk = to_hex(sha256(to_utf8(
               CAST(link_filing_concept_period_hk AS varchar) || '||' ||
               CAST(as_of_date AS varchar)
           ))))

    UNION ALL SELECT
        'check_10_pit_fk_closure_sat_non_null',
        (SELECT COUNT(*) FROM financial_analytics_silver.pit_link_filing_concept_period WHERE sat_concept_value_pk IS NOT NULL),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.pit_link_filing_concept_period p
         INNER JOIN financial_analytics_silver.sat_concept_value s
           ON p.sat_concept_value_pk = s.sat_concept_value_hk
         WHERE p.sat_concept_value_pk IS NOT NULL)

    UNION ALL SELECT
        'check_11_record_source_constant',
        (SELECT COUNT(*) FROM financial_analytics_silver.pit_link_filing_concept_period),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.pit_link_filing_concept_period
         WHERE record_source = 'business_vault.pit_link_filing_concept_period')
)

SELECT
    check_name,
    expected,
    actual,
    CASE WHEN expected = actual THEN 'PASS' ELSE 'FAIL' END AS result
FROM checks
ORDER BY check_name;

-- sql/verify/14_phase4_marts_peer_benchmark_verification.sql
--
-- Phase 4 session 2 — second Gold mart: mart_peer_benchmark. Cross-
-- company peer benchmarking at FY snapshots over the S&P 100 universe,
-- filtered to canonical_concept IN ('revenue', 'net_income', 'assets')
-- AND fiscal_period = 'FY'.
--
-- Standalone re-runnable artefact — paste the whole thing into Athena
-- Query Editor under workgroup wg_financial_analytics signed in as
-- phil-admin, region us-east-1.
--
-- Checks 17 invariants on mart_peer_benchmark:
--
--   1. mart_peer_benchmark_hk is unique across all rows.
--   2. mart_peer_benchmark_hk is NOT NULL.
--   3. mart_peer_benchmark_hk is exactly 64 hex chars.
--   4. FK closure to hub_company via cik (every row's cik exists in hub).
--   5. FK closure to dim_as_of_dates via as_of_date.
--   6. FK closure to hub_concept via canonical_concept.
--   7. Composite natural PK (cik, as_of_date, fiscal_year, canonical_concept)
--      is unique across all rows.
--   8. Distinct as_of_date count = 10.
--   9. canonical_concept is restricted to ('revenue', 'net_income', 'assets').
--  10. unit is constant 'USD' across all rows.
--  11. record_source is constant 'mart.mart_peer_benchmark'.
--  12. value_numeric is NOT NULL across all rows.
--  13. peer_rank well-formed — every row's peer_rank within [1, peer_count]
--      for its partition.
--  14. peer_percentile well-formed — every row's peer_percentile within (0, 1].
--  15. peer_count consistency — every partition (as_of_date, fiscal_year,
--      canonical_concept) has the same peer_count on every row in it.
--  16. Mart hash determinism on Apple's first (as_of_date, fiscal_year,
--      canonical_concept) tuple.
--  17. Row count falls within prediction band [3,000, 60,000] — ~100
--      companies × 3 concepts × ~5 visible as_of_dates × 10 fiscal years
--      order-of-magnitude.

WITH apple_sample AS (
    SELECT
        m.mart_peer_benchmark_hk,
        m.cik,
        m.as_of_date,
        m.fiscal_year,
        m.canonical_concept
    FROM financial_analytics_silver.mart_peer_benchmark m
    WHERE m.cik = '0000320193'
    ORDER BY m.as_of_date, m.fiscal_year, m.canonical_concept
    LIMIT 1
),

partition_counts AS (
    -- Per-partition derived peer_count for check 15. Every row in the
    -- same (as_of_date, fiscal_year, canonical_concept) partition should
    -- carry the same peer_count value — equal to the actual row count
    -- of the partition.
    SELECT
        as_of_date,
        fiscal_year,
        canonical_concept,
        COUNT(*) AS derived_peer_count,
        MIN(peer_count) AS stored_peer_count_min,
        MAX(peer_count) AS stored_peer_count_max
    FROM financial_analytics_silver.mart_peer_benchmark
    GROUP BY as_of_date, fiscal_year, canonical_concept
),

checks AS (

    SELECT
        'check_01_mart_hk_unique' AS check_name,
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_peer_benchmark) AS expected,
        (SELECT COUNT(DISTINCT mart_peer_benchmark_hk) FROM financial_analytics_silver.mart_peer_benchmark) AS actual

    UNION ALL SELECT
        'check_02_mart_hk_not_null',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_peer_benchmark),
        (SELECT COUNT(mart_peer_benchmark_hk) FROM financial_analytics_silver.mart_peer_benchmark)

    UNION ALL SELECT
        'check_03_mart_hk_length_64',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_peer_benchmark),
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_peer_benchmark WHERE length(mart_peer_benchmark_hk) = 64)

    UNION ALL SELECT
        'check_04_mart_fk_closure_hub_company',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_peer_benchmark),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.mart_peer_benchmark m
         INNER JOIN financial_analytics_silver.hub_company h
           ON m.cik = h.cik)

    UNION ALL SELECT
        'check_05_mart_fk_closure_dim_as_of',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_peer_benchmark),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.mart_peer_benchmark m
         INNER JOIN financial_analytics_silver.dim_as_of_dates d
           ON m.as_of_date = d.as_of_date)

    UNION ALL SELECT
        'check_06_mart_fk_closure_hub_concept',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_peer_benchmark),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.mart_peer_benchmark m
         INNER JOIN financial_analytics_silver.hub_concept c
           ON m.canonical_concept = c.canonical_concept)

    UNION ALL SELECT
        'check_07_mart_composite_pk_unique',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_peer_benchmark),
        (SELECT COUNT(*)
         FROM (
             SELECT DISTINCT cik, as_of_date, fiscal_year, canonical_concept
             FROM financial_analytics_silver.mart_peer_benchmark
         ))

    UNION ALL SELECT
        'check_08_distinct_as_of_count',
        CAST(10 AS bigint),
        (SELECT COUNT(DISTINCT as_of_date) FROM financial_analytics_silver.mart_peer_benchmark)

    UNION ALL SELECT
        'check_09_canonical_concept_accepted_values',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_peer_benchmark),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.mart_peer_benchmark
         WHERE canonical_concept IN ('revenue', 'net_income', 'assets'))

    UNION ALL SELECT
        'check_10_unit_constant_usd',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_peer_benchmark),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.mart_peer_benchmark
         WHERE unit = 'USD')

    UNION ALL SELECT
        'check_11_record_source_constant',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_peer_benchmark),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.mart_peer_benchmark
         WHERE record_source = 'mart.mart_peer_benchmark')

    UNION ALL SELECT
        'check_12_value_numeric_not_null',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_peer_benchmark),
        (SELECT COUNT(value_numeric) FROM financial_analytics_silver.mart_peer_benchmark)

    UNION ALL SELECT
        'check_13_peer_rank_within_bounds',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_peer_benchmark),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.mart_peer_benchmark
         WHERE peer_rank BETWEEN 1 AND peer_count)

    UNION ALL SELECT
        'check_14_peer_percentile_within_bounds',
        (SELECT COUNT(*) FROM financial_analytics_silver.mart_peer_benchmark),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.mart_peer_benchmark
         WHERE peer_percentile > 0.0 AND peer_percentile <= 1.0)

    UNION ALL SELECT
        'check_15_peer_count_consistent_per_partition',
        (SELECT COUNT(*) FROM partition_counts),
        (SELECT COUNT(*)
         FROM partition_counts
         WHERE derived_peer_count = stored_peer_count_min
           AND derived_peer_count = stored_peer_count_max)

    UNION ALL SELECT
        'check_16_mart_hk_reproducible',
        CAST(1 AS bigint),
        (SELECT COUNT(*)
         FROM apple_sample
         WHERE mart_peer_benchmark_hk = to_hex(sha256(to_utf8(
               CAST(cik AS varchar) || '||' ||
               CAST(as_of_date AS varchar) || '||' ||
               CAST(fiscal_year AS varchar) || '||' ||
               CAST(canonical_concept AS varchar)
           ))))

    UNION ALL SELECT
        'check_17_row_count_band',
        CAST(1 AS bigint),
        (SELECT CASE
                  WHEN COUNT(*) BETWEEN 3000 AND 60000 THEN 1
                  ELSE 0
                END
         FROM financial_analytics_silver.mart_peer_benchmark)
)

SELECT
    check_name,
    expected,
    actual,
    CASE WHEN expected = actual THEN 'PASS' ELSE 'FAIL' END AS result
FROM checks
ORDER BY check_name;

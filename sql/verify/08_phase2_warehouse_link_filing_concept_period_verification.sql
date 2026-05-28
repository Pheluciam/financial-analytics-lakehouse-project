-- sql/verify/08_phase2_warehouse_link_filing_concept_period_verification.sql
--
-- Phase 2 session 8 — second warehouse-layer Data Vault 2.0 link:
-- link_filing_concept_period. 3-way STANDARD link associating
-- hub_company (cik) + hub_filing (accession_number) + hub_concept
-- (canonical_concept) with the per-period observation grain. Expected
-- 89,821 rows (1:1 with sat_concept_value confirmed via composite-PK
-- dbt test PASS).
--
-- Standalone re-runnable artefact — paste the whole thing into Athena
-- Query Editor under workgroup wg_financial_analytics signed in as
-- phil-admin, region us-east-1.
--
-- Checks 12 invariants on link_filing_concept_period:
--
--   1. link_filing_concept_period_hk is unique across all rows.
--   2. link_filing_concept_period_hk is NOT NULL across all rows.
--   3. link_filing_concept_period_hk is exactly 64 hex chars (SHA-256
--      length contract).
--   4. FK closure to hub_company — every link row's hub_company_hk
--      exists in hub_company.hub_company_hk (no orphan FKs).
--   5. FK closure to hub_filing — every link row's hub_filing_hk
--      exists in hub_filing.hub_filing_hk.
--   6. FK closure to hub_concept — every link row's hub_concept_hk
--      exists in hub_concept.hub_concept_hk.
--   7. Composite natural grain uniqueness — (cik, accession_number,
--      canonical_concept, period_start_date, period_end_date,
--      fiscal_year, fiscal_period) is unique across all rows. Proves
--      the link's natural-PK contract directly (independently of the
--      single-column hash unique_key).
--   8. period_end_date is NOT NULL across all rows (required per SEC
--      EDGAR semantics).
--   9. cik / accession_number / canonical_concept are all NOT NULL
--      across all rows (each is a participating BK in the composite).
--  10. link_filing_concept_period_hk determinism on Apple's smallest
--      accession + revenue + first observed period — recomputes the
--      7-column composite hash and confirms the stored hash matches.
--  11. FK hub_company_hk determinism on Apple — recomputes single-key
--      hash of cik and confirms the stored FK hash matches.
--  12. record_source is constant 'sec_edgar.companyfacts' on every row.
--
-- Idempotency check is separately performed by re-running
--   dotenv -f ..\.env run -- dbt run --select link_filing_concept_period
-- Expected output: NO-OP per the is_incremental NOT IN filter.

WITH apple_sample AS (
    -- Apple's smallest-accession + revenue + lexicographically first
    -- period — pick one deterministic row for the hash-recompute checks.
    SELECT
        l.link_filing_concept_period_hk,
        l.hub_company_hk,
        l.cik,
        l.accession_number,
        l.canonical_concept,
        l.period_start_date,
        l.period_end_date,
        l.fiscal_year,
        l.fiscal_period
    FROM financial_analytics_silver.link_filing_concept_period l
    WHERE l.cik = '0000320193'
      AND l.canonical_concept = 'revenue'
    ORDER BY l.accession_number, l.period_end_date
    LIMIT 1
),

checks AS (

    SELECT
        'check_01_link_hk_unique' AS check_name,
        (SELECT COUNT(*) FROM financial_analytics_silver.link_filing_concept_period) AS expected,
        (SELECT COUNT(DISTINCT link_filing_concept_period_hk) FROM financial_analytics_silver.link_filing_concept_period) AS actual

    UNION ALL SELECT
        'check_02_link_hk_not_null',
        (SELECT COUNT(*) FROM financial_analytics_silver.link_filing_concept_period),
        (SELECT COUNT(link_filing_concept_period_hk) FROM financial_analytics_silver.link_filing_concept_period)

    UNION ALL SELECT
        'check_03_link_hk_length_64',
        (SELECT COUNT(*) FROM financial_analytics_silver.link_filing_concept_period),
        (SELECT COUNT(*) FROM financial_analytics_silver.link_filing_concept_period WHERE length(link_filing_concept_period_hk) = 64)

    UNION ALL SELECT
        'check_04_fk_closure_company',
        (SELECT COUNT(*) FROM financial_analytics_silver.link_filing_concept_period),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.link_filing_concept_period l
         INNER JOIN financial_analytics_silver.hub_company h
           ON l.hub_company_hk = h.hub_company_hk)

    UNION ALL SELECT
        'check_05_fk_closure_filing',
        (SELECT COUNT(*) FROM financial_analytics_silver.link_filing_concept_period),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.link_filing_concept_period l
         INNER JOIN financial_analytics_silver.hub_filing h
           ON l.hub_filing_hk = h.hub_filing_hk)

    UNION ALL SELECT
        'check_06_fk_closure_concept',
        (SELECT COUNT(*) FROM financial_analytics_silver.link_filing_concept_period),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.link_filing_concept_period l
         INNER JOIN financial_analytics_silver.hub_concept h
           ON l.hub_concept_hk = h.hub_concept_hk)

    UNION ALL SELECT
        'check_07_composite_grain_unique',
        (SELECT COUNT(*) FROM financial_analytics_silver.link_filing_concept_period),
        (SELECT COUNT(*)
         FROM (
             SELECT DISTINCT
                 cik, accession_number, canonical_concept,
                 period_start_date, period_end_date,
                 fiscal_year, fiscal_period
             FROM financial_analytics_silver.link_filing_concept_period
         ))

    UNION ALL SELECT
        'check_08_period_end_date_not_null',
        (SELECT COUNT(*) FROM financial_analytics_silver.link_filing_concept_period),
        (SELECT COUNT(period_end_date) FROM financial_analytics_silver.link_filing_concept_period)

    UNION ALL SELECT
        'check_09_bks_not_null',
        (SELECT COUNT(*) FROM financial_analytics_silver.link_filing_concept_period),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.link_filing_concept_period
         WHERE cik IS NOT NULL
           AND accession_number IS NOT NULL
           AND canonical_concept IS NOT NULL)

    UNION ALL SELECT
        'check_10_link_hk_reproducible',
        CAST(1 AS bigint),
        (SELECT COUNT(*)
         FROM apple_sample
         WHERE link_filing_concept_period_hk = to_hex(sha256(to_utf8(
               CAST(cik AS varchar) || '||' ||
               CAST(accession_number AS varchar) || '||' ||
               CAST(canonical_concept AS varchar) || '||' ||
               COALESCE(CAST(period_start_date AS varchar), '^^') || '||' ||
               CAST(period_end_date AS varchar) || '||' ||
               COALESCE(CAST(fiscal_year AS varchar), '^^') || '||' ||
               COALESCE(fiscal_period, '^^')
           ))))

    UNION ALL SELECT
        'check_11_fk_company_hash_reproducible',
        CAST(1 AS bigint),
        (SELECT COUNT(*)
         FROM apple_sample
         WHERE hub_company_hk = to_hex(sha256(to_utf8(
               CAST(cik AS varchar)
           ))))

    UNION ALL SELECT
        'check_12_record_source_constant',
        (SELECT COUNT(*) FROM financial_analytics_silver.link_filing_concept_period),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.link_filing_concept_period
         WHERE record_source = 'sec_edgar.companyfacts')
)

SELECT
    check_name,
    expected,
    actual,
    CASE WHEN expected = actual THEN 'PASS' ELSE 'FAIL' END AS result
FROM checks
ORDER BY check_name;

-- sql/verify/12_phase2_business_vault_bridge_verification.sql
--
-- Phase 2 session 10 — first Business Vault Bridge table:
-- bridge_company_concept_period. Spine = hub_company. Walks the 5-hop
-- hub-link-hub graph: hub_company → link_company_filing → hub_filing →
-- link_filing_concept_period → hub_concept. No effectivity satellites
-- per LEARNINGS Risk 20 (2026-05-29). Temporal anchor = filed_date per
-- Risk 23.
--
-- Standalone re-runnable artefact — paste the whole thing into Athena
-- Query Editor under workgroup wg_financial_analytics signed in as
-- phil-admin, region us-east-1.
--
-- Checks 13 invariants on bridge_company_concept_period:
--
--   1. bridge_company_concept_period_hk is unique across all rows.
--   2. bridge_company_concept_period_hk is NOT NULL.
--   3. bridge_company_concept_period_hk is exactly 64 hex chars.
--   4. FK closure to hub_company.
--   5. FK closure to hub_filing.
--   6. FK closure to hub_concept.
--   7. FK closure to link_company_filing.
--   8. FK closure to link_filing_concept_period.
--   9. FK closure to dim_as_of_dates.
--  10. Composite natural PK (link_filing_concept_period_hk, as_of_date)
--      is unique across all rows.
--  11. Distinct as_of_date count = 10.
--  12. Bridge hash determinism on Apple's first observed link × first
--      as_of_date — recomputes the 4-component composite SHA-256 chain
--      (hub_company_hk || link_company_filing_hk || link_filing_concept_period_hk
--      || as_of_date) and confirms stored hash matches.
--  13. record_source is constant 'business_vault.bridge_company_concept_period'.

WITH apple_sample AS (
    SELECT
        b.bridge_company_concept_period_hk,
        b.hub_company_hk,
        b.link_company_filing_hk,
        b.link_filing_concept_period_hk,
        b.as_of_date
    FROM financial_analytics_silver.bridge_company_concept_period b
    INNER JOIN financial_analytics_silver.link_filing_concept_period l
      ON b.link_filing_concept_period_hk = l.link_filing_concept_period_hk
    WHERE l.cik = '0000320193'
    ORDER BY l.accession_number, l.period_end_date, b.as_of_date
    LIMIT 1
),

checks AS (

    SELECT
        'check_01_bridge_hk_unique' AS check_name,
        (SELECT COUNT(*) FROM financial_analytics_silver.bridge_company_concept_period) AS expected,
        (SELECT COUNT(DISTINCT bridge_company_concept_period_hk) FROM financial_analytics_silver.bridge_company_concept_period) AS actual

    UNION ALL SELECT
        'check_02_bridge_hk_not_null',
        (SELECT COUNT(*) FROM financial_analytics_silver.bridge_company_concept_period),
        (SELECT COUNT(bridge_company_concept_period_hk) FROM financial_analytics_silver.bridge_company_concept_period)

    UNION ALL SELECT
        'check_03_bridge_hk_length_64',
        (SELECT COUNT(*) FROM financial_analytics_silver.bridge_company_concept_period),
        (SELECT COUNT(*) FROM financial_analytics_silver.bridge_company_concept_period WHERE length(bridge_company_concept_period_hk) = 64)

    UNION ALL SELECT
        'check_04_bridge_fk_closure_hub_company',
        (SELECT COUNT(*) FROM financial_analytics_silver.bridge_company_concept_period),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.bridge_company_concept_period b
         INNER JOIN financial_analytics_silver.hub_company h
           ON b.hub_company_hk = h.hub_company_hk)

    UNION ALL SELECT
        'check_05_bridge_fk_closure_hub_filing',
        (SELECT COUNT(*) FROM financial_analytics_silver.bridge_company_concept_period),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.bridge_company_concept_period b
         INNER JOIN financial_analytics_silver.hub_filing h
           ON b.hub_filing_hk = h.hub_filing_hk)

    UNION ALL SELECT
        'check_06_bridge_fk_closure_hub_concept',
        (SELECT COUNT(*) FROM financial_analytics_silver.bridge_company_concept_period),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.bridge_company_concept_period b
         INNER JOIN financial_analytics_silver.hub_concept h
           ON b.hub_concept_hk = h.hub_concept_hk)

    UNION ALL SELECT
        'check_07_bridge_fk_closure_link_company_filing',
        (SELECT COUNT(*) FROM financial_analytics_silver.bridge_company_concept_period),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.bridge_company_concept_period b
         INNER JOIN financial_analytics_silver.link_company_filing l
           ON b.link_company_filing_hk = l.link_company_filing_hk)

    UNION ALL SELECT
        'check_08_bridge_fk_closure_link_filing_concept_period',
        (SELECT COUNT(*) FROM financial_analytics_silver.bridge_company_concept_period),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.bridge_company_concept_period b
         INNER JOIN financial_analytics_silver.link_filing_concept_period l
           ON b.link_filing_concept_period_hk = l.link_filing_concept_period_hk)

    UNION ALL SELECT
        'check_09_bridge_fk_closure_dim_as_of',
        (SELECT COUNT(*) FROM financial_analytics_silver.bridge_company_concept_period),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.bridge_company_concept_period b
         INNER JOIN financial_analytics_silver.dim_as_of_dates d
           ON b.as_of_date = d.as_of_date)

    UNION ALL SELECT
        'check_10_bridge_composite_pk_unique',
        (SELECT COUNT(*) FROM financial_analytics_silver.bridge_company_concept_period),
        (SELECT COUNT(*)
         FROM (
             SELECT DISTINCT link_filing_concept_period_hk, as_of_date
             FROM financial_analytics_silver.bridge_company_concept_period
         ))

    UNION ALL SELECT
        'check_11_distinct_as_of_count',
        CAST(10 AS bigint),
        (SELECT COUNT(DISTINCT as_of_date) FROM financial_analytics_silver.bridge_company_concept_period)

    UNION ALL SELECT
        'check_12_bridge_hk_reproducible',
        CAST(1 AS bigint),
        (SELECT COUNT(*)
         FROM apple_sample
         WHERE bridge_company_concept_period_hk = to_hex(sha256(to_utf8(
               CAST(hub_company_hk AS varchar) || '||' ||
               CAST(link_company_filing_hk AS varchar) || '||' ||
               CAST(link_filing_concept_period_hk AS varchar) || '||' ||
               CAST(as_of_date AS varchar)
           ))))

    UNION ALL SELECT
        'check_13_record_source_constant',
        (SELECT COUNT(*) FROM financial_analytics_silver.bridge_company_concept_period),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.bridge_company_concept_period
         WHERE record_source = 'business_vault.bridge_company_concept_period')
)

SELECT
    check_name,
    expected,
    actual,
    CASE WHEN expected = actual THEN 'PASS' ELSE 'FAIL' END AS result
FROM checks
ORDER BY check_name;

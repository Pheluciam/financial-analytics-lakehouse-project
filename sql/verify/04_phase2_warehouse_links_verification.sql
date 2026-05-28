-- sql/verify/04_phase2_warehouse_links_verification.sql
--
-- Phase 2 session 5 — second + third warehouse-layer Data Vault 2.0
-- models. hub_filing (second hub, accession_number business key) +
-- link_company_filing (first link, composite hash over (cik,
-- accession_number) with '||' delimiter). Structural verification
-- surface complementing dbt schema tests. Standalone re-runnable
-- artefact — paste the whole thing into Athena Query Editor under
-- workgroup wg_financial_analytics signed in as phil-admin, region
-- us-east-1.
--
-- Checks 13 invariants (5 on hub_filing, 8 on link_company_filing):
--
-- hub_filing:
--   1. hub_filing_hk is unique across all rows.
--   2. hub_filing_hk is NOT NULL across all rows.
--   3. hub_filing_hk is exactly 64 hex chars (SHA-256 length contract).
--   4. accession_number (business key) is unique across all rows.
--   5. hub_filing row count = source distinct accession_number count
--      across the 8 in-scope concepts in the companyfacts JSON
--      (lineage parity).
--
-- link_company_filing:
--   6. link_company_filing_hk is unique across all rows.
--   7. link_company_filing_hk is NOT NULL across all rows.
--   8. link_company_filing_hk is exactly 64 hex chars.
--   9. Composite-hash determinism — Apple's earliest extracted
--      accession_number recomputed via
--      to_hex(sha256(to_utf8('0000320193' || '||' || <accn>)))
--      matches the stored link hash. Proves the '||' delimiter and
--      function chain reproduce.
--  10. FK closure to hub_company — every link.hub_company_hk exists
--      in hub_company.hub_company_hk (no orphan FKs).
--  11. FK closure to hub_filing — every link.hub_filing_hk exists in
--      hub_filing.hub_filing_hk (no orphan FKs).
--  12. Link row count = source distinct (cik, accession_number) pair
--      count across the 8 in-scope concepts (lineage parity).
--  13. Each link.cik is a substring-or-equal match to one of the
--      100 hub_company.cik values AND each link.accession_number
--      matches one of the hub_filing.accession_number values
--      (cardinality sanity — link populates with no rows referencing
--      keys that aren't in either parent hub).
--
-- Idempotency check is separately performed by re-running
--   dotenv -f ..\.env run -- dbt run --select hub_filing link_company_filing
-- Expected output: NO-OP (0 rows merged) per the is_incremental
-- source-side filter on each model.
--
-- Schema tests in dbt/models/warehouse/_models.yml cover the
-- relationships + unique + not_null contracts; this verify suite
-- restates them in raw queryable form plus adds the SHA-256-length,
-- lineage-parity, and composite-hash-determinism checks YAML can't
-- express.

WITH all_source_pairs AS (
    -- Recompute the source-side (cik, accession_number) surface the
    -- same way hub_filing + link_company_filing do — UNNEST per concept,
    -- UNION ALL the 8 in-scope concepts. Same shape as the warehouse
    -- model bodies; just hand-unrolled here since this is raw SQL
    -- (no Jinja loop available outside dbt).
    SELECT s.cik, json_extract_scalar(t.period_json, '$.accn') AS accession_number
    FROM financial_analytics_silver.stg_sec_edgar__companyfacts_raw s
    CROSS JOIN UNNEST(CAST(json_extract(s.json_text, '$.facts["us-gaap"].Revenues.units.USD') AS ARRAY(JSON))) AS t(period_json)
    UNION ALL
    SELECT s.cik, json_extract_scalar(t.period_json, '$.accn')
    FROM financial_analytics_silver.stg_sec_edgar__companyfacts_raw s
    CROSS JOIN UNNEST(CAST(json_extract(s.json_text, '$.facts["us-gaap"].SalesRevenueNet.units.USD') AS ARRAY(JSON))) AS t(period_json)
    UNION ALL
    SELECT s.cik, json_extract_scalar(t.period_json, '$.accn')
    FROM financial_analytics_silver.stg_sec_edgar__companyfacts_raw s
    CROSS JOIN UNNEST(CAST(json_extract(s.json_text, '$.facts["us-gaap"].RevenueFromContractWithCustomerExcludingAssessedTax.units.USD') AS ARRAY(JSON))) AS t(period_json)
    UNION ALL
    SELECT s.cik, json_extract_scalar(t.period_json, '$.accn')
    FROM financial_analytics_silver.stg_sec_edgar__companyfacts_raw s
    CROSS JOIN UNNEST(CAST(json_extract(s.json_text, '$.facts["us-gaap"].RevenueFromContractWithCustomerIncludingAssessedTax.units.USD') AS ARRAY(JSON))) AS t(period_json)
    UNION ALL
    SELECT s.cik, json_extract_scalar(t.period_json, '$.accn')
    FROM financial_analytics_silver.stg_sec_edgar__companyfacts_raw s
    CROSS JOIN UNNEST(CAST(json_extract(s.json_text, '$.facts["us-gaap"].NetIncomeLoss.units.USD') AS ARRAY(JSON))) AS t(period_json)
    UNION ALL
    SELECT s.cik, json_extract_scalar(t.period_json, '$.accn')
    FROM financial_analytics_silver.stg_sec_edgar__companyfacts_raw s
    CROSS JOIN UNNEST(CAST(json_extract(s.json_text, '$.facts["us-gaap"].Assets.units.USD') AS ARRAY(JSON))) AS t(period_json)
    UNION ALL
    SELECT s.cik, json_extract_scalar(t.period_json, '$.accn')
    FROM financial_analytics_silver.stg_sec_edgar__companyfacts_raw s
    CROSS JOIN UNNEST(CAST(json_extract(s.json_text, '$.facts["us-gaap"].Liabilities.units.USD') AS ARRAY(JSON))) AS t(period_json)
    UNION ALL
    SELECT s.cik, json_extract_scalar(t.period_json, '$.accn')
    FROM financial_analytics_silver.stg_sec_edgar__companyfacts_raw s
    CROSS JOIN UNNEST(CAST(json_extract(s.json_text, '$.facts["us-gaap"].StockholdersEquity.units.USD') AS ARRAY(JSON))) AS t(period_json)
),

source_pairs AS (
    SELECT DISTINCT cik, accession_number
    FROM all_source_pairs
    WHERE accession_number IS NOT NULL
),

apple_accn AS (
    -- One specific (cik, accession_number) pair for the determinism
    -- check — pick the lexicographically smallest Apple accession to
    -- keep the check stable across re-runs.
    SELECT MIN(accession_number) AS accn
    FROM source_pairs
    WHERE cik = '0000320193'
),

checks AS (

    -- ===== hub_filing =====

    SELECT
        'check_01_hubf_hk_unique' AS check_name,
        (SELECT COUNT(*) FROM financial_analytics_silver.hub_filing) AS expected,
        (SELECT COUNT(DISTINCT hub_filing_hk) FROM financial_analytics_silver.hub_filing) AS actual

    UNION ALL SELECT
        'check_02_hubf_hk_not_null',
        (SELECT COUNT(*) FROM financial_analytics_silver.hub_filing),
        (SELECT COUNT(hub_filing_hk) FROM financial_analytics_silver.hub_filing)

    UNION ALL SELECT
        'check_03_hubf_hk_length_64',
        (SELECT COUNT(*) FROM financial_analytics_silver.hub_filing),
        (SELECT COUNT(*) FROM financial_analytics_silver.hub_filing WHERE length(hub_filing_hk) = 64)

    UNION ALL SELECT
        'check_04_hubf_accn_unique',
        (SELECT COUNT(*) FROM financial_analytics_silver.hub_filing),
        (SELECT COUNT(DISTINCT accession_number) FROM financial_analytics_silver.hub_filing)

    UNION ALL SELECT
        'check_05_hubf_source_parity',
        (SELECT COUNT(DISTINCT accession_number) FROM source_pairs),
        (SELECT COUNT(*) FROM financial_analytics_silver.hub_filing)

    -- ===== link_company_filing =====

    UNION ALL SELECT
        'check_06_link_hk_unique',
        (SELECT COUNT(*) FROM financial_analytics_silver.link_company_filing),
        (SELECT COUNT(DISTINCT link_company_filing_hk) FROM financial_analytics_silver.link_company_filing)

    UNION ALL SELECT
        'check_07_link_hk_not_null',
        (SELECT COUNT(*) FROM financial_analytics_silver.link_company_filing),
        (SELECT COUNT(link_company_filing_hk) FROM financial_analytics_silver.link_company_filing)

    UNION ALL SELECT
        'check_08_link_hk_length_64',
        (SELECT COUNT(*) FROM financial_analytics_silver.link_company_filing),
        (SELECT COUNT(*) FROM financial_analytics_silver.link_company_filing WHERE length(link_company_filing_hk) = 64)

    UNION ALL SELECT
        'check_09_link_composite_hash_reproducible',
        CAST(1 AS bigint),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.link_company_filing l
         CROSS JOIN apple_accn a
         WHERE l.cik = '0000320193'
           AND l.accession_number = a.accn
           AND l.link_company_filing_hk = to_hex(sha256(to_utf8(
                   CAST('0000320193' AS varchar) || '||' || CAST(a.accn AS varchar)
               ))))

    UNION ALL SELECT
        'check_10_link_fk_closure_company',
        (SELECT COUNT(*) FROM financial_analytics_silver.link_company_filing),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.link_company_filing l
         INNER JOIN financial_analytics_silver.hub_company h
           ON l.hub_company_hk = h.hub_company_hk)

    UNION ALL SELECT
        'check_11_link_fk_closure_filing',
        (SELECT COUNT(*) FROM financial_analytics_silver.link_company_filing),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.link_company_filing l
         INNER JOIN financial_analytics_silver.hub_filing h
           ON l.hub_filing_hk = h.hub_filing_hk)

    UNION ALL SELECT
        'check_12_link_source_parity',
        (SELECT COUNT(*) FROM source_pairs),
        (SELECT COUNT(*) FROM financial_analytics_silver.link_company_filing)

    UNION ALL SELECT
        'check_13_link_business_keys_match_hubs',
        (SELECT COUNT(*) FROM financial_analytics_silver.link_company_filing),
        (SELECT COUNT(*)
         FROM financial_analytics_silver.link_company_filing l
         INNER JOIN financial_analytics_silver.hub_company hc
           ON l.cik = hc.cik
         INNER JOIN financial_analytics_silver.hub_filing hf
           ON l.accession_number = hf.accession_number)
)

SELECT
    check_name,
    expected,
    actual,
    CASE WHEN expected = actual THEN 'PASS' ELSE 'FAIL' END AS result
FROM checks
ORDER BY check_name;

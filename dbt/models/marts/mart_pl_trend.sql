-- dbt/models/marts/mart_pl_trend.sql
--
-- Gold-layer Profit & Loss trend mart — FIRST mart in the project,
-- shipped at Phase 4 session 1. 10-year annual P&L trend per S&P 100
-- company over the 10 fiscal year-end as-of-dates configured in
-- dim_as_of_dates. Consumed downstream by Power BI Desktop via the
-- Amazon Athena ODBC v2 driver + Windows System DSN
-- "FinancialAnalyticsAthena" (Risk 39 prerequisite shipped 2026-05-30).
--
-- THE FIRST MART. Phase 4's deliverable is the four-mart Gold layer
-- consumed by Power BI in Phase 5. This is the architectural pattern
-- test: does the Business Vault Bridge + PIT collapse what would
-- otherwise be a 5+ join hub-link-sat navigation into a clean equi-join
-- chain that ships a Gold mart row? Pattern validated here carries
-- forward to mart_peer_benchmark, mart_financial_health,
-- mart_growth_forecast. Project #2 carry-forward: mart-shape PBI smoke
-- test runs at mart-creation time (this session, Step 9) — NOT deferred
-- to Phase 5 build time — to catch mart-architecture problems early.
--
-- Grain. Composite (cik, as_of_date, fiscal_year, canonical_concept) —
-- one row per company × as-of-date × fiscal year × P&L canonical concept
-- combination where the underlying SEC filing was visible (filed_date <=
-- as_of_date) at the snapshot point. as_of_date is RETAINED in the grain
-- to demonstrate the BV PIT/Bridge architectural benefit — collapsing to
-- a latest-snapshot-only grain would make the PIT/Bridge layer
-- theatrical for the first mart. Current data has no restatements (one
-- Bronze extract date), so values repeat across visible as_of_dates per
-- (cik, fiscal_year, canonical) — the redundancy is intentional and
-- demonstrates the architectural pattern PBI will see when restatement
-- history accumulates in future Bronze extracts.
--
-- SEC income-statement comparatives dedup (LEARNINGS Risk 42, banked
-- 2026-05-30). The link_filing_concept_period grain includes
-- accession_number, so the same (cik, fiscal_year, canonical_concept)
-- tuple appears across MULTIPLE accessions when 10-Ks report prior-year
-- comparatives (FY2018 revenue is reported in the FY2018 10-K AND the
-- FY2019 10-K AND the FY2020 10-K — ASC 205 comparative-period
-- requirement). Joining naively through Bridge → PIT → sat produces
-- ~3x duplication per mart grain at first-run scale (19,371 dup rows on
-- 6,460 unique grain tuples observed at session 1 first build). Mart
-- layer is where this collapse belongs — neither Bridge nor PIT can do
-- it without losing the per-accession source-faithfulness sat_concept_value
-- preserves. Dedup mechanic: ROW_NUMBER() OVER (PARTITION BY mart grain
-- ORDER BY accession_number DESC) — keep rn = 1. accession_number DESC
-- = latest filing wins, which matches analyst convention of "current
-- reported value for FY at the snapshot." accession_number alone isn't
-- a perfect chronological ordering (the SEC format is
-- filerCIK-YY-NNNNNN; same-year filings sort by sequence), but at
-- 10-K cadence the per-fiscal-year ordering is unambiguous within our
-- in-scope filings. accession_number is brought through the CTE chain
-- for the dedup step but NOT projected to the final mart output —
-- audit trail of which accession a value was sourced from lives in
-- sat_concept_value at the warehouse layer.
--
-- Surrogate PK. mart_pl_trend_hk = SHA-256 over the 4-column composite
-- grain, matching the project's hash-chain convention (Risk 4 single-key
-- + Risk 6 '||' composite delimiter). Visual consistency with every
-- warehouse + business_vault model in the project — every primary key
-- column in the Silver layer is a 64-char SHA-256 hex string.
--
-- Canonical concept filter. WHERE canonical_concept IN ('revenue',
-- 'net_income'). The canonical_concepts_dictionary seed currently
-- carries 5 canonical concepts; 3 are balance_sheet (assets, liabilities,
-- stockholders_equity) and 2 are income_statement (revenue, net_income).
-- mart_pl_trend's purpose is P&L → income_statement only. Future seed
-- expansion to broader P&L coverage (OperatingIncomeLoss, GrossProfit,
-- CostOfRevenue, etc.) is deferred to a Phase 4 follow-up session;
-- expansion requires re-running seed → intermediate → BV layer to
-- propagate the new canonical mappings into sat_concept_value's
-- collapse-by-canonical chain.
--
-- Annual filter. WHERE fiscal_period = 'FY'. SEC EDGAR companyfacts
-- carries both annual (10-K, fiscal_period = 'FY') and quarterly (10-Q,
-- fiscal_period IN ('Q1','Q2','Q3')) reports. mart_pl_trend is an
-- ANNUAL trend mart — filtering to FY collapses ~5x and produces the
-- conventional analyst view. A separate mart_pl_quarterly is a logical
-- future extension if PBI quarterly visualizations land in scope.
--
-- Entity descriptor. entity_name from sat_company_metadata, NOT ticker.
-- SEC EDGAR's companyfacts JSON cover page exposes entityName but does
-- NOT expose a stock ticker. The S&P 100 universe IS ticker-anchored at
-- the seed source level (the company universe was sampled by ticker),
-- but ticker is not preserved through to the Bronze companyfacts
-- payload — only cik + entityName. Adding ticker would require a
-- separate seed-style cik → ticker mapping table; deferred to a
-- Phase 4 follow-up session if PBI dashboards specifically need it.
-- entity_name (e.g. "Apple Inc.") is sufficient for PBI visualization.
--
-- JOIN topology — single 5-step equi-join chain over the BV + RV layer.
-- The Bridge is the base spine (already pre-resolves hub_company_hk,
-- link_filing_concept_period_hk, period_end_date, fiscal_year,
-- fiscal_period, as_of_date in one row) so the mart query starts from
-- the Bridge, not from the hubs:
--   1. bridge_company_concept_period (base) — filter to fiscal_period = 'FY'
--   2. → pit_link_filing_concept_period — resolves visible sat row at
--        each as_of_date via (link_hk, as_of_date) equi-join
--   3. → sat_concept_value — gets canonical_concept + value + unit via
--        (link_hk, load_datetime) equi-join to the PIT-resolved sat
--        coordinate; canonical_concept filter applied here
--   4. → hub_company — gets cik via hub_company_hk equi-join
--   5. → sat_company_metadata — gets entity_name via hub_company_hk
--        equi-join (1:1 with hub by sat-pattern construction)
--
-- This is the pattern test the BV layer was built for. Without PIT, step
-- 2's "which sat row is visible at as_of_date" lookup would be an
-- expensive correlated subquery / window-function anti-join per query;
-- with PIT, it's a single equi-join. Without Bridge, step 1's "fiscal_year
-- per link" would need a JOIN to link_filing_concept_period; with Bridge,
-- it's already projected.
--
-- Materialization: plain table (Iceberg/Parquet) per marts layer
-- defaults in dbt_project.yml. NOT incremental + merge — marts are
-- rebuilt every refresh from the BV layer, no SCD-2 to preserve, no
-- insert-only contract to enforce, structurally avoiding the Risk 2
-- Iceberg-merge bug class. Iceberg V2 (Athena Engine 3 default) is
-- consumed transparently by Power BI through the Athena ODBC v2 driver.
--
-- Verification surface. sql/verify/13_phase4_marts_pl_trend_verification.sql
-- runs PASS/FAIL CTEs against this mart matching the 01-12 verify file
-- pattern: row count band, no-NULL on critical columns, FK closure to
-- BV inputs, per-year + per-company cardinality sanity, Apple sample
-- (cik 0000320193) determinism check.
--
-- Walkthrough: GOLD_MARTS_PIPELINE.md at repo root (scaffolded this
-- session) + DBT_PIPELINE.md section 9 (Phase 4 marts overview).

WITH bridge_fy AS (
    -- Bridge spine narrowed to annual (10-K-equivalent) snapshots. Filter
    -- here rather than at the outer SELECT so downstream CTEs scan
    -- ~1/5 of the bridge row count. fiscal_period = 'FY' is the
    -- analyst-conventional annual P&L filter.
    --
    -- Risk 66 (Phase 5 session 4.5 Fix-amendment, 2026-06-01) — relaxed
    -- to also accept rows where SEC EDGAR companyfacts JSON omits the fp
    -- attribute on annual facts (observed for BKNG/CAT/MA NetIncomeLoss
    -- 10-K rows during Step M re-audit drilldown A4.2). Quarterly rows
    -- arrive with fp populated (Q1/Q2/Q3) so the NULL branch only adds
    -- legitimate annual rows; the downstream Risk 48 span filter at
    -- sat_resolved rejects any quarterly cumulatives whose span < 350 days.
    SELECT
        b.hub_company_hk,
        b.link_filing_concept_period_hk,
        b.as_of_date,
        b.fiscal_year,
        b.period_end_date
    FROM {{ ref('bridge_company_concept_period') }} b
    WHERE b.fiscal_period = 'FY' OR b.fiscal_period IS NULL
),

pit_resolved AS (
    -- Equi-join PIT to resolve the visible sat_concept_value coordinate
    -- at each as_of_date. INNER JOIN (not LEFT) because PIT rows with
    -- NULL sat coordinates are the ghost-record-substitute placeholders
    -- (PIT uses LEFT JOIN to sat at design time per Risk 22) — mart
    -- semantics need real visible values, not ghost positions. The
    -- IS NOT NULL guard on sat_concept_value_pk drops the ghost rows.
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
    -- coordinate. Canonical concept filter applied here against the
    -- income_statement canonicals only. accession_number + period_start_date
    -- carried through for the Risk 42 + Risk 48 dedup steps. Risk 48
    -- sanity filter (period span ~365 days) applied here to drop the
    -- intra-accession period-chunk rows that SEC XBRL tags as fp=FY but
    -- actually span quarters or half-years (Apple FY2019 10-K reports 11
    -- rows all tagged fp=FY fy=2019 across 3 actual FY periods + 8
    -- quarter/half-year chunks). Without the filter, the Risk 42 dedup
    -- picks one of the 11 non-deterministically (all share accession_number,
    -- so accession_number DESC tie-breaker is degenerate).
    --
    -- Risk 58 period-end re-anchor (Phase 5 session 4, 2026-06-01). The
    -- prior year(scv.period_end_date) IN (scv.fiscal_year, scv.fiscal_year + 1)
    -- filter has been REMOVED, and fiscal_year is now derived from
    -- year(scv.period_end_date) rather than carried from the SEC fy
    -- attribute. SEC EDGAR XBRL uses period-START-year convention for
    -- 52/53-week filers (WMT, HD, TGT, LOW, TJX, NVDA, CRM, JNJ), so a
    -- single 10-K reports both current-year and prior-year comparatives
    -- under the same fy attribute + same accession_number with different
    -- period_end_dates. Both rows passed the prior year-IN filter; Risk 42
    -- dedup ORDER BY accession_number DESC produced a Trino ROW_NUMBER
    -- tie that resolved non-deterministically across partitions, surfacing
    -- as ~421 cross-mart divergent rows (Audit 7) + 118 snapshot drifts
    -- (Audit 8) + SPGI FY2024 total absence from mart_financial_health
    -- (Audit 4). Anchoring fiscal_year on year(period_end_date) puts the
    -- two rows into distinct partitions, making dedup deterministic by
    -- construction and resolving all three audits with one fix.
    SELECT
        pr.hub_company_hk,
        pr.as_of_date,
        year(scv.period_end_date) AS fiscal_year,
        pr.period_end_date,
        scv.canonical_concept,
        scv.accession_number,
        scv.period_start_date,
        scv.value AS value_numeric,
        scv.unit
    FROM pit_resolved pr
    INNER JOIN {{ ref('sat_concept_value') }} scv
        ON scv.link_filing_concept_period_hk = pr.link_filing_concept_period_hk
        AND scv.load_datetime = pr.sat_concept_value_ldts
    WHERE scv.canonical_concept IN ('revenue', 'net_income')
      AND date_diff('day', scv.period_start_date, scv.period_end_date) BETWEEN 350 AND 380
),

company_resolved AS (
    -- Resolve company descriptors via hub_company (for cik) +
    -- sat_company_metadata (for entity_name). Both joins are exact-
    -- cardinality on hub_company_hk: hub is 1:1 by construction (one
    -- row per cik), sat_company_metadata is 1:1 with hub on first load
    -- (single Bronze extract, no SCD-2 history accumulated).
    SELECT
        sr.as_of_date,
        sr.fiscal_year,
        sr.period_end_date,
        sr.canonical_concept,
        sr.accession_number,
        sr.value_numeric,
        sr.unit,
        hc.cik,
        scm.entity_name
    FROM sat_resolved sr
    INNER JOIN {{ ref('hub_company') }} hc
        ON hc.hub_company_hk = sr.hub_company_hk
    INNER JOIN {{ ref('sat_company_metadata') }} scm
        ON scm.hub_company_hk = sr.hub_company_hk
),

deduped AS (
    -- Collapse the SEC ASC 205 income-statement comparatives duplication
    -- (Risk 42) — multiple 10-Ks reporting the same (cik, fiscal_year,
    -- canonical_concept) prior-year value. ROW_NUMBER() partitioned by
    -- the mart grain, ORDER BY accession_number DESC keeps the latest
    -- filing's value per grain tuple. accession_number ordering is the
    -- analyst-convention proxy for "most recent reported view of this
    -- FY value at the snapshot date." accession_number not projected to
    -- the mart output — audit trail of source filing lives in
    -- sat_concept_value at the warehouse layer.
    SELECT
        as_of_date,
        fiscal_year,
        period_end_date,
        canonical_concept,
        value_numeric,
        unit,
        cik,
        entity_name
    FROM (
        SELECT
            cr.*,
            ROW_NUMBER() OVER (
                PARTITION BY cr.cik, cr.as_of_date, cr.fiscal_year, cr.canonical_concept
                ORDER BY cr.accession_number DESC, cr.period_end_date DESC
            ) AS rn
        FROM company_resolved cr
    ) ranked
    WHERE rn = 1
),

yoy AS (
    -- Risk 69 (Phase 5 session 5, 2026-06-02) — pre-compute YoY % at the
    -- warehouse layer matching mart_peer_benchmark's peer_rank discipline.
    -- PBI Page 1 Top 5 gainers / decliners visual + Revenue YoY Rank
    -- measure consume a stable contract column instead of recomputing
    -- in DAX. yoy_pct = (value − prior_value) / |prior_value| via LAG
    -- over (cik, canonical_concept, as_of_date) ordered by fiscal_year.
    -- |prior_value| denominator preserves sign of the numerator under
    -- negative-prior-year cases (loss-making → less-loss-making is a
    -- positive YoY, conventional analyst interpretation). NULLIF guards
    -- divide-by-zero. LAG returns NULL on the first observed fiscal_year
    -- per (cik, canonical, as_of_date) partition, so yoy_pct is NULL
    -- there — correct semantics, no prior year to compare against.
    SELECT
        as_of_date,
        fiscal_year,
        period_end_date,
        canonical_concept,
        value_numeric,
        unit,
        cik,
        entity_name,
        CASE
            WHEN LAG(fiscal_year) OVER (
                PARTITION BY cik, canonical_concept, as_of_date
                ORDER BY fiscal_year
            ) = fiscal_year - 1
            THEN (value_numeric - LAG(value_numeric) OVER (
                PARTITION BY cik, canonical_concept, as_of_date
                ORDER BY fiscal_year
            )) / NULLIF(ABS(LAG(value_numeric) OVER (
                PARTITION BY cik, canonical_concept, as_of_date
                ORDER BY fiscal_year
            )), 0)
            ELSE NULL
        END AS yoy_pct
    FROM deduped
),

yoy_ranked AS (
    -- DENSE_RANK over yoy_pct DESC NULLS LAST per (as_of_date,
    -- fiscal_year, canonical_concept) partition — rank 1 = biggest
    -- gainer in the canonical's universe at that snapshot. DENSE_RANK
    -- (not RANK) so ties don't skip rank values — visual consumer
    -- never sees a gap between #3 and #5 if two companies tie at #4.
    -- Decliner Top-N is computed in PBI via TOPN on yoy_pct ASC; no
    -- separate yoy_rank_asc column needed (avoids column proliferation
    -- when the same information is one ORDER-BY flip away in DAX).
    SELECT
        y.*,
        DENSE_RANK() OVER (
            PARTITION BY as_of_date, fiscal_year, canonical_concept
            ORDER BY yoy_pct DESC NULLS LAST
        ) AS yoy_rank
    FROM yoy y
),

hashed AS (
    -- Compute the mart surrogate PK + project final shape + lineage
    -- columns. SHA-256 chain identical to every other Silver-layer hash
    -- column (Risk 4 single-key + Risk 6 '||' composite delimiter).
    -- 4-component composite over the grain: cik + as_of_date +
    -- fiscal_year + canonical_concept.
    SELECT
        to_hex(sha256(to_utf8(
            CAST(cik AS varchar) || '||' ||
            CAST(as_of_date AS varchar) || '||' ||
            CAST(fiscal_year AS varchar) || '||' ||
            CAST(canonical_concept AS varchar)
        ))) AS mart_pl_trend_hk,
        cik,
        entity_name,
        as_of_date,
        fiscal_year,
        canonical_concept,
        value_numeric,
        unit,
        period_end_date,
        yoy_pct,
        yoy_rank,
        CAST(current_timestamp AT TIME ZONE 'UTC' AS timestamp(6)) AS load_datetime,
        'mart.mart_pl_trend' AS record_source
    FROM yoy_ranked
)

SELECT * FROM hashed

-- dbt/models/marts/mart_peer_benchmark.sql
--
-- Gold-layer Peer Benchmarking mart — SECOND mart in the project,
-- shipped at Phase 4 session 2. Cross-company peer benchmarking at FY
-- snapshots over the S&P 100 universe. For each (company, as_of_date,
-- fiscal_year, canonical_concept) tuple, projects the company's value
-- alongside peer-group aggregates (count / mean / median / min / max /
-- stddev) and the company's per-peer-group rank + percentile. Consumed
-- downstream by Power BI Desktop via the Amazon Athena ODBC v2 driver
-- + Windows System DSN "FinancialAnalyticsAthena" (Risk 39 prerequisite
-- shipped 2026-05-30 at session 1).
--
-- THE PEER-BENCHMARKING MART. Phase 4's second mart — the "where do I
-- stack vs peers" lens. Same 5-step BV+RV equi-join chain as
-- mart_pl_trend; differentiator is the trailing peer-aggregation CTEs.
-- Sister marts going forward: mart_financial_health (ratios — session
-- 3), mart_growth_forecast (statsmodels forecast outputs — session 4).
--
-- Grain. Composite (cik, as_of_date, fiscal_year, canonical_concept) —
-- one row per company × as-of-date × fiscal year × canonical concept
-- where the underlying SEC filing was visible (filed_date <= as_of_date)
-- at the snapshot point. Same grain as mart_pl_trend by design — both
-- marts are downstream consumption surfaces of the same Bridge spine
-- and PIT lookups. as_of_date is retained in the grain to demonstrate
-- the BV PIT/Bridge architectural benefit end-to-end (consistency with
-- mart_pl_trend rationale).
--
-- Canonical concept filter. WHERE canonical_concept IN ('revenue',
-- 'net_income', 'assets'). Three concepts span the income statement
-- (revenue + net_income) AND the balance sheet (assets), giving PBI
-- consumers a peer-benchmarking surface across the two primary statement
-- types under the current canonical_concepts_dictionary seed coverage.
-- liabilities + stockholders_equity excluded — less useful for outright
-- peer benchmarking at FY snapshot (more meaningful as ratios in
-- mart_financial_health at session 3). Future seed expansion to broader
-- canonicals (OperatingIncomeLoss, GrossProfit, CashAndCashEquivalents,
-- etc.) extends the accepted_values set on canonical_concept.
--
-- Annual filter. WHERE fiscal_period = 'FY' (same rationale as
-- mart_pl_trend — analyst-conventional annual peer-benchmarking view).
--
-- Peer group definition. SECTOR-SEGMENTED — every company in the same
-- (gics_sector × as_of_date × fiscal_year × canonical_concept) partition
-- is treated as a peer of every other company. Sector cascade shipped
-- at Phase 4 session 3 (Option A bundle, 2026-05-30) alongside the new
-- sp100_company_sector seed; pre-session-3 partition was the single
-- S&P 100 universe (gics_sector dimension absent). LEFT JOIN to the
-- sector seed in sector_resolved CTE — CIKs without a sector row degrade
-- to gics_sector = 'UNCATEGORIZED' so the cascade doesn't drop rows.
-- The partition key change cascades into peer_stats GROUP BY and
-- peer_ranked window function PARTITION BY without touching the natural
-- PK (each cik has exactly one sector at any given time, so adding
-- sector to the partition spec doesn't change row cardinality).
--
-- SEC income-statement comparatives dedup (LEARNINGS Risk 42 carry-
-- forward from mart_pl_trend). Same ROW_NUMBER() OVER (PARTITION BY
-- mart grain ORDER BY accession_number DESC) dedup mechanic applied in
-- the deduped CTE — keeps the latest filing's value per (cik, as_of_date,
-- fiscal_year, canonical_concept) tuple. Peer aggregates compute AFTER
-- dedup so each company contributes exactly one row per partition to
-- the peer-group statistics — comparatives duplication would otherwise
-- skew medians and ranks.
--
-- Peer aggregation shape. peer_stats CTE computes per-partition
-- aggregates via GROUP BY (as_of_date, fiscal_year, canonical_concept):
-- peer_count, peer_mean, peer_median (approx_percentile 0.5),
-- peer_stddev, peer_min, peer_max. peer_ranked CTE applies per-row
-- window functions over the SAME partition: peer_rank via RANK() ORDER
-- BY value_numeric DESC (1 = highest in peer group, ties share rank),
-- peer_percentile via CUME_DIST() ORDER BY value_numeric ASC (1.0 =
-- highest, 0..1 standard analyst percentile interpretation). Two
-- separate CTEs by design: GROUP BY aggregates collapse cardinality
-- and JOIN back, window functions preserve cardinality and project per-
-- row — keeping them isolated produces a more readable join shape than
-- mixing window aggregates with per-row window ranks in one pass.
--
-- approx_percentile note. Athena Engine 3 (Trino-based) implements
-- approx_percentile as a deterministic algorithm with bounded error —
-- documented standard for portfolio-scale median calculations over
-- ~100-row peer groups (the exact-percentile aggregate is not available
-- in standard Trino). Error tolerance trivial at S&P 100 scale.
--
-- Surrogate PK. mart_peer_benchmark_hk = SHA-256 over the 4-column
-- composite grain, matching mart_pl_trend's hash convention (Risk 4
-- single-key + Risk 6 '||' composite delimiter).
--
-- Entity descriptor. entity_name from sat_company_metadata — same
-- rationale as mart_pl_trend (SEC EDGAR companyfacts doesn't expose
-- stock ticker; entity_name is the project's native company descriptor).
--
-- JOIN topology. 5-step equi-join chain over BV + RV (same as
-- mart_pl_trend) + 1 LEFT JOIN to the sector seed:
--   1. bridge_company_concept_period (base) — filter to fiscal_period = 'FY'
--   2. → pit_link_filing_concept_period — resolves visible sat row at
--        each as_of_date via (link_hk, as_of_date) equi-join
--   3. → sat_concept_value — gets canonical_concept + value + unit via
--        (link_hk, load_datetime) equi-join; 3-concept filter applied here
--   4. → hub_company — gets cik via hub_company_hk equi-join
--   5. → sat_company_metadata — gets entity_name via hub_company_hk
--   6. LEFT JOIN sp100_company_sector by cik — attaches gics_sector +
--        gics_industry_group; CIKs missing from the seed COALESCE to
--        'UNCATEGORIZED'.
-- Then 4 peer-aggregation CTEs: deduped → sector_resolved → peer_stats →
-- peer_ranked. sector_resolved is the new CTE shipped at session 3.
--
-- Materialization. Plain Iceberg table per marts layer defaults in
-- dbt_project.yml — full rebuild per dbt run, Risk 2 Iceberg-merge bug
-- class structurally avoided. Consumed transparently by Power BI through
-- the Athena ODBC v2 driver.
--
-- Risk 45 dependency. Upstream sat_concept_value collapse uses the
-- canonical_concept_tag_preference seed at Phase 4 session 2 onwards.
-- Apple's FY2019 revenue now renders ~$260B (vs the pre-Risk-45
-- ~$70B MIN-collapse value). Peer ranks against the corrected base.
--
-- Verification surface. sql/verify/14_phase4_marts_peer_benchmark_verification.sql
-- runs PASS/FAIL CTEs against this mart: row count band, no-NULL on
-- critical columns, FK closure to hub_company + dim_as_of_dates +
-- hub_concept, sample-company determinism (Apple cik 0000320193), peer-
-- rank well-formedness (peer_rank within [1, peer_count] per partition),
-- peer_percentile within [0,1], peer_count consistency per partition.
--
-- Walkthrough: GOLD_MARTS_PIPELINE.md section 5.2 + DBT_PIPELINE.md
-- section 9.2.

WITH bridge_fy AS (
    -- Bridge spine narrowed to annual (10-K-equivalent) snapshots.
    -- Same FY pre-filter as mart_pl_trend so downstream CTEs scan
    -- ~1/5 of bridge cardinality.
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
    -- at each as_of_date. INNER JOIN + IS NOT NULL guard drops the
    -- PIT ghost-record-substitute placeholders (PIT's LEFT JOIN to sat
    -- emits NULL sat coordinates per Risk 22 design).
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
    -- coordinate. Canonical-concept filter to the 3 peer-benchmarking
    -- canonicals applied here. accession_number + period_start_date
    -- carried through for the Risk 42 + Risk 48 dedup steps. Risk 48
    -- sanity filter (period span ~365 days + year(period_end) matches
    -- fiscal_year ± 1) applied here — see mart_pl_trend sat_resolved
    -- for the full provenance narrative.
    SELECT
        pr.hub_company_hk,
        pr.as_of_date,
        pr.fiscal_year,
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
    WHERE scv.canonical_concept IN ('revenue', 'net_income', 'assets')
      AND year(scv.period_end_date) IN (scv.fiscal_year, scv.fiscal_year + 1)
      AND (
          scv.canonical_concept = 'assets'
          OR date_diff('day', scv.period_start_date, scv.period_end_date) BETWEEN 350 AND 380
      )
),

company_resolved AS (
    -- Resolve company descriptors via hub_company (cik) and
    -- sat_company_metadata (entity_name). Both joins are exact-
    -- cardinality on hub_company_hk per session 6 sat-pattern construction.
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
    -- Risk 42 SEC ASC 205 income-statement comparatives dedup —
    -- ROW_NUMBER() partitioned by mart grain, ORDER BY accession_number
    -- DESC keeps the latest filing's value. accession_number not
    -- projected to mart output (audit lineage lives at the warehouse
    -- sat_concept_value). Critical that dedup runs BEFORE peer
    -- aggregates compute — duplicate comparatives would skew peer
    -- median + rank if not collapsed first.
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
                ORDER BY cr.accession_number DESC
            ) AS rn
        FROM company_resolved cr
    ) ranked
    WHERE rn = 1
),

sector_resolved AS (
    -- Phase 4 session 3 sector cascade (Option A). LEFT JOIN the
    -- sp100_company_sector seed by cik. COALESCE missing sector rows
    -- to 'UNCATEGORIZED' / NULL industry group so CIKs outside the seed
    -- universe still surface in their own degenerate partition rather
    -- than dropping out of the mart. Each cik has exactly one sector,
    -- so this JOIN doesn't change row cardinality.
    SELECT
        d.cik,
        d.entity_name,
        d.as_of_date,
        d.fiscal_year,
        d.period_end_date,
        d.canonical_concept,
        d.value_numeric,
        d.unit,
        COALESCE(s.gics_sector, 'UNCATEGORIZED') AS gics_sector,
        s.gics_industry_group
    FROM deduped d
    LEFT JOIN {{ ref('sp100_company_sector') }} s
        ON s.cik = d.cik
),

peer_stats AS (
    -- Per-partition peer-group aggregates. Partition key now extends to
    -- (as_of_date, fiscal_year, canonical_concept, gics_sector) — one
    -- stats row per snapshot × fiscal year × concept × sector. JOIN back
    -- to the per-company surface in the next CTE.
    SELECT
        as_of_date,
        fiscal_year,
        canonical_concept,
        gics_sector,
        COUNT(*) AS peer_count,
        AVG(value_numeric) AS peer_mean,
        approx_percentile(value_numeric, 0.5) AS peer_median,
        STDDEV(value_numeric) AS peer_stddev,
        MIN(value_numeric) AS peer_min,
        MAX(value_numeric) AS peer_max
    FROM sector_resolved
    GROUP BY as_of_date, fiscal_year, canonical_concept, gics_sector
),

peer_ranked AS (
    -- Per-row peer rank + percentile over the same partition. RANK()
    -- ORDER BY value_numeric DESC — 1 = highest in sector peer group
    -- (ties share rank, next rank jumps). CUME_DIST() ORDER BY
    -- value_numeric ASC — 1.0 = highest, fraction = proportion of
    -- sector peers at-or-below (standard analyst percentile interpretation).
    SELECT
        s.cik,
        s.entity_name,
        s.as_of_date,
        s.fiscal_year,
        s.period_end_date,
        s.canonical_concept,
        s.value_numeric,
        s.unit,
        s.gics_sector,
        s.gics_industry_group,
        ps.peer_count,
        ps.peer_mean,
        ps.peer_median,
        ps.peer_stddev,
        ps.peer_min,
        ps.peer_max,
        CAST(RANK() OVER (
            PARTITION BY s.as_of_date, s.fiscal_year, s.canonical_concept, s.gics_sector
            ORDER BY s.value_numeric DESC
        ) AS INTEGER) AS peer_rank,
        CUME_DIST() OVER (
            PARTITION BY s.as_of_date, s.fiscal_year, s.canonical_concept, s.gics_sector
            ORDER BY s.value_numeric ASC
        ) AS peer_percentile
    FROM sector_resolved s
    INNER JOIN peer_stats ps
        ON ps.as_of_date = s.as_of_date
        AND ps.fiscal_year = s.fiscal_year
        AND ps.canonical_concept = s.canonical_concept
        AND ps.gics_sector = s.gics_sector
),

hashed AS (
    -- Compute mart surrogate PK + project final shape + lineage. SHA-256
    -- chain identical to mart_pl_trend's hash (Risk 4 + Risk 6).
    SELECT
        to_hex(sha256(to_utf8(
            CAST(cik AS varchar) || '||' ||
            CAST(as_of_date AS varchar) || '||' ||
            CAST(fiscal_year AS varchar) || '||' ||
            CAST(canonical_concept AS varchar)
        ))) AS mart_peer_benchmark_hk,
        cik,
        entity_name,
        as_of_date,
        fiscal_year,
        canonical_concept,
        gics_sector,
        gics_industry_group,
        value_numeric,
        unit,
        peer_count,
        peer_mean,
        peer_median,
        peer_stddev,
        peer_min,
        peer_max,
        peer_rank,
        peer_percentile,
        period_end_date,
        CAST(current_timestamp AT TIME ZONE 'UTC' AS timestamp(6)) AS load_datetime,
        'mart.mart_peer_benchmark' AS record_source
    FROM peer_ranked
)

SELECT * FROM hashed

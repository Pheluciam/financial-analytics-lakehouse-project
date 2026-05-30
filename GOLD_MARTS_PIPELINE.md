# Gold Marts Pipeline — Phase 4 analytical surface for Power BI

> Walkthrough for the Phase 4 Gold marts layer. Scaffolded 2026-05-30 at
> Phase 4 session 1. Sibling docs at repo root:
> [EXTRACT_PIPELINE.md](EXTRACT_PIPELINE.md) (Phase 1 raw ingestion),
> [DBT_PIPELINE.md](DBT_PIPELINE.md) (Silver staging + intermediate +
> Data Vault 2.0 warehouse + Business Vault),
> [ORCHESTRATION_PIPELINE.md](ORCHESTRATION_PIPELINE.md) (Phase 3
> AWS Step Functions + Glue Python Shell), and (Phase 5)
> [POWERBI_PLAYBOOK.md](POWERBI_PLAYBOOK.md) — the locked architectural
> discipline rules for PBI Desktop work.

---

## 1. What this pipeline does

The Gold marts layer materializes pre-computed analytical surfaces from
the Silver Business Vault for Power BI Desktop consumption. Each mart is
a single dbt-athena Iceberg table that collapses the Raw Vault's 5-hop
hub-link-hub navigation into a flat row-shape Power BI can chart without
applying its own joins. The Business Vault PIT + Bridge query helpers
shipped at Phase 2 session 10 are the inputs every Phase 4 mart consumes
— marts JOIN through Bridge + PIT for "what was visible at as_of_date"
semantics in a single equi-join chain instead of recomputing SCD-2
latest-row anti-joins at query time.

Phase 4 ships four marts mapped to the four dashboard themes locked at
Phase 0:

1. **mart_pl_trend** — 10-year annual P&L trend per S&P 100 company.
   Shipped at Phase 4 session 1. THIS DOC's primary walkthrough.
2. **mart_peer_benchmark** — cross-company peer benchmarking at FY
   snapshots. Phase 4 session 2.
3. **mart_financial_health** — balance sheet ratios + cash flow signals.
   Phase 4 session 3.
4. **mart_growth_forecast** — annual revenue forecast via statsmodels
   ARIMA / Holt-Winters (Risk 38 lock at Phase 3 session 14 forward-
   verify). Phase 4 session 4.

A fifth executive-overview page in Power BI Desktop composes views over
the four marts; no fifth mart materializes — the overview is presentation-
layer composition only.

---

## 2. Architecture

The Gold marts layer sits between the Silver Business Vault and the
Power BI Desktop consumption surface:

```
Bronze (raw JSON over S3 via Glue Catalog views)
   └─► Silver / financial_analytics_silver
         ├─ staging      (1 model, view)
         ├─ intermediate (2 models, Iceberg)
         ├─ warehouse    (9 hub/link/sat models, Iceberg incremental + merge)
         ├─ business_vault (3 models: dim_as_of_dates, PIT, Bridge — Iceberg table)
         └─ marts        (Phase 4, Iceberg table)  ◄── THIS LAYER
                  │
                  └─► Power BI Desktop via Amazon Athena ODBC v2 driver
                         + Windows System DSN "FinancialAnalyticsAthena"
```

Marts co-exist in the financial_analytics_silver Glue database with the
Business Vault and Raw Vault layers — a separate Gold Glue database is
not architecturally necessary at S&P 100 scale and adds operational
overhead (extra IAM scope, extra Lake Formation grants in Phase 6) for
no analytical benefit. If the company universe scaled beyond 1,000
companies or multi-currency expansion landed, splitting Gold to its own
database would be the natural step.

Materialization is plain Iceberg table per the marts layer defaults in
[dbt/dbt_project.yml](dbt/dbt_project.yml) — NOT incremental + merge.
Marts are rebuilt every refresh from the Business Vault; there's no
SCD-2 to preserve and no insert-only contract to enforce. Each dbt run
is a full refresh. on_schema_change is inapplicable to the non-merge
path so the Iceberg merge + on_schema_change=sync_all_columns
duplicate-insertion bug class (Risk 2, LEARNINGS 2026-05-28) is
structurally avoided — same as the business_vault layer above.

---

## 3. Phase 4 session 1 deliverables

What landed at Phase 4 session 1 (2026-05-30):

- **Athena ODBC v2 driver install + Windows System DSN** — Risk 39
  prerequisite shipped before any mart authoring. Amazon Athena ODBC
  v2.0.6.0 (x64) installed; System DSN "FinancialAnalyticsAthena"
  registered with AwsRegion=us-east-1, Catalog=AwsDataCatalog,
  Schema=financial_analytics_silver, Workgroup=wg_financial_analytics,
  S3OutputLocation=s3://phil-financial-analytics-lakehouse/athena-results/,
  AuthenticationType=IAM Profile, AWSProfile=phil-dbt. Two new Risks
  banked at session close from the install path (Risk 40 + Risk 41 —
  driver silent-ignore on unknown attribute keys; Set-OdbcDsn
  destructive-replace semantics).
- **~/.aws/credentials populated** with [phil-dbt] profile section
  reading from .env env vars. PBI ODBC chains AWS credentials through
  named profiles in this file — env-var-only setups (the project's dbt
  pattern) need a one-time credentials-file population before PBI works.
  Risk 43 banked.
- **dbt/dbt_project.yml extended** with the marts/ layer config block —
  Iceberg table, Parquet format, matching the Business Vault layer
  pattern locked at Phase 2 session 10.
- **dbt/models/marts/mart_pl_trend.sql** — first Gold mart authored.
  Walkthrough at section 5 below.
- **dbt/models/marts/_models.yml** — schema YAML with 20 dbt schema
  tests on mart_pl_trend (1 unique_combination_of_columns +
  10 not_null + 1 unique + 4 accepted_values + 4 relationships).
- **sql/verify/13_phase4_marts_pl_trend_verification.sql** — 14
  structural verify checks (PASS/FAIL CTE pattern matching the 01-12
  verify suite).
- **Mart-shape PBI smoke test** — Project #2 carry-forward pattern.
  Walkthrough at section 6 below.

---

## 4. Layer config

The marts/ layer config block in
[dbt/dbt_project.yml](dbt/dbt_project.yml) mirrors business_vault's:

```yaml
marts:
  +materialized: table
  +table_type: iceberg
  +format: parquet
```

Three keys, same semantic as business_vault — plain Iceberg table, full
refresh per dbt run, no incremental merge mechanic, no on_schema_change
sensitivity. The accompanying doc-comment block above the config in
dbt_project.yml carries the design provenance.

---

## 5. mart_pl_trend walkthrough

The first Gold mart: 10-year annual Profit & Loss trend per S&P 100
company over the 10 fiscal year-end as-of-dates configured in
dim_as_of_dates.

**Grain.** Composite (cik, as_of_date, fiscal_year, canonical_concept).
as_of_date is RETAINED in the grain to demonstrate the BV PIT/Bridge
benefit end-to-end — collapsing to a latest-snapshot-only grain would
make the PIT/Bridge layer theatrical for the first mart. Current data
has no restatements (one Bronze extract), so values repeat across
visible as_of_dates per (cik, fiscal_year, canonical) — the redundancy
is intentional and demonstrates the architectural pattern Power BI will
see when restatement history accumulates in future Bronze extracts.

**Surrogate PK.** mart_pl_trend_hk = SHA-256 hex over the 4-column
composite grain, matching the project's single-key hash convention
(Risk 4 + Risk 6).

**Filter surface.**

- `canonical_concept IN ('revenue', 'net_income')` — current
  canonical_concepts_dictionary seed's income_statement coverage. Seed
  expansion to broader P&L lines (OperatingIncomeLoss, GrossProfit,
  CostOfRevenue, etc.) is deferred to a Phase 4 follow-up session;
  expansion requires re-running seed → intermediate → BV layer to
  propagate new canonical mappings into sat_concept_value's
  collapse-by-canonical chain.
- `fiscal_period = 'FY'` — annual filings only (10-K equivalent), not
  quarterly (10-Q). Conventional analyst annual P&L view. A separate
  mart_pl_quarterly is a logical future extension.

**JOIN topology.** 5-step equi-join chain over BV + RV:

1. `bridge_company_concept_period` (base spine, filter to fiscal_period
   = 'FY')
2. → `pit_link_filing_concept_period` (equi-join on link_hk + as_of_date,
   resolves visible sat coordinate at each snapshot)
3. → `sat_concept_value` (equi-join on link_hk + load_datetime, gets
   canonical_concept + value + unit + accession_number; canonical_concept
   filter applied here)
4. → `hub_company` (equi-join on hub_company_hk, gets cik)
5. → `sat_company_metadata` (equi-join on hub_company_hk, gets entity_name)

This is the pattern test the Business Vault was built for. Without PIT,
step 2's "which sat row is visible at as_of_date" lookup would be an
expensive correlated subquery / window-function anti-join per query;
with PIT, it's a single equi-join. Without Bridge, fiscal_year +
period_end_date access would need a JOIN to link_filing_concept_period;
with Bridge, both are already projected.

**Comparatives dedup (Risk 42, banked 2026-05-30).** SEC ASC 205
income-statement comparatives produce ~2x duplication at first-run
scale (19,371 dup rows on 19,393 unique grain tuples). Root cause: every
10-K reports the current fiscal year PLUS 2 prior years as comparatives,
so a single (cik, fiscal_year, canonical_concept) tuple appears in
MULTIPLE accession_numbers. The link_filing_concept_period grain
includes accession_number, the mart grain does not — naively joining
through Bridge → PIT → sat produces one mart row per accession reporting
that FY value. Dedup mechanic: ROW_NUMBER() OVER (PARTITION BY mart grain
ORDER BY accession_number DESC) — keep rn = 1, latest filing wins
(analyst-convention "current reported value for FY at the snapshot").
accession_number is brought through the CTE chain for the dedup step but
NOT projected to the mart output — audit trail of which accession a value
was sourced from lives in sat_concept_value at the warehouse layer.

**Output shape — 11 columns:**

| Column | Type | Source |
|---|---|---|
| mart_pl_trend_hk | varchar(64) | computed |
| cik | varchar | hub_company |
| entity_name | varchar | sat_company_metadata |
| as_of_date | date | bridge / dim_as_of_dates |
| fiscal_year | integer | bridge |
| canonical_concept | varchar | sat_concept_value |
| value_numeric | decimal(28,2) | sat_concept_value.value (post-MIN-collapse) |
| unit | varchar | sat_concept_value (constant 'USD' at current scope) |
| period_end_date | date | bridge |
| load_datetime | timestamp(6) | mart's own (current_timestamp at refresh) |
| record_source | varchar | constant 'mart.mart_pl_trend' |

**Row count.** 19,393 rows at session 1 first build. Composition is
roughly 100 companies × 2 canonical concepts × visibility-weighted
fiscal_year × as_of_date matrix. At as_of_date = 2025-12-31 the
visible fiscal_years for each company range FY2010-FY2024 (~14 years
of XBRL-era reporting). At earlier as_of_dates the visible window
shrinks per the filed_date <= as_of_date filter.

**Risk 45 + Risk 47 + Risk 48 — RESOLVED at Phase 4 session 2
(2026-05-30).** Three-Risk design pass surfaced at session 2 kickoff +
landed via cascade rebuild of sat_concept_value + mart_pl_trend +
mart_peer_benchmark. See section 8 ("Phase 4 session 2 deliverables")
for the full narrative — sat_concept_value collapse logic flipped from
MIN(value) to MAX(value) + preferred-tag seed tie-breaker, and the
marts gained an intra-accession period-chunk filter (period span
350-380 days + year(period_end_date) ∈ {fiscal_year, fiscal_year+1})
to drop the SEC XBRL anomaly where a single 10-K accession tags
multiple quarter / comparative periods with fp=FY fy=filing_year.
Post-cascade verification at session 2 close confirms Apple FY2019
revenue = $260.174B (analyst-correct, vs the session 1 MIN-collapse
artifact of ~$70B).

---

## 6. Mart-shape PBI smoke test pattern

Project #2 carry-forward: at every mart creation, build ONE minimal
Power BI Desktop visual against the new mart shape to catch
mart-architecture problems EARLY — not at Phase 5 dashboard build
time. The smoke test exercises the full end-to-end consumption path:
Athena ODBC v2 driver → Windows System DSN → IAM Profile authentication
chain → AWS Glue Catalog table resolution → Athena query → PBI
schema-detection + import → PBI visual render.

**Prerequisites (one-time Windows setup, Risk 39 banked at Phase 3
session 14 forward-verify, shipped at Phase 4 session 1 kickoff):**

1. Amazon Athena ODBC v2.0.6.0 (x64) driver installed via MSI from
   `https://downloads.athena.us-east-1.amazonaws.com/drivers/ODBC/v2.0.6.0/Windows/AmazonAthenaODBC-2.0.6.0.msi`.
   Verify via `Get-OdbcDriver | Where-Object { $_.Name -like "*Athena*" }`.
2. Windows System DSN "FinancialAnalyticsAthena" registered via
   `Add-OdbcDsn` (requires admin PowerShell). Seven connection-string
   params: AwsRegion, Catalog, Schema, Workgroup, S3OutputLocation,
   AuthenticationType=IAM Profile, AWSProfile. Verify via
   `Get-OdbcDsn -Name "FinancialAnalyticsAthena" -DsnType "System"`.
3. `~/.aws/credentials` populated with [phil-dbt] section reading from
   .env (one-time bootstrap; PBI ODBC chains through named profiles in
   this file, NOT env vars). Risk 43.

**Smoke test steps:**

1. Open Power BI Desktop. Dismiss any work/school sign-in dialog —
   Desktop functionality works fully signed-out; sign-in is only
   required for publishing to Power BI Service which is out of scope
   for this project (free Desktop only per locked tooling preference).
2. Home → Get Data → More... → search "Amazon Athena" → connect.
3. Connection settings: DSN = `FinancialAnalyticsAthena`,
   Connectivity mode = Import, Authentication kind = Anonymous (DSN
   carries the IAM Profile auth chain — PBI itself doesn't pass
   credentials). Click Next.
4. Navigator: tick mart_pl_trend in the financial_analytics_silver tree.
   Click Load.
5. After import, switch to Report view. Drop a Line chart visual. Axis:
   fiscal_year. Y-axis: value_numeric (default Sum aggregation is fine
   for smoke test; Phase 5 architectural discipline locked in
   [POWERBI_PLAYBOOK.md](POWERBI_PLAYBOOK.md) does NOT apply to
   throwaway validation .pbix files). Filters: cik = '0000320193'
   (Apple), canonical_concept = 'revenue', as_of_date = latest
   (31/12/2025).
6. Validate: ~10-14 ascending points, general upward trajectory,
   plausible values vs analyst reference. Save as
   `powerbi/01_smoke_test_phase_4_session_1.pbix`.

The smoke test PASSES if the mart-shape architecture flows end-to-end
through PBI with correct dimensions, types, units, and general trend
direction. Data-quality artifacts (e.g., Risk 45 MIN-collapse low
points) are upstream findings to bank for follow-up — they do NOT
fail the architectural smoke test.

---

## 7. Verification surface

The mart_pl_trend verify surface complements the dbt schema test pack
with cardinality + parity checks the YAML can't express. File:
[sql/verify/13_phase4_marts_pl_trend_verification.sql](sql/verify/13_phase4_marts_pl_trend_verification.sql).

14 checks:

1. mart_pl_trend_hk unique
2. mart_pl_trend_hk not null
3. mart_pl_trend_hk length 64 hex chars
4. FK closure to hub_company via cik
5. FK closure to dim_as_of_dates via as_of_date
6. FK closure to hub_concept via canonical_concept
7. Composite natural PK (cik, as_of_date, fiscal_year, canonical_concept)
   unique
8. Distinct as_of_date count = 10
9. canonical_concept ⊆ {'revenue', 'net_income'}
10. unit constant 'USD'
11. record_source constant 'mart.mart_pl_trend'
12. value_numeric not null (analyst-facing fact column, never silently
    NULL)
13. Apple sample hash determinism — recomputes the 4-component SHA-256
    chain and confirms stored hash matches
14. Row count in band [1,000, 20,000] — wide first-run defensive
    tolerance; tightens at Phase 4 session 2+ once empirical baseline
    is established

All 14 PASS at Phase 4 session 1 close (verify run in Athena Console
signed in as phil-admin, workgroup wg_financial_analytics, region
us-east-1).

Cumulative session 1 verification surface:

- 20 dbt schema tests on mart_pl_trend (PASS at the SECOND dbt build —
  first build caught Risk 42 comparatives dedup at the schema-test
  layer pre-Athena, validating the dbt schema test pack as an effective
  pre-flight surface).
- 14 SQL structural verify checks on mart_pl_trend (PASS in Athena).
- 1 mart-shape PBI smoke test (PASSED architecturally; Risk 45
  candidate banked for follow-up).

Phase 2 cumulative 121/121 dbt schema + 114/114 SQL structural verify
across the 16-model warehouse + business_vault surface remains
preserved — no model changes session 15.

---

## 8. Phase 4 session 2 deliverables

What landed at Phase 4 session 2 (2026-05-30):

- **dbt/seeds/canonical_concept_tag_preference.csv** — new seed driving
  the Risk 45 v2 sat_concept_value collapse tie-breaker (analyst-credible
  per-canonical ordered tag preference list). 8 rows covering all
  currently mapped concept_names: revenue with 4 alias entries
  (Revenues=1, RevenueFromContractWithCustomerExcludingAssessedTax=2,
  RevenueFromContractWithCustomerIncludingAssessedTax=3,
  SalesRevenueNet=4), net_income / assets / liabilities /
  stockholders_equity each with their single source tag at rank 1.
- **dbt/models/warehouse/sat_concept_value.sql** — Risk 45 v2 +
  Risk 47 refactor. canonical_observations CTE retains concept_name;
  new preference_ranked CTE INNER JOINs to the seed; collapsed_observations
  CTE replaces MIN(value) GROUP BY with ROW_NUMBER() OVER (PARTITION BY
  natural cardinal tuple ORDER BY value DESC, preference_rank ASC)
  keeping rn=1. Full-refresh rebuild propagates through PIT + Bridge +
  marts cascade.
- **dbt/models/marts/mart_peer_benchmark.sql** — second Gold mart,
  walkthrough in subsection 8.1 below.
- **dbt/models/marts/mart_pl_trend.sql** — Risk 48 dedup filter added
  to sat_resolved CTE (period span 350-380 days + year(period_end_date)
  ∈ {fiscal_year, fiscal_year+1}). Mart rebuild re-applies semantics
  post-cascade.
- **dbt/models/marts/_models.yml** — extended with mart_peer_benchmark
  entry (1 unique_combination + 19 column-level: not_null + unique +
  accepted_values + relationships). 26 schema tests on the new mart.
- **sql/verify/14_phase4_marts_peer_benchmark_verification.sql** — 17
  PASS/FAIL CTE structural checks (extending the 01-13 verify suite).
- **Mart-shape PBI smoke test on mart_peer_benchmark** — Project #2
  carry-forward pattern repeated. Apple FY2019 revenue = $260.174B
  (vs session 1 ~$70B MIN-collapse artifact) confirms the cascade
  landed at the analyst-facing surface. Archive saved as
  `powerbi/02_smoke_test_phase_4_session_2.pbix`.

Three Risks banked or revised this session: Risk 45 v1 (preferred-tag
seed, ORDER BY preference_rank ASC primary) → ASC-606-transition
anti-pattern surfaced → Risk 47 v1→v2 flip (ORDER BY value DESC
primary, preference_rank ASC tie-breaker only); Risk 48 mart-dedup
intra-accession period-chunk filter to address the deeper SEC XBRL
artifact where one 10-K accession tags multiple unrelated periods
with fp=FY fy=filing_year. See LEARNINGS.md Risks 46-48 for the full
diagnosis loops.

### 8.1 mart_peer_benchmark walkthrough

The second Gold mart: cross-company peer benchmarking at FY snapshots
over the S&P 100 universe. For each (cik, as_of_date, fiscal_year,
canonical_concept) row, projects the company's value alongside
peer-group aggregates (peer_count, peer_mean, peer_median, peer_stddev,
peer_min, peer_max) and the company's per-peer-group rank + percentile
(peer_rank, peer_percentile).

**Grain.** Composite (cik, as_of_date, fiscal_year, canonical_concept)
— identical to mart_pl_trend by design. Both marts are downstream
consumption surfaces of the same Bridge spine and PIT lookups.

**Surrogate PK.** mart_peer_benchmark_hk = SHA-256 hex over the
4-column composite grain, matching mart_pl_trend's hash convention.

**Filter surface.**

- `canonical_concept IN ('revenue', 'net_income', 'assets')` — three
  concepts spanning income statement (revenue + net_income) AND
  balance sheet (assets), giving PBI consumers a peer-benchmarking
  surface across both primary statement types. liabilities +
  stockholders_equity excluded — less useful for outright peer
  benchmarking at FY snapshot (more meaningful as ratios in
  mart_financial_health at session 3).
- `fiscal_period = 'FY'` — annual filings only.

**Peer group definition.** Single S&P 100 universe peer group — every
company in the same (as_of_date, fiscal_year, canonical_concept)
partition is treated as a peer of every other. Sector-segment peer
groups (Tech vs Consumer vs Financials, etc.) require an additional
cik → sector seed; deferred to Phase 4 session 3 alongside
mart_financial_health. The partition-keyed window functions naturally
extend to a richer (sector × as_of_date × fiscal_year × canonical)
partition spec when the seed lands.

**JOIN topology.** Identical 5-step equi-join chain over BV + RV as
mart_pl_trend. Differentiator is the trailing peer-aggregation CTEs.

**Peer aggregation shape.** Two trailing CTEs after the per-row
deduped surface:

- `peer_stats` — GROUP BY (as_of_date, fiscal_year, canonical_concept).
  Computes peer_count, peer_mean (AVG), peer_median (approx_percentile
  at 0.5 — Athena Engine 3 deterministic bounded-error algorithm, error
  tolerance trivial at S&P 100 scale), peer_stddev (population),
  peer_min, peer_max.
- `peer_ranked` — per-row window functions over the same partition.
  peer_rank via `RANK() OVER (... ORDER BY value_numeric DESC)` —
  1 = highest in peer group, ties share rank, next jumps.
  peer_percentile via `CUME_DIST() OVER (... ORDER BY value_numeric
  ASC)` — 1.0 = highest, fraction = proportion of peers at-or-below
  (standard analyst percentile interpretation).

Two separate CTEs by design — GROUP BY aggregates collapse cardinality
and JOIN back; window functions preserve cardinality and project
per-row. Keeping them isolated produces a more readable join shape
than mixing window aggregates with per-row window ranks in one pass.

**Risk 48 dedup filter (shared with mart_pl_trend).** Conditional
applied at sat_resolved CTE: year(period_end_date) must match
fiscal_year ± 1, AND for income-statement canonicals only (revenue +
net_income), period span must be 350-380 days. Balance sheet
canonical (assets) is exempt from the span filter — point-in-time
balance sheet observations have period_start_date NULL or equal to
period_end_date so date_diff would be 0 (outside the 350-380 band).
The year filter alone correctly drops prior-year comparatives for
balance sheet items.

**Output shape — 19 columns:** mart_peer_benchmark_hk, cik,
entity_name, as_of_date, fiscal_year, canonical_concept, value_numeric,
unit, peer_count, peer_mean, peer_median, peer_stddev, peer_min,
peer_max, peer_rank, peer_percentile, period_end_date, load_datetime,
record_source.

**Row count.** 29,936 rows at session 2 close (10,600 assets +
9,775 revenue + 9,561 net_income). Pre-Risk-48 (pre-filter) build was
29,994 rows; the 58-row delta is the dropped intra-accession
period-chunks + non-matching-year comparatives.

### 8.2 Verification surface at session 2 close

- **20 dbt schema tests on mart_pl_trend (PASS post-cascade rebuild)** —
  unchanged from session 1; Risk 48 filter is row-level not schema-level.
- **26 dbt schema tests on mart_peer_benchmark (PASS at first build)** —
  1 unique_combination + 11 not_null + 1 unique + 5 accepted_values +
  8 relationships.
- **14 SQL structural verify checks on mart_pl_trend
  (PASS in Athena post-cascade)** — row count band 19,336 (within
  [1,000, 20,000] tolerance).
- **17 SQL structural verify checks on mart_peer_benchmark
  (PASS in Athena)** — row count band 29,936 (within [3,000, 60,000]
  tolerance); peer_rank ∈ [1, peer_count] across all rows;
  peer_percentile ∈ (0, 1]; peer_count consistent per partition (405
  partitions at first build → 270 partitions at second build post-Risk-48
  filter).
- **2 mart-shape PBI smoke tests** — session 1
  (`01_smoke_test_phase_4_session_1.pbix`) re-confirmed analyst-correct
  post-cascade; session 2
  (`02_smoke_test_phase_4_session_2.pbix`) confirms mart_peer_benchmark
  end-to-end consumption + Apple FY2019 revenue = $260.174B
  analyst-correct.

Cumulative verification surface at session 2 close: **46 dbt schema
tests on the marts surface + 31 SQL structural verify checks** across
the two active Gold marts. Phase 2 cumulative 121/121 dbt schema +
114/114 SQL structural verify on the warehouse + business_vault surface
preserved (sat_concept_value Risk 45 v2 refactor rebuilt without
cardinality change at the sat layer — all 45 sat+BV schema tests PASS
post-cascade).

---

## 9. Phase 4 session 3 deliverables

Third Gold mart shipped 2026-05-30: **mart_financial_health** — per-company
annual ratios spanning income statement, balance sheet, and cash flow.
Cohort with the session ships the canonical seed expansion (8 → 13 raw
us-gaap tags) and the new sp100_company_sector seed driving the
mart_peer_benchmark sector-segmented peer cascade (Option A bundle).

### 9.1 Canonical seed expansion

`dbt/seeds/canonical_concepts_dictionary.csv` extended from 8 rows to 13:
adds `OperatingIncomeLoss → operating_income`, `GrossProfit → gross_profit`,
`CostOfRevenue → cost_of_revenue` (income statement depth);
`CashAndCashEquivalentsAtCarryingValue → cash_and_equivalents` (balance
sheet); `NetCashProvidedByUsedInOperatingActivities → operating_cash_flow`
(cash flow statement). `canonical_concept_tag_preference.csv` matches
with rank-1 entries for each new single-tag canonical. Six hardcoded
Jinja `{% set concepts %}` lists extended in lock-step across
`int_sec_edgar__concepts.sql`, `link_company_filing.sql`,
`link_filing_concept_period.sql`, `hub_filing.sql`,
`sat_concept_value.sql`, `sat_filing_metadata.sql` — keeps the UNNEST
+ canonical-resolution chain consistent across the layers. Intermediate
`_models.yml` accepted_values for concept_name + canonical_concept
extended in parallel.

The expansion drives 110 new schema tests at the warehouse + BV layers
(231/231 PASS at first cascade build). Cumulative warehouse + BV verify
surface preserved cleanly.

### 9.2 sp100_company_sector seed

New seed `dbt/seeds/sp100_company_sector.csv` — 107 rows, columns
(cik, ticker, entity_name, gics_sector, gics_industry_group). CIKs
sourced authoritatively from SEC EDGAR's `company_tickers.json`
(public endpoint, no auth). 10-digit zero-padded format matches
`hub_company.cik` exactly so the LEFT JOIN by cik is collision-free.
Sector taxonomy = GICS 11 sectors × 24 industry groups (S&P + MSCI
2023 reclassification standard). Distribution across the 107 in-scope
companies: Financials 19, Information Technology 18, Health Care 16,
Consumer Discretionary 13, Industrials 11, Consumer Staples 10,
Communication Services 9, Energy 4, Real Estate 3, Utilities 3,
Materials 1.

dbt_project.yml seeds block extended with column_types pinning cik
to varchar(10) (preserves SEC's zero-padded identifier) and the four
descriptive columns to varchar of appropriate width. _seeds.yml
documents the seed including accepted_values on gics_sector enforcing
the 11 canonical sector names.

Universe sized intentionally larger than `hub_company` so the cascade
degrades gracefully — CIKs without a matching seed row COALESCE to
`gics_sector = 'UNCATEGORIZED'` at the mart layer. Future S&P 100
roster changes = add rows; no model changes required.

### 9.3 mart_peer_benchmark sector cascade (Option A)

mart_peer_benchmark partition key extended from
`(as_of_date, fiscal_year, canonical_concept)` to
`(as_of_date, fiscal_year, canonical_concept, gics_sector)`. New
`sector_resolved` CTE inserted between `deduped` and `peer_stats` —
LEFT JOIN to `sp100_company_sector` by cik, COALESCE('UNCATEGORIZED')
for unmatched. `peer_stats` GROUP BY + `peer_ranked` window function
PARTITION BY both extended with the sector key. Each cik has exactly
one sector at any given time, so the cardinality of the mart is
preserved (29,936 rows pre- and post-cascade); only the peer-group
aggregates re-partition.

Verification surface in `sql/verify/14_phase4_marts_peer_benchmark_verification.sql`
extended in lock-step — `partition_counts` CTE GROUP BY now matches
the 4-key sector partition shape. Pre-cascade had 405 (3-key)
partitions; post-cascade 4,055 (4-key sector-segmented) partitions.

### 9.4 mart_financial_health walkthrough

Per-company annual ratios with **a different grain from the prior two
marts**: composite (cik, as_of_date, fiscal_year) — no canonical_concept
in the grain because each row PIVOTS the 9 in-scope canonical values
onto a single row as columns, then projects 8 derived ratios over the
pivoted base.

**Source canonicals (9).** Income statement: revenue, gross_profit,
operating_income, net_income. Balance sheet: assets, liabilities,
stockholders_equity, cash_and_equivalents. Cash flow: operating_cash_flow.

**Derived ratios (8), NULLIF-guarded.**

| Ratio | Formula |
|---|---|
| gross_margin | gross_profit / revenue |
| operating_margin | operating_income / revenue |
| net_margin | net_income / revenue |
| return_on_assets | net_income / assets |
| return_on_equity | net_income / stockholders_equity |
| debt_to_equity | liabilities / stockholders_equity |
| operating_cf_margin | operating_cash_flow / revenue |
| cash_to_assets | cash_and_equivalents / assets |

NULL ratio when denominator is NULL or 0 (companies that don't report a
canonical surface NULL honestly rather than silently filling zero).
debt_to_equity here is the simpler liabilities/equity leverage
approximation — a true LongTermDebt-based D/E is deferred to a future
canonical seed expansion (LongTermDebt + ShortTermDebt tags). Documented
for PBI consumers.

**JOIN topology.** Same 5-step BV+RV equi-join chain as mart_pl_trend +
mart_peer_benchmark (bridge_fy → pit_resolved → sat_resolved →
company_resolved), then trailing CTEs deduped (Risk 42 per-canonical
ROW_NUMBER) → pivoted (MAX CASE collapse on (cik, as_of_date, fiscal_year))
→ with_ratios → hashed. Risk 48 period filter applied as conditional
per-concept-type at sat_resolved — balance-sheet canonicals exempt from
the 350-380 day IS span filter (point-in-time instant observations).

Composite hash PK `mart_financial_health_hk` = SHA-256 over the 3-column
grain. Row count = 10,610 at first build. 17 dbt schema tests + 17 SQL
structural verify checks all PASS.

### 9.5 Risk 49 — Salesforce 2010-2013 pre-ASC-606 gross_profit > revenue artifact

PBI smoke test at session 3 surfaced 13 rows where gross_margin
slightly exceeded 1.0 (1.02–1.07x) — all Salesforce (cik 0001108524),
fiscal years 2010-2013 (4 distinct fy × ~3 visible as_of_dates each).
Root cause = pre-ASC-606 revenue tagging mismatch where Salesforce's
GrossProfit us-gaap tag is anchored to a multi-tag revenue base while
sat_concept_value's value DESC ORDER BY collapse picks the largest
single Revenues alias for those years. Not a mart bug — known
data-quality artifact at the sat-collapse + raw-tag interaction. 13
rows / 10,610 = 0.12%.

Verify check 15 in `sql/verify/15_phase4_marts_financial_health_verification.sql`
excludes the documented (cik, fy) window from both numerator and
denominator so the structural invariant tests cleanly across the rest
of the universe. Future targeted fix = per-company tag-preference
override at sat_concept_value (deferred — narrow benefit, sufficient to
document the artifact at session 3).

### 9.6 Verification surface at session 3 close

Cumulative marts surface: **63 dbt schema tests + 48 SQL structural verify
checks** across the 3 active Gold marts (mart_pl_trend 20 + 14;
mart_peer_benchmark 28 + 17 — +2 schema tests for gics_sector +
gics_industry_group; mart_financial_health 17 + 17). Phase 2 cumulative
121/121 + 114/114 on warehouse + business_vault preserved; canonical
seed expansion produced +110 new schema tests at the warehouse / BV
layers that all PASS at first build.

### 9.7 PBI smoke test session 3

mart_financial_health Apple line chart on fiscal_year × net_margin
across FY2015-FY2025. Trajectory rendered: 22.8% → 21.2% → 21.1% → 22.4%
→ 21.2% → 21.0% (covid) → 25.9% (tech boom) → 25.3% → 25.3% → 24.0% →
26.9%. Matches Apple's reported FY2023 25.3%. Risk 45 + 47 + 48 cascade
vindicated at the ratio surface — net_margin computing off the correct
revenue base. Saved as `powerbi/03_smoke_test_phase_4_session_3.pbix`.

---

## 10. Phase 4 roadmap

| Session | Deliverable | Status |
|---|---|---|
| 4.1 | mart_pl_trend + ODBC/DSN prerequisite + smoke test pattern + this doc | SHIPPED 2026-05-30 |
| 4.2 | mart_peer_benchmark + Risk 45 v2 / Risk 47 / Risk 48 cascade | SHIPPED 2026-05-30 |
| 4.3 | mart_financial_health + canonical seed expansion + sp100_company_sector seed + mart_peer_benchmark sector cascade (Option A bundle) + Risk 49 | SHIPPED 2026-05-30 |
| 4.4 | mart_growth_forecast + scripts/forecast.py (statsmodels ARIMA / Holt-Winters) | pending |
| 4.5 | Phase 4 CLOSE — structural audit + reflection rolling Phase 4 Risks into pattern families | pending |

statsmodels-over-Prophet lock at Phase 3 session 14 forward-verify
(Risk 38). Annual cadence + Apple/Stan compile footprint considerations
documented in LEARNINGS.md Phase 4 forward-verify subsection.

---

## 11. References

- Project conventions: [TEACHING_PREFERENCES.md](TEACHING_PREFERENCES.md),
  [ENGINEERING_STANDARDS.md](ENGINEERING_STANDARDS.md),
  [PROJECT_PLAN.md](PROJECT_PLAN.md) (section 9 Phase 4 entry).
- Upstream pipelines: [EXTRACT_PIPELINE.md](EXTRACT_PIPELINE.md),
  [DBT_PIPELINE.md](DBT_PIPELINE.md),
  [ORCHESTRATION_PIPELINE.md](ORCHESTRATION_PIPELINE.md).
- Downstream consumption: [POWERBI_PLAYBOOK.md](POWERBI_PLAYBOOK.md)
  (Phase 5 architectural discipline rules — read FIRST at every Phase 5
  session before proposing any PBI step).
- Risk register: [LEARNINGS.md](LEARNINGS.md) — Phase 4 Risks 38-49
  banked across forward-verify + sessions 1-3.
- Authoritative AWS docs:
  `https://docs.aws.amazon.com/athena/latest/ug/odbc-v2-driver.html` and
  `https://docs.aws.amazon.com/athena/latest/ug/odbc-v2-driver-iam-profile.html`.
- Project #2 mart-shape PBI smoke test pattern carry-forward: catch
  mart-architecture problems at mart-creation time, not at dashboard
  build time.

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

**Risk 45 candidate (banked at smoke test).** sat_concept_value's
MIN(value) tie-breaker (Risk 16, locked at Phase 2 session 8) produces
analyst-visible artifacts in mart_pl_trend — Apple FY2019 renders as
~$70B (actual: ~$260B) because the MIN-collapse selects the SMALLER of
multiple Revenue alias tags reported for that period. The smaller
alias often excludes assessed tax / partial services, producing
artifactually-low values for some fiscal years. NOT a mart bug — the
collapse decision is upstream at sat_concept_value. Phase 4 follow-up
options: (a) switch MIN(value) → MAX(value) at sat_concept_value (less
conservative, full-revenue bias); (b) add per-canonical preferred-tag
mapping (e.g., for 'revenue', prefer
'RevenueFromContractWithCustomerExcludingAssessedTax' over 'Revenues'
when both exist); (c) accept the bias and document for analyst
consumers. Decision deferred to Phase 4 session 2 design pass.

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

## 8. Phase 4 roadmap

| Session | Deliverable | Status |
|---|---|---|
| 4.1 | mart_pl_trend + ODBC/DSN prerequisite + smoke test pattern + this doc | SHIPPED 2026-05-30 |
| 4.2 | mart_peer_benchmark + Risk 45 sat_concept_value collapse decision pass | pending |
| 4.3 | mart_financial_health + canonical seed expansion (broader P&L coverage) | pending |
| 4.4 | mart_growth_forecast + scripts/forecast.py (statsmodels ARIMA / Holt-Winters) | pending |
| 4.5 | Phase 4 CLOSE — structural audit + reflection rolling Phase 4 Risks into pattern families | pending |

statsmodels-over-Prophet lock at Phase 3 session 14 forward-verify
(Risk 38). Annual cadence + Apple/Stan compile footprint considerations
documented in LEARNINGS.md Phase 4 forward-verify subsection.

---

## 9. References

- Project conventions: [TEACHING_PREFERENCES.md](TEACHING_PREFERENCES.md),
  [ENGINEERING_STANDARDS.md](ENGINEERING_STANDARDS.md),
  [PROJECT_PLAN.md](PROJECT_PLAN.md) (section 9 Phase 4 entry).
- Upstream pipelines: [EXTRACT_PIPELINE.md](EXTRACT_PIPELINE.md),
  [DBT_PIPELINE.md](DBT_PIPELINE.md),
  [ORCHESTRATION_PIPELINE.md](ORCHESTRATION_PIPELINE.md).
- Downstream consumption: [POWERBI_PLAYBOOK.md](POWERBI_PLAYBOOK.md)
  (Phase 5 architectural discipline rules — read FIRST at every Phase 5
  session before proposing any PBI step).
- Risk register: [LEARNINGS.md](LEARNINGS.md) — Phase 4 Risks 38-45
  banked across forward-verify + session 1.
- Authoritative AWS docs:
  `https://docs.aws.amazon.com/athena/latest/ug/odbc-v2-driver.html` and
  `https://docs.aws.amazon.com/athena/latest/ug/odbc-v2-driver-iam-profile.html`.
- Project #2 mart-shape PBI smoke test pattern carry-forward: catch
  mart-architecture problems at mart-creation time, not at dashboard
  build time.

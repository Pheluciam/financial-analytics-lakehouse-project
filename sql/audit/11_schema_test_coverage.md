# sql/audit/11_schema_test_coverage.md — Audit 10 schema test coverage gap report

> Phase 5 audit 10 of 10 — schema test coverage gap report.
>
> This is a documentation audit. No SQL queries run against the warehouse.
> The audit inventories every dbt schema test currently defined, maps
> coverage to the failure modes Audits 1-9 surfaced, and queues new tests
> for the Fix-all phase. The 249/249 passing dbt schema tests give a
> green light on STRUCTURAL integrity but caught ZERO of the 191-cell
> gap matrix from Audit 3 — all current tests are structural, none are
> semantic.
>
> Authored 2026-06-01.

---

## A10.1 — Inventory of current dbt schema tests

Sourced from:
- `dbt/models/intermediate/_models.yml`
- `dbt/models/warehouse/_models.yml`
- `dbt/models/business_vault/_models.yml`
- `dbt/models/marts/_models.yml`

### Intermediate layer (2 models)

| Model | Tests applied |
|---|---|
| int_sec_edgar__concepts | not_null on cik, extract_date, concept_name, unit; accepted_values on concept_name (13 us-gaap tags), unit ('USD') |
| int_sec_edgar__concepts_canonical | + accepted_values on canonical_concept (10 values), business_area (3 values) |

### Warehouse layer (9 models — Raw Vault)

| Model | Tests applied |
|---|---|
| hub_company | unique + not_null on hub_company_hk; unique + not_null on cik; not_null on load_datetime, record_source |
| hub_filing | unique + not_null on hub_filing_hk; unique + not_null on accession_number; not_null on load_datetime, record_source |
| hub_concept | unique + not_null on hub_concept_hk; unique + not_null on canonical_concept; not_null on load_datetime, record_source |
| link_company_filing | unique + not_null on link_company_filing_hk; relationships to hub_company + hub_filing; not_null on cik, accession_number, load_datetime, record_source |
| link_filing_concept_period | unique + not_null on link_filing_concept_period_hk; 3 relationships (hub_company, hub_filing, hub_concept); not_null on cik, accession_number, canonical_concept, period_end_date, load_datetime, record_source. NO not_null on period_start_date, fiscal_year, fiscal_period (defensive) |
| sat_filing_metadata | dbt_utils.unique_combination_of_columns(hub_filing_hk, load_datetime); unique + not_null on sat_filing_metadata_hk; relationships to hub_filing; not_null on hashdiff, accession_number, form_type, filed_date, load_datetime, record_source |
| sat_company_metadata | dbt_utils.unique_combination_of_columns(hub_company_hk, load_datetime); unique + not_null on sat_company_metadata_hk; relationships to hub_company; not_null on hashdiff, cik, entity_name, load_datetime, record_source |
| sat_concept_value | dbt_utils.unique_combination_of_columns(link_filing_concept_period_hk, load_datetime); unique + not_null on sat_concept_value_hk; relationships to link_filing_concept_period; not_null on hashdiff, cik, accession_number, canonical_concept, period_end_date, value, unit, load_datetime, record_source |
| sat_concept_canonical (MAS) | dbt_utils.unique_combination_of_columns(hub_concept_hk, sub_sequence_key, load_datetime); unique + not_null on sat_concept_canonical_hk; relationships to hub_concept; not_null on hashdiff, sub_sequence_key, canonical_concept, concept_name, load_datetime, record_source |

### Business Vault layer (3 models)

| Model | Tests applied |
|---|---|
| dim_as_of_dates | unique + not_null on as_of_date; not_null on as_of_datetime, fiscal_year_end, load_datetime, record_source |
| pit_link_filing_concept_period | dbt_utils.unique_combination_of_columns(link_filing_concept_period_hk, as_of_date); unique + not_null on pit_link_filing_concept_period_hk; relationships to link_filing_concept_period + dim_as_of_dates; not_null on load_datetime, record_source. NO not_null on sat_concept_value_pk, sat_concept_value_ldts (ghost-record deferral) |
| bridge_company_concept_period | dbt_utils.unique_combination_of_columns(link_filing_concept_period_hk, as_of_date); unique + not_null on bridge_company_concept_period_hk; 4 relationships (hub_company, hub_filing, hub_concept, link_company_filing, link_filing_concept_period); not_null on period_end_date, as_of_date, load_datetime, record_source. NO not_null on fiscal_year, fiscal_period |

### Marts layer (4 models)

| Model | Tests applied |
|---|---|
| mart_pl_trend | dbt_utils.unique_combination_of_columns(cik, as_of_date, fiscal_year, canonical_concept); unique + not_null on mart_pl_trend_hk; relationships to hub_company (cik), dim_as_of_dates, hub_concept; accepted_values on canonical_concept (['revenue','net_income']), unit (['USD']), record_source; not_null on entity_name, fiscal_year, value_numeric, period_end_date, load_datetime |
| mart_peer_benchmark | same + accepted_values on canonical_concept (['revenue','net_income','assets']); not_null on gics_sector, peer_count, peer_mean, peer_median, peer_min, peer_max, peer_rank, peer_percentile |
| mart_financial_health | dbt_utils.unique_combination_of_columns(cik, as_of_date, fiscal_year); unique + not_null on mart_financial_health_hk; relationships to hub_company + dim_as_of_dates; accepted_values on record_source; not_null on entity_name, fiscal_year, period_end_date, load_datetime. NO not_null on the 9 canonical columns or 8 ratio columns (defended NULL allowed) |
| mart_growth_forecast | dbt_utils.unique_combination_of_columns(cik, canonical_concept, fiscal_year, as_of_date, row_kind); unique + not_null on mart_growth_forecast_hk; relationships to hub_company, hub_concept; accepted_values on canonical_concept (['revenue']), row_kind (['historical','forecast']), model_name (['holt_winters_additive','arima_1_1_0']), record_source |

**Total dbt schema tests: 249 (passing 249/249 at session start per PROJECT_CONTEXT).**

---

## A10.2 — Failure modes caught vs missed

Current tests catch 6 failure-mode classes:

1. Hash-key uniqueness violations (silent join-graph corruption)
2. Business-key uniqueness violations (duplicate entities)
3. Foreign-key closure violations (dangling joins, orphan rows)
4. Not-null integrity violations on required columns
5. Accepted-values violations (schema drift on canonical_concept, business_area, row_kind, model_name, etc.)
6. Composite-PK uniqueness violations at the sat / mart grain (dbt_utils)

These are STRUCTURAL tests — they verify the warehouse SHAPE is consistent with the contract, but they don't verify the VALUES are semantically correct.

Failure-mode classes NOT caught:

1. **Completeness thresholds** — no test ensures "mart_financial_health has at least N of 107 CIKs reporting revenue at FY2024." Audit 2's 191-cell gap matrix passes all current tests.
2. **Cross-mart consistency** — no test ensures mart_pl_trend.revenue equals mart_financial_health.revenue for the same (cik, fy). Audit 7's 421 divergent rows pass all current tests.
3. **Value sanity ranges** — no test enforces "Apple FY2024 revenue must be > $300B." Garbage values in any single cell pass.
4. **Filter-chain bug detection** — no test catches "fiscal_period='FY' filter dropped SPGI." Audit 4's bug passes all current tests.
5. **Collapse semantics validation** — no test verifies Risk 47 collapse picks the analyst-headline value for multi-tag canonicals (revenue).
6. **Forecast plausibility** — no test on CI ordering, growth ratio sanity, or AIC outlier detection. Audit 9's 5 outliers pass.
7. **Snapshot stability** — no test on PIT consistency across as_of_dates. Audit 8's 123 drifted tuples pass.
8. **Tag mapping coverage** — no test that the canonical_concepts_dictionary covers raw us-gaap tags appearing in production filings for in-scope companies.

---

## A10.3 — Map to the 191-cell gap matrix from Audit 3

| Gap class (from AUDIT_FINDINGS Audit 3) | Cells | Current tests catch? |
|---|---|---|
| RECENT_PIPELINE_BUG (mart filter chain drops) | 22 | NO — passes structural tests |
| OLD_TAG_RENAME (seed alias expansion needed) | 55 | NO — passes structural tests |
| NEVER_IN_SAT — derivable via mart-layer formula | 65 | NO — passes structural tests |
| NEVER_IN_SAT — truly defended NULL | 49 | NO — correctly absent, no test needed |

**Current tests catch 0 of the 191 gap cells.** All gaps are semantic; all tests are structural.

This is the project's most consequential single gap — the dbt schema test layer needs SEMANTIC coverage added in Fix-all to catch regressions of Audit 4-7 architectural fixes when they ship.

---

## A10.4 — Recommended new tests for Fix-all phase

### Data tests (project-level, in dbt/tests/*.sql)

1. **`mart_financial_health_revenue_completeness.sql`** — assert at the latest as_of_date, count(distinct cik) WHERE revenue IS NOT NULL AND fiscal_year=2024 >= 95. Catches Audit 4 regression (post-fix expected ~104 of 107).

2. **`mart_financial_health_anchor_aapl_revenue.sql`** — assert that AAPL FY2024 revenue at latest as_of_date is between $380B and $400B. Anchored to Audit 6 anchor truth (verified $391.035B). Same pattern for MSFT, JPM, BRK.B, WMT, XOM. 6 anchor data tests.

3. **`cross_mart_revenue_consistency.sql`** — assert count of (cik, fy) tuples where mart_pl_trend.revenue != mart_financial_health.revenue (within $1) = 0 at latest as_of_date. Catches Audit 7 regression.

4. **`cross_mart_net_income_consistency.sql`** — same shape for net_income.

5. **`cross_mart_assets_consistency.sql`** — same for assets (mart_peer_benchmark vs mart_financial_health).

6. **`mart_growth_forecast_ci_ordering.sql`** — assert count of forecast rows WHERE NOT (lower_ci_95 <= forecast_value AND forecast_value <= upper_ci_95) = 0. Catches forecast CI corruption.

7. **`mart_pl_trend_snapshot_stability.sql`** — assert count of (cik, fy, canonical) tuples with distinct_values > 1 across as_of_dates is <= EXPECTED_RESTATEMENT_COUNT (initially set to the Audit 8 baseline of 5 real restatements; post-Fix expected to fall back to 5 once the 118 dedup-bug tuples heal).

8. **`canonical_concept_tag_preference_collapse_rule.sql`** — assert every row in the canonical_concept_tag_preference seed has collapse_rule IN ('value_desc', 'preference_rank_asc'). Catches seed schema drift on the new column introduced at Fix-all per Audit 5.

### Generic tests (add to existing _models.yml)

9. **dbt_expectations.expect_column_values_to_be_between** on mart_financial_health.net_margin: min_value=-1.0, max_value=1.0. Catches ratio corruption.

10. **dbt_expectations.expect_column_values_to_be_between** on mart_financial_health.return_on_assets: min_value=-1.0, max_value=1.0 (with row_condition for non-bank sectors — banks legitimately fall in narrower range).

11. **dbt_expectations.expect_column_values_to_be_between** on mart_growth_forecast.growth_ratio (computed column): min_value=0.3, max_value=3.0. Flags model pathologies like the GE / MMM cases from Audit 9.

### Tag coverage (intermediate layer)

12. **`canonical_concepts_dictionary_coverage.sql`** — post-Fix, after the seed expansion adds the alias tags (CashCashEquivalentsRestricted..., StockholdersEquityIncludingPortionAttributableToNoncontrollingInterest, MinorityInterest, LiabilitiesAndStockholdersEquity, CostOfRevenue variants, sector-specific revenue tags). Assert count of (cik, canonical) tuples WHERE expected_tag IS NOT NULL but sat_concept_value has no row = 0. Catches seed regression where a tag gets removed but its mapped canonical still needs it.

### Total recommended additions

12 new tests. Conservative estimate. The first 8 (data tests) are highest priority — they catch the specific architectural fixes from Audits 4, 5, 6, 7, 8, 9.

---

## A10.5 — Tests that COULD be added but would create false positives

1. **"Every CIK has gross_profit"** — banks (JPM, BAC, etc.), REITs (PLD, AMT, CCI), and asset-light services correctly don't report GrossProfit. Defended NULL — adding this test fails by design.

2. **"Every CIK has operating_cash_flow under the exact NetCashProvidedByUsedInOperatingActivities tag"** — some entities use the ContinuingOperations variant. Defended NULL.

3. **"Every CIK has revenue at every FY"** — the 49 truly defended NULLs from Audit 3 would fail. Should be replaced with "every CIK has revenue at every FY OR is in the defended-NULL pin list."

4. **"value_numeric > 0"** — net_income legitimately negative for distressed quarters; operating_income negative for early-stage growth companies. Replace with "value_numeric IS NOT NULL AND |value_numeric| < 10^13" (sanity range).

5. **"mart_growth_forecast.forecast_value is always within historical range"** — defeats the forecast's purpose of projecting growth or decline beyond observed bounds.

These false-positive avoidance principles will inform the Fix-all phase test additions to keep the test suite green-on-correct-data.

---

## A10.6 — Audit 10 verdict

- Current 249 dbt schema tests are SOUND for structural integrity but BLIND to semantic correctness.
- Adding the 12 recommended data + generic tests during Fix-all phase brings semantic coverage to the architectural fixes from Audits 4-9.
- Post-Fix dbt build + dbt test should report 249 + 12 = 261 passing tests.
- Re-audit pass (re-run sql/audit/02 through sql/audit/11) confirms the warehouse heals as predicted.

---

## Files referenced

- `dbt/models/intermediate/_models.yml`
- `dbt/models/warehouse/_models.yml`
- `dbt/models/business_vault/_models.yml`
- `dbt/models/marts/_models.yml`
- `AUDIT_FINDINGS.md` (Audits 1-3)
- `sql/audit/05_pipeline_filter_diagnosis.sql` (Audit 4 finding)
- `sql/audit/06_collapse_semantics.sql` (Audit 5 finding + scorecard)
- `sql/audit/07_external_anchors.sql` (Audit 6 anchor results)
- `audit/anchor_truth.md` (Audit 6 anchor values + source URLs)
- `sql/audit/08_cross_mart_consistency.sql` (Audit 7 finding)
- `sql/audit/09_snapshot_consistency.sql` (Audit 8 finding)
- `sql/audit/10_forecast_sanity.sql` (Audit 9 finding)

---

*Authored AI-assisted (Claude by Anthropic) per the standing AI-assistance disclosure convention.*

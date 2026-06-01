# AUDITS_4_TO_10_SCOPE.md — Next-session scope handoff

> Written 2026-06-01 at end of Phase 5 session 2 to hand off Audits 4-10
> to the next session. Audits 1-3 documented in AUDIT_FINDINGS.md.
>
> Read this + AUDIT_FINDINGS.md at session kickoff. Together they tell
> the next session everything it needs to start cold without drifting
> from the audit plan.

---

## Session kickoff checklist

1. Read TEACHING_PREFERENCES.md, PROJECT_CONTEXT.md, LEARNINGS.md (latest).
2. Read AUDIT_FINDINGS.md (Audits 1-3 results).
3. Read this file (Audits 4-10 scope).
4. Confirm state: should have 107 seed in Bronze, 115 in hub_company
   (107 seed + 8 orphans), Audits 1-3 audit files in `sql/audit/`.
5. Pick up at Audit 4.

---

## Operating principles

- **No "essentially complete" language.** Every audit either PASSes or
  doesn't. No "sort of." No "I think we have enough." Phil flagged this
  explicitly. Each audit closes when the SQL evidence proves it.
- **No fixes during audits.** Audits 4-10 INVESTIGATE only. Fix-all phase
  (task #30) batches every fix at the end as one coherent change.
- **No drift from the audit plan.** Each audit has a specific scope below.
  Stay in scope. Don't expand mid-audit.

---

## Audit 4 — Mart-pipeline filter diagnosis

**Scope.** Find every "tag-present-but-mart-null" pattern across all 9
canonicals. From AUDIT_FINDINGS.md A3.10, 22 RECENT_PIPELINE_BUG cells
need this diagnosis. Plus SPGI's total mart absence (A3.11).

**File to create.** `sql/audit/05_pipeline_filter_diagnosis.sql`.

**Suggested query progression.**

- A4.1 — SPGI complete trace at FY2024. For SPGI specifically, query
  every layer with fiscal_year=2024 (no fiscal_period filter) to see at
  what stage SPGI's FY2024 data drops out:
  - Bronze stg_sec_edgar__companyfacts_raw: how many rows for SPGI?
  - sat_concept_value: at what fiscal_period codes does SPGI have rows
    for FY2024? Q1/Q2/Q3 only? Or also Q4 or CY or other?
  - link_filing_concept_period at FY2024 for SPGI: fiscal_period codes
    actually filed.
  - bridge_company_concept_period at FY2024 for SPGI: fiscal_period
    codes actually present.
  - mart_pl_trend WHERE fiscal_period = 'FY' filter: where does SPGI
    drop?
- A4.2 — For the 22 RECENT_PIPELINE_BUG cells, query
  sat_concept_value to see what fiscal_period codes their canonical
  values use at FY2024.
- A4.3 — Compare the fiscal_period code distribution between "passing"
  CIKs (have FY-period sat rows) vs "failing" CIKs at FY2024.
- A4.4 — Diagnose the root cause: are these CIKs filing under fp='CY'
  instead of 'FY'? fp='Q4' for the year-end? Some other code?
- A4.5 — Identify the smallest mart_financial_health.sql change that
  recovers the cells. Likely "WHERE fiscal_period IN ('FY', 'CY', 'Q4')"
  on the bridge OR a smarter "latest FY-period instance per
  (cik, fiscal_year, canonical)" rule. Document the proposed fix shape
  — do NOT apply.

**Expected output.** Root cause identified + fix proposal documented.
Heals 22 cells.

---

## Audit 5 — Risk 45/47 Collapse Semantics Validation Per Canonical

**Scope.** For each canonical with multiple seed-mapped tags, verify
that the Risk 47 value-DESC + preference_rank ASC collapse picks the
correct value. Check for silent inflation (e.g., is cash_and_equivalents
inflated by Restricted-cash component when we add the alias?).

**File to create.** `sql/audit/06_collapse_semantics.sql`.

**Suggested query progression.**

- A5.1 — For revenue (currently 4 mapped tags), per CIK at FY2024 latest:
  list ALL pre-collapse value candidates + the collapsed value. Verify
  the picked value matches the company's published headline revenue.
- A5.2 — For cash_and_equivalents AFTER the proposed alias addition
  (CashCashEquivalentsRestricted...): for each (CIK, FY) where both bare
  and Restricted tags exist, the value-DESC would pick the larger. Quantify
  the over-statement vs published 10-K cash.
- A5.3 — For every multi-tag canonical, document the collapse rule + its
  worst-case impact.

**Expected output.** Documented collapse-semantics scorecard per canonical.
Identifies any need for canonical-specific collapse override.

---

## Audit 6 — External Anchor Checks vs Published 10-Ks

**Scope.** Validate values against external truth. Per-company spot-checks
against the published 10-K for FY2024. S&P 100 aggregate vs published
index summaries.

**File to create.** `sql/audit/07_external_anchors.sql` + companion
`audit/anchor_truth.md` listing the manually-verified anchor values
per CIK from their 10-Ks.

**Suggested query progression.**

- A6.1 — Apple FY2024: revenue ~$391B, net_income ~$93.7B, assets ~$364B,
  cash ~$67B. Cross-check via Athena.
- A6.2 — Microsoft FY2024 (FY ends June): revenue ~$245B, net_income
  ~$88B, assets ~$512B.
- A6.3 — JPMorgan FY2024: net_income ~$58B (banks have unusual revenue
  shape; cross-check the IncomeBeforeTax proxy).
- A6.4 — Berkshire Hathaway FY2024 (anomalous — holding company; complex
  consolidation).
- A6.5 — Walmart FY2024 (FY ends late January).
- A6.6 — Exxon Mobil FY2024: revenue ~$344B.
- A6.7 — S&P 100 aggregate revenue FY2024 vs published index summary
  (~$10T expected).
- A6.8 — Sector subtotals for the 2-3 sectors where aggregate-published
  numbers are checkable.

**Expected output.** Per-CIK per-canonical match/mismatch report. Any
mismatch >1% gets root-caused before Fix-all phase.

---

## Audit 7 — Cross-mart consistency

**Scope.** For canonicals appearing in multiple marts, values match per
(CIK, FY, as_of_date). A2.5 confirmed count consistency for revenue
across mart_pl_trend + mart_financial_health + mart_peer_benchmark.
Audit 7 verifies VALUE consistency, not just count consistency.

**File to create.** `sql/audit/08_cross_mart_consistency.sql`.

**Suggested query progression.**

- A7.1 — Per (CIK, FY), mart_pl_trend.value_numeric (revenue) =
  mart_financial_health.revenue = mart_peer_benchmark.value_numeric
  (where canonical='revenue').
- A7.2 — Same for net_income, assets.
- A7.3 — mart_growth_forecast historical leg = mart_pl_trend revenue
  value per (CIK, FY).
- A7.4 — Any divergence rows surfaced explicitly + root-caused.

**Expected output.** Count of divergent rows. Expected: 0. Any non-zero =
real bug.

---

## Audit 8 — Snapshot consistency (as_of_date PIT logic)

**Scope.** Verify the BV PIT/Bridge logic correctly produces snapshot-
specific views. mart rows at multiple as_of_dates should correctly
reflect restatement scenarios.

**File to create.** `sql/audit/09_snapshot_consistency.sql`.

**Suggested query progression.**

- A8.1 — For each (CIK, fiscal_year, canonical) tuple in mart_pl_trend
  with multiple as_of_date rows, do the value_numeric values change?
  If yes — restatement detected, verify it's a real restatement (10-K/A
  filing) not a bug.
- A8.2 — For a sample CIK known to have restated (need to identify one
  from EDGAR — possibly Boeing post-2024), verify the values across
  as_of_dates reflect the restatement story.
- A8.3 — Latest-snapshot consistency: at MAX(as_of_date), every CIK
  should have only its most-recent reported value for each (FY, canonical).
  No duplicates.

**Expected output.** PIT logic validated OR restatement bugs surfaced.

---

## Audit 9 — Forecast sanity (mart_growth_forecast)

**Scope.** 98 forecasts × 3 forecast years validated for plausibility.
CI bands sensible. Per-company model fit didn't blow up.

**File to create.** `sql/audit/10_forecast_sanity.sql`.

**Suggested query progression.**

- A9.1 — Forecast bounds sanity: lower_ci_95 < forecast_value <
  upper_ci_95 for every forecast row. (CI ordering invariant.)
- A9.2 — Forecast growth plausibility: forecast_value / latest historical
  revenue per CIK. Flag anything >2x or <0.5x as suspicious — likely
  model fit pathology.
- A9.3 — model_aic distribution: identify outlier-AIC models (very large
  AIC = bad fit, very small AIC = suspicious overfit).
- A9.4 — Cohort sanity: per AUDIT_FINDINGS A2.4, 4 cohorts identified.
  Verify the stale cohorts (FY2014-latest, FY2019-latest) are exactly
  the companies whose historical revenue series stops at those years (=
  Risk 55 chronic-missing CIKs).

**Expected output.** Forecast quality scorecard. Flag any forecasts that
shouldn't ship to dashboards.

---

## Audit 10 — Schema test coverage gap report

**Scope.** Document what each dbt schema test covers + does NOT cover.
Identify gaps where schema tests pass but data is materially wrong.
Strengthen schema tests where needed (additions to `dbt/models/.../_models.yml`).

**File to create.** `sql/audit/11_schema_test_coverage.md` (markdown,
not SQL — this is a documentation audit).

**Suggested approach.**

- A10.1 — Inventory every dbt schema test currently defined across the
  4 marts + warehouse + business_vault + intermediate layers.
- A10.2 — For each test, document what failure mode it catches.
- A10.3 — Map to the 191-cell gap matrix from Audit 3: which gaps would
  any current test have caught? Answer: zero — all current tests are
  structural, none semantic.
- A10.4 — Recommend new tests to add: completeness threshold tests,
  value-correctness tests via anchor CIKs (Apple revenue >$300B at
  FY2024), cross-mart consistency tests.
- A10.5 — Document tests that COULD be added but would create false
  positives (e.g., "every CIK has gross_profit" would fail for banks —
  banks are correctly absent).

**Expected output.** Schema test coverage strengthening recommendations
queued for the Fix-all phase.

---

## After Audits 4-10 close

Move to **task #30 — Fix-all phase.** Implement every fix in one coherent
commit family:

1. Universe filter at hub_company (Audit 1 fix).
2. Mart-pipeline bug fix in mart_financial_health.sql (Audit 4 fix).
3. Seed alias expansions per canonical (canonical_concept_tag_preference.csv
   + canonical_concepts_dictionary.csv + Jinja concept lists in sat_concept_value +
   intermediate models per lockstep).
4. Mart-layer derivation columns: gross_profit = rev − cost; liabilities =
   LiabAndSE − SE; SE = SEIncludingNCI − MI; cash via Restricted alias.
5. Defended-NULL evidence pinning: companion markdown listing each defended
   cell with JSON-probe URL.
6. Schema test additions from Audit 10.
7. Cascade rebuild + re-run all 10 audit files. Every audit PASSes.

Then **task #32** documentation, **task #33** resume Page 1 design call
on data we trust 100%.

---

## State snapshot at handoff

- Seed: 107 distinct CIKs.
- Bronze: 115 distinct CIKs (107 seed + 8 orphans).
- hub_company: 115 CIKs.
- 4 marts: 115 CIKs each (8 orphans propagating).
- mart_growth_forecast: 114 CIKs (8 orphans + 106 seed = 114; GS missing
  due to Risk 55 revenue gap).
- mart_financial_health FY2024 latest snapshot: 191 missing cells
  classified per AUDIT_FINDINGS.md.
- Audit files shipped: `sql/audit/02_universe_integrity.sql`,
  `sql/audit/03_completeness.sql`, `sql/audit/04_tag_evidence.sql`.
- Audit file pending creation: `sql/audit/05_pipeline_filter_diagnosis.sql`
  through `sql/audit/11_schema_test_coverage.md` (Audits 4-10).
- Bronze cik enum extended in `sql/ddl/01_create_bronze_tables.sql` +
  `sql/ddl/02_create_bronze_raw_text_table.sql` (115 values).
- All dbt schema tests passing (249/249 at last build).

---

*Authored AI-assisted (Claude by Anthropic) per the standing
AI-assistance disclosure convention.*

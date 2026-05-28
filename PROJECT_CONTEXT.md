# Project Context — financial-analytics-lakehouse-project

> Running state record. Read at the start of every session alongside
> TEACHING_PREFERENCES.md. Captures WHERE we are in the project — what's
> shipped, what's locked, what's open, what's blocked, what's queued for
> the next session. PROJECT_PLAN.md is the static "what we're building";
> this file is the live "where we are right now."
>
> Created: 2026-05-23 (Phase 0 closeout). Updated at every session close
> per the bundled-commit cadence in TEACHING_PREFERENCES.md.

---

## Current status

| Field | Value |
|---|---|
| Active phase | **Phase 2 in progress.** Session 8 CLOSED 2026-05-28 — value satellite end-to-end. Three new warehouse models shipped: hub_concept (5 rows, BK = canonical_concept), link_filing_concept_period (3-way STANDARD link, 89,821 rows, period attributes as descriptive link-level payload), sat_concept_value (89,821 rows, payload = value + unit, parent = link_filing_concept_period). THIS IS the model holding the actual numerical SEC EDGAR financial data — Apple's FY2023 revenue, Microsoft's quarterly net income, S&P 100 balance-sheet totals — every Phase 4 Gold mart joins through here. Forward-verify pass refined the kickoff Option-A direction via doc-verify (scalefree.com multi-temporality + non-historized link articles) + empirical four-aggregate probes against int_sec_edgar__concepts_canonical. Three new Risks banked at the pass BEFORE any model code shipped: Risk 14 (hub_period is non-standard for transactional observation data — 10,974 distinct periods is transactional grain, not reference-hub grain; hub_period DEFERRED indefinitely), Risk 15 (non-historized vs standard link decision depends on whether relationship-instance grain is unique-per-source-event or repeating — SEC XBRL fits standard link, NOT NHL), Risk 16 (canonical-concept dictionary joins produce per-canonical duplicates from multi-tag-same-period dual-reporting; DISTINCT at post-canonical natural cardinal tuple collapses 5,941-row gap; MIN(value) tie-breaker on disagreements). 34/34 dbt schema tests PASS (6 hub_concept + 14 link + 14 sat including 3 FK relationships + composite-PK + value/unit not_null). 32/32 SQL structural verify PASS in 7.7 sec total. Idempotency proven via second dbt run [OK 0 / OK 0 / OK 0 in 37.56s]. 10/10 ENGINEERING_STANDARDS audit PASS. Cumulative warehouse-layer: 77/77 dbt schema + 76/76 SQL structural across 5 hubs + 2 links + 3 sats. |
| Next phase | Phase 2 session 9 — TBD. Three possible directions: (a) **Phase 2 close** if no more warehouse models needed — would write a phase-boundary structural audit + LEARNINGS Phase 2 reflection + push to Phase 3 kickoff (orchestration via Step Functions, dbt-runtime decision per Risk 3). (b) **Additional satellites** — sat_concept_canonical (mapping audit lineage from raw concept_name → canonical_concept via the dictionary) is the obvious candidate if it earns its keep for downstream consumers. (c) **Information delivery objects** — PIT (point-in-time) tables or Bridge tables in the Business Vault for the per-as-of-date snapshot pattern the Gold marts will consume. Default direction at session 9 kickoff = (a) Phase 2 close + Phase 3 transition unless the Phase 4 mart design needs surface mid-flow. |
| Last session closed | 2026-05-28 (Phase 2 session 8 — CLOSE) |
| Last bundled commit | 2026-05-28 — Phase 2 session 8 bundle (3 new warehouse models: hub_concept.sql + link_filing_concept_period.sql + sat_concept_value.sql with 7-column composite hash including period payload + standard-link locked over NHL + MIN(value) tie-breaker on canonical-collapse disagreement; warehouse/_models.yml extended with 3 new blocks = 34 schema tests; sql/verify/07/08/09 = 32 structural checks; sql/diagnostic/01_phase2_session8_sat_concept_value_cardinality_probes.sql as the design-time empirical-probe artefact (new sql/diagnostic/ folder convention); DBT_PIPELINE.md sections 8.16/8.17/8.18/8.19 covering hub_concept + the 3-way standard link architectural decision + sat_concept_value SCD-2 framing + 3-file verify surface + cumulative 77/77 + 76/76 stats; LEARNINGS.md Risks 14/15/16 banked at the forward-verify pass BEFORE code shipped) |
| Active blockers | None |
| Open questions | None at the architectural level. Phase 2 may be close-ready — direction call deferred to session 9 kickoff. |

---

## What's locked

All Phase 0 decisions locked 2026-05-23. Full table in PROJECT_PLAN.md
section 4. Stack summary in PROJECT_PLAN.md section 3. Full deliberation
history in LEARNING_ROADMAP.md "Notes / changes" 2026-05-23 entries.

Eight locks at a glance:

1. History depth — 10 years
2. Operational layer — direct-to-S3 (no RDS)
3. Transformation tool — dbt-athena
4. Power BI publishing — continuous + freeze at v1.0
5. Company universe — S&P 100 current roster
6. Dashboard themes — 4 (P&L trend, Peer benchmarking, Financial health/ratios, Growth/forecasting) + 1 executive overview
7. Orchestration — AWS Step Functions
8. SEC EDGAR User-Agent — `Phil <pheluciam@outlook.com>`

Two major pivots also locked this session: cloud (Azure → AWS), analytical
platform (Databricks → AWS-native lakehouse S3 + Glue + Athena + Lake
Formation). Databricks deferred to mini-project slot 2 of the mini-projects
block (see LEARNING_ROADMAP.md).

Three standing conventions baked in across the project (live in
TEACHING_PREFERENCES.md):

- AI-assistance disclosure on every README (paste-able template lives in
  TEACHING_PREFERENCES.md)
- In-session debugging discipline (Phil drives the diagnosis, not just
  accepts the fix; bank non-trivial bugs in LEARNINGS.md)
- Debugging fluency as the priority emphasis area in the 6-8 week training
  journey

---

## What's open

Deliberately deferred OUT of Phase 0, handled at Phase 1 kickoff:

- AWS account creation (12-month Free Tier clock starts at account creation
  — timing with actual build start is optimal)
- GitHub repo creation + first commit
- Python venv setup + `requirements.txt` scaffolding
- `.env.example` template authoring

Deferred to specific later phases (per PROJECT_PLAN.md section 14):

- Python forecasting library choice (Prophet vs statsmodels) → Phase 4
- dbt-athena Iceberg vs Parquet materialisation → Phase 2 dbt scaffolding
- Lake Formation governance → Phase 6 stretch

Not deferred — actively NOT in scope for Project #3:

- Databricks (deferred to mini-project slot 2)
- AWS Glue ETL Spark / PySpark (deferred to mini-project slot 5 — streaming)
- Microsoft Fabric (deferred to mini-project slot 3)
- Streaming ingestion (deferred to mini-project slot 5)
- ML beyond simple Python forecasting (deferred — no ML platform in Project #3)
- Risk + anomaly dashboard theme (10-K/A restatements — dropped at Phase 0)

---

## Session log

Append a new entry at every session close. Newest at top.

### 2026-05-28 — Phase 2 session 8 — value satellite end-to-end (hub_concept + link_filing_concept_period + sat_concept_value) + 3 new Risks (14/15/16) at forward-verify pass + cumulative 77/77 dbt schema + 76/76 SQL structural warehouse-layer all-green

**Goal.** Ship the value satellite — sat_concept_value — that holds the actual numerical SEC EDGAR financial data every downstream Phase 4 Gold mart will consume. Resolve the period/fiscal attribute home decision deferred from session 6 (Risk 12). First activity = phase-kickoff forward-verify pass per the standing rule (period-grain modeling is a genuinely new architectural pattern relative to the single-parent satellite shape established in sessions 6 + 7).

**Forward-verify pass (fifth time the rule applied) — biggest scope yet.** Doc-verify against scalefree.com (multi-temporality in DV2.0 part 1, non-historized links article) + automate-dv.readthedocs.io (t_link tutorial). Two key findings refined the kickoff Option-A direction (hub_period + link_filing_period split):

1. **Period-as-hub is non-standard for transactional observation data.** Scalefree's multi-temporality article treats period attributes as time-spans inside satellites with multi-temporal awareness, not as separate hubs. hub_period is only DV2.0-idiomatic for enterprise-wide reference entities (fiscal calendar with cross-system reuse). For per-source-observation period attributes the canonical placement is link-level or sat-level payload.
2. **XBRL fact values are transactional-shape in source.** Per Scalefree's non-historized link article, source-event observation data at original granularity is the canonical NHL use case — but the link-class call depends on whether the relationship-instance grain is unique-per-source-event (standard link) or repeating-per-source-event (NHL).

Empirical four-aggregate probes against int_sec_edgar__concepts_canonical (Risk 13 carry-forward, run by Phil in Athena):

- **Probe 1.** 93,869 rows / 5 distinct canonical_concepts / 2 distinct business_areas / canonicals = [net_income, stockholders_equity, liabilities, assets, revenue]. → hub_concept = 5 rows locked.
- **Probe 2.** 93,869 total vs 87,928 distinct (cik, canonical_concept, period_*) tuples → 5,941-row canonical-collapse gap from multi-tag-same-period dual-reporting (revenue alias tags during ASC 606 transition). → DISTINCT + GROUP BY collapse strategy + MIN(value) tie-breaker locked. Also confirmed Bronze cardinality drift = 2 extract_dates from Risk 13 carries through to canonical layer.
- **Probe 3.** 10,974 distinct (period_start, period_end, fy, fp) instances → transactional grain, not reference-hub grain. → hub_period DEFERRED indefinitely (Risk 14 banked).
- **Probe 4.** 29,815 (cik, canonical, period_end_date) groups with 9,335 (31%) having value disagreement; max 10 distinct values per group → analysis surfaced this is a mix of period-grain ambiguity, multi-filing same-period reporting, canonical-collapse double-projection, and only a subset of true restatements. Critically: adding accession_number to the grain made each tuple unique-per-filing. → standard link locked over NHL (Risk 15 banked).

**Probe artefact preserved.** sql/diagnostic/01_phase2_session8_sat_concept_value_cardinality_probes.sql — new sql/diagnostic/ folder convention for design-time investigation queries (distinct from sql/verify/ which holds re-runnable structural PASS/FAIL checks). Full SQL + intent + observed results + design implications captured inline so the artefact is self-documenting in git.

**Three new Risks banked at forward-verify pass BEFORE any code shipped:**

- **Risk 14** — hub_period is non-standard for transactional observation data. Carry-forward: probe distinct period cardinality before adding a temporal hub; if it's tens of thousands relative to source observations, periods are transactional grain and belong as payload, not as a hub. Generalises to any future portfolio project with date-keyed observation data.
- **Risk 15** — non-historized vs standard link decision depends on whether the relationship-instance grain is unique-per-source-event or repeating. Carry-forward: the link-class test is "if the upstream source pushed the same relationship-tuple twice, would those be distinct events with potentially different values [→ NHL] or duplicate-extract noise [→ standard link]." SEC XBRL fits standard; sales transactions per (customer, store, product) fit NHL. Domain-agnostic principle.
- **Risk 16** — canonical-concept dictionary joins produce per-canonical duplicates from multi-tag-same-period dual-reporting. Carry-forward: when sourcing from a layer that performs semantic collapse (dictionary join, code-to-label mapping), DISTINCT at the post-collapse natural cardinal tuple is the defensive standard. Generalises Risk 11 (pre-collapse DISTINCT) into a post-collapse DISTINCT principle.

**What landed.**

- **dbt/models/warehouse/hub_concept.sql shipped.** Third DV2.0 hub. BK = canonical_concept. 5 rows. Source = int_sec_edgar__concepts_canonical (intermediate view) rather than the seed directly — DV2.0 hubs hold first-observed BKs in actual data, not enumerated reference lists. Same single-key SHA-256 hash chain as hub_company / hub_filing.
- **dbt/models/warehouse/link_filing_concept_period.sql shipped.** Second DV2.0 link, 3-way STANDARD link (not NHL per Risk 15) associating hub_company + hub_filing + hub_concept with the per-period observation grain. 89,821 rows. 7-column composite SHA-256 hash includes both parent BKs AND the period payload (period_start_date, period_end_date, fiscal_year, fiscal_period) — without the payload in the hash, two genuinely-distinct observations sharing the same (cik, accn, canonical) but different period instances would collide. DISTINCT at post-canonical natural cardinal tuple per Risk 16 collapses 5,941 dual-tag duplicates. COALESCE-to-'^^' sentinel on period_start_date (NULL for balance-sheet instant-period concepts) per Risk 8. 3 FK hash columns computed via single-key chains matching each parent hub so FK joins are valid by construction. Insert-only via source-side NOT IN filter pattern matching link_company_filing.
- **dbt/models/warehouse/sat_concept_value.sql shipped.** Third DV2.0 satellite. Parent = link_filing_concept_period. Payload = value (DECIMAL(28,2)) + unit ('USD'). 89,821 rows = 1:1 with link. THIS IS the model with the actual financial data. Inherits the satellite pattern from sessions 6 + 7 (NOT EXISTS anti-join + COALESCE-sentinel hashdiff + dedicated sat hash + composite-PK test). Value disagreement collapse via MIN(value) at source-side GROUP BY (Risk 16 sub-decision) — deterministic, audit-traceable, biases toward conservative revenue measurement (analyst convention). SCD-2 mechanic fires only on rare same-accession value drift across extract_dates (1 chance within current Bronze); restatements normally come via NEW accession_numbers which produce NEW link rows naturally.
- **dbt/models/warehouse/_models.yml extended.** Three new model blocks: hub_concept (6 column tests), link_filing_concept_period (14 column tests including 3 FK relationships), sat_concept_value (14 column tests + 1 composite-PK test on (link_filing_concept_period_hk, load_datetime)). 34 new schema tests total.
- **sql/verify/07/08/09 shipped.** 32 structural checks across 3 new models — 8 on hub_concept (1.73 sec), 12 on link (3.77 sec), 12 on sat (2.20 sec). All hash-determinism reproducibility checks anchor on Apple sample (cik 0000320193, revenue) per project convention.
- **sql/diagnostic/01_phase2_session8_sat_concept_value_cardinality_probes.sql shipped.** Design-time empirical-probe artefact. New sql/diagnostic/ folder convention.
- **DBT_PIPELINE.md sections 8.16-8.19 shipped.** 8.16 hub_concept structural intro, 8.17 link_filing_concept_period with the architectural-decision narrative + probe artefact references + 7-column composite-hash explainer, 8.18 sat_concept_value as THE fact-value model + MIN-tie-breaker rationale + SCD-2 mechanic on SEC restatement patterns, 8.19 cumulative verification surface + idempotency proof + 77/77 + 76/76 cumulative stats.
- **LEARNINGS.md** — Risks 14/15/16 banked at the kickoff forward-verify pass (BEFORE any code shipped, per the rule). All three carry forward to future portfolio projects beyond Project #3.

**Verification surface at session 8 close.**

- 34/34 dbt schema tests PASS on the 3 new models in 37.10 sec
- 77/77 dbt schema tests PASS across the warehouse layer (cumulative — 43 sessions 4-7 + 34 session 8)
- 32/32 SQL structural verify PASS across the 3 new models in 7.7 sec total
- 76/76 SQL structural verify PASS across the warehouse layer (cumulative — 44 sessions 4-7 + 32 session 8)
- 10/10 ENGINEERING_STANDARDS tick-box audit PASS (Currency, Compactness, Resource efficiency, Privacy & security, Workflow consistency, Dev env hygiene, Upstream/downstream contract, Idempotency, Pre/post verification, Observable progress)
- Idempotency proven: second dbt run [OK 0 / OK 0 / OK 0 in 37.56s] across all three models — NOT IN filter (hub + link), NOT EXISTS anti-join (sat) all fired correctly
- dbt parse implicitly clean (would have errored at dbt run otherwise)

**Decisions locked this session (at the forward-verify pass).**

- **link_filing_concept_period is a STANDARD link, not non-historized.** Source-event grain is unique-per-filing in SEC reporting; restatements come via NEW accession_numbers. NHL deferred indefinitely.
- **Period attributes live as descriptive link-level payload, not on a separate hub_period.** 10,974 distinct period instances is transactional grain. hub_period deferred indefinitely.
- **Canonical-concept dictionary collapse needs DISTINCT at post-collapse natural cardinal tuple AT MODEL SOURCE SIDE.** 5,941-row gap from dual-tag dual-reporting; DISTINCT + GROUP BY + MIN(value) tie-breaker collapses cleanly.
- **MIN(value) is the deterministic tie-breaker on canonical-collapse value disagreement.** Biases toward conservative revenue measurement (analyst convention); audit-traceable.
- **sql/diagnostic/ is a new project folder convention** for design-time investigation artefacts (vs sql/verify/ for re-runnable structural PASS/FAIL checks).

**Blockers / surprises.** Within-session refinement: the kickoff direction-check locked "Option A — hub_period + link_filing_period split", but the doc-verify pass refined the architecture to standard link + period-as-payload (NO hub_period). Flagged to Phil mid-session as a refinement of the chosen direction, not a flip; Phil acknowledged and the work continued. No actual blockers. One probe-2 metric-label slip ("distinct_filings_seen" should have been "distinct_cik_form_type_pairs") — caught and corrected in the saved diagnostic SQL file; underlying result still informative for design.

**NOT in this session — deferred.**

- **sat_concept_canonical** (raw-tag → canonical-concept audit lineage satellite) → Phase 2 session 9+ if it earns its keep for downstream consumers.
- **PIT / Bridge tables in Business Vault** → Phase 4 mart-design time if needed.
- **Phase 2 close + Phase 3 transition** → Phase 2 session 9 kickoff direction call.
- **README.md Status line refresh** → Phase 2 close.

**Next session.** Phase 2 session 9 — TBD direction call at kickoff: (a) Phase 2 close + Phase 3 transition (default), (b) sat_concept_canonical satellite, or (c) Business Vault PIT/Bridge objects. Est. 30-90 min depending on direction.

---

### 2026-05-28 — Phase 2 session 7 — second DV2.0 satellite (sat_company_metadata) + empirical-probe-over-inferred-parity carry-forward (Risk 13) + 11/11 structural verify PASS + cumulative 43/43 warehouse-layer test all-green

**Goal.** Ship the second DV2.0 satellite — sat_company_metadata,
parent = hub_company, payload = entity_name from $.entityName
top-level companyfacts JSON field. Exercise the 1:1 cardinality
invariant explicitly at the simplest satellite shape so the
Risk 12 carry-forward discipline (cardinality-test at design
time, test-ordering by cost, forward-verify-pass includes
cardinality reasoning) gets a clean working example. First
activity = phase-kickoff forward-verify pass per the standing
rule.

**Forward-verify pass (fourth time the rule applied).**
Restricted-domain web-search-verify against sec.gov (companyfacts
JSON top-level structure — confirmed $.entityName by fetching
Apple's live companyfacts and inspecting the first bytes:
`{"cik":320193,"entityName":"..."`) and scalefree.com (DV2.0 1:1
satellite pattern reaffirmation). New element this session per
Risk 12 + the now-banked Risk 13: empirical cardinality probe
against actual Bronze BEFORE writing the model.

The probe surfaced an empirical cardinality fact that the
inferred-parity argument (parent = 100, payload = top-level field,
expected first-load = 100) had missed. Phil ran via Athena:

```sql
SELECT
    COUNT(*) AS total_bronze_rows,
    COUNT(DISTINCT cik) AS distinct_ciks,
    COUNT(DISTINCT extract_date) AS distinct_extract_dates,
    COUNT(DISTINCT json_extract_scalar(json_text, '$.entityName')) AS distinct_entity_names
FROM financial_analytics_bronze.sec_edgar_companyfacts_raw;
```

Result: 101 / 100 / 2 / 100. One CIK had been extracted twice on
two different dates (likely a Phase 1 ingestion re-run mid-session
for one company), with the SAME entity_name across both extract
rows. Naive read of staging without DISTINCT would have shipped
101 satellite rows on first load, breaking the 1:1 invariant with
hub_company. DISTINCT (cik, entity_name) baked into the model's
distinct_companies CTE before any code ran. Risk 13 banked with
the carry-forward principle: every future satellite's
forward-verify pass includes the same four-aggregate empirical
probe against actual Bronze, not just function-chain doc-verify.

**Sub-note within the forward-verify pass — table-name verify-then-write miss.**
First attempt at the empirical probe used a guessed table name
(`bronze_sec_edgar_companyfacts_raw_text` — Claude's read-from-memory
guess) that returned `TABLE_NOT_FOUND`. Actual table name from the
session-2 DDL is `sec_edgar_companyfacts_raw` (no `bronze_`
prefix). Caught immediately (Phil pasted the error, fix landed in
one round) but it's a verify-then-write category miss adjacent to
the criterion-6 proactive-bypass rule. Banked as a sub-note on
Risk 13 with carry-forward: for any diagnostic query targeting a
table identifier Claude hasn't recently written, grep the project
for the canonical identifier first.

**What landed.**

- **`dbt/models/warehouse/sat_company_metadata.sql` shipped.**
  Second DV2.0 satellite. Parent = hub_company. 1 truly
  company-level payload attribute: entity_name (from
  $.entityName top-level field, exposed by the typed cover-page
  staging stg_sec_edgar__companyfacts — the openx SerDe handles
  the JSON-to-typed-column mapping at table creation time).
  Materially simpler model body than session 6 — no Jinja
  for-loop, no CROSS JOIN UNNEST. DISTINCT (cik, entity_name)
  collapse defends against Bronze cardinality drift (Risk 13).
  Dedicated sat_company_metadata_hk = SHA-256 hash over
  (hub_company_hk || '||' || CAST(load_datetime AS varchar)) —
  visual-consistency carry from session 6. hashdiff = SHA-256
  over COALESCE(entity_name, '^^') — single-column payload, no
  '||' delimiter required (delimiter defends against
  multi-column concat ambiguity, not present here). SCD-2
  insert-on-change via NOT EXISTS anti-join on
  latest-hashdiff-per-parent — identical pattern to
  sat_filing_metadata.
- **`dbt/models/warehouse/_models.yml` extended.** sat_company_metadata
  block — 7 columns (sat_company_metadata_hk, hashdiff,
  hub_company_hk, cik, entity_name, load_datetime,
  record_source), 9 column-level tests, + 1 model-level
  dbt_utils.unique_combination_of_columns on the composite
  natural PK (hub_company_hk, load_datetime). 10 schema tests
  total. dbt_utils argument-nesting structure inherited from
  the session-6 working example — no new proactive-bypass
  invocation needed since the test type was already locked at
  session 6. Stale-description fix on sat_filing_metadata
  hashdiff column applied at the same edit ("6 payload columns"
  corrected to "2 payload columns" with a note on the session-6
  scope trim).
- **`sql/verify/06_phase2_warehouse_sat_company_metadata_verification.sql`
  shipped.** Parallel CTE PASS/FAIL pattern to verify/05. 11
  checks: sat hash key uniqueness + not_null + length 64,
  hashdiff not_null + length 64, FK closure to hub_company,
  composite natural PK (hub_company_hk, load_datetime)
  uniqueness, parent coverage parity (sat distinct parent count
  = hub_company count = 100 — the 1:1 invariant guard, Risk 13
  run-time counterpart to the design-time empirical probe),
  sat_hk + hashdiff reproducibility on Apple (cik 0000320193 —
  simpler than session-6 verify/05 because 1:1 with hub_company
  means a direct cik filter, no min-accession join chain),
  record_source constant. 11/11 PASS in 2.55 sec.
- **DBT_PIPELINE.md sections 8.14 / 8.15 shipped.** 8.14 frames
  sat_company_metadata as the second satellite inheriting the
  session-6 pattern with a materially simpler model body
  (entityName is a top-level field, no UNNEST), surfaces the
  forward-verify cardinality probe artefact (the four-aggregate
  Athena query + empirical result 101/100/2/100 + the SCD-2
  contract validity note for future loads), explains why the
  hashdiff function chain drops the '||' delimiter for a
  single-column payload. 8.15 walks through verify/06's 11-check
  surface + cumulative warehouse-layer test stats: 43/43 schema
  tests + 44/44 SQL structural checks all-green.
- **LEARNINGS.md** — Risk 13 banked at the kickoff forward-verify
  pass (BEFORE any code shipped, per the rule). Title: "Bronze
  cardinality drift across extract_dates breaks naive parent-count
  inference: empirical cardinality probe mandatory at every
  satellite forward-verify pass." Carry-forward: empirical probe
  over inferred parity. Sub-note: verify-then-write miss on the
  table name `sec_edgar_companyfacts_raw` (Claude's `bronze_`-prefixed
  guess was wrong). Carry-forward for diagnostic identifier
  references: grep the project for canonical identifier first.

**Verification surface at session 7 close.**

- 10/10 dbt schema tests PASS on sat_company_metadata's 7 columns
  + composite-PK test (2 hk + 1 hashdiff + 2 FK + 1 cik + 1
  entity_name + 1 LDTS + 1 RSRC + 1 composite)
- 43/43 dbt schema tests PASS across the warehouse layer
  (cumulative — 6 hub_company + 6 hub_filing + 10 link + 11
  sat_filing_metadata + 10 sat_company_metadata) in 43.71 sec
- 11/11 SQL structural verify PASS for sat_company_metadata
  (2.55 sec)
- 44/44 SQL structural verify PASS across the warehouse layer
  (cumulative — 9 verify/03 + 13 verify/04 + 11 verify/05 + 11
  verify/06)
- 10/10 ENGINEERING_STANDARDS tick-box audit PASS (Currency,
  Compactness, Resource efficiency, Privacy & security, Workflow
  consistency, Dev env hygiene, Upstream/downstream contract,
  Idempotency, Pre/post verification, Observable progress)
- Idempotency proven: second dbt run [OK 0 in 27.01s] — anti-join
  filter excluded every inbound row whose hashdiff matched the
  latest stored hashdiff
- `dbt parse` implicitly clean (would have errored at dbt run
  otherwise)

**Decisions locked this session (at the forward-verify pass).**

- **Satellite source for top-level JSON fields = typed cover-page
  staging** (stg_sec_edgar__companyfacts), NOT raw-text staging +
  json_extract. When the upstream openx SerDe has already mapped
  the JSON field to a typed column, the sat trusts that work.
  Reserves the raw-text staging + UNNEST pattern for satellites
  whose payload lives in deeply-nested arrays (sat_filing_metadata,
  future sat_concept_value).
- **Single-column hashdiff drops the '||' delimiter.** The
  delimiter is a defense against multi-column concat ambiguity
  that doesn't exist with one column. COALESCE-to-'^^' sentinel
  still applies as project standard defensive shield against
  Trino's concat NULL propagation. Pattern: SHA-256 over
  COALESCE(payload, '^^') directly when payload is a single
  column; SHA-256 over COALESCE(col_1, '^^') || '||' ||
  COALESCE(col_2, '^^') || ... for multi-column payloads.
- **Forward-verify cardinality probe = four-aggregate signature.**
  COUNT(*) / COUNT(DISTINCT business_key) / COUNT(DISTINCT
  extract_date_or_load_partition) / COUNT(DISTINCT payload_concat).
  Run against actual Bronze BEFORE writing any satellite model.
  If those four numbers don't match the parent hub count exactly,
  name the collapse mechanism and bake it into the model's
  source-side CTE.

**Blockers / surprises.** One within-session miss surfaced
during the forward-verify pass — Claude guessed the Bronze
raw-text table name with a stale `bronze_` prefix, hit
TABLE_NOT_FOUND. Phil pasted the error, Claude grepped the DDL,
fix landed in one round. Banked as a Risk 13 sub-note carry-forward.
Net session impact: ~30 seconds. Also a process miss — the 10-point
ENGINEERING_STANDARDS audit wasn't on the task list at kickoff;
Phil flagged it post-idempotency-proof, added as task #8 ahead
of docs update so any FAIL could surface in time for code fix.
Audit landed 10/10 PASS so no code change required, but the
oversight goes into the carry-forward bank: future session
kickoffs include the audit as an explicit task from the start.

**NOT in this session — deferred.**

- **Period/fiscal attribute model home** (hub_period +
  link_filing_period split vs baked into sat_concept_value) →
  Phase 2 session 8. Forward design call, sized for its own
  forward-verify pass per the standing rule.
- **sat_concept_value + sat_concept_canonical** → Phase 2 session
  8+ as needed by the Gold marts in Phase 4.
- **hub_concept + hub_period + remaining links** → Phase 2 session
  8+ as needed by the period/fiscal attribute design call.
- **README.md Status line refresh** → Phase 2 close (per session
  3+ close deferral, still parked).

**Next session.** Phase 2 session 8 — next DV2.0 model. Likely
sat_concept_value with the period-attribute home decision baked
in. First activity = phase-kickoff forward-verify pass per the
standing rule (new architectural pattern qualifies — period-grain
modeling is genuinely different from the single-parent satellite
shape established in sessions 6 + 7). Est. 60-90 min.

---

### 2026-05-28 — Phase 2 session 6 — first DV2.0 satellite (sat_filing_metadata) + SCD-2 anti-join filter + within-session cardinality scope correction + 11/11 structural verify PASS

**Goal.** Ship the first DV2.0 satellite — sat_filing_metadata,
parent = hub_filing — and establish the SCD-2 insert-on-change
pattern via the hash-diff anti-join filter. New mechanic relative
to hubs/links: change detection, not just first-observation
detection. First activity = phase-kickoff forward-verify pass per
the standing rule.

**Forward-verify pass (third time the rule applied).**
Restricted-domain web-search-verify against scalefree.com
(canonical hash-diff + insert-only DV2.0), automate-dv.readthedocs.io
(sat macro + hash-diff change-detection idiom),
docs.getdbt.com + docs.aws.amazon.com (dbt-athena Iceberg merge
satellite-specific behavior — Risk 2 caveat on_schema_change=ignore
mandatory), trino.io (concat NULL propagation, sha256 + to_utf8 +
to_hex chain), github.com/dbt-labs/dbt-utils
(unique_combination_of_columns argument-nesting structure for
dbt 1.10+). Surfaced 4 new forward-projected risks BEFORE any SQL
shipped — banked in LEARNINGS as Risks 8/9/10/11 on top of the 7
already on the board. Total time on the pass: ~25 min. Earned its
keep: every risk informed a real design decision in the model
body or the verify suite.

**Within-session scope correction (Risk 12 banked).** First dbt
run returned 45,851 rows — ~7x the expected 6,551. The 4 period/
fiscal columns I'd scoped into the initial payload (period_start_date,
period_end_date, fiscal_year, fiscal_period) are
per-period-instance attributes, not per-filing — a 10-K reports
comparatives (current FY + 2 prior FYs) and a 10-Q reports current
quarter + YTD + prior-year-same, each as a separate array entry
within each concept's units.USD array. Per-instance attributes
break the satellite's 1:1 parent-coverage-parity invariant.
Trimmed scope at first-run-time to the 2 truly filing-level
attributes — form_type and filed_date. Phil drove the diagnosis
question to senior-DE framing ("what would a senior pro do?")
which surfaced the right fix path immediately. Rebuilt via
--full-refresh; rebuild landed clean at 6,551 rows = hub_filing
parent count. Banked as LEARNINGS Risk 12 with three
carry-forward principles: (a) cardinality-test discipline at every
satellite design (expected first-load count = parent hub count for
1:1 sats); (b) test-ordering by cost (row-count parity FIRST,
schema tests SECOND, structural verify LAST); (c) forward-verify
pass must include cardinality reasoning, not just function-chain
reasoning, going forward.

**What landed.**

- **`dbt/models/warehouse/sat_filing_metadata.sql` shipped.** First
  DV2.0 satellite. Parent = hub_filing. 2 truly filing-level
  payload attributes: form_type + filed_date. Same per-concept
  Jinja for-loop UNNEST pattern as hub_filing /
  link_company_filing; only the projection list + DISTINCT
  cardinal unit + downstream filter differ. Dedicated
  sat_filing_metadata_hk = SHA-256 hash over (hub_filing_hk ||
  '||' || CAST(load_datetime AS varchar)) — keeps the
  warehouse-layer surface visually consistent with every other
  model (Risk 10 lock). hashdiff = SHA-256 over
  COALESCE(form_type, '^^') || '||' || COALESCE(filed_date, '^^')
  — sentinel pattern is project standard even for reliably-populated
  payload columns (defensive default for every future satellite).
- **`dbt/models/warehouse/_models.yml` extended.** sat_filing_metadata
  block — 8 columns (sat_filing_metadata_hk, hashdiff,
  hub_filing_hk, accession_number, form_type, filed_date,
  load_datetime, record_source), 10 column-level tests (unique +
  not_null on sat hk, not_null on hashdiff, not_null + relationships
  FK on hub_filing_hk, not_null on every other column), + 1
  model-level dbt_utils.unique_combination_of_columns test on the
  composite natural PK (hub_filing_hk, load_datetime). New test
  type for this project — verified its argument-nesting structure
  against the dbt-utils source repo BEFORE writing the YAML, per
  the THIRD-miss locked rule. The proactive bypass FIRED CORRECTLY
  this session — first time since the rule was locked at session 5
  close. No deprecation warnings on first parse.
- **`sql/verify/05_phase2_warehouse_satellites_verification.sql`
  shipped.** Parallel CTE PASS/FAIL pattern to verify/03 + verify/04.
  11 checks: sat hash key uniqueness + not_null + length 64,
  hashdiff not_null + length 64, FK closure to hub_filing,
  composite natural PK (hub_filing_hk, load_datetime) uniqueness,
  parent coverage parity (sat distinct parent count = hub_filing
  count — the 1:1 invariant guard), sat_hk + hashdiff
  reproducibility on Apple's smallest accession, record_source
  constant. 11/11 PASS in 2.59 sec.
- **DBT_PIPELINE.md sections 8.11 / 8.12 / 8.13 shipped.** 8.11
  introduces satellite framing + the three mechanic-divergences
  from hubs/links (hashdiff column, anti-join not NOT IN, sat hash
  key construction) + the Risk 12 scope-correction explainer. 8.12
  walks the SCD-2 mechanic through three sequential loads to make
  the contract auditable (load 1 = first observation; load 2 =
  same payload, dropped at anti-join; load 3 = changed payload,
  inserted with new LDTS, prior row preserved). 8.13 covers
  verify/05's 11-check surface with the cardinality-check
  carry-forward principle called out explicitly.
- **GLOSSARY.md** — Hashdiff entry added under section 2 DV2.0
  group. Walks through the concat NULL propagation trap, the
  '^^' COALESCE sentinel defense, and the column-order contract.
- **LEARNINGS.md** — 5 new entries banked:
  - Risk 8 (Trino concat NULL propagation in hashdiff defeats
    SCD-2 change detection; COALESCE-sentinel pattern locked).
  - Risk 9 (satellite source-side filter is an anti-join on
    latest-hashdiff-per-parent, NOT a NOT IN on parent hash key;
    new mechanic relative to hubs/links).
  - Risk 10 (single sat hash key vs composite unique_key —
    project standard is the single sat hash for visual consistency,
    composite natural PK enforced via dbt_utils test).
  - Risk 11 (satellite source from companyfacts JSON needs DISTINCT
    at the natural-cardinal-unit level — not at the BK level).
  - Risk 12 (filing-level vs filing-instance-level attribute scope
    miss surfaced at first-dbt-run; cardinality-test discipline +
    test-ordering-by-cost + forward-verify-pass cardinality
    reasoning locked as three carry-forward principles).

**Verification surface at session 6 close.**

- 11/11 dbt schema tests PASS on sat_filing_metadata's 8 columns +
  model-level composite PK test
- 33/33 dbt schema tests PASS across the warehouse layer
  (cumulative — 6 hub_company + 6 hub_filing + 10 link + 11 sat)
- 11/11 SQL structural verify PASS for sat_filing_metadata (2.59 sec)
- 33/33 SQL structural verify PASS across the warehouse layer
  (cumulative — 9 verify/03 + 13 verify/04 + 11 verify/05)
- Idempotency proven: second dbt run [OK 0] rows merged — anti-join
  filter excluded every inbound row whose hashdiff matched the
  latest stored hashdiff
- `dbt parse` clean across both runs (post-scope-trim parse + initial)

**Decisions locked this session (at the forward-verify pass and at
the within-session scope correction).**

- **Satellite hashdiff function chain** = SHA-256 over the
  COALESCE(col, '^^')-protected concat of payload columns,
  '||' delimiter between. Project standard for every future
  satellite hashdiff.
- **Satellite source-side filter pattern** = NOT EXISTS anti-join
  against latest-hashdiff-per-parent via ROW_NUMBER window. Project
  standard for every future satellite — distinct mechanic from
  the hub/link NOT IN pattern, by design.
- **Satellite unique_key** = single dedicated sat_<entity>_hk column
  over hash(parent_hk || '||' || CAST(load_datetime AS varchar)).
  Composite natural PK enforced via
  dbt_utils.unique_combination_of_columns test, not via runtime
  unique_key list. Visual consistency with hub/link single-hash-PK
  surface.
- **Satellite payload scope** = ONLY attributes that are 1:1 with
  the parent. Per-period-instance attributes belong on a different
  model class (hub_period + link_filing_period, OR
  sat_concept_value). Cardinality-test at design time is the
  enforcement mechanism.
- **dbt_utils.unique_combination_of_columns argument-nesting** =
  under `arguments: combination_of_columns: [...]` for dbt 1.10+
  (verified against the dbt-utils source repo).

**Blockers / surprises.** One within-session scope miss surfaced at
first dbt run — the cardinality miss (45,851 ≠ 6,551). Diagnosed
within ~3 minutes, fix landed within ~10 minutes, full-refresh
rebuild + retest + verify all-green within another ~15 minutes.
Net session impact: ~25 minutes vs a clean-first-try ship. The
miss became the most valuable LEARNINGS entry of the session
(Risk 12 + 3 carry-forward principles). Phil's "what would a
senior pro do" question reset the discussion to ship-mode rather
than engaged-debug-mode — invoked the senior-DE-default override
correctly.

**NOT in this session — deferred.**

- **Period/fiscal attribute model home** (hub_period vs
  sat_concept_value) → Phase 2 session 7+. Forward design call;
  the right answer depends on whether downstream marts want
  temporal grain modeled as a separate hub (clean DV2.0 textbook
  shape) or baked into the value satellite (denser but less
  decomposed). Park until session 7's scope crystallises.
- **sat_company_metadata + sat_concept_value + sat_concept_canonical**
  → Phase 2 session 7+ as needed by the Gold marts in Phase 4.
- **hub_concept + hub_period + remaining links** → Phase 2 session 7+
  as needed by the period/fiscal attribute design call.
- **README.md Status line refresh** → Phase 2 close (per session 3+
  close deferral, still parked).

**Next session.** Phase 2 session 7 — next DV2.0 model. Likely
sat_company_metadata (simpler 1:1 satellite, exercises the
cardinality invariant explicitly), OR sat_concept_value with the
period-attribute home decision baked in. First activity =
phase-kickoff forward-verify pass per the standing rule (re-fires
when a new architectural pattern enters; the period/fiscal attribute
home decision qualifies). Est. 60-90 min.

---

### 2026-05-28 — Phase 2 session 5 — second hub (hub_filing) + first link (link_company_filing) + composite-hash construction + 13/13 structural verify PASS

**Goal.** Ship the second DV2.0 hub (hub_filing, accession_number BK)
and the first DV2.0 link (link_company_filing, composite hash over
(cik, accession_number) with explicit delimiter). Establish the link
pattern + multi-hub composite hash key + same insert-only-via-source-side-filter
semantics as hubs. First activity = phase-kickoff forward-verify pass
per ENGINEERING_STANDARDS.

**Forward-verify pass (second time the rule applied).** Restricted-domain
web-search-verify against scalefree.com (canonical DV2.0 + link-table
best practices), automate-dv.readthedocs.io (hashing + concat_string
default), github.com/dbt-labs/dbt-utils (generate_surrogate_key delimiter
+ issue #1015), docs.aws.amazon.com + trino.io (concat operator semantics
on varchar), sec.gov/search-filings/edgar-application-programming-interfaces
(companyfacts JSON structure + accn field). Surfaced 2 new forward-projected
risks BEFORE any SQL shipped — banked in LEARNINGS as Risks 6 + 7 on top
of the 5 already on the board. Total time on the pass: ~20 min. Earned
its keep: both decisions (composite-hash '||' delimiter + companyfacts
JSON sourcing instead of Phase 1 extract extension) drove the code design
directly and avoided un-freezing Bronze mid-project.

**What landed.**

- **`dbt/models/warehouse/hub_filing.sql` shipped.** Second DV2.0 hub.
  Business key = accession_number. Source = stg_sec_edgar__companyfacts_raw
  via Jinja for-loop UNNEST across the same 8 in-scope XBRL concepts
  as int_sec_edgar__concepts. 6,551 distinct accession_numbers across
  the S&P 100 over the 10-year companyfacts history. Hash function
  chain identical to hub_company (SHA-256 hex via to_hex(sha256(to_utf8(CAST(<bk>
  AS varchar))))). Source-side is_incremental filter + unique_key safety
  net carry from hub_company unchanged.
- **`dbt/models/warehouse/link_company_filing.sql` shipped.** First
  DV2.0 link. Composite hash key over (cik || '||' || accession_number)
  — the '||' delimiter is the AutomateDV ecosystem default; picked over
  dbt_utils' '-' delimiter which has a documented collision-on-hyphenated-inputs
  failure mode (dbt-utils issue #1015) that bites SEC accession numbers
  specifically (they contain literal hyphens in positions 11 and 14).
  Carries hub_company_hk and hub_filing_hk as FK columns alongside the
  composite link hash; each FK hash uses the same single-key chain as
  its parent hub so FK joins are valid by construction. Source-side
  UNNEST mirrors hub_filing.
- **`dbt/models/warehouse/_models.yml` extended.** 16 new schema tests
  total: hub_filing gets 6 (not_null x4 + unique x2 on hub_filing_hk
  AND accession_number); link_company_filing gets 10 (not_null x7 +
  unique x1 + relationships x2 — FK closure to hub_company and hub_filing
  enforced at test time, not just verify-suite time).
- **`sql/verify/04_phase2_warehouse_links_verification.sql` shipped.**
  Parallel CTE PASS/FAIL pattern to verify/03. 13 checks: 5 on hub_filing
  (hash-key uniqueness + not_null + length-64 + business-key uniqueness +
  source-parity vs UNION-ALL'd source pairs), 8 on link_company_filing
  (composite-hash uniqueness + not_null + length-64 + composite-hash
  determinism reproducibility on Apple's lexicographically-smallest
  accession_number + FK closure to both parent hubs + source-pair
  lineage parity + business-key cardinality sanity). 13/13 PASS in
  9.298 sec; 6,551 rows each in hub_filing and link_company_filing —
  meaning every accession_number is associated with exactly one filer
  (SEC convention proven empirically).
- **DBT_PIPELINE.md sections 8.8 / 8.9 / 8.10 shipped.** 8.8 walks
  through hub_filing's source + UNNEST + hash chain; 8.9 walks through
  link_company_filing's composite hash construction + delimiter rationale
  + FK hash chain + insert-only semantics carry from hubs (with Scalefree
  source-link); 8.10 walks through verify/04's 13-check surface.
- **GLOSSARY.md** — composite hash key entry added under section 2
  DV2.0 group. Walks through the delimiter trade-off (||-vs-'-'),
  the dbt-utils issue #1015 collision pattern, and the project standard.
- **LEARNINGS.md** — 2 forward-projected risks banked at the kickoff
  forward-verify pass (BEFORE any code shipped, per the rule):
  Risk 6 (composite-hash delimiter choice — '||' over '-' to defeat
  dbt-utils collision pattern on hyphenated accession numbers), Risk 7
  (accession_number sourcing — companyfacts JSON accn field sufficient,
  NO Phase 1 submissions-endpoint extract extension required, demo-durability
  Bronze freeze preserved). Both with verified-against-authoritative-source
  provenance + locked design decision + carry-forward principle. Plus
  THIRD-miss amendment to the existing 2026-05-27 criterion-6-proactive-bypass
  entry: the verify-then-write rule didn't fire AGAIN on the relationships
  test introduction — re-locked the trigger to fire on first-use-of-test-type-in-project,
  not first-creation-of-config-file.

**Verification surface at session 5 close.**

- 16/16 dbt schema tests PASS on session 5's new models (6 hub_filing
  + 10 link)
- 22/22 dbt schema tests PASS across the warehouse layer (cumulative —
  6 hub_company + 16 new)
- 13/13 SQL structural verify PASS for the link bundle (4.461 sec for
  verify/03 + 9.298 sec for verify/04)
- 22/22 SQL structural verify PASS across the warehouse layer
  (cumulative — 9 verify/03 + 13 verify/04)
- 2 dbt runs back-to-back per new model: first PASS=2 with CREATE TABLE
  AS materialization, second PASS=2 with [OK 0] rows merged on both
  (idempotency proven on the link composite-hash filter pattern, same
  as hubs)
- `dbt parse` clean after the in-session fix to the relationships test
  argument nesting

**Decisions locked this session (at the forward-verify pass).**

- **Composite-hash delimiter = '||'** (AutomateDV ecosystem default).
  Project standard for every composite hash in every future DV2.0 link
  + composite-parent satellite. '-' delimiter explicitly rejected on
  the dbt-utils issue #1015 collision pattern.
- **Hub-filing source = stg_sec_edgar__companyfacts_raw** (honors the
  session-4 lock that DV2.0 hubs source from the rawest layer where
  the BK first appears). Phase 1 submissions-endpoint extract extension
  explicitly rejected to preserve Bronze freeze.
- **Link insert-only pattern = source-side is_incremental filter + unique_key
  as engine-level safety net** (Scalefree-verified — links are pure
  append-only). Same pattern as hubs; carries to future links unchanged.

**Blockers / surprises.** One within-session warning — the
MissingArgumentsPropertyInGenericTestDeprecation fired on the new
relationships test arguments (third consecutive miss of the criterion-6
proactive-bypass rule for new dbt YAML test types). Fixed in-session
by nesting under `arguments:`. Banked as a THIRD-miss amendment to
the existing LEARNINGS entry rather than a new entry. Zero engine-side
debug loops; the forward-verify pass front-loaded every architectural
call.

**NOT in this session — deferred.**

- **First DV2.0 satellite (sat_company_metadata OR sat_filing_metadata)**
  → Phase 2 session 6. Different filter pattern (SCD-2 insert-on-change
  via hash-diff between inbound row and latest satellite version for
  the same parent), but same merge config + on_schema_change defaults.
- **hub_concept + hub_period + remaining links** → Phase 2 session 6+
  as needed by the Gold marts in Phase 4. May descope to the minimum
  set that powers the 4 dashboard themes rather than the full Phase 0
  list of 4 hubs + 3 links + 4 satellites.
- **README.md Status line refresh** → Phase 2 close (per session 3 close
  deferral, still parked).

**Next session.** Phase 2 session 6 — first DV2.0 satellite. First
activity = phase-kickoff forward-verify pass (now the standing pattern
for every session that introduces a new architectural pattern). Scope:
verify SCD-2 hash-diff filter idiom against Scalefree + AutomateDV docs,
verify dbt-athena Iceberg merge behavior for satellite-shaped models
(LEARNINGS Risk 2 caveat applies — on_schema_change must stay at
default ignore), pick satellite parent (hub_company vs hub_filing),
ship model + schema tests + verify/05. Est. 60-90 min.

---

### 2026-05-28 — Phase 2 session 4 — first warehouse-layer DV2.0 hub (hub_company) + forward-verify pass + 9/9 structural verify PASS

**Goal.** Ship the first warehouse-layer Data Vault 2.0 model — hub_company,
business key = SEC CIK. Establish the hand-rolled DV2.0 pattern (no
AutomateDV) the rest of the warehouse layer (link_company_filing,
sat_company_metadata, hub_filing, etc.) will follow structurally.
First activity: the new mandatory phase-kickoff forward-verify pass
per the ENGINEERING_STANDARDS rule banked at session 3 close-amend.

**Forward-verify pass (NEW — first time the rule applied).** Restricted-domain
web-search-verify against docs.aws.amazon.com (Athena engine v3 functions,
Iceberg MERGE INTO semantics), docs.getdbt.com (dbt-athena configs,
incremental-strategy docs), scalefree.com (canonical DV2.0 reference body),
automate-dv.readthedocs.io (hashing best practices), github.com/dbt-labs
(dbt_utils.generate_surrogate_key compatibility, dbt-adapters known issues),
trino.io (binary functions). Surfaced 2 new forward-projected risks
BEFORE any SQL shipped — banked in LEARNINGS.md as Risks 4 + 5 on top
of the 3 from session 3 close-amend. Total time on the pass: ~25 min.
Earned its keep: both risks informed the model design directly.

**What landed.**

- **`dbt/models/warehouse/hub_company.sql` shipped.** First DV2.0 hub in
  the project. Business key = cik (10-digit zero-padded SEC Central Index
  Key). Source = `stg_sec_edgar__companyfacts` (NOT
  `int_sec_edgar__concepts_canonical` — staging guarantees all 100 S&P
  CIKs while canonical filters to CIKs with at least one in-scope XBRL
  concept). 4 columns: hub_company_hk (SHA-256 hash of cik), cik,
  load_datetime (timestamp(6) UTC), record_source ('sec_edgar.companyfacts').
- **Hand-rolled SHA-256 hash chain.**
  `to_hex(sha256(to_utf8(CAST(cik AS varchar))))` — Athena/Trino native
  engine v3 functions only. Defensive CAST guards against future staging-side
  type changes. SHA-256 over MD5 (AutomateDV/Scalefree default) is the
  deliberate portfolio choice — locked at the forward-verify pass.
  Locks the hash function chain for every future DV2.0 hash key
  (hub_filing_hk, hub_concept_hk, hub_period_hk, link composite keys,
  satellite parent-key references).
- **Insert-only semantics via source-side `is_incremental()` filter.**
  `WHERE hub_company_hk NOT IN (SELECT hub_company_hk FROM {{ this }})`
  excludes already-seen hash keys from the source SELECT before the
  engine reaches the merge — matched rows literally never exist at
  engine level, so the dbt-athena default merge-overwrites-matched
  behavior never fires. `unique_key=hub_company_hk` is the
  belt-and-braces engine-level safety net. Locked at the forward-verify
  pass — alternatives (`update_condition: '1 = 0'`,
  `merge_update_columns: []`, `incremental_strategy: 'append'`)
  considered and rejected; full rationale chain in LEARNINGS Risk 5.
- **`dbt/models/warehouse/_models.yml` shipped.** Column contracts for
  every hub_company column: `not_null` x4 (every column), `unique` x2
  (hub_company_hk AND cik — both the hash and the business key tested
  for uniqueness; belt-and-braces against hash-function-chain bugs).
  6 schema tests total.
- **`dbt_project.yml` warehouse block added.**
  `+materialized: incremental`, `+incremental_strategy: merge`,
  `+table_type: iceberg`, `+format: parquet`, `+on_schema_change: ignore`
  under `models.financial_analytics.warehouse`. Long comment block
  above explains why `on_schema_change=ignore` is the right project-wide
  default for ALL DV2.0 model classes (cross-links Risk 2 — the
  Iceberg merge + on_schema_change=sync_all_columns duplicate-insertion
  bug). Per-model unique_key stays in each model's own config block since
  hash-key column name varies across hubs/links/sats.
- **`sql/verify/03_phase2_warehouse_verification.sql` shipped.** Parallel
  CTE PASS/FAIL pattern to verify/01 + verify/02. 9 checks: row count =
  100 (S&P 100 parity), hash-key uniqueness (raw SQL), hash-key not_null
  (raw SQL), hash-key length = 64 chars (SHA-256 structural contract),
  cik uniqueness (raw SQL), source-parity vs stg_sec_edgar__companyfacts
  distinct CIK count (lineage parity), Apple (cik 0000320193) hash
  deterministic-reproducibility check (recomputes
  `to_hex(sha256(to_utf8('0000320193')))` and confirms stored hash
  matches), load_datetime within reasonable UTC bounds, record_source
  constant 'sec_edgar.companyfacts'. 9/9 PASS in 4.461 sec, ~41 KB scanned.
- **DBT_PIPELINE.md section 8 expanded** from 4-line stub to 7 subsections:
  8.1 what this layer is (DV2.0 framing), 8.2 hand-rolled lock (no
  AutomateDV), 8.3 first hub: hub_company (design + source choice),
  8.4 hash key construction (the function chain walkthrough), 8.5
  insert-only semantics via source-side filter (the alternatives table
  + rationale), 8.6 verification surface (3-layer: schema tests +
  structural verify + idempotency proof), 8.7 pattern reusability for
  future warehouse models.
- **GLOSSARY.md extended.** 7 new DV2.0 entries added at the end of
  section 2 (Dimensional Modelling): Data Vault 2.0 framing entry +
  Hub + Link + Satellite + Hash key + Business key (DV2.0 context) +
  load_datetime (LDTS) + record_source (RSRC). 5 new acronyms added to
  the table: BK, DV2.0, HK, LDTS, RSRC. All tagged `[Project 3]`.
- **LEARNINGS.md** — 2 forward-projected risks banked at the kickoff
  forward-verify pass (BEFORE any code shipped, per the new rule):
  Risk 4 (hash algorithm choice MD5 vs SHA-256 + hand-rolled vs
  dbt_utils trade-off), Risk 5 (dbt-athena Iceberg merge overwrites
  matched rows by default; DV2.0 hubs need insert-only semantics).
  Both with verified-against-authoritative-source provenance + locked
  design decision + carry-forward principle.
- **`dbt/models/warehouse/.gitkeep` removed.** Stale placeholder per
  ENGINEERING_STANDARDS phase-boundary structural audit (now that
  warehouse has real models).

**Verification surface at session 4 close.**

- 6/6 dbt schema tests PASS (not_null x4 + unique x2)
- 9/9 SQL structural verify PASS (4.461 sec, ~41 KB scanned)
- 2 dbt runs back-to-back: first PASS=1 in 16 sec (CREATE TABLE AS),
  second PASS=1 in 27 sec with `OK 0` rows merged (idempotency proven)
- `dbt parse` clean (0 errors, 0 warnings)

**Decisions locked this session (at the forward-verify pass).**

- **DV2.0 hash function chain = SHA-256 hand-rolled via
  `to_hex(sha256(to_utf8(CAST(<bk> AS varchar))))`.** Athena/Trino
  native, no third-party macros. Project standard for every hash key
  in every future DV2.0 model (hubs, links, satellites).
- **Hub insert-only pattern = source-side `is_incremental()` filter +
  `unique_key` as engine-level safety net.** Project standard for every
  hub and link going forward. Satellites use a different filter pattern
  (hash-diff insert-on-change) but the same merge config + on_schema_change
  defaults.
- **Warehouse layer defaults = incremental + merge + iceberg + parquet +
  on_schema_change=ignore.** Shared by all three DV2.0 model classes.
  Per-model unique_key stays in each model's own config block.
- **DV2.0 hubs source from the rawest layer where the business key
  first appears** (staging, not canonical/intermediate). Lineage rule
  baked in from day 1.

**Blockers / surprises.** None. The forward-verify pass front-loaded
every architectural decision that would otherwise have surfaced mid-build.
First end-to-end PASS on first try at every step (dbt parse → dbt run →
dbt test → second dbt run → SQL verify). 0 in-session debug loops —
the verify pass paid for itself.

**NOT in this session — deferred.**

- **First DV2.0 link (link_company_filing) + hub_filing** → Phase 2
  session 5. Establishes the link pattern + multi-hub composite hash
  key + same insert-only semantics. Composite key: cik || '||' || accession_number
  hashed (the '||' delimiter avoids the 'AB'+'C' = 'A'+'BC' digest-collision
  ambiguity).
- **First DV2.0 satellite (sat_company_metadata)** → Phase 2 session 6+.
  Different filter pattern (hash-diff insert-on-change) but same merge
  config + on_schema_change defaults.
- **README.md Status line refresh** → Phase 2 close (per session 3 close
  deferral). Will bump from "Phase 1 complete" to "Phase 2 complete"
  once all hubs/links/sats land.
- **AWS Glue Catalog re-crawl of warehouse layer** → not needed; dbt-athena
  registered the hub_company table at dbt run time, visible in the Glue
  Console under `financial_analytics_silver`.

**Next session.** Phase 2 session 5 — first link model + second hub.
First activity = phase-kickoff forward-verify pass (this is now
standard for every phase kickoff — verify pass should also re-fire
when introducing a new architectural pattern mid-phase, per
ENGINEERING_STANDARDS). Scope: hub_filing (accession_number business
key, sourced from a Bronze submissions endpoint extract — note: only
Bronze companyfacts is landed currently; may need to extend Phase 1
extract OR derive accession_number from companyfacts JSON if available).
Then link_company_filing connecting the two hubs via composite hash.
Est. 60-90 min for forward-verify pass + hub_filing + link_company_filing
+ verify suite.

---

### 2026-05-28 — Phase 2 session 3 — canonical-concept reconciliation + intermediate-as-Iceberg + Bronze enum switch + verification 11/11 PASS

**Goal.** Ship canonical-concept reconciliation as a second intermediate
model that collapses the four S&P 100 revenue alias XBRL tags (Revenues,
SalesRevenueNet, RevenueFromContractWithCustomerExcludingAssessedTax,
RevenueFromContractWithCustomerIncludingAssessedTax) to one canonical
'revenue' name via a seed-driven dictionary; add `period_start_date` to
the upstream intermediate model; extend the verification suite with
post-FY2018 Apple revenue continuity checks proving the ASC 606
discontinuity is bridged. Stretch: first warehouse-layer hub_company.

**What landed.**

- **`canonical_concepts_dictionary` seed shipped.** `dbt/seeds/canonical_concepts_dictionary.csv`.
  8 rows mapping XBRL US-GAAP tag names to project-canonical concepts
  with business_area classification (income_statement / balance_sheet /
  cash_flow). 4 revenue aliases collapse to 'revenue'; the other 4 in-scope
  concepts identity-map. Authoritative source: XBRL US DQC Revenue Guidance
  + FASB Taxonomy Implementation Guide "Revenue from Contracts with
  Customers". `dbt/seeds/_seeds.yml` shipped alongside with column
  descriptions + not_null/unique tests.
- **`dbt_project.yml` extended.** New `seeds:` block with column types
  locked (varchar(128) / varchar(64) / varchar(32)). Per-seed config under
  `financial_analytics.canonical_concepts_dictionary`.
- **`int_sec_edgar__concepts` extended.** Concept list expanded from 5 to
  8 XBRL tags (added the 3 revenue alias variants). New `period_start_date`
  column extracted from `$.start` — populated for income-statement and
  cash-flow concepts; NULL for balance-sheet point-in-time facts (Athena's
  TRY_CAST handles both cleanly). `_models.yml` accepted_values list
  expanded to match.
- **`int_sec_edgar__concepts_canonical` shipped.**
  `dbt/models/intermediate/int_sec_edgar__concepts_canonical.sql`. INNER
  JOIN to the seed on `concept_name`. Adds `canonical_concept` +
  `business_area` columns alongside the existing schema. By design any
  concept not in the dictionary is excluded — contract guarantee that
  every downstream row carries a curated canonical name. `_models.yml`
  shipped with full column contracts + accepted_values tests on
  canonical_concept and business_area.
- **`sql/verify/02` extended from 6 to 11 checks.** Five new checks cover
  Apple FY2019-FY2021 canonical revenue values reconciling to published
  10-K filings ($260.174B / $274.515B / $365.817B), continuity check
  (≥6 distinct fiscal years of canonical revenue, proving the FY18→FY19
  discontinuity is bridged), and `period_start_date` population check
  on canonical revenue rows. 11/11 PASS in 1.805 sec, 8.05 MB scanned.
- **Intermediate layer materialization flipped views → Iceberg tables.**
  `dbt_project.yml` `models.financial_analytics.intermediate` block now
  carries `+materialized: table` + `+table_type: iceberg` + `+format: parquet`.
  Reason: schema tests against Bronze-cascade views hit Bronze's
  type=injected cik partition projection constraint; materializing the
  intermediate as Iceberg means tests scan compact Parquet files on S3,
  not raw JSON via the view chain. Also aligned with the locked Phase 2
  Silver-as-Iceberg architecture.
- **Bronze cik partition projection switched type=injected → type=enum.**
  Both `sql/ddl/01_create_bronze_tables.sql` and `02_create_bronze_raw_text_table.sql`
  updated. `'projection.cik.values'` enumerates all 100 S&P 100 CIKs.
  Phil DROP+CREATEd both Bronze tables via Athena Console (phil-admin
  identity) in 4 statements. S3 data untouched; Glue Catalog table
  definitions swapped. The Phase 1 verify suite (queries with explicit
  cik = '<value>' filters) continues to work unchanged.
- **DBT_PIPELINE.md sections 7.5-7.8 shipped.** 7.5 reframes session-2
  limitations as session-3 deliverables; 7.6 documents the 11/11 PASS
  verification surface; 7.7 walks through the canonical-concept seed
  pattern; 7.8 narrates the materialization-architecture flip + Bronze
  enum diagnosis loop.
- **TEACHING_PREFERENCES.md updated.** Phil's locked rule: every Athena
  / AWS Console instruction names the IAM identity (phil-admin vs phil-dbt)
  upfront. Banked alongside the standing conventions.
- **LEARNINGS.md** — four new entries banked (see below).

**Diagnosis loops banked (LEARNINGS entries).**

1. Bronze cik partition projection `type=injected` blocks both dbt CTAS
   materialization and dbt schema-test scans — fix is type=enum.
2. dbt-athena docs recommend Iceberg `table_properties.format_version=2`
   that AWS Athena engine rejects with InvalidRequestException — verify
   against engine docs (`docs.aws.amazon.com/athena`), not adapter-wrapper
   docs, for stakes-sensitive syntax.
3. Athena COLUMN_NOT_FOUND error message includes misleading
   "or requester is not authorized to access requested resources"
   boilerplate — likely SQL projection issue, not IAM.
4. Phil's standing AWS-identity-naming preference now locked in
   TEACHING_PREFERENCES — every Console-step instruction names the
   identity to sign in as.

**Verification surface at session 3 close.**

- 19/19 dbt schema tests PASS (was 0 tests pre-session)
- 11/11 SQL verify suite PASS (was 6/6 pre-session)
- 4/4 dbt run PASS (2 view models + 2 Iceberg table models)
- 1/1 dbt seed PASS (canonical_concepts_dictionary materialized)

**Decisions locked this session.**

- **Seed-as-dictionary pattern for reference data.** Standard senior-DE
  approach. canonical_concepts_dictionary is the first; future portable
  reference data (e.g. sector mappings, ticker→CIK lookup if introduced)
  follows the same shape.
- **Intermediate layer = Iceberg table from session 3 onwards.** Views
  remain default for staging only (1:1 pass-throughs over Bronze where
  materialization adds nothing).
- **Bronze cik partition projection = type=enum.** Both Bronze tables.
  Trade-off accepted: new S&P 100 turnover requires DDL update + DROP+CREATE.

**Blockers / surprises.** Two within-session debug loops, both Phil-driven
on diagnosis (per the in-session debug discipline):

- First dbt test run errored on type=injected constraint. Phil correctly
  identified the dbt run vs dbt test distinction; my initial diagnosis
  only covered the schema-test angle and missed that CTAS materialization
  itself hits the same constraint. Second loop surfaced when we then
  flipped to Iceberg materialization and dbt run errored. Final fix:
  type=enum on Bronze cik projection. Two LEARNINGS entries between them.
- Athena rejected `format_version=2` Iceberg table property mid-flow.
  Initially set from dbt-athena adapter docs recommendation; AWS Athena's
  own docs enumerate a closed allowlist that excludes the property.
  Removed; Athena defaults to Iceberg v2 anyway. LEARNINGS banked.

**NOT in this session — deferred.**

- **First warehouse-layer Data Vault 2.0 hub_company** → Phase 2 session 4.
  Originally a session-3 stretch; deferred due to time spent on the
  two debug loops above.
- **README.md Status line refresh** → Phase 2 close.
- **Multi-unit support on int_sec_edgar__concepts** (currently USD only)
  → if needed. Defer until a non-USD concept is in scope.

**Next session.** Phase 2 session 4 — first warehouse-layer Data Vault 2.0
model: hub_company (cik as business key). Iceberg incremental materialization
with merge strategy. **Hand-rolled DV2.0 in plain dbt-athena SQL** (NOT
AutomateDV — verified 2026-05-28 that AutomateDV doesn't support Athena).
Establishes the DV2.0 pattern that link_company_filing, sat_company_metadata,
etc. follow in subsequent sessions. **First activity of session 4 = phase-kickoff
forward-verify pass** per the new ENGINEERING_STANDARDS rule banked
2026-05-28. Est. 60-90 min for hub_company + verify pass.

**Session-3 close-amend (added 2026-05-28 post-commit f4c95b9).** After the
main session-3 commit was pushed, Phil challenged the criterion-7 audit
discipline given today's debug loops surfaced query-pattern issues the
data-shape-only audit didn't catch. Drove a forward-projected risk pass +
deep dive into AU job market + reset of the learning roadmap. Resulting
changes shipped in a second bundled commit on top of f4c95b9 (separate
commit, not amend — no force-push of pushed history):

- **ENGINEERING_STANDARDS.md** — criterion 7 strengthened to cover
  consumption-pattern contracts in addition to data-shape contracts
  (the gap that bit Phase 2 session 3); new "Phase-kickoff forward-verify
  pass" section added as a standing project rule.
- **LEARNINGS.md** — 3 forward-projected risk entries banked (AutomateDV
  doesn't support Athena; Iceberg merge incremental + on_schema_change
  has a known duplicate-insertion bug; Step Functions has no native dbt
  integration — Glue Python Shell vs Lambda Container Image trade-off
  for Phase 3).
- **PROJECT_PLAN.md** — section 7 (DV2.0) annotated with hand-rolled
  approach; section 9 (Phase breakdown) Phase 2 entry annotated with
  Iceberg-merge gotcha and Phase 3 entry annotated with dbt-runtime
  decision required at kickoff.
- **LEARNING_ROADMAP.md** — major reset of mini-projects lineup +
  training journey scope + career target context after AU market deep
  dive (Precision Sourcing 2026 + Robert Half / Hays salary guides +
  SEEK Melbourne sample). Mini-projects: DROPPED Databricks and Streaming
  slots; ADDED T-SQL + Microsoft stack and dbt patterns deep-dive. Final
  5-slot lineup: dbt Cloud + CI/CD → T-SQL + MS stack → Fabric end-to-end
  → dbt patterns deep-dive → Iceberg vs Delta. Timing target locked at
  4-5 days per mini-project. Training journey: dbt-heavy weighting,
  Python recalibrated to basic-to-intermediate (was "Python for DE"
  foundations + advanced), Phil-drives-the-keyboard pattern locked
  (inverts watch-Claude-type-it-up from Projects #1-3), interview-prep
  intensive added as week 8. Career targets: dropped Analytics Engineer
  (US-coined, low AU volume), primary targets are Senior DA with
  pipeline / BI Developer / BI Engineer / Senior Reporting Analyst in
  Melbourne volume order, Data Engineer remains longer-term stretch.

---

### 2026-05-27 — Phase 2 session 2 — first intermediate model + raw-JSON-read pattern locked + verification 6/6 PASS

**Goal.** Solve the raw-JSON-read pattern for Bronze `facts` (locked one of
three options at session start via web-search-verify), then build the first
intermediate model performing XBRL concept extraction over 5 representative
concepts for the S&P 100. Re-add intermediate layer config to dbt_project.yml.
Ship a verification suite parallel to Phase 1's pattern. Cross-reference
extracted values against Apple's public 10-K filings before declaring the
pipeline portfolio-ready.

**What landed.**

- **Raw-JSON-read pattern locked: Option B** (second Athena table over same
  S3 location with a single text column). Three options compared via
  web-search-verify against docs.aws.amazon.com (openx SerDe), docs.getdbt.com
  (dbt-athena adapter), and github.com/dbt-athena/dbt-athena-external-tables.
  Option A (extend openx with STRING column on nested object) rejected:
  AWS docs only document nested JSON via struct typing — exactly what blew
  Glue Catalog's 128KB cap on NVIDIA in Phase 1. Option C (dbt-external-tables
  package) rejected: experimental Athena-specific package marked "USE AT
  OWN RISK", 4 stars, dormant since v0.0.1 Aug 2024 — portfolio-disqualifying
  dependency. Option B uses only documented Athena features, leaves the
  Phase 1 verified Bronze surface untouched, needs no IAM policy changes.
- **Second Bronze table shipped.** `sql/ddl/02_create_bronze_raw_text_table.sql`.
  Manual DDL run via Athena Console under phil-admin (one-statement-at-a-time
  per the Console constraint). LazySimpleSerDe via ROW FORMAT DELIMITED,
  `FIELDS TERMINATED BY '\001'` (SOH — cannot appear unescaped in well-formed
  JSON), single `json_text` column, same partition projection scheme as
  the existing Bronze table. Sanity check: `length(json_text)` for Apple
  returned 3,748,682 bytes (full file as one row, single-line minified JSON
  confirmed).
- **`.gitignore` extended.** `dbt/.user.yml` added inside the existing dbt
  runtime-artefacts block. The file is dbt-generated per-developer-local
  identity (random UUID on first invocation) that was accidentally committed
  in Phase 2 session 1; `git rm --cached` in the session-2 bundled commit
  stops tracking without deleting from disk.
- **`dbt_project.yml` intermediate layer config re-added.**
  `+materialized: view` under `models.financial_analytics.intermediate`.
  Comment block status line flipped from "TO ADD: Phase 2 session 2" to
  "ACTIVE: Phase 2 session 2 onwards". Warehouse + marts blocks still
  parked in the comment as future scope.
- **Second staging model.** `dbt/models/staging/stg_sec_edgar__companyfacts_raw.sql`
  — 1:1 pass-through over the new Bronze raw-text source. Three columns:
  cik, extract_date (cast to DATE), json_text. View materialization.
- **First intermediate model — `int_sec_edgar__concepts`.**
  `dbt/models/intermediate/int_sec_edgar__concepts.sql`. Jinja for-loop
  over 5 in-scope XBRL concepts (Revenues, NetIncomeLoss, Assets, Liabilities,
  StockholdersEquity), each block running `CROSS JOIN UNNEST(CAST(json_extract(...)
  AS ARRAY(JSON)))` to flatten the per-period array into rows. Bracket-quote
  JSONPath `'$.facts["us-gaap"].<concept>.units.USD'` (verified against
  Trino JSON functions docs). Output schema: cik, extract_date, concept_name,
  unit, period_end_date, period_form_type, period_fiscal_year,
  period_fiscal_period, value (DECIMAL(28,2)). `TRY_CAST` on numerics
  defends against malformed source JSON. View materialization.
- **`dbt/models/intermediate/_models.yml`.** Column contracts + schema
  tests for the new intermediate model. `not_null` on cik / extract_date /
  concept_name / unit. `accepted_values` on concept_name (the 5 in-scope
  concepts) and unit (USD only). MissingArgumentsPropertyInGenericTestDeprecation
  surfaced on first parse — `accepted_values` arguments now need to nest
  under an `arguments` property per dbt-core 1.10.5+ change. Fixed in-session;
  banked as a LEARNINGS entry on second-consecutive criterion-6-proactive-bypass
  miss.
- **`dbt/models/staging/_sources.yml` extended.** Second Bronze source
  declared (`sec_edgar_companyfacts_raw`). Column contracts on json_text +
  partition keys.
- **`sql/verify/02_phase2_silver_intermediate_verification.sql` shipped.**
  Parallel CTE-based PASS/FAIL pattern to Phase 1's verification suite.
  Six checks: Bronze raw-text row count for Apple, raw-text json byte
  length floor (≥1 MB sanity), intermediate distinct concept count, and
  Apple FY2018/FY2017/FY2016 annual Revenues reconciliation to public 10-K
  filings ($265.595B / $229.234B / $215.639B respectively). 6/6 PASS in
  1.767 sec, ~3 MB scanned.
- **`DBT_PIPELINE.md` section 7 flipped from TBD to shipped.** Full
  architectural decision record (Option A/B/C compared with verified
  rationale), second Bronze table walkthrough, staging fanout explanation,
  first intermediate model design (Jinja for-loop, JSONPath quoting,
  UNNEST flattening), known limitations (concept aliasing + missing
  period_start_date) with explicit next-iteration plan, verification
  surface summary.
- **LEARNINGS.md** — two new entries banked: (1) raw-JSON-read pattern
  lock as Option B with the three-option comparison preserved for portfolio
  context, including the WHY behind rejecting A (re-litigating Phase 1
  unverified claim) and C (experimental package optics); (2) criterion-6
  proactive-bypass miss on _models.yml — second consecutive session
  surfacing a parse-time warning on a new tool/adapter config file that
  the Phase 2 session 1 LEARNINGS entry should have caught at file-creation
  time.

**10-criteria audit at session close.** 10/10 PASS with one criterion-6
footnote (dbt parse zero warnings only AFTER fixing the
MissingArgumentsPropertyInGenericTestDeprecation that fired on first parse).
Tick-box table delivered in chat at close.

**Decisions locked this session.**

- **Raw-JSON-read pattern → Option B** (second Bronze table). Locked for
  the rest of Project #3. The pattern carries to future per-source raw-text
  Bronze tables (e.g. Yahoo Finance stock-price JSON, FRED macro JSON if
  introduced in mini-projects).
- **JSONPath bracket-and-double-quote form** as the project convention for
  any key containing special characters (hyphens, dots, spaces). Verified
  against Trino JSON functions docs. Applies to every json_extract /
  json_extract_scalar call in any future dbt model.
- **TRY_CAST defaulting on numeric extraction** from source JSON. Defensive
  coding standard for any future intermediate/warehouse model reading
  external JSON.

**Blockers / surprises.** Two operational surprises, both banked or
addressed:

- MissingArgumentsPropertyInGenericTestDeprecation on first dbt parse
  (dbt-core 1.10.5+ change to generic test argument structure). Fixed
  in-session; LEARNINGS entry banked.
- Apple's bare `Revenues` XBRL tag only returns FY2018 and prior filings
  (Apple switched to RevenueFromContractWithCustomerExcludingAssessedTax
  on ASC 606 adoption FY2019+). NOT a bug — exactly the canonical-concept
  reconciliation problem the next intermediate model solves. Surfaced
  naturally during verification; flagged in the section-7 walkthrough and
  the session-3 scope.

**NOT in this session — deferred.**

- **Canonical-concept reconciliation intermediate model** → Phase 2 session 3.
  Maps Revenues / SalesRevenueNet / RevenueFromContractWithCustomerExcludingAssessedTax
  → canonical `revenue` (and similar aliasing for the other 4 concepts).
- **`period_start_date` column on the intermediate model** → Phase 2
  session 3. Needed to disambiguate annual periods from quarterly periods
  that share an end-of-fiscal-year date.
- **First warehouse model (Data Vault 2.0 hub_company)** → Phase 2 session 3
  or 4 once canonical-concept reconciliation lands.
- **Multi-unit support on int_sec_edgar__concepts** (currently USD only)
  → Phase 2 session 3+ if needed; defer until a non-USD concept is in
  scope. Most S&P 100 financial statement line items are USD.
- **Schema tests on the staging models** → next time they're materially
  edited.
- **Delete `dbt/models/intermediate/.gitkeep`** stale resource → handled
  by Phil in PowerShell as part of the session-2 bundled commit.

**Next session.** Phase 2 session 3 — canonical-concept reconciliation
intermediate model + period_start_date schema addition + (stretch) first
warehouse-layer Data Vault 2.0 hub. Est. 60-90 min. Web-search-verify
discipline for any non-trivial UNION/case statement covering the alias
mapping. Three-layer doc pattern as usual; LEARNINGS bank at close.

---

### 2026-05-25 — Phase 2 session 1 — dbt-athena scaffolding + first staging model + four LEARNINGS banked

**Goal.** Stand up dbt-athena end-to-end with a dedicated IAM identity,
prove the pipeline (Bronze source → staging view → Glue Catalog → Athena
query) with a first minimal-viable staging model, and bank a Phase 2
session 2 starting point. Iceberg vs Parquet materialization design call
locked at session start (Iceberg, post web-search-verify on adapter
maturity).

**What landed.**

- **dbt-athena adapter installed.** `dbt-athena-community>=1.10.1` added
  to `requirements.txt`. Pulls dbt-core 1.11.11, dbt-adapters 1.24.2,
  pyathena 3.31.0 as transitive deps. Patch-ahead of the
  1.10.0/1.11.8 line the web-search returned (expected for May 2026).
- **Iceberg vs Parquet locked → Iceberg.** Web-search-verify against
  docs.getdbt.com + dbt-labs/dbt-adapters + docs.aws.amazon.com confirmed
  adapter is dbt-Labs maintained, stable, current. Iceberg's ACID merge
  (only available with Iceberg, not Hive/Parquet) is the natural fit for
  Data Vault 2.0 satellite SCD-2 history. Operational edge cases the
  search surfaced (concurrent-run data loss, DROP TABLE timeout, orphan
  S3 files) all require parallel dbt runs or production-scale concurrency
  — none apply at portfolio scale.
- **Dedicated `phil-dbt` IAM user provisioned.** Customer Managed Policy
  `lakehouse-dbt-runtime-access` (JSON in `iam/lakehouse_dbt_runtime_policy.json`).
  Scoped to: Athena workgroup execute on `wg_financial_analytics`, Glue
  Catalog R/W on `financial_analytics_bronze` + `financial_analytics_silver`,
  S3 R on `zone=bronze/`, S3 R/W on `zone=silver/` and `athena-results/`.
  Console access disabled — programmatic-only. Initial attempt as
  inline-on-user policy failed against the 2048 non-whitespace character
  cap; pivoted to Customer Managed (6144 char cap + reusable + versioned).
  Banked as LEARNINGS entry.
- **Glue database `financial_analytics_silver` created** alongside
  `financial_analytics_bronze` (Phase 1).
- **`.env.example` extended** with placeholders for `AWS_DBT_ACCESS_KEY_ID`
  and `AWS_DBT_SECRET_ACCESS_KEY`. Two-identity convention now documented
  in the template: `phil-admin` for Phase 1 extract/verify scripts,
  `phil-dbt` for Phase 2+ dbt runtime.
- **dbt project scaffold shipped.** `dbt/dbt_project.yml`,
  `dbt/profiles.yml.example`, `dbt/packages.yml` (dbt_utils 1.x),
  `dbt/models/staging/_sources.yml`. Folder layout: staging/
  intermediate/ warehouse/ marts/ (intermediate/warehouse/marts hold
  `.gitkeep` until first model lands).
- **First staging model.** `dbt/models/staging/stg_sec_edgar__companyfacts.sql`
  — materialized as view, three columns: cik (string), extract_date
  (DATE, cast from partition-projection string), entity_name (renamed
  from openx-mapped entityname). Path A picked over json_extract scope
  per "staging passes through, intermediate does the heavy work" senior-DE
  pattern.
- **IDE/runtime delta handling shipped.** `.vscode/settings.json` +
  `.vscode/dbt_project.permissive.schema.json` override SchemaStore's
  dbt-core-only schema for `dbt_project.yml` with a local empty schema.
  Documented intentional bypass per ENGINEERING_STANDARDS criterion 6.
  `flags.warn_error_options.silence` in `dbt_project.yml` silences
  `CustomKeyInConfigDeprecation` + `DeprecationsSummary` false positives
  on adapter-specific keys (linked to dbt-core issues #12314, #12342,
  #12355, #12087).
- **dotenv CLI wrapper convention locked.** `python-dotenv[cli]` extras
  installed; every dbt invocation in this session ran as
  `dotenv -f ..\.env run -- dbt <command>` from the `dbt/` subdirectory.
  Documented in DBT_PIPELINE.md section 5.
- **End-to-end pipeline verified.** `dbt parse` clean (0 errors, 0
  warnings). `dbt run` PASS=1 WARN=0 ERROR=0 SKIP=0 NO-OP=0 TOTAL=1.
  Glue Catalog visual check confirmed view registration with three
  columns. Athena functional smoke query returned 2 rows for Apple
  (CIK 0000320193) across both extract_date partitions, entity_name
  "Apple Inc." both rows.
- **DBT_PIPELINE.md stub shipped** at repo root — 10 sections covering
  pipeline architecture, layer responsibilities, IAM identity separation,
  profiles.yml + .env contract, dotenv wrapper convention, session 1
  deliverables, verification surface. Sections 7 (intermediate) and 8
  (warehouse DV2.0) marked as Phase 2 session 2+ scope.
- **TEACHING_PREFERENCES.md third re-lock** on paste-able discipline.
  Two violations within session 1 (step 3d + step 4) prompted Phil to
  request a different enforcement mechanism. Locked: mandatory pre-send
  backtick scan + binary mental test ("am I telling Phil to paste this?
  → own code block; else → plain text, no inline backticks").
- **LEARNINGS.md** — four new "Project #3 lessons" entries banked:
  (1) AWS IAM inline-policy 2048-char cap + ASCII-only description
  sub-note; (2) paste-able discipline third re-lock with mechanical
  pre-send check; (3) criterion-6 reflex on every new tool/adapter
  config file — anticipate IDE-vs-runtime drift proactively, ship
  bypass directives at file creation; (4) dbt does NOT auto-load .env
  files, python-dotenv[cli] wrapper is the cross-platform pattern.

**10-criteria audit at session close.** 10/10 PASS across the deliverable
bundle (iam/lakehouse_dbt_runtime_policy.json + .vscode/* + dbt/* +
staging model). Tick-box table delivered in chat at close.

**Decisions locked this session.**

- **dbt-athena Iceberg vs Parquet → Iceberg** (Silver materialization,
  per dbt-labs maintenance state + Iceberg-only merge incremental
  strategy fitting DV2.0 SCD-2).
- **IAM separation pattern locked across the rest of Project #3.**
  `phil-admin` for human/Phase-1 work; `phil-dbt` for dbt automation
  with Customer Managed Policy lakehouse-dbt-runtime-access. Future
  Step Functions execution role (Phase 3) will follow the same
  Customer-Managed-from-the-start pattern.
- **Staging materialization defaults to view** per dbt_project.yml.
  Re-evaluate (promote to table) only if scan cost exceeds budget.
- **dotenv CLI wrapper as the project standard** for every dbt
  invocation. Reflected in DBT_PIPELINE.md and any future CI YAML.

**Blockers / surprises.** No architectural blockers; four operational
surprises, all banked in LEARNINGS:

- AWS IAM 2048-char inline policy cap (vs ~3KB policy size).
- VS Code SchemaStore schema misfiring on adapter-specific keys (red
  squigglies on valid dbt config).
- dbt-core 1.11 emits false-positive `CustomKeyInConfigDeprecation` on
  adapter-supported keys per multiple open dbt-labs/dbt-core issues.
- dbt-core does not auto-load .env files; needs explicit wrapper.

**NOT in this session — deferred.**

- json_extract pattern against Bronze `facts` JSON → Phase 2 session 2.
- First intermediate model (XBRL canonical-concept reconciliation) →
  Phase 2 session 2.
- Re-adding intermediate / warehouse / marts layer defaults to
  dbt_project.yml — happens as each layer's first model lands.
- Iceberg Silver tables (first warehouse model) → Phase 2 session 3+.
- Schema + data tests on the staging model → next time the model is
  touched or once intermediate consumers exist.
- VS Code venv auto-activate config → Phase 6 polish.

**Next session.** Phase 2 session 2 — first intermediate model. Solve
the raw-JSON-read pattern for Bronze `facts` first (three options on
the table: revise Bronze DDL, second Athena table over same S3
location, dbt-athena raw-S3 read macro). Then build first intermediate
model performing XBRL canonical-concept reconciliation for ~3-5
representative concepts (Revenues, NetIncomeLoss, Assets, Liabilities)
across the S&P 100. Re-add intermediate layer defaults to
dbt_project.yml. Smoke-query the intermediate model from Athena.
Estimated 60-120 min.

---

### 2026-05-25 — Phase 1 session 4 — 100-company extract + boto3 S3 metadata verify + Phase 1 CLOSE-OUT (Bronze frozen)

**Goal.** Phase 1 close-out + Bronze freeze per demo-durability principle 1.
Full S&P 100 extract (final Bronze landing), boto3-based S3 metadata
verification script (covers what SQL can't), SQL verify suite refactor
11 → 100 scale, Phase 1 structural audit. After today: Bronze is the
system-of-record snapshot that everything else hangs off; SEC EDGAR API
is not in the live demo path.

**What landed.**

- **S&P 100 roster derivation.** Authoritative source — iShares OEF S&P 100
  ETF NPORT-P schedule of investments as of 2025-12-31 (filed 2026-02-25).
  101 ticker line items confirmed; 100 distinct CIKs (Alphabet's GOOGL +
  GOOG share a single SEC filer CIK 1652044). Tickers mapped to 10-digit
  CIKs via SEC's company_tickers.json master file. All 100 found cleanly
  on first regex pass. Wikipedia S&P 100 page returned blank via web_fetch
  (sandbox/JS-render issue); SEC NPORT-P route was the cleaner authoritative
  path in hindsight.
- **100-company SEC EDGAR extract PASSED.** 5 min 25 sec wall-clock for
  100 CIKs (vs 12 min estimate — SEC fetches are the dominant cost, not
  the 0.12s rate-limit sleep). Rate limiter validated at full scale — no
  429s, no SEC rejections, no retry exhaustion. Final summary `All 100
  CIK(s) landed`. Bronze post-extract: 100 distinct CIKs × 2 extract_date
  partitions = 101 objects (Apple in both; 99 others only at 2026-05-25).
  The 10 session-3 CIKs re-extracted into the same 2026-05-25 partition
  (overwrote own files cleanly per S3 versioning).
- **`scripts/verify_bronze_s3_metadata.py` SHIPPED.** Three-layer pattern
  (verbose chat → clean disk → EXTRACT_PIPELINE.md section 11). Paginated
  `list_objects_v2` + sequential `head_object` loop + 5 PASS/FAIL checks:
  object count = 101, distinct CIKs = 100, partition count = 2, min size
  > 0, sha256_cross_cik_collisions = 0. First run 5/5 PASS in 27 sec.
  Non-conforming-key skip caught the bare `zone=bronze/` folder placeholder
  from session 1's bucket setup — defensive design earned its keep on
  first run. 10-criteria audit: 10/10 PASS.
- **`sql/verify/01_phase1_bronze_verification.sql` REFACTORED for 100-scale.**
  Four targeted edits — header comment scope (Bronze freeze context),
  out-of-scope section (boto3 script no longer deferred), IN list 11 →
  100 CIKs (10 per line for readability), expected values updates
  (11 → 101, 11 → 100, 10 → 100, 11 → 101; checks 3 and 5 unchanged).
  Re-run via Athena workgroup `wg_financial_analytics`: 6/6 PASS,
  1.994 sec runtime, 2.03 GB scanned (~$0.01 Athena cost).
- **Phase 1 close-out structural audit clean.** File inventory complete
  (all PROJECT_PLAN.md section 9 Phase 1 deliverables shipped), naming
  monotonicity intact, no stale .gitkeep, verify-pairs intact, doc
  currency confirmed at session close.
- **`EXTRACT_PIPELINE.md`** — section 11 (boto3 metadata verification
  walkthrough) shipped; existing References renamed to section 12;
  Status line updated to "Phase 1 COMPLETE — Bronze frozen 2026-05-25";
  section 10 closing paragraph updated to drop the "deferred" framing.
- **`README.md`** — Status line bumped from "Phase 1 session 1 complete"
  to "Phase 1 complete (Bronze frozen)" with the 11-check verification
  surface summarized.
- **`LEARNINGS.md`** — three new "Project #3 lessons" entries banked
  (1) web fetch blank-page escalation pattern → SEC NPORT-P route,
  (2) defensive non-conforming-key skip earns its keep on first run,
  (3) Athena scan on raw JSON Bronze scales with CIK count not query
  selectivity (rationale for Phase 2 Parquet materialization).

**Verification surface at Bronze freeze (the canonical Phase 1 ship gate).**

- 5/5 boto3 metadata PASS
- 6/6 Athena SQL PASS
- 11 independent checks, all PASS
- Bronze inventory: 101 objects, 100 distinct CIKs, 2 extract_date partitions

**Decisions locked this session.** None new at the project-stack level —
Phase 1 close, no architecture pivots. Data-side calibration: authoritative
S&P 100 source = iShares OEF NPORT-P (cleaner than Wikipedia or S&P Dow
Jones interactive pages when both fail under direct fetch).

**Blockers / surprises.** Two minor process surprises, no architectural
surprises:

- Wikipedia S&P 100 page returned blank via web_fetch (likely JS-rendered
  table or sandbox-level bot detection). Pivoted to iShares OEF NPORT-P
  SEC filing as the authoritative roster source — actually cleaner in
  hindsight (the OEF holdings ARE the S&P 100 by construction).
- Athena scan jumped 8400x (241 KB → 2.03 GB) for 10x CIK count increase.
  JSON content read per partition is the cost driver — openx JsonSerDe
  reads every byte regardless of column projection. Silver Parquet in
  Phase 2 will collapse this. Banked as the explicit cost rationale for
  Phase 2 materialization.

**NOT in this session — deferred.**

- dbt-athena Iceberg vs Parquet materialization decision → Phase 2 session 1.
- IAM permission expansion for dbt write paths → Phase 2 session 1.
- VS Code venv auto-activate config → Phase 6 polish.
- Bronze stamped-sha256 vs recomputed-sha256 deep integrity check (`--deep`
  flag on verify_bronze_s3_metadata.py) → Phase 6 polish.

**Next session.** Phase 2 session 1 — dbt-athena scaffolding kickoff.
Estimated 90-150 min. Scope: pip install dbt-athena-community, IAM
permission expansion (dbt write to Glue Catalog + Athena workgroup + S3
silver/gold zones), Iceberg vs Parquet decision (locked once at start),
dbt project init (dbt_project.yml, profiles.yml.example, packages.yml,
sources.yml pointing at sec_edgar_companyfacts), first staging model
(stg_sec_edgar__companyfacts exercising `json_extract_*` on Bronze JSON),
dbt run + verify Silver Parquet lands in S3, DBT_PIPELINE.md stub,
10-criteria audit, session close.

---

### 2026-05-25 — Phase 1 session 3 — 10-company extract + Glue Crawler attempt + manual Bronze DDL + verification suite

**Goal.** 10-company sector-diverse extract test (10 fresh CIKs across financials, tech, healthcare, energy, consumer staples) using the existing `extract_sec_edgar.py` with repeated `--cik` flags. Bronze verification suite first draft via Athena SQL. Optional Glue Crawler bootstrap. Phil opted up-front for Option A (Crawler-first → SQL-via-Athena verification) per pacing signal welcoming 30-60 min for professional-quality routes.

**What landed.**

- **10-company SEC EDGAR extract PASSED.** ~12-15 seconds wall-clock for 10 CIKs across financials (JPM 19617, BAC 70858), tech (MSFT 789019, NVDA 1045810), healthcare (JNJ 200406, UNH 731766), energy (XOM 34088, CVX 93410), consumer (WMT 104169, PG 80424). All 11 partition combos (10 from today + Apple from session 2) reachable through partition projection. Rate limiter held cleanly at moderate scale — no 429s, no SEC rejections.
- **Glue infrastructure shipped (Crawler retained as scaffolding, NOT used for Bronze).** IAM role `AWSGlueServiceRole-financial-analytics-lakehouse` created with managed AWSGlueServiceRole policy + custom inline `S3ReadAccess-financial-analytics-lakehouse` policy scoped to our bucket. Glue database `financial_analytics_bronze` created. Crawler `crawler_bronze_sec_edgar` configured (S3 source `zone=bronze/`, on-demand schedule, table prefix `sec_edgar_`). Crawler ran 49 seconds and FAILED with ValidationException on the 128 KB column-type-definition limit during NVIDIA's struct inference — 6 partial tables created before bail. Crawler infrastructure kept for future Silver/Gold Parquet layers where the schema heterogeneity won't apply.
- **Athena workgroup `wg_financial_analytics` created.** Customer-managed query results at `s3://phil-financial-analytics-lakehouse/athena-results/`, override-client-side-settings ON, IAM auth, engine v3. Per-query bytes-scanned hard cap deferred — AWS UI now surfaces only soft CloudWatch alerts at workgroup level; the historical hard cap moved to post-creation edit path. Acceptable at our 30-300 MB bucket scale; revisit in Phase 6 if data crosses GB territory.
- **Manual Bronze DDL shipped.** `sql/ddl/01_create_bronze_tables.sql` — `CREATE EXTERNAL TABLE` with `facts` column intentionally excluded (deferred to Phase 2 Silver dbt parsing), `entityname` mapped via openx JsonSerDe, partition projection on `extract_date` (type=date, range=`2026-05-24,NOW`) + `cik` (type=injected). DDL ran clean; smoke check returned 11 rows including NVIDIA (the one that broke the Crawler). 10/10 audit PASS.
- **Bronze verification suite shipped.** `sql/verify/01_phase1_bronze_verification.sql` — CTE-based PASS/FAIL pattern carried from Project #2 LEARNINGS. 6 checks: total rows = 11, distinct CIKs = 11, extract_date partitions = 2, today's row count = 10, yesterday's row count = 1, non-null entitynames = 11. All 6 PASSED on first run. Run time 1.181 sec, 241.5 KB scanned. 10/10 audit PASS.
- **LEARNINGS.md** — five new "Project #3 lessons" entries banked: (1) venv-not-active on fresh PowerShell session — Phil drove the diagnosis; (2) Glue Crawler heterogeneity / 128 KB column-type-definition limit; (3) Athena Query Editor one-statement-at-a-time constraint; (4) TYPE_MISMATCH on date BETWEEN over string partition column + four-options consolidation — Phil drove the diagnosis; (5) web-search-verify discipline before shipping unverified syntax claims.
- **EXTRACT_PIPELINE.md** — extended with section 9 (Glue Crawler attempt + pivot), section 10 (manual Bronze DDL design), section 11 (Athena workgroup + verification suite). Section 7 (step-up testing protocol) flipped: 10-company status PASSED 2026-05-25; 100-company still PENDING.

**Decisions locked this session.**

- Bronze table schema: minimal column set (entityname + partition keys), `facts` deferred to Silver.
- Glue Crawler retained as infrastructure scaffolding for Silver/Gold layers; not used for Bronze where heterogeneous JSON broke it.
- Athena workgroup `wg_financial_analytics` is the project-default workgroup for the rest of Project #3.
- Web-search-verify discipline: standing pattern for any non-trivial DDL or API claim — `allowed_domains` restricted to authoritative sources only.

**Blockers / surprises.** The Glue Crawler failure was a genuine architectural surprise — the 128 KB Catalog limit isn't prominently documented and the heterogeneous-JSON limitation wasn't anticipated at design time. Pivot was clean once the limitation was understood. The `::` cast and openx-string-serialization claims being WRONG were the meta-surprise — reinforced the web-search-verify discipline.

**NOT in this session — deferred.**

- 100-company full S&P 100 extract → next session (Phase 1 session 4, final Bronze extract; Bronze freeze).
- boto3-based S3 byte-count + sha256 fingerprint verification script → next session (the SQL verification suite covers JSON content; Python script needs to cover S3 object metadata).
- VS Code venv auto-activate config → Phase 6 polish.
- Per-query bytes-scanned hard cap on Athena workgroup → Phase 6 polish if bucket scales past GB.

**Next session.** Phase 1 session 4 — 100-company full S&P 100 extract + rate-limiter scaling validation + boto3-based S3 metadata verification script + Phase 1 close-out structural audit. Bronze freezes on this snapshot per demo-durability principle 1.

---

### 2026-05-24 — Phase 1 session 2 — smoke test + SEC EDGAR extract + Apple 1-company test

**Goal.** Ship the AWS smoke test (deferred from session 1) + first draft
SEC EDGAR extract script + validate against Apple Inc (CIK 320193) per
the step-up testing protocol. Bank session-2 lessons in
TEACHING_PREFERENCES + LEARNINGS.

**What landed.**

- `scripts/smoke_test_aws.py` — connectivity proof for the AWS auth + S3
  stack. Three-layer pattern (verbose chat walkthrough → clean on disk →
  EXTRACT_PIPELINE section 3a updated). Structured logging with specific
  exception classes, 5 distinct exit codes, dedicated `health_checks/`
  prefix on S3, sha256-style separation of concerns (lifecycle policy
  banked for Phase 6). 10-criteria audit: 10/10 PASS.
- `scripts/extract_sec_edgar.py` — SEC EDGAR companyfacts → S3 Bronze.
  argparse `--cik` (default Apple), polite ~8 req/sec rate limiter,
  `urllib3.Retry` adapter for transient failures (5 attempts, expo
  backoff), Hive-style partition key `zone=bronze/extract_date=YYYY-MM-DD/cik=XXXXXXXXXX/`,
  10-digit CIK pad, sha256 fingerprint in S3 object metadata, 8 exit
  codes. 10-criteria audit: 10/10 PASS.
- `requirements.txt` — boto3, python-dotenv, requests (minimum-version
  pinning during build; lock file deferred to Phase 6).
- `.venv/` — local virtual environment created and gitignored (already
  covered by session-1 `.gitignore`).
- `PROJECT_PLAN.md` section 10 principle #4 — Free Tier wording fixed
  (12-month Free Tier → 6-month Free Plan / $200 credits; account cliff
  23 Nov 2026 explicit).
- `EXTRACT_PIPELINE.md` — section 3a flipped from "deferred" to "shipped"
  (smoke test); sections 4-8 expanded with extract script details, rate
  limiter design, retry tuning, step-up testing protocol with Apple PASS.
- `TEACHING_PREFERENCES.md` — four pace / depth calibration bullets
  added under "Anything else Claude should know": (1) no inline code
  formatting in explanations — re-lock; (2) verbose-in-chat depth =
  block-level for Python, line-level for configs; (3) pace > teaching
  density — Project #3 ships first, deep instruction deferred to 6-8
  week training journey + interview prep; (4) standard response template
  — brief bullet summary, light explanation, one optional direction
  question, senior-DE default, Phil asks for depth.
- `LEARNINGS.md` — two new entries under "Project #3 lessons": inline-code
  formatting drift (diagnosis → fix → lesson) and process-density drift
  (diagnosis → fix → lesson).

**Apple 1-company test result.** PASSED 2026-05-24 12:26 local. ~3.6 MB
raw JSON landed to `s3://phil-financial-analytics-lakehouse/zone=bronze/extract_date=2026-05-24/cik=0000320193/companyfacts.json`.
sha256 prefix `31f9ab439840`. End-to-end ~4 seconds. AWS Console
inspection confirmed: 5 metadata fields (Content-Type + cik + extracted-at
+ sha256 + source) and 3 tags (Purpose=Extract + Component=extract_sec_edgar
+ Source=SECEDGAR) all rendered correctly. S3 versioning audited via
"Show versions" toggle — confirmed smoke test delete-marker preserved.

**Decisions locked this session.** None new at the project-level — all
session-2 decisions were within the locked Phase 0 stack. Calibrations
locked at the working-style level (4 bullets in TEACHING_PREFERENCES).

**Lessons captured in LEARNINGS.md "Project #3 lessons" section.**

Two diagnosis → fix → lesson loops banked: (1) inline-code formatting
in explanations breaks Phil's reading flow — re-locked the 2026-05-20
rule with explicit violation categories; (2) process-density drift —
session 2 drifted into Phase-0-style discussion density (multi-paragraph
design call write-ups, 6 green-light questions before building); fixed
with three coordinated TEACHING_PREFERENCES bullets locking the new
ship-tight default template.

**Blockers / surprises.** None. Smoke test ran clean first try; extract
ran clean first try; AWS Console inspection confirmed every metadata
field and tag we set.

**NOT in this session — deferred.**

- 10-company sector-diverse extract test → next session.
- Full S&P 100 extract → session after.
- Glue Crawler bootstrap → next session (or session after, depending on
  whether Phil wants to crawl after the 10-company landing or after the
  100-company freeze).
- `sql/verify/01_phase1_bronze_verification.sql` → next session.
- Pylance squiggle check on `scripts/*.py` in VS Code → flag from
  10-criteria audit item 6; non-blocking, glance next time VS Code opens.

**Next session.** Phase 1 session 3 — 10-company sector-diverse extract
+ rate-limiter scaling validation + Bronze verification suite first
draft + (optional) Glue Crawler bootstrap if 10-company landing looks
clean.

---

### 2026-05-23 — Phase 1 session 1 — AWS bootstrap + S3 landing + GitHub repo

**Goal.** Lay the AWS + git foundation that everything else hangs off.
AWS account, Admin IAM user with MFA, $5 budget alert, S3 bucket with
medallion prefix folders, GitHub repo creation. SEC EDGAR extract is
session 2 scope, not this session.

**What landed.**

- AWS account on Free Plan (~$200 credits + 6 months; Free Plan expires
  23 Nov 2026 — banked as the conversion-to-paid cliff date). Account ID
  470439680370.
- Root MFA enabled (Microsoft Authenticator, device `phil-root-msauth`);
  root signed out and shelved post-bootstrap.
- Admin IAM user `phil-admin` via Administrators user group +
  `AdministratorAccess` policy. MFA enabled (`phil-admin-msauth`).
  Programmatic access keys generated → written straight into `.env`.
- Budget alert `portfolio-monthly-5usd-tripwire` — $5/month cap, alerts
  at 85% actual / 100% actual / 100% forecasted to
  `pheluciam@outlook.com`.
- S3 bucket `phil-financial-analytics-lakehouse` in **us-east-1** (region
  locked at this step). General purpose, ACLs disabled,
  block-all-public-access ✓, versioning enabled, default SSE-S3
  encryption. Three prefix folders: `zone=bronze/`, `zone=silver/`,
  `zone=gold/`.
- `.env` populated with real credentials + locked region + locked bucket
  + locked SEC EDGAR User-Agent (gitignored). `.env.example` committed
  as the template counterpart.
- `.gitignore` committed — covers Python artifacts, venv, secrets, AWS
  local creds, linter caches, IDE scratch, OS junk, local data scratch.
- `EXTRACT_PIPELINE.md` stub authored — distinguishes session 1 vs
  session 2 scope; will expand session 2 as extract is built.
- GitHub repo `Pheluciam/financial-analytics-lakehouse-project` (public).
  Local `git init` + `origin` remote wired up + default branch `main`.

**Decisions locked this session.**

- AWS region: **us-east-1** (N. Virginia). Cheapest tier + strongest
  tutorial alignment. Cost difference at our 100-300 MB scale is ~$0.01
  per month vs Sydney; tutorial alignment is the dominant signal.

**Lessons captured in LEARNINGS.md "Project #3 lessons" section.**

Three diagnosis → fix → lesson loops banked this session: (1) build
locally first, GitHub commit at session close (no mid-session git
plumbing); (2) never screenshot AWS one-time credentials — clipboard or
password manager only; (3) AWS Console region selector doesn't take
effect on Global-service pages, only on region-bound services. Also
banked two trackable open items: Free Plan cliff (23 Nov 2026) and
phil-admin lacking IAM-access-to-billing.

**NOT in this session — deferred.**

- `scripts/smoke_test_aws.py` — boto3 → AWS auth → S3 read/write
  end-to-end value proof. Originally session 1 scope; deferred at
  mid-session scope reshape. To be built first thing in session 2
  BEFORE the extract script, since the extract script depends on the
  same boto3 + auth chain working.
- PROJECT_PLAN.md section 10 Free Tier wording update (12-month →
  6-month / $200-credits). Minor; banked.
- (Resolved in this session close) LEARNINGS.md lessons captured in
  the new "Project #3 lessons" section — workflow, credentials, Console
  UI. No longer deferred.

**Blockers / surprises.** Region dropdown click intermittently
unresponsive on Global-service pages — diagnosed in-session (only
takes effect on region-bound services). Account temp password
exposed in a screenshot — mitigated by force-change + MFA.

**Next session.** `scripts/smoke_test_aws.py` first, then
`scripts/extract_sec_edgar.py` first draft against single company
(Apple, CIK 320193) + polite rate limiter validation + step-up to 10
companies.

---

### 2026-05-23 — Phase 0 kickoff and closeout (single session)

**Goal.** Complete Phase 0 — load context, validate SEC EDGAR API live,
resolve the three non-blocking pre-Phase-0 items, drive all open Phase 0
decisions, lock the stack, author the project-specific docs, structural audit.

**What landed.**

- Live SEC EDGAR API sanity check PASSED against Apple Inc (CIK 320193) with
  User-Agent `Phil <pheluciam@outlook.com>`. ~59KB JSON, populated
  `filings.recent.accessionNumber` array.
- Three non-blocking items resolved: Databricks trial timing (defer to Bronze
  landing close); Azure SQL operational layer (locked as fresh, then
  superseded by AWS pivot); User-Agent format (confirmed).
- **PIVOT 1: Cloud vendor — Azure → AWS.** Driver: portfolio breadth for
  Australian DE job market (research showed Australia/Melbourne split closer
  to 50/50 than feared 90/10 Azure; Phil already has Azure on CV via Project
  #2). Phil prior AWS familiarity from NEC Australia.
- **PIVOT 2: Analytical platform — Databricks → AWS-native (S3 + Glue
  Catalog + Athena + Lake Formation).** Driver: cost-vs-keyword analysis
  (Databricks has 14-day trial cliff + $3-5/demo; AWS-native is pennies/demo
  forever; AWS-native S3/Glue/Athena cluster appears in roughly 2.8× more
  AWS-shop postings than Databricks).
- **Mini-projects block** earmarked at 5 slots, sequenced simpler →
  more complex: (1) dbt Cloud + CI/CD, (2) Databricks, (3) Microsoft Fabric
  end-to-end, (4) Iceberg vs Delta comparison, (5) Streaming (Kinesis + Glue
  ETL Spark Structured Streaming). 1-2 Tableau + ~3 Power BI BI-split target.
- **Mini-projects sit BEFORE the 6-8 week training journey** — journey
  consolidates lessons from 8 codebases (3 main + 5 mini), not 3.
- **AI-assistance disclosure convention** baked as standing convention
  across all 8 portfolio repos. Paste-able README template in
  TEACHING_PREFERENCES.md.
- **Debugging fluency** locked as the priority emphasis area in the training
  journey; in-session debug discipline added to TEACHING_PREFERENCES.md;
  ≥1 debug-pattern question per session locked as a standing quiz category.
- All 8 Phase 0 decisions locked (see PROJECT_PLAN.md section 4).
- **PROJECT_PLAN.md authored fresh.**
- **PROJECT_CONTEXT.md authored fresh** (this file).
- **LEARNING_ROADMAP.md** updated extensively — full table refreshed, Project
  #3 stack section rewritten, mini-projects section added, training journey
  scope expanded, debugging emphasis added, AI-disclosure convention noted,
  Notes/changes appended.
- **ENGINEERING_STANDARDS.md** light update — Project #3 context note added
  at top, date updated.
- **LEARNINGS.md** carry-forward subsection populated with Project #2 → Project
  #3 carry-forward principles.
- Phase 0 structural audit run — no findings.

**Blockers / surprises.** None. Single bash curl was blocked by sandbox
proxy allowlist for `data.sec.gov` — pivoted to `mcp__workspace__web_fetch`,
which routed correctly and returned the JSON. Lesson banked: for SEC EDGAR
API calls from the sandbox during build, route via web_fetch (or via Phil's
local Python in Phase 1 once the extract script exists).

**Next session.** Phase 1 — Bronze landing layer kickoff. First sub-steps
expected: (1) AWS account creation + IAM bootstrap + S3 bucket creation;
(2) GitHub repo creation + first commit (this Phase 0 doc set); (3)
`scripts/extract_sec_edgar.py` first draft with polite rate limiter +
single-company smoke test (Apple, CIK 320193) before any 10-company or
full-100 scale-up.

---

## Files in the project (Phase 2 session 4 close inventory — 2026-05-28)

Doc-shaped:

- `README.md` ✓ (stub; polish at Phase 6 — Status line current as of Phase 1 close, will refresh at Phase 2 close)
- `PROJECT_PLAN.md` ✓
- `PROJECT_CONTEXT.md` ✓ (this file)
- `LEARNING_ROADMAP.md` ✓
- `TEACHING_PREFERENCES.md` ✓ (Phase 2 session 1 — third re-lock on paste-able discipline)
- `ENGINEERING_STANDARDS.md` ✓
- `GLOSSARY.md` ✓
- `LEARNINGS.md` ✓ (25 Project #3 entries — 10 sessions 1-3 + 3 session 4 + 4 Phase 2 session 1 + 2 Phase 2 session 2 + 4 Phase 2 session 3 + 2 Phase 2 session 4 forward-projected risks 4 + 5)
- `EXTRACT_PIPELINE.md` ✓ (Phase 1 walkthrough — frozen at Phase 1 close)
- `DBT_PIPELINE.md` ✓ (Phase 2 session 4 — sections 1-7.8 + 8.1-8.7 + 9 + 10 shipped; section 8 expanded from 4-line stub to 7 subsections covering DV2.0 framing, hand-rolled lock, hub_company, hash key, insert-only filter, verification surface, pattern reusability)
- `GLOSSARY.md` ✓ (Phase 2 session 4 — extended with 7 DV2.0 entries at end of section 2 + 5 acronyms in section 16)

Code-shaped:

- `scripts/smoke_test_aws.py` ✓ (Phase 1 session 2)
- `scripts/extract_sec_edgar.py` ✓ (Phase 1 sessions 2-4)
- `scripts/verify_bronze_s3_metadata.py` ✓ (Phase 1 session 4)
- `sql/ddl/01_create_bronze_tables.sql` ✓ (Phase 1 session 3; Phase 2 session 3 — cik projection switched type=injected → type=enum with 100 CIKs enumerated)
- `sql/ddl/02_create_bronze_raw_text_table.sql` ✓ (Phase 2 session 2 — second Bronze table, raw-text view over same S3 location; Phase 2 session 3 — cik projection switched to type=enum)
- `sql/verify/01_phase1_bronze_verification.sql` ✓ (Phase 1 sessions 3-4)
- `sql/verify/02_phase2_silver_intermediate_verification.sql` ✓ (Phase 2 session 3 — extended from 6 to 11 checks; 11/11 PASS)
- `sql/verify/03_phase2_warehouse_verification.sql` ✓ (Phase 2 session 4 — 9-check CTE PASS/FAIL structural verify for hub_company; 9/9 PASS)
- `iam/lakehouse_dbt_runtime_policy.json` ✓ (Phase 2 session 1 — Customer Managed Policy JSON for phil-dbt; Phase 2 sessions 2-3 — coverage validated, no edits needed)
- `dbt/dbt_project.yml` ✓ (Phase 2 session 1; Phase 2 session 2 — intermediate +materialized: view re-added; Phase 2 session 3 — intermediate flipped to +materialized: table + Iceberg config; seeds: block added with column_types; Phase 2 session 4 — warehouse block added with incremental + merge + iceberg + parquet + on_schema_change=ignore defaults)
- `dbt/profiles.yml.example` ✓ (Phase 2 session 1 — env_var template, real profiles.yml gitignored)
- `dbt/packages.yml` ✓ (Phase 2 session 1 — dbt_utils 1.x)
- `dbt/seeds/canonical_concepts_dictionary.csv` ✓ (Phase 2 session 3 — 8 rows mapping XBRL US-GAAP tag names to project-canonical concepts + business_area)
- `dbt/seeds/_seeds.yml` ✓ (Phase 2 session 3 — seed column contracts + not_null/unique tests)
- `dbt/models/staging/_sources.yml` ✓ (Phase 2 session 1; Phase 2 session 2 — second Bronze source declared)
- `dbt/models/staging/stg_sec_edgar__companyfacts.sql` ✓ (Phase 2 session 1 — typed cover-page staging model, PASSING)
- `dbt/models/staging/stg_sec_edgar__companyfacts_raw.sql` ✓ (Phase 2 session 2 — raw-text staging model, PASSING)
- `dbt/models/intermediate/int_sec_edgar__concepts.sql` ✓ (Phase 2 session 2 — first intermediate model; Phase 2 session 3 — expanded to 8 XBRL tags + period_start_date; PASSING as Iceberg table)
- `dbt/models/intermediate/int_sec_edgar__concepts_canonical.sql` ✓ (Phase 2 session 3 — canonical-concept reconciliation via seed join; PASSING as Iceberg table)
- `dbt/models/intermediate/_models.yml` ✓ (Phase 2 session 2; Phase 2 session 3 — extended with canonical model contracts)
- `dbt/models/warehouse/hub_company.sql` ✓ (Phase 2 session 4 — first DV2.0 hub; hand-rolled SHA-256 hash + source-side insert-only filter; PASSING as Iceberg incremental merge table)
- `dbt/models/warehouse/_models.yml` ✓ (Phase 2 session 4 — hub_company column contracts + 6 schema tests)
- `dbt/models/marts/.gitkeep` (Phase 2 session 1 — placeholder until Phase 4 first mart model)
- `.vscode/settings.json` ✓ (Phase 2 session 1 — yaml.schemas override for dbt_project.yml)
- `.vscode/dbt_project.permissive.schema.json` ✓ (Phase 2 session 1 — empty schema referenced by settings.json)
- `requirements.txt` ✓ (Phase 1 session 2; Phase 2 session 1 — added dbt-athena-community)

AWS infrastructure (provisioned via Console, not yet captured as IaC):

- IAM user `phil-admin` (Phase 1 session 1 — AdministratorAccess; Phase 1 scripts)
- IAM user `phil-dbt` (Phase 2 session 1 — Customer Managed Policy lakehouse-dbt-runtime-access; dbt-athena runtime)
- IAM Customer Managed Policy `lakehouse-dbt-runtime-access` (Phase 2 session 1)
- IAM role `AWSGlueServiceRole-financial-analytics-lakehouse` (Phase 1 session 3 — Glue + custom S3 read inline)
- Glue database `financial_analytics_bronze` (Phase 1 session 3)
- Glue database `financial_analytics_silver` (Phase 2 session 1)
- Glue Crawler `crawler_bronze_sec_edgar` (Phase 1 session 3 — retained scaffolding)
- Athena workgroup `wg_financial_analytics` (Phase 1 session 3)
- Glue Catalog view `financial_analytics_silver.stg_sec_edgar__companyfacts` (Phase 2 session 1 — dbt-managed)
- Glue Catalog table `financial_analytics_bronze.sec_edgar_companyfacts_raw` (Phase 2 session 2 — second raw-text Bronze table over same S3 location; manual DDL)
- Glue Catalog view `financial_analytics_silver.stg_sec_edgar__companyfacts_raw` (Phase 2 session 2 — dbt-managed)
- Glue Catalog view `financial_analytics_silver.int_sec_edgar__concepts` (Phase 2 session 2 — dbt-managed; first intermediate model)
- Glue Catalog table `financial_analytics_silver.hub_company` (Phase 2 session 4 — dbt-managed Iceberg incremental merge; first DV2.0 hub)

Repo-config:

- `.env` (gitignored — phil-admin + phil-dbt credential blocks)
- `.env.example` ✓ (Phase 1 session 1; Phase 2 session 1 — added AWS_DBT_* placeholders)
- `.gitignore` ✓ (Phase 1 session 1; Phase 2 session 1 — added dbt runtime artifacts + .vscode partial allow)
- `.venv/` (gitignored, Phase 1 session 2; Phase 2 session 1 — added dbt-athena-community + python-dotenv[cli])
- `dbt/profiles.yml` (gitignored, Phase 2 session 1 — copy of dbt/profiles.yml.example)
- `dbt/dbt_packages/`, `dbt/target/`, `dbt/logs/` (gitignored, Phase 2 session 1 — dbt runtime artifacts)

---

## Cross-doc reading order at session start

1. **TEACHING_PREFERENCES.md** — how Phil wants to work
2. **PROJECT_CONTEXT.md** (this file) — where we are right now
3. **PROJECT_PLAN.md** sections relevant to the active phase — what we're building
4. **ENGINEERING_STANDARDS.md** if writing code — the audit bar
5. **LEARNING_ROADMAP.md** sections only if context-shifting (rare mid-project)
6. **LEARNINGS.md** as needed when a bug class is familiar

---

*Last updated: 2026-05-28 (Phase 2 session 4 close — first warehouse-layer
Data Vault 2.0 hub (hub_company) shipped end-to-end with hand-rolled
SHA-256 hash + insert-only source-side filter + Iceberg merge incremental;
6/6 dbt tests + 9/9 SQL structural verify PASS; idempotency proven via
second-run NO-OP; first ever phase-kickoff forward-verify pass ran +
banked 2 forward-projected risks BEFORE any code shipped; DBT_PIPELINE
section 8 + GLOSSARY DV2.0 entries shipped). Append a session-log entry
at every session close.*

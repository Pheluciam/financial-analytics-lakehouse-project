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
| Active phase | **Phase 2 in progress.** Session 3 CLOSED 2026-05-28 — canonical-concept reconciliation shipped end-to-end, intermediate layer flipped to Iceberg tables, Bronze cik partition projection switched to enum, verification suite 11/11 PASS reconciling Apple's published FY16-FY21 revenues across the ASC 606 alias discontinuity. |
| Next phase | Phase 2 session 4 — first warehouse-layer Data Vault 2.0 model (hub_company). Reads cik + entity_name from the staging layer; Iceberg merge incremental strategy for future SCD-2 history at the satellite layer. Est. 60-90 min. |
| Last session closed | 2026-05-28 (Phase 2 session 3 — CLOSE) |
| Last bundled commit | 2026-05-28 — Phase 2 session 3 bundle (canonical_concepts_dictionary seed + _seeds.yml + dbt_project.yml seeds block; int_sec_edgar__concepts expanded to 8 XBRL tags + period_start_date column; new int_sec_edgar__concepts_canonical model joining the seed; _models.yml extended with column contracts on the new model; sql/verify/02 extended from 6 to 11 checks reconciling Apple FY19-FY21 canonical revenue; intermediate layer flipped to Iceberg tables in dbt_project.yml; Bronze cik partition projection switched type=injected → type=enum on both Bronze table DDLs; 4 new LEARNINGS entries; DBT_PIPELINE.md sections 7.5-7.8 shipped; TEACHING_PREFERENCES.md updated with AWS-identity-naming standing rule) |
| Active blockers | None |
| Open questions | None at the architectural level. |

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

## Files in the project (Phase 2 session 3 close inventory — 2026-05-28)

Doc-shaped:

- `README.md` ✓ (stub; polish at Phase 6 — Status line current as of Phase 1 close, will refresh at Phase 2 close)
- `PROJECT_PLAN.md` ✓
- `PROJECT_CONTEXT.md` ✓ (this file)
- `LEARNING_ROADMAP.md` ✓
- `TEACHING_PREFERENCES.md` ✓ (Phase 2 session 1 — third re-lock on paste-able discipline)
- `ENGINEERING_STANDARDS.md` ✓
- `GLOSSARY.md` ✓
- `LEARNINGS.md` ✓ (23 Project #3 entries — 10 sessions 1-3 + 3 session 4 + 4 Phase 2 session 1 + 2 Phase 2 session 2 + 4 Phase 2 session 3)
- `EXTRACT_PIPELINE.md` ✓ (Phase 1 walkthrough — frozen at Phase 1 close)
- `DBT_PIPELINE.md` ✓ (Phase 2 session 3 — sections 1-7.8, 9, 10 shipped; section 8 expands at Phase 2 session 4+)

Code-shaped:

- `scripts/smoke_test_aws.py` ✓ (Phase 1 session 2)
- `scripts/extract_sec_edgar.py` ✓ (Phase 1 sessions 2-4)
- `scripts/verify_bronze_s3_metadata.py` ✓ (Phase 1 session 4)
- `sql/ddl/01_create_bronze_tables.sql` ✓ (Phase 1 session 3; Phase 2 session 3 — cik projection switched type=injected → type=enum with 100 CIKs enumerated)
- `sql/ddl/02_create_bronze_raw_text_table.sql` ✓ (Phase 2 session 2 — second Bronze table, raw-text view over same S3 location; Phase 2 session 3 — cik projection switched to type=enum)
- `sql/verify/01_phase1_bronze_verification.sql` ✓ (Phase 1 sessions 3-4)
- `sql/verify/02_phase2_silver_intermediate_verification.sql` ✓ (Phase 2 session 3 — extended from 6 to 11 checks; 11/11 PASS)
- `iam/lakehouse_dbt_runtime_policy.json` ✓ (Phase 2 session 1 — Customer Managed Policy JSON for phil-dbt; Phase 2 sessions 2-3 — coverage validated, no edits needed)
- `dbt/dbt_project.yml` ✓ (Phase 2 session 1; Phase 2 session 2 — intermediate +materialized: view re-added; Phase 2 session 3 — intermediate flipped to +materialized: table + Iceberg config; seeds: block added with column_types)
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
- `dbt/models/warehouse/.gitkeep` (Phase 2 session 1 — placeholder until session 4+ first DV2.0 model)
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

*Last updated: 2026-05-28 (Phase 2 session 3 close-amend — first commit
shipped canonical-concept reconciliation + Iceberg flip + Bronze enum;
amend commit shipped forward-projected risk pass + AU-market-aligned
learning roadmap + ENGINEERING_STANDARDS criterion-7 strengthening + new
phase-kickoff forward-verify rule). Append a session-log entry at every
session close.*

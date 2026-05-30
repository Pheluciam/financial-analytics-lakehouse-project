# Project Plan — financial-analytics-lakehouse-project

> Project #3 of Phil's data engineering pathway. Source of truth for what we're
> building, the locked stack, the locked Phase 0 decisions, and the
> phase-by-phase delivery plan. Companion to PROJECT_CONTEXT.md (running
> session state), LEARNING_ROADMAP.md (broader learning trajectory),
> ENGINEERING_STANDARDS.md (per-script + phase-boundary audit), TEACHING_PREFERENCES.md
> (standing working conventions), GLOSSARY.md (term definitions), and
> LEARNINGS.md (diagnosis → fix → lesson loops, including Project #2 carry-forward).
>
> Created: 2026-05-23 (Phase 0 closeout). Authored AI-assisted per the standing
> AI-assistance disclosure convention in TEACHING_PREFERENCES.md.

---

## 1. Project overview

**Goal.** Build a production-style AWS-native data lakehouse that ingests US
public-company corporate-finance data from the SEC EDGAR API, models it as
Data Vault 2.0 inside a Bronze / Silver / Gold medallion, and surfaces it
through a polished 5-page Power BI report. The project is the third in
Phil's portfolio sequence and serves as a recruiter-facing artifact
demonstrating AWS-native lakehouse architecture + Data Vault 2.0 modeling
+ corporate-finance domain knowledge.

**Career target.** Analytics Engineer, Senior Data Analyst with pipeline work,
BI Engineer, or mid-level Data Engineer roles in the Australian market.
North star: get a job. Secondary north star: $0 idle cost so the demo lives
indefinitely after build (per demo-durability principle 4).

**Why this stack and domain.** Full decision arc — what was considered, what
was pivoted, and why each lock landed where it did — lives in
LEARNING_ROADMAP.md "Project #3 — locked stack" section and the dated
"Notes / changes" entries beneath it. This file captures the LOCKED outcome,
not the deliberation history.

**Portfolio differentiation from Projects #1 and #2.**

| | Project #1 | Project #2 | Project #3 (this) |
|---|---|---|---|
| Domain | GTFS transit data | M5 retail forecasting | SEC EDGAR corporate finance |
| Cloud | None / local | Azure | AWS |
| Analytical platform | Local Postgres + dbt | Snowflake | AWS-native lakehouse (S3 + Glue + Athena) |
| Modeling pattern | dbt analytics | Kimball star (3-tier) | Data Vault 2.0 inside medallion |
| Orchestration | None | Airflow + Cosmos | AWS Step Functions |

---

## 2. Domain and data source

**Domain.** US corporate finance — public-company income statements, balance
sheets, cash-flow statements, financial ratios, restatement history (latter
captured but not surfaced in dashboards per the dropped "risk + anomaly"
theme).

**Data source.** SEC EDGAR API at `data.sec.gov`. Free, no API key, REST,
JSON responses. SEC rate-limit safe ceiling: 10 requests per second. User-Agent
header required by SEC policy — locked value: `Phil <pheluciam@outlook.com>`.

Three endpoints in use:

- `data.sec.gov/submissions/CIK##########.json` — filing history per company
- `data.sec.gov/api/xbrl/companyfacts/CIK##########.json` — all XBRL
  financial facts per company (income statement, balance sheet, cash flow)
- `data.sec.gov/api/xbrl/frames/...` — one fact across all companies for a
  reporting period (powers the peer-benchmarking mart)

**Ticker → CIK lookup.** `https://www.sec.gov/files/company_tickers.json` —
free master file mapping ticker symbols to SEC's Central Index Key (CIK)
numbers. Consumed once at the start of the extract phase.

**Live API check passed 2026-05-23.** GET against Apple Inc (CIK 320193) with
the locked User-Agent returned ~59KB JSON with a populated
`filings.recent.accessionNumber` array. API is live and structurally sound.

---

## 3. Locked stack

| Layer | Choice |
|---|---|
| Cloud vendor | AWS |
| Operational source | None — direct-to-S3 lakehouse-native |
| Object storage | Amazon S3 (single bucket, prefix-partitioned by zone + extract date) |
| Metastore | AWS Glue Data Catalog |
| Query engine | Amazon Athena (serverless SQL) |
| Optional governance | AWS Lake Formation (Phase 6 stretch; default off for portfolio scope) |
| Transformation tool | dbt-athena |
| Orchestration | AWS Step Functions |
| Modeling pattern | Data Vault 2.0 inside Bronze / Silver / Gold medallion |
| Forecasting compute | Local Python (Prophet or statsmodels) → Parquet on S3 → dbt source |
| BI tool | Power BI Desktop, Import mode .pbix |
| CI/CD | GitHub Actions — ruff F821 + dbt parse + sqlfluff (Snowflake dialect swapped for Athena dialect) |

---

## 4. Locked Phase 0 decisions

All eight locked 2026-05-23. Full deliberation history per decision lives in
LEARNING_ROADMAP.md under the dated "Notes / changes" entries.

| # | Decision | Lock |
|---|---|---|
| 1 | History depth | 10 years of SEC EDGAR filings (back to ~mid-2016) |
| 2 | Operational layer | Direct-to-S3 (no RDS Postgres intermediary) |
| 3 | Transformation tool | dbt-athena |
| 4 | Power BI publishing | Continuous publish during build + freeze at v1.0 |
| 5 | Curated company universe | S&P 100, current (mid-2026) constituent roster |
| 6 | Dashboard themes | 4 themed pages + 1 executive overview (5 total) |
| 7 | Orchestration | AWS Step Functions |
| 8 | SEC EDGAR User-Agent | `Phil <pheluciam@outlook.com>` |

Dashboard themes locked:

1. P&L trend + decomposition
2. Peer / sector benchmarking
3. Financial health + ratios
4. Growth + forecasting

Risk + anomaly (10-K/A restatements) considered and dropped — highest cost / lowest portfolio value of the five candidates.

---

## 5. Architecture

```
SEC EDGAR API (HTTPS / JSON, public, 10 req/sec safe ceiling)
        |
        |  Python extract — polite rate-limited, User-Agent set,
        |  exponential backoff + retry, step-up tested (1 → 10 → 100 companies)
        v
[ S3 Bronze ]  raw JSON, partitioned by zone=bronze / extract_date / cik
        |
        |  AWS Glue Crawler discovers schema → registers in Glue Data Catalog
        v
[ Glue Data Catalog: bronze database ]
        |
        |  dbt-athena: SELECT statements compile to Athena SQL,
        |  read from Glue Catalog, write back as Parquet/Iceberg on S3
        v
[ S3 Silver ]  Data Vault 2.0: hubs / links / satellites
        +     XBRL canonical-concept reconciliation (Revenues / SalesRevenueNet
        +     / Revenue → canonical revenue)
        |
        v
[ S3 Gold ]   4 information marts:
              mart_pl_trend, mart_peer_benchmark,
              mart_financial_health, mart_growth_forecast
        |
        v
[ Amazon Athena ]  serverless SQL query layer
        |
        |  Power BI Athena native connector — Import mode
        v
[ Power BI Desktop ]  5-page .pbix — 1 executive overview + 4 themed pages

[ AWS Step Functions ]  state machine orchestrating:
        Python extract → Glue Crawler refresh → dbt run → dbt test → verify
        On-demand only (per demo-durability principle 2 — no live cron)

[ Local Python ]  Prophet / statsmodels forecasting — outputs Parquet to S3,
                  picked up by dbt as a source for mart_growth_forecast
```

---

## 6. Data flow — Bronze / Silver / Gold

**Bronze (raw landing).** Append-only Delta or Parquet on S3. Schema mirrors
SEC EDGAR JSON exactly — no transformation, no joining, no enrichment. Each
extract run lands under `zone=bronze/extract_date=YYYY-MM-DD/` so re-extracts
don't overwrite history. Bronze IS the system of record per
demo-durability principle 1 (snapshot once during build, then freeze; the
SEC EDGAR API is not in the live demo path).

**Silver (raw vault + canonical concepts).** Data Vault 2.0 raw vault built
from Bronze via dbt-athena models. Hubs hold business keys; links hold
relationships; satellites hold descriptive attributes with full history.
Alongside the vault, the Silver layer performs XBRL canonical-concept
reconciliation — mapping the heterogeneous concept names different companies
use for the same metric (e.g. `Revenues` / `SalesRevenueNet` / `Revenue`)
to a single canonical concept (`revenue`). This normalisation IS the
genuine data engineering work for Silver.

**Gold (information marts).** Denormalised, aggregation-friendly marts built
for BI consumption. One mart per dashboard theme:

- `mart_pl_trend` — quarterly P&L line items per company, time-series shaped
- `mart_peer_benchmark` — cross-company metric snapshots, sector-tagged
- `mart_financial_health` — pre-computed ratios per company per quarter
- `mart_growth_forecast` — historical growth + Python-forecast next 4 quarters

Power BI reads Gold marts via Athena's native connector in Import mode.

---

## 7. Data Vault 2.0 modeling pattern

Brief explainer; full reference in GLOSSARY.md and DBT_PIPELINE.md.

**Implementation approach (locked 2026-05-28 after phase-kickoff forward-verify pass).** Data Vault 2.0 hubs / links / satellites for Project #3 are HAND-ROLLED in plain dbt-athena SQL — NOT via the AutomateDV (formerly dbtvault) package. Verified against automate-dv.readthedocs.io Platform Support page: AutomateDV officially supports Snowflake, BigQuery, MS SQL Server, Databricks, Postgres; Athena is not on the supported list and not on the planned list. The hand-rolled approach is the stronger portfolio story regardless — recruiters see pattern understanding (you can write a SCD-2 satellite from scratch), not just library usage. Full diagnosis loop banked in LEARNINGS.md "Forward-projected risks" subsection.

**Hubs** hold the unique business keys of entities. Actual hubs (locked through
session 8, 2026-05-28):

- `hub_company` — one row per company (business key: CIK). 100 rows. Shipped
  session 4.
- `hub_filing` — one row per filing (business key: accession_number). 6,551
  rows. Shipped session 5.
- `hub_concept` — one row per canonical XBRL concept (business key:
  canonical_concept). 5 rows. Shipped session 8.
- `hub_period` — **DEFERRED indefinitely** per LEARNINGS Risk 14 (2026-05-28
  forward-verify probe). 10,974 distinct period instances is transactional-grain
  territory, not reference-hub territory. Period attributes live as descriptive
  link-level payload on link_filing_concept_period instead.

**Links** hold relationships between hubs. Actual links:

- `link_company_filing` — which filings belong to which company. 6,551 rows.
  Shipped session 5.
- `link_filing_concept_period` — 3-way standard link associating hub_company +
  hub_filing + hub_concept with the per-period observation grain (period
  attributes as descriptive link-level payload, NOT a separate hub_period).
  89,821 rows. Shipped session 8. **Supersedes** the originally-planned
  `l_filing_concept` + `l_filing_period` — the 3-way link with period payload
  is the more DV2.0-idiomatic shape per LEARNINGS Risks 14 + 15.

**Satellites** hold descriptive attributes + history (SCD-2 native to the
pattern). Actual + scheduled satellites:

- `sat_filing_metadata` — form_type + filed_date. Shipped session 6.
- `sat_company_metadata` — entity_name. Shipped session 7.
- `sat_concept_value` — the actual XBRL fact value + unit, parent =
  link_filing_concept_period. THIS IS the model holding the real numerical
  financial data every Phase 4 Gold mart consumes. 89,821 rows. Shipped
  session 8.
- `sat_concept_canonical` — raw concept_name → canonical_concept audit lineage
  mapping. Shipped session 9. First multi-active satellite (MAS) in the project
  — new DV2.0 mechanic on hub_concept; defends the MIN(value) information-loss
  decision baked into sat_concept_value by preserving raw-tag provenance for
  regulatory-defensible audit lineage. 8 active rows (4 revenue alias raw tags
  + 4 identity-mapped). CDK = stable source-provided raw concept_name hash per
  Scalefree priority rule (LEARNINGS Risk 18); degenerate payload (CDK ==
  payload) explicitly named (Risk 17).

**Business Vault objects** (Scalefree-canonical layer between raw vault and
information marts). Shipped session 10:

- `dim_as_of_dates` — 10-row Business Vault as-of-dates spine, fiscal year-ends
  2016-12-31 through 2025-12-31. Consumed by both PIT and Bridge.
- `pit_link_filing_concept_period` — single-sat Point-in-Time table on the
  most-queried link spine (link_filing_concept_period + sat_concept_value).
  634,431 rows. Single-sat PIT framing acknowledged honestly per LEARNINGS Risk 19
  — picked over hub-level PITs because the link spine is THE fact-shape Phase 4
  marts consume.
- `bridge_company_concept_period` — 5-hop hub-link-hub navigation Bridge spanning
  hub_company → link_company_filing → hub_filing → link_filing_concept_period →
  hub_concept. 634,431 rows. No effectivity satellites per LEARNINGS Risk 20
  (insert-only links, no end-date semantics). Targets Phase 4 mart_pl_trend +
  mart_peer_benchmark directly.
- Temporal anchor for both PIT and Bridge = filed_date from sat_filing_metadata
  (NOT load_datetime) per LEARNINGS Risk 23 — project's load_datetime captures
  ingestion-time, not observation-time.

Both PIT and Bridge demonstrate full DV2.0 fluency beyond the Raw Vault and
materially accelerate Phase 4 mart queries by collapsing multi-join walks to
straight SELECTs against the Business Vault. Materialized as plain Iceberg
tables (not incremental merge) — query helpers rebuilt each refresh, structurally
avoiding the Risk 2 Iceberg-merge on_schema_change duplicate-insertion bug
class. Hand-rolled per Risk 1 — AutomateDV's pit + bridge macros + pit_incremental
+ bridge_incremental materializations don't ship for dbt-athena.

Native SCD, full audit lineage, restatement history captured by appending
new satellite rows rather than updating in place. Strong fit for the
regulated-finance domain.

---

## 8. File layout (expected)

```
financial-analytics-lakehouse-project/
├── README.md                       # Phase 6 — public-facing entry point
├── PROJECT_PLAN.md                 # this file
├── PROJECT_CONTEXT.md              # running session state
├── LEARNING_ROADMAP.md             # broader pathway
├── TEACHING_PREFERENCES.md         # standing working conventions
├── ENGINEERING_STANDARDS.md        # 10-criteria audit + phase audit
├── GLOSSARY.md                     # term definitions
├── LEARNINGS.md                    # diagnosis → fix → lesson loops
├── DEMO_RUNBOOK.md                 # Phase 6 — 10-min demo script
├── EXTRACT_PIPELINE.md             # Phase 1 walkthrough
├── DBT_PIPELINE.md                 # Phase 2 + 4 walkthrough
├── ORCHESTRATION_PIPELINE.md       # Phase 3 walkthrough
├── GOLD_MARTS_PIPELINE.md          # Phase 4 walkthrough (mart-specific)
├── POWERBI_PIPELINE.md             # Phase 5 walkthrough
├── scripts/
│   ├── extract_sec_edgar.py        # the polite extract
│   ├── forecast.py                 # Prophet / statsmodels forecast → Parquet
│   └── smoke_test_aws.py           # connectivity proof for AWS stack
├── sql/
│   ├── ddl/                        # Glue Catalog / Athena DDL if not crawler-driven
│   └── verify/                     # standalone verification queries
├── dbt/
│   ├── dbt_project.yml
│   ├── profiles.yml.example
│   ├── packages.yml
│   ├── .sqlfluff                   # athena dialect, dbt templater
│   ├── models/
│   │   ├── staging/                # 1:1 with Bronze tables
│   │   ├── intermediate/           # cleaning, canonical-concept mapping
│   │   ├── warehouse/              # Data Vault 2.0 hubs / links / satellites
│   │   └── marts/                  # 4 Gold marts
│   └── tests/
├── stepfunctions/
│   ├── state_machine.json
│   └── iam_policies/
├── pbi/
│   └── financial_analytics.pbix    # 5-page Import mode
├── .github/
│   └── workflows/
│       ├── lint-python.yml         # ruff F821
│       └── dbt-ci.yml              # dbt parse + sqlfluff
├── pyrightconfig.json
├── requirements.txt
├── .env.example                    # template for credentials (gitignored .env)
├── .gitignore
└── .gitkeep                        # only in genuinely-empty folders pre-first-commit
```

---

## 9. Phase breakdown

Numbered Phase 1 onward; Phase 0 is the planning phase closing now.

| Phase | Focus | Primary deliverables |
|---|---|---|
| **Phase 0** (closing 2026-05-23) | Planning + lock | PROJECT_PLAN.md, PROJECT_CONTEXT.md, LEARNING_ROADMAP.md updates, ENGINEERING_STANDARDS.md context note, LEARNINGS.md carry-forward, Phase 0 audit |
| **Phase 1** | Bronze landing | `scripts/extract_sec_edgar.py`, polite rate limiter, step-up testing (1 → 10 → 100 companies), S3 bucket + IAM, Glue Crawler bootstrap, Bronze verification suite, `EXTRACT_PIPELINE.md`. AWS account creation happens at this phase, not Phase 0. |
| **Phase 2 (CLOSED 2026-05-29)** | Silver — Data Vault 2.0 (Raw Vault + Business Vault) | **SHIPPED.** 12 dbt models: staging 1:1 with Bronze (2 models); intermediate XBRL canonical-concept normalisation (2 models); **Raw Vault** hand-rolled in plain dbt-athena SQL per Risk 1 — 3 hubs (hub_company / hub_filing / hub_concept) + 2 links (link_company_filing / link_filing_concept_period) + 4 sats (sat_filing_metadata / sat_company_metadata / sat_concept_value / sat_concept_canonical — the last being the project's first multi-active satellite); **Business Vault** Scalefree-canonical query-acceleration layer — 1 dim (dim_as_of_dates) + 1 PIT (pit_link_filing_concept_period, 634,431 rows) + 1 Bridge (bridge_company_concept_period, 634,431 rows). Both BV objects anchor on filed_date instead of canonical load_datetime per Risk 23 — project's load_datetime captures ingestion time not observation time. Final verification surface: **121/121 dbt schema tests + 114/114 SQL structural verify checks PASS** across 12 verify files (sql/verify/01-12). 11 sessions delivered (sessions 1-11) all-green, ENGINEERING_STANDARDS audit PASS on sessions 4 + 8-11 (5/6/7 missed, captured as carry-forward, four-session streak unbroken through session 11). 23 forward-projected Risks banked across the phase (Risks 1-23), rolled into 8 top-level training-journey pattern families at session 11 close. Per-session detail in PROJECT_CONTEXT.md session log. |
| **Phase 3 (sessions 12-13 SHIPPED 2026-05-29)** | Step Functions orchestration | **SHIPPED.** `stepfunctions/state_machine.json` (3-state Standard JSONPath ASL — RunDbtBuildOnGlue StartJobRun.sync → VerifyHubCompanyRowCount StartQueryExecution.sync sanity → VerifyStructuralSurface Parallel block fanning out across all 10 sql/verify/03-12 queries, session 13 extension), `stepfunctions/iam_policies/` (4 Customer Managed JSONs — Glue role trust + policy + Step Functions role trust + policy; Step Functions role policy patched session 13 to include Bronze Catalog read for view-resolution path), `scripts/run_dbt_in_glue.py` (Glue Python Shell entry point — boto3 S3 sync of dbt project + dbtRunner.invoke(["deps"]) + dbtRunner.invoke(["build", "--target", "glue"]) + exit-code-only success per Risk 25), `scripts/sync_phase3_artifacts_to_s3.py` (manual deploy helper), new `glue` target in dbt/profiles.yml (omits static AWS keys; pyathena uses boto3 default credential chain → Glue role), `requirements.txt` upper-bounded dbt-core<1.11 (Risk 30 — Glue Python Shell 3.9 ceiling), `ORCHESTRATION_PIPELINE.md` walkthrough, `DBT_PIPELINE.md` section 6.1 Phase 3 invocation-mode reference, `GLOSSARY.md` section 6 7 Phase 3 vocabulary entries. **dbt-runtime LOCKED as Glue Python Shell** at the Phase 3 kickoff forward-verify pass (session 11 close, 2026-05-29) — senior-DE default per Risk 3: 480-min timeout vs Lambda's 15-min cap (Risk 28), pyathena 2.5.3 pre-installed in analytics library set, no container build / no ECR, no VPC required, lowest IAM expansion, Free-Tier fit with ~8x margin. **Locked dep pins (Risk 30 cascade): dbt-core==1.9.10 + dbt-athena-community==1.9.5** — last 1.x series supporting Python 3.9; downgraded from 1.11/1.10 because dbt-core 1.11+ and dbt-athena-community 1.10+ require Python >=3.10. Risks 24-37 baked in at design time. **First orchestrated run session 12 via Step Functions: Succeeded in 4m 59s, dbt build PASS=157 / ERROR=0 / SKIP=0 / TOTAL=157, Athena verify task green, Risk 27 cold-start gate (5 min) passed by an order of magnitude (55s on first standalone Glue run). Second orchestrated run session 13 after Parallel fan-out + IAM patch: Succeeded in 6m 15s with all 10 Parallel verify branches TaskSucceeded — full Phase 2 cumulative 114-check structural verify surface preserved in the orchestrated path.** 10/10 ENGINEERING_STANDARDS audit PASS on scripts/run_dbt_in_glue.py (session 12) + stepfunctions/state_machine.json (session 13) — SIX-session unbroken streak (sessions 8/9/10/11/12/13). Session 14: Phase 3 CLOSE + Phase 4 kickoff forward-verify. |
| **Phase 4 (CLOSED 2026-05-30 at session 5)** | Gold marts + forecasting | **Sessions 1+2+3 SHIPPED.** Two Gold marts live in `financial_analytics_silver`. **Session 1:** `dbt/models/marts/mart_pl_trend.sql` — 10-year annual P&L trend per S&P 100 (revenue + net_income), JOIN topology bridge → PIT → sat → hub + sat_company_metadata, surrogate hash PK, Risk 42 ROW_NUMBER dedup for ASC 205 comparatives. Row count 19,393 → 19,336 after session 2 Risk 48 cascade. `sql/verify/13` 14/14 PASS. **Risk 39 Phase 5 pre-prerequisite shipped** at session 1 kickoff (Athena ODBC v2 driver + Windows System DSN + ~/.aws/credentials [phil-dbt] bootstrap). 6 new Risks banked session 1 (40-45). **Session 2:** `dbt/models/marts/mart_peer_benchmark.sql` — cross-company peer benchmarking at FY snapshots over S&P 100 (revenue + net_income + assets), 29,936 rows. Per-row peer aggregates (count / mean / median / stddev / min / max) + RANK + CUME_DIST percentile via window functions over (as_of_date, fiscal_year, canonical_concept) partition. Same 5-step BV+RV equi-join chain + 2 trailing peer-aggregation CTEs. 26 dbt schema tests + 17 SQL structural verify checks (`sql/verify/14`) PASS. **Risk 45 RESOLVED via 3-Risk cascade at session 2:** Risk 46 = preferred-tag seed pattern (`dbt/seeds/canonical_concept_tag_preference.csv` + sat_concept_value refactor — INNER JOIN to seed for preference_rank, ROW_NUMBER ORDER BY value DESC primary + preference_rank ASC tie-breaker); Risk 47 = v1→v2 ORDER BY flip after preference_rank ASC primary broke on ASC 606 transition (Apple FY2019 = $62.9B in v1); Risk 48 = mart-dedup intra-accession period-chunk filter at sat_resolved CTE (year(period_end_date) ∈ {fy, fy+1} + period span 350-380 days for IS canonicals only, balance-sheet canonicals exempt) addresses SEC XBRL anomaly where 11 unrelated periods within Apple's FY2019 10-K accession all tag fp=FY fy=2019. Mart-shape PBI smoke test PASSED at session 2 — Apple FY2019 = $260.174B analyst-correct (vs session 1 MIN-collapse $70B). 10/10 ENGINEERING_STANDARDS audit PASS sessions 1+2 — EIGHT-session unbroken streak (sessions 8/9/10/11/12/13/15/16; session 14 was phase-boundary, no code shipped). GOLD_MARTS_PIPELINE.md extended (sections 8 + 9 + 10) + DBT_PIPELINE.md section 9.3 mart_peer_benchmark + Risk 45/47/48 cascade narrative. **Session 3:** `dbt/models/marts/mart_financial_health.sql` — per-company annual ratios spanning income statement + balance sheet + cash flow, composite grain (cik, as_of_date, fiscal_year), 9 canonicals pivoted onto columns via MAX(CASE WHEN canonical=X THEN value END) + 8 NULLIF-guarded derived ratios (gross_margin, operating_margin, net_margin, return_on_assets, return_on_equity, debt_to_equity, operating_cf_margin, cash_to_assets). 10,610 rows. 17 dbt schema tests + 17 SQL structural verify checks (`sql/verify/15`) PASS. **Canonical seed expansion 8 → 13 raw us-gaap tags** drives the IS depth + BS cash + CF operating coverage; six hardcoded Jinja `{% set concepts %}` lists extended in lock-step across intermediate + 5 warehouse models. **New seed `dbt/seeds/sp100_company_sector.csv`** — 107 rows, GICS 11-sector taxonomy, CIKs sourced authoritatively from SEC EDGAR `company_tickers.json`. **mart_peer_benchmark sector cascade (Option A bundle):** partition key extended from 3-key to 4-key (+gics_sector); new sector_resolved CTE LEFT JOINs the seed with COALESCE('UNCATEGORIZED') for unmatched; row cardinality preserved at 29,936 (per-cik 1:1 sector); partition count went from 405 to 4,055. **Risk 49 banked** — Salesforce (cik 0001108524) FY2010-2013 gross_profit > revenue artifact (0.12% of mart_financial_health rows) from pre-ASC-606 revenue tagging mismatch; verify check 15 documents + excludes the known (cik, fy) window. Mart-shape PBI smoke test PASSED at session 3 — Apple net_margin 2015-2025 trajectory analyst-correct (FY2023 25.3% matches Apple reported). 10/10 ENGINEERING_STANDARDS audit PASS — NINTH consecutive code-shipping session unbroken (sessions 8/9/10/11/12/13/15/16/17). GOLD_MARTS_PIPELINE.md extended (new sections 9 + 10 + 11 references renumbered) + DBT_PIPELINE.md section 9.5 added. Cumulative marts surface at session 3 close: 63 dbt schema tests + 48 SQL structural verify checks across 3 active marts; cascade rebuild PASS=231 / WARN=0 / ERROR=0. **Session 4:** `dbt/models/marts/mart_growth_forecast.sql` — per-company annual revenue trajectory unifying historical observed values (from mart_pl_trend) and forward-looking 3-year forecasts (from `scripts/forecast.py`). UNION-shaped composite grain (cik, canonical_concept, fiscal_year, as_of_date, row_kind), 10,069 rows = 9,775 historical + 294 forecast (98 companies × 3 forecast years; 1 single-observation entrant skipped). **`scripts/forecast.py` SHIPPED** — boto3 Athena → pandas → statsmodels.tsa Holt-Winters Exponential Smoothing (additive trend) primary + ARIMA(1,1,0) drift-walk fallback for short / non-trended series + 95% prediction intervals + pyarrow Parquet write to S3. **Forecast architecture Option A** (Parquet to S3 + dbt sources) chosen at session 4 kickoff direction-check — clean compute/consumption separation. **Forecast Parquet at `zone=silver/forecasts/`** — matches the project's zone= S3 layout convention AND inherits phil-dbt's existing S3SilverReadWrite IAM scope. **Triple-pinned forecast schema** across `scripts/forecast.py` FORECAST_SCHEMA + `sql/ddl/03` column list + `dbt/models/marts/_sources.yml` columns block. **Risks 50 + 51 banked** — 50 = zone=silver/ S3 prefix + IAM scope forward-projection; 51 = forecast schema triple-pin coordinated-drift contract. 21 dbt schema tests + 18 SQL structural verify checks (`sql/verify/16`) PASS. Mart-shape PBI smoke test PASSED — Apple revenue FY2009 ~$42B → FY2024 ~$391B + forecast 2026-2028 with 95% CI band; MAX aggregation chosen over SUM (historical leg has 10 identical as_of_date snapshots — SUM over-counts 10x). 10/10 ENGINEERING_STANDARDS audit PASS — TENTH consecutive code-shipping session (8/9/10/11/12/13/15/16/17/18 unbroken). GOLD_MARTS_PIPELINE.md extended (new section 10 with 6 subsections) + DBT_PIPELINE.md section 9.6. Cumulative marts surface at session 4 close: 84 dbt schema tests + 66 SQL structural verify checks across 4 active marts; cascade rebuild PASS=161 / WARN=0 / ERROR=0. **Session 5 (Phase 4 CLOSED):** Phase-boundary structural audit 6/6 PASS (stale `dbt/models/marts/.gitkeep` cleaned up). Step Functions Parallel state extended from 10 to 14 branches fanning out across all `sql/verify/03-16` queries (10 warehouse + business_vault + 4 marts — `VerifyMartPlTrend`, `VerifyMartPeerBenchmark`, `VerifyMartFinancialHealth`, `VerifyMartGrowthForecast`); IAM scope sanity check confirmed existing `GlueCatalogReadForAthenaVerify` wildcard already covers all 4 marts + `forecast_surface` external table (no IAM patch needed). **`scripts/deploy_state_machine.py` shipped** as companion to `sync_phase3_artifacts_to_s3.py` for the state machine definition deploy path (boto3 `stepfunctions.update_state_machine`, phil-admin creds from `.env`). End-to-end orchestrated run (execution name `phase-4-close-orchestrated-smoke-test-01-2026-05-30`) **Succeeded in 8 min 8 sec** — Glue dbt build PASS + Athena hub_company sanity + 14-branch Parallel verify all TaskSucceeded. **Forecast orchestration locked Option A** at kickoff direction-check — `scripts/forecast.py` stays manual (annual cadence, on demand), NOT wired into the DAG; production-shape forecast orchestration deferred to Phase 6 stretch concern. 14 Phase 4 Risks (38-51) **rolled into 4 pattern families (G-J)** in LEARNINGS.md — Family G forecasting library + observation-cadence cross-check; Family H BI-tool prerequisite + local-machine stack; Family I source-domain dedup + collapse architectural location; Family J compute-output surface + IAM zone convention + multi-artefact schema agreement. **Phase 5 PBI kickoff forward-verify shipped 3 new Risks (52-54)** BEFORE any Phase 5 work begins — Risk 52 Athena marts full-rebuild Iceberg avoids V2 position-delete merge-on-read complexity at PBI consumption; Risk 53 pure Import storage mode is the right default at <100K row total mart scale; Risk 54 PBI Desktop known issue 321 Performance Analyzer + Pause Visuals interaction. GOLD_MARTS_PIPELINE section 11 + ORCHESTRATION_PIPELINE section 3.5 + README Status line + PROJECT_CONTEXT status table + this PROJECT_PLAN Phase 4 row all refreshed. 10/10 ENGINEERING_STANDARDS audit streak preserved (sessions 1-4 unbroken, session 5 is phase-boundary with no new code surface). |
| **Phase 5** | Power BI | **Phase 5 pre-prerequisite (must land before session 1 PBI work): install Amazon Athena ODBC v2 driver + configure System DSN on Phil's Windows machine + smoke-test first Athena connection from PBI Desktop per Risk 39** — ~15-30 min Windows admin step, not part of any PBI build session. Then: 5-page `.pbix` (executive overview + 4 themed pages), `_Measures` table, explicit DAX measures, continuous publish to git, theme picked early, `POWERBI_PIPELINE.md`. |
| **Phase 6** | CI/CD + ship | GitHub Actions (ruff F821, dbt parse, sqlfluff), `README.md` polish + architecture diagram + screen recording, `DEMO_RUNBOOK.md`, `.pbix` freeze, v1.0 tag |

Each phase ends with a phase-boundary structural audit per ENGINEERING_STANDARDS.md and a Notes/changes update + bundled commit per TEACHING_PREFERENCES.md.

---

## 10. Demo-durability principles applied

The six principles from LEARNING_ROADMAP.md, restated with Project #3-specific
mechanics:

1. **Bronze = snapshot, not stream.** SEC EDGAR extract runs ONCE during build,
   raw JSON frozen on S3. Post-build the API is not in the live demo path. Bronze
   is append-only by extract-date partition, so a future opt-in refresh is
   possible without overwriting history.
2. **DAG runs on-demand, not on a schedule.** Step Functions state machine has
   no EventBridge cron rule. Demos show the state machine UI + past
   execution history; live triggers are optional.
3. **Power BI in Import mode at publication.** `.pbix` is fully self-contained
   at v1.0 freeze. Opens years later with no live AWS connection required.
4. **AWS cost model preserves $0 idle.** AWS Free Plan covers the build for 6
   months from account creation OR $200 in promotional credits (whichever
   exhausts first; account `470439680370` cliff is 23 Nov 2026). Post-cliff
   pay-as-you-go pricing: S3 ~$0.023/GB/month for ~100-300 MB of compressed
   Parquet (~$0.01/month at our scale); Athena pay-per-query at pennies per
   demo; Glue Data Catalog free up to 1M objects; Step Functions ~$25 per 1M
   state transitions; no always-on RDS. Per-demo cost ~$0.05; idle cost
   effectively $0 even on pay-as-you-go.
5. **GitHub repo = canonical artifact.** Public repo with README, architecture
   diagram, screen recording, `.pbix`, `DEMO_RUNBOOK.md`. Even if AWS account
   expires, the repo proves the build.
6. **Demo-day runbook from day 1.** `DEMO_RUNBOOK.md` authored DURING build,
   refined per phase, captures the 10-minute interview-demo script.

---

## 11. Data budget

- **Bronze cap: 2,000,000 rows.** Expected ~800K rows (100 companies × ~40
  quarterly filings × ~200 XBRL line items over 10 years). ~40% headroom.
- **Gold cap: 500,000 rows.** Expected substantially smaller — pre-aggregated marts.
- **S3 storage:** estimated 100-300 MB compressed Parquet for the full lake.
  ~5% of the 5GB free-tier S3 cap.
- **Network egress:** SEC EDGAR is free / no rate cost; S3 egress is free
  for AWS-internal queries; Athena scan cost is the only meaningful per-query
  charge (~$0.02 per typical demo session).

---

## 12. Engineering standards

Cross-reference: ENGINEERING_STANDARDS.md. The 10-criteria per-script audit
and phase-boundary structural audit apply unchanged to Project #3 — both are
platform-agnostic.

**Project #3 right-sizing / scale-up checks (counterpart to Project #2's
Snowflake XS→XL warehouse decision pain — bookmarked at task #9):**

- **Athena workgroup query limits.** Set bytes-scanned-per-query caps on the
  workgroup to prevent runaway scans. Cheap insurance against accidental
  full-table-scan queries during dev.
- **Glue ETL DPU sizing.** Glue ETL is NOT in Project #3's stack (Glue ETL
  Spark deferred to mini-project slot 5). N/A here, flagged for completeness.
- **RDS instance class.** RDS not in Project #3's stack. N/A.
- **Polite rate limiter validation.** The SEC EDGAR extract MUST validate
  its rate limiter on a single-company test BEFORE scaling to 100 companies.
  Step-up testing (1 → 10 → 100) per criterion 9 of ENGINEERING_STANDARDS.md.
  Exponential backoff + retry from day 1, not retrofitted.

---

## 13. Standing conventions (carry-forward from TEACHING_PREFERENCES.md)

- **AI-assistance disclosure on every README** — paste-able template lives in
  TEACHING_PREFERENCES.md; applied to all 8 portfolio repos (3 main + 5 mini).
- **In-session debugging discipline** — Phil engages with the diagnosis,
  doesn't just accept the fix; non-trivial bugs banked in LEARNINGS.md under
  the Project #2 "Mistakes & diagnoses" pattern.
- **Three-layer documentation for code-shaped files** — verbose-in-chat,
  clean-on-disk, walkthrough-doc-alongside (`*_PIPELINE.md`).
- **Power BI architectural discipline** — `_Measures` table, measures aggregate
  the fact not the mart, dual storage for dims joined to DirectQuery facts,
  Pause Visuals check first, save+close+reopen before deep-diving cyclic
  references. Full list in TEACHING_PREFERENCES.md.
- **PBI mart-shape smoke test EARLY** — at the dbt session that first creates
  each Gold mart, drag 1-2 fields into 1-2 PBI visuals and confirm correct
  slicing across required dims. Carry-forward from Project #2's expensive
  late-Phase-5 mart-shape diagnosis.
- **Commit cadence** — one bundled commit per session at session close.
- **Senior-DE professional defaults** when picking between options; learning
  depth lives in conversation, not in production code.

---

## 14. Open questions / known TBDs at Phase 0 close

- **AWS account creation.** Deferred to Phase 1 first session (Phil has no
  existing AWS account; 12-month Free Tier clock starts at creation, so timing
  with actual build start is optimal).
- **GitHub repo creation.** Deferred to Phase 1 first commit.
- **Python forecasting library choice (Prophet vs statsmodels).** Deferred
  to Phase 4 when the mart_growth_forecast model is being built — Prophet
  leans easy-to-pretty-output but heavier dependency footprint; statsmodels
  leans lighter but more code per forecast.
- **dbt-athena Iceberg vs Parquet for materialised tables.** Deferred to
  Phase 2 dbt scaffolding session — Iceberg gives time-travel + schema
  evolution (genuine lakehouse features); Parquet is simpler.
- **Lake Formation governance layer.** Deferred to Phase 6 stretch. Default
  off for portfolio scope.

---

## 15. Cross-doc references

- **LEARNING_ROADMAP.md** — broader pathway context, all decision deliberation history.
- **PROJECT_CONTEXT.md** — current state, session log, what's locked / open right now.
- **ENGINEERING_STANDARDS.md** — 10-criteria audit + phase-boundary audit.
- **TEACHING_PREFERENCES.md** — standing working conventions including AI-disclosure template and in-session debugging discipline.
- **LEARNINGS.md** — Project #2 diagnosis / fix / lesson loops + (newly populated) carry-forward to Project #3 subsection.
- **GLOSSARY.md** — term definitions; cross-reference any unfamiliar term from this file there.

---

*Last updated: 2026-05-28 (Phase 2 session 3 close-amend — section 7 updated with hand-rolled DV2.0 approach after AutomateDV/Athena verify; section 9 Phase 2 entry annotated with Iceberg-merge-incremental gotcha; Phase 3 entry annotated with dbt-runtime decision required at kickoff). Prior milestone: 2026-05-23 (Phase 0 closeout — initial authoring). Updated as each phase closes; the file IS the single-page source of truth for "what we're building." Deliberation history of changes lives in LEARNING_ROADMAP.md "Notes / changes" section, not here.*

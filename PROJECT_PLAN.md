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
  mapping. **Scheduled session 9** (2026-05-28 lock per "ship the most
  professional version a senior DE would land in production" rule). Multi-active
  satellite pattern on hub_concept — new DV2.0 mechanic, defends the MIN(value)
  information-loss decision baked into sat_concept_value by preserving
  raw-tag provenance for regulatory-defensible audit lineage.

**Business Vault objects** (Scalefree-canonical layer between raw vault and
information marts). **Scheduled session 10** (2026-05-28 lock per the same
rule):

- PIT (Point-in-Time) tables — pre-compute per-as-of-date snapshots joining a
  parent hub to its current satellites.
- Bridge tables — pre-compute hub-link-hub join graphs at a point in time.

Both demonstrate full DV2.0 fluency beyond the Raw Vault and materially
accelerate Phase 4 mart queries by collapsing multi-join walks to straight
SELECTs against the Business Vault.

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
| **Phase 2** | Silver — Data Vault 2.0 (Raw Vault + Business Vault) | `dbt/` scaffolding (`dbt_project.yml`, `profiles.yml.example`, `packages.yml`, sources), staging models 1:1 with Bronze, intermediate models doing XBRL canonical-concept normalisation, **Raw Vault** models for hubs / links / satellites (HAND-ROLLED in plain dbt-athena SQL — AutomateDV does not support Athena per the 2026-05-28 forward-verify pass), **Business Vault** PIT + Bridge tables (Scalefree-canonical query-acceleration + audit-snapshot layer between Raw Vault and Phase 4 marts), schema tests, `DBT_PIPELINE.md` (Silver section). Scope locked at 11 sessions (2026-05-28): sessions 1-3 scaffolding + staging + intermediate; sessions 4-8 Raw Vault hubs/links/sats already shipped (5 hubs + 2 links + 3 sats); session 9 sat_concept_canonical (multi-active sat for raw-tag audit lineage); session 10 Business Vault PIT + Bridge; session 11 Phase 2 close (boundary audit + Phase 3 forward-verify + dbt-runtime decision). **Known gotcha for satellites** (banked 2026-05-28): Iceberg merge incremental strategy + on_schema_change setting has a duplicate-insertion bug (dbt-adapters issue #571); satellite models must avoid on_schema_change and carefully control unique_key composition (hub_hashkey + load_datetime), with parity-count verification after every satellite refresh. |
| **Phase 3** | Step Functions orchestration | `stepfunctions/state_machine.json`, IAM execution role, on-demand trigger (no schedule per demo-durability principle 2), `ORCHESTRATION_PIPELINE.md`. **First session = forward-verify pass + dbt-runtime decision** (added 2026-05-28): Step Functions has no native dbt integration; dbt-athena must be invoked from Step Functions via one of three runtimes — Glue Python Shell (preferred, lowest IAM expansion), Lambda Container Image (fallback if Glue has dbt-specific issues), or ECS Fargate (cleanest container model, highest deployment overhead). Decision locks at Phase 3 kickoff. Step Functions otherwise integrates natively with Athena (StartQueryExecution / GetQueryExecution) for direct Athena query orchestration. |
| **Phase 4** | Gold marts + forecasting | 4 mart models in dbt, `scripts/forecast.py` producing Parquet for `mart_growth_forecast`, mart-shape smoke test against Power BI for EACH mart at creation time (Project #2 carry-forward), `GOLD_MARTS_PIPELINE.md`, `DBT_PIPELINE.md` (Gold section) |
| **Phase 5** | Power BI | 5-page `.pbix` (executive overview + 4 themed pages), `_Measures` table, explicit DAX measures, continuous publish to git, theme picked early, `POWERBI_PIPELINE.md` |
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

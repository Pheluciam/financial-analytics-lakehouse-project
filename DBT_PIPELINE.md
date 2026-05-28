# dbt Pipeline — Silver Data Vault 2.0 via dbt-athena

> Walkthrough for the Phase 2+ dbt-athena pipeline. Companion to the
> `dbt/` directory contents and the Phase 1 walkthrough in
> `EXTRACT_PIPELINE.md`.
>
> Status: STUB. Authored 2026-05-25 (Phase 2 session 1).
> Sections 1-6 shipped session 1 (scaffolding + first staging model).
> Sections 7+ expand as intermediate / warehouse / Data Vault 2.0 models
> land in later Phase 2 sessions. Phase 4 Gold marts get their own
> walkthrough (GOLD_MARTS_PIPELINE.md).

---

## 1. What this pipeline does

The dbt pipeline transforms raw SEC EDGAR JSON in the Bronze layer into
modeled, query-ready Silver Data Vault 2.0 tables, then onward into Gold
information marts for Power BI consumption. dbt-athena is the adapter;
all SQL compiles to Athena dialect and runs against the Glue Catalog.

Layer responsibilities at a glance:

- **Staging** (`dbt/models/staging/`) — pass-through, rename, retype.
  No heavy transformation. One model per Bronze source table.
- **Intermediate** (`dbt/models/intermediate/`) — XBRL canonical-concept
  reconciliation (Revenues / SalesRevenueNet / Revenue → canonical
  revenue), JSON extraction, cleaning. Lives between staging and the
  warehouse vault.
- **Warehouse** (`dbt/models/warehouse/`) — Data Vault 2.0 raw vault:
  hubs (business keys), links (relationships), satellites (descriptive
  attributes with full SCD-2 history).
- **Marts** (`dbt/models/marts/`) — denormalised information marts, one
  per Power BI dashboard theme. Phase 4 scope.

## 2. Architecture

```
[ Glue Catalog: financial_analytics_bronze ]   <-- Phase 1 deliverable
        |
        |  dbt-athena: SELECT statements compile to Athena SQL,
        |  Iceberg/Parquet table data written to S3 zone=silver/
        v
[ Glue Catalog: financial_analytics_silver ]
   - staging      <-- session 1 scope (this stub)
   - intermediate <-- Phase 2 session 2+
   - warehouse    <-- Phase 2 session 3+ (DV2.0 hubs/links/sats)
        |
        |  dbt-athena marts/ models
        v
[ Glue Catalog: financial_analytics_gold ]     <-- Phase 4 scope
   - mart_pl_trend
   - mart_peer_benchmark
   - mart_financial_health
   - mart_growth_forecast
```

## 3. Session 1 deliverables — what landed in this session

Scope: dbt-athena scaffolding + first staging model. End-to-end pipeline
proven (Bronze source → staging view → Glue Catalog → Athena query).

- **dbt-athena adapter installed** — `dbt-athena-community>=1.10.1` added
  to `requirements.txt`. Pulls dbt-core 1.11.11, dbt-adapters, pyathena.
- **Dedicated `phil-dbt` IAM user provisioned** — Customer Managed Policy
  `lakehouse-dbt-runtime-access` (JSON in `iam/lakehouse_dbt_runtime_policy.json`).
  Scoped to: Athena workgroup execute on `wg_financial_analytics`, Glue
  Catalog R/W on `financial_analytics_bronze` + `financial_analytics_silver`,
  S3 R on `zone=bronze/`, S3 R/W on `zone=silver/` and `athena-results/`.
  Programmatic access keys in `.env` as `AWS_DBT_ACCESS_KEY_ID` /
  `AWS_DBT_SECRET_ACCESS_KEY`. Separate from `phil-admin` (Phase 1 scripts).
- **dbt project scaffold** — `dbt/dbt_project.yml`, `dbt/profiles.yml.example`,
  `dbt/packages.yml` (dbt_utils 1.x), `dbt/models/staging/_sources.yml`.
  Folder layout: staging / intermediate / warehouse / marts (intermediate /
  warehouse / marts hold `.gitkeep` until their first model lands).
- **First staging model** — `dbt/models/staging/stg_sec_edgar__companyfacts.sql`.
  Materialized as view. Three columns: cik (string), extract_date (DATE,
  cast from partition-projection string), entity_name (renamed from
  openx-mapped `entityname`).
- **IDE/runtime delta handling** — `.vscode/settings.json` overrides
  SchemaStore's dbt-core-only schema for `dbt_project.yml` with a local
  permissive schema (`.vscode/dbt_project.permissive.schema.json`).
  Documented intentional bypass per ENGINEERING_STANDARDS criterion 6.
- **dbt-core 1.11 false-positive deprecation silenced** —
  `CustomKeyInConfigDeprecation` + `DeprecationsSummary` added to
  `flags.warn_error_options.silence` in `dbt_project.yml`. Linked to
  dbt-labs/dbt-core issues #12314, #12342, #12355, #12087.
- **Glue database `financial_analytics_silver` created** alongside
  `financial_analytics_bronze` (Phase 1).

## 4. IAM identity separation

Two AWS identities in this project, by design:

- **`phil-admin`** — human operator. AdministratorAccess. Used at the
  console for setup work and by Phase 1 Python scripts
  (`extract_sec_edgar.py`, `verify_bronze_s3_metadata.py`,
  `smoke_test_aws.py`) via `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`.
- **`phil-dbt`** — automation identity. Customer Managed Policy
  `lakehouse-dbt-runtime-access`. Used exclusively by `dbt-athena` via
  `dbt/profiles.yml` env_var lookups against `AWS_DBT_ACCESS_KEY_ID` /
  `AWS_DBT_SECRET_ACCESS_KEY`.

Least-privilege guardrail: if `phil-dbt`'s keys leak, the blast radius
is limited to Glue Catalog + Athena + S3 silver+results. The user cannot
create new IAM users, delete the S3 bucket, or touch billing.

Architectural enforcement: phil-dbt has NO write permission on
`zone=bronze/`. A buggy dbt model literally cannot clobber raw Bronze
data. The IAM boundary is the hard guardrail for "Bronze is immutable".

## 5. profiles.yml + .env contract

dbt does NOT auto-load `.env` files (dbt-labs/dbt-core issue #8026
remains open). Standing convention for this project:

- `dbt/profiles.yml.example` is committed (template); `dbt/profiles.yml`
  is gitignored. Phil copies the example to the real file at first setup.
- Every dbt invocation is wrapped with `dotenv` (from `python-dotenv[cli]`)
  to inject `.env` vars into the command's environment:

  ```powershell
  dotenv -f ..\.env run -- dbt <command>
  ```

  Run from the `dbt/` subdirectory; `-f ..\.env` points at the project-root
  `.env` because dotenv defaults to looking in the current directory.

## 6. Running the pipeline

Pre-flight (one-time setup):

1. Copy `dbt/profiles.yml.example` to `dbt/profiles.yml` (no edits needed).
2. Install dbt deps: `dotenv -f ..\.env run -- dbt deps`.

Per-run commands (from `dbt/` with `.venv` active):

```powershell
dotenv -f ..\.env run -- dbt parse    # compile-time validation only
dotenv -f ..\.env run -- dbt run      # builds models in Athena
dotenv -f ..\.env run -- dbt test     # runs schema + data tests (no tests yet)
```

## 7. Intermediate layer (Phase 2 session 2 onwards)

The intermediate layer performs JSON extraction and concept-shaping over the
Bronze layer's heterogeneous SEC EDGAR JSON. Phase 2 session 2 (2026-05-27)
shipped the first intermediate model, `int_sec_edgar__concepts`, after
locking the raw-JSON-read pattern via web-search-verify against authoritative
docs.

### 7.1 The raw-JSON-read design call

Phase 1 closed with Bronze deliberately exposing only typed cover-page
columns (`entityname`, `cik`, `extract_date`) via the openx JSON SerDe.
The full `facts` object was excluded because Glue Crawler's struct-inference
exceeded Glue Catalog's 131,072-character column type-string limit on
NVIDIA's filing (LEARNINGS entry — Phase 1 session 3). Phase 2 needs to
reach inside `facts.us-gaap` to pull XBRL concepts like Revenues,
NetIncomeLoss, Assets — none of which the existing Bronze table can see.

Three options were evaluated at session 2 kickoff:

**Option A.** Extend the existing Bronze DDL with a `facts` column typed as
STRING, hoping the openx SerDe would serialize the nested object back to
JSON text. Verified against `docs.aws.amazon.com/athena/latest/ug/openx-json-serde.html`:
the only documented nested-JSON handling pattern in openx is struct typing
— which is exactly what blew the 128 KB ceiling on NVIDIA in Phase 1. No
documented "slurp the nested object into a STRING column" behavior exists.
The same unverified claim was banked in Phase 1 session 3 LEARNINGS; today's
verification confirms it remains unsupported. Dead end.

**Option B.** Build a SECOND Athena table over the same S3 files, but with
a text-based SerDe (LazySimpleSerDe) and a single STRING column holding
each file's full content. Then run `json_extract_*` against that column.
Uses only documented Athena features. The Phase 1-verified Bronze table
stays untouched. Selected.

**Option C.** Wrap the DDL via `dbt-external-tables` + the experimental
`dbt-athena-external-tables` package. The Athena-specific package reads
"PROOF OF CONCEPT — USE AT OWN RISK" in its README header, has 4 GitHub
stars / one v0.0.1 release / dormant since August 2024. Adds a fragile
dependency for the same outcome Option B achieves in 20 lines of hand-written
SQL. Rejected on portfolio-polish grounds.

### 7.2 The second Bronze table (raw-text view over the same files)

The new table `financial_analytics_bronze.sec_edgar_companyfacts_raw` is
defined in `sql/ddl/02_create_bronze_raw_text_table.sql`. It points at the
same S3 LOCATION as the existing Bronze table (`s3://phil-financial-analytics-lakehouse/zone=bronze/`)
and uses the same partition projection scheme, so the two tables share
identical partition surfaces. Three things make it work:

- **LazySimpleSerDe via `ROW FORMAT DELIMITED`**. The default text SerDe
  in Athena. Each line of input becomes one row; with only one column
  declared, the whole line goes into that column. No JSON parsing happens
  at SerDe time — the column is pure bytes-as-text.
- **`FIELDS TERMINATED BY '\001'`**. The SOH control byte (ASCII 0x01)
  cannot appear unescaped in well-formed JSON string values (the JSON spec
  requires control bytes to be `\u`-escaped). So no SEC EDGAR JSON file
  can ever contain a literal SOH byte, guaranteeing the SerDe never
  accidentally splits one file's content across multiple columns. `\001`
  is also Athena's CTAS default field delimiter — idiomatic.
- **Single-line minified JSON assumption**. The SEC EDGAR `data.sec.gov`
  API returns minified JSON (no embedded newlines). Each file maps to
  exactly one row. Verified empirically: the existing openx SerDe requires
  single-line JSON or fails on parse, and Phase 1's verification suite
  successfully read all 100 files via openx — so single-line is proven
  by observation. Day-of verification: `SELECT length(json_text) FROM
  sec_edgar_companyfacts_raw WHERE cik = '0000320193'` returned 3,748,682
  bytes for Apple — full file as one row, no truncation.

### 7.3 Staging layer fanout

Phase 2 session 1 shipped `stg_sec_edgar__companyfacts` over the typed
Bronze table. Phase 2 session 2 adds a companion `stg_sec_edgar__companyfacts_raw`
over the new raw-text Bronze table. Both staging models are 1:1 pass-throughs
of their source (rename + retype only) materialized as views. They expose
the same partition keys (`cik`, `extract_date`), so downstream models can
join on those keys with no partition skew.

### 7.4 First intermediate model — `int_sec_edgar__concepts`

The first intermediate model reads from `stg_sec_edgar__companyfacts_raw`
and produces a long-format XBRL concept panel — one row per
(cik, concept_name, period) triple. Scope this session: 5 universally-reported
concepts across the S&P 100 (Revenues, NetIncomeLoss, Assets, Liabilities,
StockholdersEquity), USD unit only.

The model uses three composed patterns:

- **Jinja for-loop over a concept list.** A compile-time loop emits one
  `SELECT ... CROSS JOIN UNNEST(...)` block per concept, joined with
  `UNION ALL`. Adding a 6th concept is one line in the `concepts` array.
- **`json_extract` with bracket-and-double-quote JSONPath**.
  `'$.facts["us-gaap"].Revenues.units.USD'`. The bracket-quote form is
  required because `us-gaap` contains a hyphen (dot notation would fail);
  verified against the Trino JSON functions docs (`json_extract` examples
  at `trino.io/docs/current/functions/json.html`).
- **`CROSS JOIN UNNEST(CAST(... AS ARRAY(JSON)))`** to flatten the per-concept
  array of period entries into one row per entry. `TRY_CAST` on the value
  field defends against malformed numerics in the source JSON. Companies
  that don't report a given concept naturally contribute zero rows (UNNEST
  of NULL returns no rows per Athena docs).

### 7.5 Session 2 limitations — both addressed in session 3

Two limitations surfaced at session 2 first-run verification. Both shipped
as session 3 deliverables.

- **Concept aliasing collapsed via seed-driven canonical reconciliation.**
  Apple's bare `Revenues` query returned rows only for FY2016-FY2018
  because Apple switched to `RevenueFromContractWithCustomerExcludingAssessedTax`
  on ASC 606 adoption in FY2019. Session 3's `int_sec_edgar__concepts_canonical`
  model + `canonical_concepts_dictionary` seed bridge the discontinuity —
  see section 7.7 below.
- **`period_start_date` extracted from `$.start`.** Session 3 extended
  `int_sec_edgar__concepts` to pull the new column. Populated for
  income-statement and cash-flow concepts; NULL for balance-sheet
  point-in-time concepts (Assets, Liabilities, StockholdersEquity)
  because SEC EDGAR omits `start` for instant-period facts. Verified
  by check 11 in `sql/verify/02`.

### 7.6 Verification surface for the intermediate layer

Phase 2 sessions 2-3 close: 11/11 PASS on the SQL verification suite +
19/19 PASS on dbt schema tests + 4/4 PASS on dbt run. Highlight checks:

- Apple FY2016-FY2018 annual revenues (bare `Revenues` tag era):
  $265.595B / $229.234B / $215.639B — match SEC records exactly.
- Apple FY2019-FY2021 annual revenues under canonical `revenue`
  (ASC 606 `RevenueFromContractWithCustomerExcludingAssessedTax` era):
  $260.174B / $274.515B / $365.817B — match published 10-K filings exactly.
  Proves the seed-driven alias collapse bridges the FY18→FY19 discontinuity.
- Apple canonical revenue has ≥6 distinct fiscal years of continuous
  coverage (pre-canonical: 3 years under bare `Revenues`).
- `period_start_date` populated on at least one canonical revenue row
  (proves the new column extraction).

### 7.7 Canonical-concept reconciliation (Phase 2 session 3)

The session 3 architectural addition is a seed-driven canonical-concept
dictionary, joined into a second intermediate model that produces the
final canonical panel downstream consumers (warehouse-layer satellites,
Gold marts) read from.

**The seed.** `dbt/seeds/canonical_concepts_dictionary.csv` holds 8 rows
mapping XBRL US-GAAP tag names to project-canonical concept names plus
financial-statement classification:

| concept_name | canonical_concept | business_area |
|---|---|---|
| Revenues | revenue | income_statement |
| SalesRevenueNet | revenue | income_statement |
| RevenueFromContractWithCustomerExcludingAssessedTax | revenue | income_statement |
| RevenueFromContractWithCustomerIncludingAssessedTax | revenue | income_statement |
| NetIncomeLoss | net_income | income_statement |
| Assets | assets | balance_sheet |
| Liabilities | liabilities | balance_sheet |
| StockholdersEquity | stockholders_equity | balance_sheet |

The four revenue aliases collapse to one canonical name (`revenue`); the
other four concepts are identity mappings. Authoritative source for the
revenue alias set: XBRL US Data Quality Committee Revenue Guidance and
FASB Taxonomy Implementation Guide "Revenue from Contracts with Customers".
Future extensions = add a row.

**The model.** `dbt/models/intermediate/int_sec_edgar__concepts_canonical.sql`
INNER JOINs `int_sec_edgar__concepts` to the seed on `concept_name`,
adds `canonical_concept` and `business_area` columns. INNER JOIN by
design — any raw concept_name not in the dictionary is excluded, which
is the contract that guarantees every downstream row carries a curated
canonical name. New concepts extend by adding both a seed row AND the
tag to the upstream model's Jinja concept list; the two ends move together.

**Pattern reusability.** The seed-as-dictionary pattern carries forward
to the Phase 2 session 3+ warehouse layer: hub_concept's business key
will be `canonical_concept` (a curated stable name), and the alias-to-canonical
join lineage is auditable through the seed file in git history.

### 7.8 Materialization architecture — intermediate as Iceberg, Bronze cik as enum

Two architectural changes landed in session 3 in response to a dbt-test
failure that surfaced a deeper partition-projection constraint.

**Intermediate layer: views → Iceberg tables.** The session-2 intermediate
models materialized as views — cheap, no S3 writes. dbt schema tests
attempted to scan those views, which cascade-compiled to SELECT queries
against Bronze raw-text JSON. Bronze's cik partition projection was
`type=injected` (chosen Phase 1 session 3 for flexibility), which requires
every query to include a static `cik = '<value>'` predicate. Schema-test
queries don't include one — so 8 tests errored with `CONSTRAINT_VIOLATION`.

Initial diagnosis pointed at materialization: flipping the intermediate
layer to `+materialized: table` + `+table_type: iceberg` + `+format: parquet`
means schema tests scan the materialized Iceberg tables, never reach
Bronze. This aligned with the locked Phase 2 Silver-as-Iceberg architecture.

Implementation note: removed an initial `+table_properties.format_version: "2"`
setting after Athena rejected it with `InvalidRequestException: Table
properties [format_version] are not supported`. AWS Athena's own docs
enumerate a closed allowlist for Iceberg table properties (`format`,
`write_compression`, `optimize_rewrite_*`, `vacuum_*`); `format_version`
is not in the list. Athena defaults to Iceberg v2 anyway. The dbt-athena
adapter docs recommended this property — they're stale relative to the
underlying engine's current behavior. Banked: always verify against the
engine's own docs (`docs.aws.amazon.com/athena`) for stakes-sensitive
syntax, not just the adapter's documentation.

**Bronze: cik projection switched from type=injected to type=enum.** The
intermediate materialization itself runs CTAS over Bronze, hitting the
same type=injected constraint as the schema tests. Switched both Bronze
table DDLs (`sql/ddl/01_create_bronze_tables.sql` and
`sql/ddl/02_create_bronze_raw_text_table.sql`) to `'projection.cik.type'
= 'enum'` with the 100 S&P 100 CIKs enumerated in `'projection.cik.values'`.
Verified per AWS docs that enum projection has no hard cap on value count
— the constraint is total Glue Catalog metadata size (~1 MB gzip-compressed),
which 100 CIKs at ~11 chars each fit comfortably under.

DROP+CREATE for both Bronze tables ran via the Athena Console under
phil-admin. The underlying S3 data files were untouched; only the Glue
Catalog table definitions swapped. Existing queries with explicit
`cik = '<value>'` predicates (Phase 1 verify suite, future Step Functions
state machine queries) continue to work fine — enum is permissive about
static-cik filters, just doesn't require them.

Trade-off accepted: new S&P 100 turnover requires editing the enum list
in both Bronze DDLs and re-running DROP+CREATE. Cheap operation; the
explicit list serves as documentation of "what's in the lake" anyway.

## 8. Warehouse layer — Data Vault 2.0 (Phase 2 session 3+)

(To be expanded in Phase 2 session 3+.)

Raw vault built from intermediate via dbt-athena Iceberg models. Hubs
hold business keys; links hold relationships; satellites hold descriptive
attributes with full SCD-2 history. Iceberg's `merge` incremental
strategy is the natural fit for satellite history (insert new rows on
attribute change; never overwrite).

## 9. Verification surface (per session)

Each dbt session ships with a verification suite parallel to Phase 1's
SQL + boto3 pattern. Session 1 surface:

- `dbt parse` returns 0 errors, 0 warnings.
- `dbt run` reports `PASS=N WARN=0 ERROR=0` for all models.
- Glue Catalog shows each new model as a registered table or view.
- Athena smoke query returns expected rows for at least one CIK.

## 10. References

- dbt-athena adapter docs: https://docs.getdbt.com/docs/local/connect-data-platform/athena-setup
- dbt-athena configuration reference: https://docs.getdbt.com/reference/resource-configs/athena-configs
- dbt-labs/dbt-adapters monorepo (dbt-athena lives here): https://github.com/dbt-labs/dbt-adapters/tree/main/dbt-athena
- AWS Athena Iceberg docs: https://docs.aws.amazon.com/athena/latest/ug/querying-iceberg.html
- Data Vault 2.0 reference: see PROJECT_PLAN.md section 7 and GLOSSARY.md

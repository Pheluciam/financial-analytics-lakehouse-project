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

### 7.5 Known limitations + next intermediate

Two known limitations surfaced at first-run verification, both deferred
to the next intermediate model:

- **Concept aliasing not yet collapsed.** Apple's Revenues query returned
  only 11 rows, all under fiscal year 2018, because Apple switched from
  the bare `Revenues` XBRL tag to `RevenueFromContractWithCustomerExcludingAssessedTax`
  on ASC 606 adoption (FY2019+). The next intermediate model
  (canonical-concept reconciliation) will UNION across alias concept names
  and emit a single canonical concept name (e.g. `revenue`) so downstream
  consumers don't need to know about the alias zoo.
- **No `period_start_date` column.** Without start date alongside end date,
  consumers can't visually distinguish annual periods from quarterly periods
  that share an end-of-fiscal-year date. Schema additions for the next
  intermediate model: `period_start_date` plus a computed `period_length_days`
  column for downstream slicing.

### 7.6 Verification surface for the intermediate layer

Three checks at session 2 close, all PASS:

- `dbt parse` returns 0 errors, 0 warnings (initially fired
  `MissingArgumentsPropertyInGenericTestDeprecation` on first parse — a
  dbt-core 1.10.5+ change requiring `accepted_values` tests to nest under
  an `arguments` property; fixed in-session and re-verified clean).
- `dbt run` reports PASS=3 WARN=0 ERROR=0 across the existing staging
  model plus the two new models.
- Athena smoke against Apple: 5 concept rows for the 5 in-scope concepts,
  three sample Revenues values cross-referenced against the public 10-K
  filing — FY2018 $265.595B, FY2017 $229.234B, FY2016 $215.639B — all
  match SEC records exactly.

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

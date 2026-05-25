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

## 7. Intermediate layer (Phase 2 session 2+)

(To be expanded in Phase 2 session 2.)

Intermediate models will perform the XBRL canonical-concept reconciliation
work — mapping the heterogeneous concept names different companies use
for the same metric (e.g. `Revenues` / `SalesRevenueNet` / `Revenue`) to
a single canonical concept (`revenue`). This is also where `json_extract_*`
gets exercised against the Bronze JSON structure.

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

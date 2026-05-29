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

## 8. Warehouse layer — Data Vault 2.0 (Phase 2 session 4 onwards)

### 8.1 What this layer is

The warehouse layer is the project's Data Vault 2.0 raw vault — hubs
holding unique business keys, links holding relationships between hubs,
satellites holding descriptive attributes with full SCD-2 history. It
sits between the canonical Silver intermediate layer (where XBRL concept
heterogeneity is reconciled to canonical names) and the Gold marts that
power Power BI consumption in Phase 4.

DV2.0 separates immutable business keys from mutable descriptive context
by construction — hubs are insert-only forever, satellites append
on-change rather than overwrite, links record relationship history. That
shape gives the lake natural audit lineage (every change is inspectable
through satellite version history) and natural restatement handling (a
corrected 10-K/A doesn't overwrite the original 10-K filing — both
versions live alongside, distinguishable by load_datetime).

### 8.2 Hand-rolled, no third-party DV2.0 macros

Locked at Phase 2 session 3 close-amend (2026-05-28) after the
phase-kickoff forward-verify pass: every DV2.0 model in this project is
written in plain dbt-athena SQL with no third-party macros. AutomateDV
(formerly dbtvault) is the dominant DV2.0 macro package in the dbt
ecosystem but does NOT support Athena per its platform support page —
only Snowflake, BigQuery, MS SQL Server, Databricks, Postgres are on
the supported list. See LEARNINGS Risk 1 (banked 2026-05-28) for the
full source-verification chain.

The portfolio story is stronger for hand-rolled regardless. A recruiter
who sees `{{ dbtvault.hub(...) }}` macro calls learns that the candidate
typed a macro and trusted it. A recruiter who sees hand-rolled hub SQL
with the hash key built from `to_hex(sha256(to_utf8(...)))` learns that
the candidate understands the DV2.0 mechanic — what a hash key is, why
it's deterministic, how insert-only semantics protect audit lineage,
what the unique_key contract guards against.

### 8.3 First hub: hub_company

`dbt/models/warehouse/hub_company.sql` is the first hub. Business key =
SEC Central Index Key (cik) — the 10-digit zero-padded identifier SEC
assigns to every filer. One row per unique cik across the S&P 100
universe. Records the first observation of each company in the lake;
load_datetime is immutable on subsequent refreshes.

**Source = staging, not canonical.** The model reads from
`stg_sec_edgar__companyfacts` rather than `int_sec_edgar__concepts_canonical`.
Staging has one row per (cik, extract_date) across all 100 S&P CIKs;
canonical filters to CIKs with at least one in-scope XBRL concept and
could silently under-populate the hub if a given company reported none
of the 8 in-scope tags. The DV2.0 lineage rule — hubs source from the
rawest layer where the business key first appears — is satisfied by
the staging read.

### 8.4 Hash key — hand-rolled SHA-256

The hub primary key is a SHA-256 hash of the business key, hex-encoded:

```sql
to_hex(sha256(to_utf8(CAST(cik AS varchar)))) AS hub_company_hk
```

`to_utf8()` converts the varchar input to varbinary (Trino's `sha256()`
requires varbinary input); `sha256()` returns a 32-byte digest as
varbinary; `to_hex()` encodes those 32 bytes as 64 hex characters. The
defensive `CAST(cik AS varchar)` guards against future staging-side
type changes silently breaking the hash.

SHA-256 over MD5 (AutomateDV's and Scalefree's default) is a deliberate
choice — collision rate is theoretical at S&P 100 scale, but picking
SHA-256 despite that signals "I understand the trade-offs and chose the
higher-strength option knowingly," which is the portfolio artifact's
narrative job. See LEARNINGS Risk 4 (banked 2026-05-28) for the full
verification chain against Scalefree, AutomateDV, and the Athena engine
v3 functions reference.

The same hash function chain extends unchanged to future single-key
hubs (hub_filing on accession_number, hub_concept on canonical_concept,
hub_period on period_end_date). Multi-column composite-key hubs (none
in scope yet for Project #3) would concatenate the business-key columns
with an explicit delimiter before hashing, to avoid the ambiguity where
'AB' + 'C' and 'A' + 'BC' produce the same digest.

### 8.5 Insert-only semantics via source-side filter

dbt-athena's default Iceberg merge strategy OVERWRITES matched rows
with new values — the standard analytics-engineering upsert pattern.
For DV2.0 hubs that default is wrong: re-seeing the same cik on a
subsequent extract would overwrite the original load_datetime and
record_source, silently corrupting the first-seen audit trail that is
the whole point of the hub.

The fix is a source-side `is_incremental()` filter that excludes
already-seen hash keys before the engine reaches the merge:

```sql
SELECT * FROM hashed
{% if is_incremental() %}
WHERE hub_company_hk NOT IN (SELECT hub_company_hk FROM {{ this }})
{% endif %}
```

On the first run, `is_incremental()` is false (no `{{ this }}` exists
yet) — the whole source flows through as CREATE TABLE AS SELECT. On
subsequent runs, `is_incremental()` is true — the source SELECT excludes
every cik already in the hub, so the merge has nothing to match against
and only ever inserts genuinely-new keys. The `unique_key='hub_company_hk'`
config provides a belt-and-braces safety net at the engine level — if
the source-side filter ever fails to dedupe (broken upstream, bug in
the model), the merge would still refuse to insert a duplicate hash.
See LEARNINGS Risk 5 (banked 2026-05-28) for the alternatives considered
and rejected (`update_condition: '1 = 0'`, `merge_update_columns: []`,
`incremental_strategy: 'append'`) and the rationale chain.

Layer defaults (`materialized: incremental`, `incremental_strategy: merge`,
`table_type: iceberg`, `format: parquet`, `on_schema_change: ignore`)
live in `dbt_project.yml` under the warehouse block — all three DV2.0
model classes (hubs, links, satellites) share those defaults. Only the
per-model `unique_key` lives in each model's own config block, since
the hash-key column name varies (`hub_company_hk`, `link_company_filing_hk`,
`sat_company_metadata_hk`, etc.). `on_schema_change` stays at `ignore`
project-wide for the warehouse layer because the Iceberg merge +
`on_schema_change=sync_all_columns` combination has a documented
duplicate-insertion bug (LEARNINGS Risk 2, dbt-glue issue #571). DV2.0
hubs and links are schema-stable by construction; satellites evolve
schema via full-refresh when needed, not via on_schema_change.

### 8.6 Verification surface for the warehouse layer

Three layers of verification, each catching a different class of issue:

**Schema tests** (`dbt/models/warehouse/_models.yml`): 6 tests on
hub_company — `not_null` on every column (hub_company_hk, cik,
load_datetime, record_source) plus `unique` on hub_company_hk AND cik.
Unique on the business key is the hub uniqueness contract; unique on
the hash key is its mathematical guarantee. Both tested gives
belt-and-braces — if one passes and the other fails, the hash function
chain has a bug.

**Structural verify** (`sql/verify/03_phase2_warehouse_verification.sql`):
9 PASS/FAIL checks in the same CTE-then-SELECT pattern as verify/01
and verify/02. Covers: row count = 100 (S&P 100 parity), hash-key
uniqueness restated in raw SQL, hash-key length = 64 chars (SHA-256
structural contract), business-key uniqueness restated in raw SQL,
hub count = source distinct CIK count (lineage parity vs staging),
Apple hash deterministic-reproducibility check (recomputes
`to_hex(sha256(to_utf8('0000320193')))` and confirms the stored hash
matches — proves the hash function chain is reproducible and the model
wrote the expected value), load_datetime within reasonable UTC bounds,
record_source constant for every row. 9/9 PASS in 4.461 sec, ~41 KB
scanned at session 4 close.

**Idempotency proof** (separate dbt re-run): running `dbt run --select
hub_company` a second time returns `OK 0 in 27.00s` — the merge query
executes but inserts 0 rows because the source-side filter excluded
all 100 already-seen hash keys. The "0 rows" line IS the insert-only
contract demonstrating in production.

### 8.7 Pattern reusability — what carries to future warehouse models

The first hub establishes patterns subsequent warehouse models inherit
structurally:

- **Hash function chain** (`to_hex(sha256(to_utf8(CAST(<bk> AS varchar))))`)
  is the project standard for every hash key in every DV2.0 model.
- **Source-side `is_incremental()` filter** carries to hub_filing,
  hub_concept, hub_period — identical pattern with the appropriate
  hash-key column name.
- **Links** apply the same source-side filter pattern; the difference
  is the SELECT body computes a composite hash over multiple business
  keys (e.g., `link_company_filing_hk` over cik + accession_number).
- **Satellites** use a different filter pattern (insert-on-change keyed
  on hash diff between the inbound row and the latest satellite version
  for the same parent), but the merge config, hash function, and
  `on_schema_change: ignore` defaults all carry unchanged.
- **Verify-suite pattern** (CTE PASS/FAIL with `check_NN_<name>` naming)
  carries verbatim — each future warehouse model gets its own
  `sql/verify/NN_...sql` file in the same shape.

### 8.8 Second hub: hub_filing (Phase 2 session 5)

`dbt/models/warehouse/hub_filing.sql` is the second hub. Business key =
accession_number, the 18-character SEC-assigned identifier (format
`'##########-##-######'`, with literal hyphens in positions 11 and 14).
One row per unique filing across the S&P 100 universe; session 5 close
landed 6,551 distinct filings spanning the 10-year companyfacts history.

**Source = stg_sec_edgar__companyfacts_raw.** Honors the session-4 lock
that DV2.0 hubs source from the rawest layer where the business key
first appears (LEARNINGS Risk 7, 2026-05-28). The model body Jinja-loops
the same 8 in-scope XBRL concepts as `int_sec_edgar__concepts`, UNNESTs
each `$.facts["us-gaap"].<concept>.units.USD` array, projects `accn` as
accession_number, applies DISTINCT, and hashes. Phase 1 submissions-endpoint
extract extension explicitly rejected at the forward-verify pass —
would have un-frozen Bronze mid-project for a marginal coverage gain.
Coverage trade-off documented: hub_filing covers every accession_number
for filings that reported at least one of the 8 in-scope concepts;
for the S&P 100 universe every meaningful 10-K / 10-Q reports at least
one of those, so coverage is universal in practice.

**Hash function chain is identical to hub_company.** `to_hex(sha256(to_utf8(CAST(accession_number AS varchar))))`.
The defensive CAST guards against future staging-side type changes.

**Insert-only semantics carry from hub_company.** Same source-side
`is_incremental()` filter pattern, same `unique_key` engine-level
safety net.

### 8.9 First link: link_company_filing (Phase 2 session 5)

`dbt/models/warehouse/link_company_filing.sql` is the first link. One
row per unique (cik, accession_number) pair observed in the
companyfacts JSON — recording the natural relationship that "filer X
filed filing Y." Session 5 close landed 6,551 link rows (identical to
hub_filing's row count, as expected — SEC's accession-number
assignment convention guarantees one filing maps to exactly one
filer, so the link is a one-to-many from filers to filings, never
many-to-many).

**Composite hash construction (LEARNINGS Risk 6, 2026-05-28).** The
link's primary hash key concatenates the two business keys with a
`'||'` delimiter before hashing:

```sql
to_hex(sha256(to_utf8(
    CAST(cik AS varchar) || '||' || CAST(accession_number AS varchar)
))) AS link_company_filing_hk
```

The `'||'` delimiter is the AutomateDV ecosystem default. It defeats
the documented `'-'`-delimiter collision-on-hyphenated-inputs ambiguity
that bites the dbt_utils.generate_surrogate_key macro (dbt-utils issue
#1015 — `'123-' + '-456'` produces the same digest as `'123' + '--456'`).
SEC EDGAR accession numbers literally contain hyphens in positions 11
and 14, so `'-'` as a delimiter would not be hash-safe here; `'||'`
never appears in either business-key value, so the digest is
unambiguous by construction. Document the design call in the model
body so the choice is auditable.

**FK hashes match the parent hub chain.** The link carries
`hub_company_hk` and `hub_filing_hk` as foreign-key columns alongside
the composite `link_company_filing_hk`. Each FK hash is computed via
the same single-key chain as its parent hub
(`to_hex(sha256(to_utf8(CAST(cik AS varchar))))` for `hub_company_hk`,
ditto for `hub_filing_hk`). Joining from link to either parent hub
on the hash columns is therefore valid by construction — no integrity
gymnastics needed at join time. The verify/04 FK-closure checks
(checks 10 + 11) confirm this empirically: every link row's
`hub_company_hk` and `hub_filing_hk` resolve to a parent hub row.

**Insert-only semantics carry from hubs.** Scalefree confirms
(scalefree.com/scalefree-newsletter/insert-only-in-data-vault/):
"the Link should remain a pure, append-only record of every
relationship ever observed, without status flags or end dates." Same
source-side `is_incremental()` filter pattern, same `unique_key`
safety net, same `on_schema_change: ignore` default. Re-seeing the
same (cik, accession_number) pair on a later extract is excluded
from the source SELECT before the merge — original `load_datetime`
+ `record_source` are immutable.

**Source-side UNNEST mirrors hub_filing.** Same Jinja loop over the
8 in-scope concepts, but the link projects both cik (from the
partition key) and accession_number (from accn) and applies DISTINCT
on the pair rather than the accn alone.

### 8.10 Verification surface for hub_filing + link_company_filing

`sql/verify/04_phase2_warehouse_links_verification.sql` — 13 CTE
PASS/FAIL checks in the same shape as verify/03:

- Checks 1-5 cover hub_filing: hash-key uniqueness, NOT NULL, length =
  64, business-key uniqueness, and lineage parity against the
  source-side DISTINCT accession_number count across the 8 in-scope
  concepts.
- Checks 6-13 cover link_company_filing: composite-hash uniqueness,
  NOT NULL, length = 64, composite-hash determinism reproducibility
  on Apple's lexicographically-smallest accession_number (recomputes
  `to_hex(sha256(to_utf8('0000320193' || '||' || <accn>)))` and
  confirms it matches the stored link hash), FK closure to both
  parent hubs, source-pair lineage parity, and business-key
  cardinality sanity (every link's (cik, accession_number) pair
  matches a hub_company.cik AND a hub_filing.accession_number).

13/13 PASS in 9.3 sec at session 5 close. Composite-hash determinism
check earned its keep — it's the structural proof that the '||'
delimiter convention is what's actually in the digest, not a different
delimiter from a copy-paste regression.

### 8.11 First satellite: sat_filing_metadata (Phase 2 session 6)

`dbt/models/warehouse/sat_filing_metadata.sql` is the first DV2.0
satellite in the project. Parent = hub_filing (accession_number
business key). Carries 2 truly filing-level descriptive attributes
observed in the SEC EDGAR companyfacts JSON: form_type and filed_date.
1:1 cardinality with hub_filing on first load — every parent has
exactly one sat row when no history has accumulated.

**Scope correction at first-run time (LEARNINGS Risk 12,
2026-05-28).** Initial session 6 design carried 4 additional payload
columns (period_start_date, period_end_date, fiscal_year,
fiscal_period). First dbt run returned 45,851 rows — ~7x the expected
6,551 (hub_filing parent count). Diagnosis: those 4 columns are
per-period-instance, not per-filing — a 10-K reports comparatives
(current FY + 2 prior FYs) and a 10-Q reports the current quarter
plus YTD plus prior-year-same, each as a separate array entry within
each concept's units.USD array. Per-instance attributes break the
satellite's 1:1 parent-coverage-parity invariant. Trimmed scope to
the 2 truly filing-level attributes. The per-period attributes
belong on a future model class (hub_period + link_filing_period, OR
baked into sat_concept_value when that lands). Carry-forward
principle banked: every satellite gets a 30-second cardinality
sanity check at design time — "expected first-load row count
should equal parent hub row count" — before code ships.

**Why satellites exist (DV2.0 framing).** Hubs and links carry the
structural skeleton — what entities exist and how they relate —
but they intentionally hold no descriptive attributes. Every
attribute that describes an entity lives in a satellite. The
SCD-2-by-construction contract is the differentiator: any time an
attribute changes, the satellite inserts a NEW row with a new
load_datetime, preserving the prior row indefinitely. The full
history of every attribute change for every entity is recoverable
at any future point — exactly the property regulators want for
restatement auditability, and exactly the property that motivated
Linstedt's DV2.0 design in the first place.

**Three new mechanics relative to hub_filing.** All three were
surfaced at the session 6 forward-verify pass and banked as
LEARNINGS Risks 8/9/10/11 BEFORE any code shipped. They distinguish
satellite design from hub/link design:

1. **hashdiff column.** SHA-256 over the COALESCEd payload concat,
   alongside the parent hash key. The hashdiff fingerprints the
   payload state at a single load_datetime — unchanged payload
   yields the same hashdiff next load, changed payload yields a
   different one. The COALESCE-sentinel pattern (`'^^'` default,
   per AutomateDV convention) is mandatory because Trino's concat
   returns NULL whenever any input is NULL, and `period_start_date`
   is NULL upstream for balance-sheet point-in-time facts (LEARNINGS
   Risk 8).

2. **Source-side filter is an anti-join, not a NOT IN.** The hub
   pattern `WHERE hub_hk NOT IN (SELECT hub_hk FROM {{ this }})`
   would exclude every already-seen parent — including parents
   whose payload genuinely changed. The satellite filter instead
   computes the latest stored hashdiff per parent (window function
   over load_datetime DESC, take rn = 1) and excludes inbound rows
   whose hashdiff matches the latest stored one for the same parent.
   Inbound rows pass through to merge only when (a) no existing row
   for that parent OR (b) the inbound hashdiff differs from the
   latest stored hashdiff (LEARNINGS Risk 9).

3. **Dedicated sat_filing_metadata_hk over the natural composite
   PK.** The DV2.0 textbook satellite PK is (parent_hk, load_datetime).
   Two equally-valid implementations: composite list as unique_key,
   or a single SHA-256 hash over the natural PK. Project standard is
   the single hash — keeps the hub/link/sat surface visually
   consistent (every warehouse-layer model has one column named
   `<class>_<entity>_hk` that's its single-column unique_key). The
   composite natural PK becomes a test-time contract enforced via
   `dbt_utils.unique_combination_of_columns` in `_models.yml`
   (LEARNINGS Risk 10).

**Source DISTINCT discipline.** Same UNNEST chain as hub_filing and
link_company_filing, but projects 6 payload columns alongside
accession_number. Same accn appears across all 8 in-scope concept
arrays in the JSON with identical filing-level attributes (form,
filed, fy, fp, end, start are filing-level, not concept-level).
DISTINCT applied to the FULL payload tuple (not just the BK)
collapses these to one row per genuinely-distinct (accession_number,
payload-tuple) before hashing — keeps engine-side scan cost
proportional to the natural cardinal unit (LEARNINGS Risk 11).

**hashdiff function chain.**

```sql
to_hex(sha256(to_utf8(
    COALESCE(CAST(form_type AS varchar), '^^') || '||' ||
    COALESCE(CAST(filed_date AS varchar), '^^')
))) AS hashdiff
```

Same SHA-256 chain as the hub_company / hub_filing / link composite
hashes (LEARNINGS Risk 4); only the input expression differs.
Per-column CAST AS varchar guards against upstream type changes
silently breaking the hash. Column order inside the concat is part
of the contract — changing it would change every hashdiff and
spuriously re-insert every row on next load. Both payload columns
are reliably populated in the companyfacts JSON, but the COALESCE
pattern is applied as a defensive project standard — every future
satellite hashdiff uses the same shape.

**sat_filing_metadata_hk function chain.**

```sql
to_hex(sha256(to_utf8(
    CAST(hub_filing_hk AS varchar) || '||' || CAST(load_datetime AS varchar)
))) AS sat_filing_metadata_hk
```

Single load_datetime expression evaluated once per query so every
row in this batch shares it — DV2.0 contract that a batch of changes
lands with one consistent LDTS.

**Source-side anti-join filter.**

```sql
{% if is_incremental() %}
WHERE NOT EXISTS (
    SELECT 1
    FROM (
        SELECT
            hub_filing_hk,
            hashdiff,
            ROW_NUMBER() OVER (
                PARTITION BY hub_filing_hk
                ORDER BY load_datetime DESC
            ) AS rn
        FROM {{ this }}
    ) latest
    WHERE latest.hub_filing_hk = inbound.hub_filing_hk
      AND latest.hashdiff = inbound.hashdiff
      AND latest.rn = 1
)
{% endif %}
```

The window function picks each parent's latest stored row; the
NOT EXISTS clause excludes inbound rows whose hashdiff matches.
Pattern is DV2.0-idiomatic and structurally matches the AutomateDV
sat-macro semantics.

**Materialization config.** Same warehouse-layer defaults from
`dbt_project.yml`: incremental + merge + iceberg + parquet +
on_schema_change=ignore. The on_schema_change=ignore is MANDATORY
for satellites per LEARNINGS Risk 2 — Iceberg merge +
on_schema_change=sync_all_columns has a documented duplicate-insertion
bug (dbt-glue issue #571). Schema evolution on satellites is
handled via full-refresh, never via on_schema_change. Per-model
`unique_key='sat_filing_metadata_hk'` only.

### 8.12 SCD-2 mechanic walkthrough (sat_filing_metadata)

The full mechanic on three sequential loads, to make the contract
auditable:

| Load | Inbound payload for parent X | Existing latest hashdiff for X | Anti-join verdict | Engine action |
|---|---|---|---|---|
| Load 1 (first run) | (10-K, 2024-11-01, ...) → hashdiff = H1 | (no existing row) | NOT EXISTS = true → row passes | INSERT row with H1, LDTS = T1 |
| Load 2 (re-run, payload unchanged) | (10-K, 2024-11-01, ...) → hashdiff = H1 | H1 | NOT EXISTS = false → row dropped | NO-OP |
| Load 3 (filing amended, form_type → 10-K/A) | (10-K/A, 2024-11-01, ...) → hashdiff = H2 | H1 | NOT EXISTS = true → row passes | INSERT row with H2, LDTS = T3. Row from Load 1 (H1, T1) preserved. |

Querying the current state of any filing = window function in the
mart layer (take the row with MAX(load_datetime) per parent_hk).
Querying historical state at any past date = `WHERE load_datetime
<= <as-of-date>` then MAX. The point of DV2.0: every historical
state is recoverable; no row is ever overwritten.

### 8.13 Verification surface for sat_filing_metadata

`sql/verify/05_phase2_warehouse_satellites_verification.sql` — 11
CTE PASS/FAIL checks in the same shape as verify/03 and verify/04:

- Checks 1-5 cover the structural contract: sat hash key
  uniqueness + NOT NULL + length = 64, hashdiff NOT NULL + length
  = 64.
- Check 6 is FK closure to hub_filing (no orphan parent keys).
- Check 7 is the composite natural PK (hub_filing_hk,
  load_datetime) uniqueness check — independently confirms the
  DV2.0 textbook contract that the single-column unique_key
  enforces at engine level.
- Check 8 is parent coverage parity — on first load, sat row
  count = distinct hub_filing_hk in sat = hub_filing row count
  (1:1 cardinality invariant). This is the check that would have
  surfaced the original scope miss (Risk 12) BEFORE the
  expensive schema-test scan, if it had been promoted to a
  design-time sanity check rather than a verify-suite check;
  carry-forward principle banked in LEARNINGS.
- Checks 9-10 are hash-determinism reproducibility on Apple's
  lexicographically-smallest accession — recomputes both
  sat_filing_metadata_hk (Risk 10 function chain) and hashdiff
  (Risk 8 function chain — 2-column COALESCE-protected payload)
  and confirms the stored values match. Earns its keep as
  structural proof that the function chains reproduce
  deterministically across runs.
- Check 11 confirms record_source is the constant
  'sec_edgar.companyfacts' on every row.

Idempotency check is the second dbt run — expected NO-OP per the
anti-join filter excluding every inbound row whose hashdiff
matches the latest stored hashdiff for the same parent. Same
pattern as hubs/links but the mechanic that gets exercised is
different (anti-join, not NOT IN).

### 8.14 Second satellite: sat_company_metadata (Phase 2 session 7)

`dbt/models/warehouse/sat_company_metadata.sql` — second DV2.0
satellite. Parent = hub_company (cik business key). Carries one
payload attribute: entity_name (the company's registered name as
reported to SEC EDGAR — e.g., 'Apple Inc.', 'Microsoft Corp').
1:1 cardinality with hub_company on first load — 100 rows = S&P
100 universe size.

The model body is materially simpler than sat_filing_metadata
because entity_name is a top-level JSON field already exposed by
the typed cover-page staging (`stg_sec_edgar__companyfacts`,
which the Bronze openx SerDe maps from $.entityName at table
creation time). No Jinja for-loop, no CROSS JOIN UNNEST over a
concept list — just a DISTINCT (cik, entity_name) collapse +
hash computation + the inherited NOT EXISTS anti-join filter.

The session-7 forward-verify pass surfaced the cardinality
discipline that Risk 12 (banked at session 6) had locked as a
carry-forward principle. The pass included an explicit empirical
probe against Bronze BEFORE any SQL shipped:

```sql
SELECT
    COUNT(*) AS total_bronze_rows,
    COUNT(DISTINCT cik) AS distinct_ciks,
    COUNT(DISTINCT extract_date) AS distinct_extract_dates,
    COUNT(DISTINCT json_extract_scalar(json_text, '$.entityName')) AS distinct_entity_names
FROM financial_analytics_bronze.sec_edgar_companyfacts_raw;
```

Result on the actual Bronze: 101 rows / 100 distinct CIKs / 2
distinct extract_dates / 100 distinct entityNames. One CIK had
been extracted twice on two different dates with identical
entity_name both times. The naive read — sourcing staging
directly without DISTINCT — would have shipped 101 satellite
rows on first load, breaking the 1:1 invariant with hub_company.
The empirical probe caught the cardinality drift at design time,
not first-run time. DISTINCT (cik, entity_name) in the model's
distinct_companies CTE collapses cleanly to 100. Risk 13
candidate banked in LEARNINGS: every future satellite's
forward-verify pass must include an empirical cardinality probe
against actual Bronze, not just function-chain doc-verify
against authoritative sources.

The SCD-2 change-detection mechanic won't fire on entity_name
within Project #3's data scope — current Bronze has identical
entityName across both extract_dates for the duplicate CIK, and
the S&P 100 roster within a single Phase 1 ingestion run has no
genuine rename events. The contract is valid for future loads:
if the same CIK ever appears with a renamed entity_name on a
later refresh, the source-side hashdiff would differ from the
latest stored hashdiff, the anti-join would pass the inbound
row through, and a new SCD-2 row would land with a new
load_datetime, preserving the prior row for audit lineage.

hashdiff for a single-column payload is SHA-256 over
COALESCE(entity_name, '^^') directly — no '||' delimiter
inside (the delimiter defends against multi-column concat
ambiguity, not present here). The '^^' sentinel still applies
as project standard defensive shield against Trino's concat
NULL propagation (Risk 8), even though entity_name is reliably
populated upstream per the Bronze openx SerDe contract.

### 8.15 Verification surface for sat_company_metadata

`sql/verify/06_phase2_warehouse_sat_company_metadata_verification.sql`
— 11 CTE PASS/FAIL checks in the same shape as verify/05:

- Checks 1-5 cover the structural contract: sat hash key
  uniqueness + NOT NULL + length = 64, hashdiff NOT NULL +
  length = 64.
- Check 6 is FK closure to hub_company (no orphan parent keys).
- Check 7 is the composite natural PK (hub_company_hk,
  load_datetime) uniqueness check — independently confirms the
  DV2.0 textbook contract that the single-column unique_key
  enforces at engine level.
- Check 8 is parent coverage parity — on first load, sat row
  count = distinct hub_company_hk in sat = hub_company row
  count = 100 (1:1 cardinality invariant). Risk 13's empirical
  cardinality probe at the forward-verify pass is the
  design-time counterpart to this run-time check; together they
  enforce the 1:1 contract twice over.
- Checks 9-10 are hash-determinism reproducibility on Apple
  (cik 0000320193) — recomputes both sat_company_metadata_hk
  (Risk 10 function chain) and hashdiff (Risk 8 function chain
  — single-column COALESCE-protected payload, no '||'
  delimiter) and confirms the stored values match.
- Check 11 confirms record_source is the constant
  'sec_edgar.companyfacts' on every row.

11/11 PASS in 2.55 sec; ~few MB scanned. 10/10 schema tests
PASS in 14.22 sec across the new model. Idempotency proven via
second dbt run [OK 0 in 27.01s] — the SCD-2 unchanged-payload
contract held.

Cumulative warehouse-layer verification surface at session 7
close: 6 hub_company + 6 hub_filing + 10 link_company_filing +
11 sat_filing_metadata + 10 sat_company_metadata = 43 schema
tests PASS. 9 verify/03 + 13 verify/04 + 11 verify/05 + 11
verify/06 = 44 SQL structural checks PASS.

### 8.16 Third hub: hub_concept (Phase 2 session 8)

`dbt/models/warehouse/hub_concept.sql` — third DV2.0 hub.
Business key = canonical_concept (the canonical XBRL concept name
after dictionary collapse). 5 rows: revenue, net_income, assets,
liabilities, stockholders_equity. The 4 revenue alias raw tags
(Revenues, SalesRevenueNet, RevenueFromContractWithCustomer-
Excluding/IncludingAssessedTax) all collapse to canonical
'revenue' via the canonical_concepts_dictionary seed; the other 4
in-scope raw tags identity-map to canonical names.

Source = int_sec_edgar__concepts_canonical (the intermediate view
that joins int_sec_edgar__concepts to the seed by raw concept_name)
rather than the seed directly. DV2.0 hubs hold first-observed
business keys in actual data, not enumerated reference lists — a
canonical concept defined in the seed but never reported by any
S&P 100 company shouldn't appear in hub_concept. Inner-joining
seed → actual data via the canonical view is exactly this filter.

Hash chain: to_hex(sha256(to_utf8(CAST(canonical_concept AS varchar))))
— identical single-key chain as hub_company / hub_filing (Risk 4,
2026-05-28). 5 sixty-four-char SHA-256 hashes at S&P 100 scale is
a trivially-small reference hub — but the project-standard chain
is still applied for lineage consistency. Insert-only via the
source-side NOT IN filter pattern matching the other two hubs.

### 8.17 Second link: link_filing_concept_period (Phase 2 session 8)

`dbt/models/warehouse/link_filing_concept_period.sql` — second
DV2.0 link, **3-way standard link** associating hub_company (cik)
+ hub_filing (accession_number) + hub_concept (canonical_concept)
with the per-period observation grain. 89,821 rows on first load.
One row per unique (cik, accession_number, canonical_concept,
period_start_date, period_end_date, fiscal_year, fiscal_period)
tuple observed in the companyfacts JSON.

**Architectural call locked at the session 8 forward-verify pass.**
This was the biggest design decision in Phase 2 so far. Two
candidate shapes surfaced at kickoff: (a) hub_period +
link_filing_period split (textbook DV2.0 temporal-grain
decomposition) vs (b) period attributes baked into sat_concept_value
as multi-active satellite payload. The forward-verify pass refined
Option A's intent via doc-verify against scalefree.com (multi-
temporality + non-historized link patterns), surfacing that the
canonical DV2.0 idiom for transactional observation data has
period attributes as descriptive link-level payload rather than
a separate hub_period. Empirical probe 3 then confirmed
empirically: 10,974 distinct period instances is transactional-
grain territory (a true reference-style fiscal-calendar hub
lands at ~40-50 rows), not reference-hub territory. hub_period
DEFERRED indefinitely. LEARNINGS Risk 14 banked.

Empirical probe 4 then surfaced the link-class call: 9,335 (cik,
canonical_concept, period_end_date) groups had value disagreement
across observations (~31% of 29,815 groups) — mix of period-grain
ambiguity (3-month Q3 vs 9-month YTD sharing end date), multi-
filing same-period reporting, canonical-collapse double-projection,
and only a subset of true restatements. Critically: adding
accession_number to the grain made each tuple unique-per-filing.
**Standard link, not non-historized link** — restatements appear
as NEW link rows because they carry NEW accession_numbers; the
non-historized-link idiom is for relationship triples that repeat
with different transaction values (sales-per-customer-store-product
pattern), which SEC XBRL doesn't fit. LEARNINGS Risk 15 banked.

**Cardinality probe artefact.** Phil ran the four-aggregate
signature against int_sec_edgar__concepts_canonical at the
forward-verify pass (Risk 13 carry-forward, 2026-05-28). The
full probe SQL + observed results live in
sql/diagnostic/01_phase2_session8_sat_concept_value_cardinality_probes.sql
as a versioned design-time artefact:

- Probe 1: 5 distinct canonical_concepts → hub_concept row count locked
- Probe 2: 93,869 total vs 87,928 distinct (cik, canonical, period_*)
  tuples → 5,941-row canonical-collapse gap → DISTINCT + GROUP BY
  collapse strategy locked
- Probe 3: 10,974 distinct period instances → hub_period deferred
- Probe 4: 9,335 value-disagreement groups → standard link locked,
  MIN(value) tie-breaker locked

**Composite hash construction.** 7-column SHA-256 composite
including BOTH the parent BKs (cik, accession_number,
canonical_concept) AND the period payload (period_start_date,
period_end_date, fiscal_year, fiscal_period). Without the period
payload in the hash, two genuinely-distinct observations sharing
the same (cik, accn, canonical) but different period instances
would collide to the same link hash. '||' delimiter per Risk 6;
COALESCE-to-'^^' sentinel on period_start_date (NULL for
balance-sheet instant-period concepts) per Risk 8. 3 FK hash
columns (hub_company_hk, hub_filing_hk, hub_concept_hk) computed
via the same single-key chains as their parent hubs so FK joins
are valid by construction.

**DISTINCT discipline at post-canonical grain.** Per Risk 16
(banked at this forward-verify pass). The canonical-concept
dictionary collapses 4 revenue alias raw tags into canonical
'revenue'. When a single filing reports the SAME period under
multiple revenue alias tags (common during ASC 606 transition
years), the post-join layer produces duplicate-canonical rows.
DISTINCT applied at the natural cardinal tuple BEFORE composite-
hash computation collapses these to one link row per genuine
observation. Same DISTINCT discipline as Risk 11 (pre-collapse
on UNNEST repetition) but extended to the post-collapse layer.

### 8.18 Third satellite: sat_concept_value (Phase 2 session 8)

`dbt/models/warehouse/sat_concept_value.sql` — third DV2.0
satellite. Parent = link_filing_concept_period. 2 payload
attributes: value (DECIMAL(28,2), the actual XBRL fact value) and
unit ('USD' within current scope). 1:1 cardinality with the link
parent on first load — 89,821 rows = link row count.

**THIS IS THE MODEL holding the actual numerical SEC EDGAR
financial data.** Every downstream Gold mart in Phase 4
(mart_pl_trend, mart_peer_benchmark, mart_financial_health,
mart_growth_forecast) joins through link_filing_concept_period
to sat_concept_value for fact values. Apple's $383.3B FY2023
revenue, Microsoft's quarterly net income, S&P 100 balance-sheet
totals — all live here.

**Inherits the satellite pattern locked at sessions 6 + 7.** SCD-2
NOT EXISTS anti-join on latest-hashdiff-per-parent (Risk 9),
COALESCE-sentinel hashdiff with '^^' sentinel + '||' delimiter
(Risk 8), dedicated single-column sat_concept_value_hk over
(link_filing_concept_period_hk || '||' || load_datetime) with
composite natural PK enforced at test time via
dbt_utils.unique_combination_of_columns (Risk 10). No new sat
mechanic introduced — the structural innovation of session 8 is
on the link side (3-way standard link + period-as-payload), the
sat reuses the established session-6 shape.

**Value disagreement collapse via MIN at source-side** (Risk 16
sub-decision, 2026-05-28). When canonical-collapse produces
multiple rows for the same (cik, accession, canonical, period)
tuple with different reported values from multi-tag dual-reporting
(the 5,941-row gap in probe 2), MIN(value) is the deterministic
tie-breaker. MIN biases toward the conservative revenue
measurement (e.g., excluding-assessed-tax over including-) which
aligns with analyst convention of "smallest defensible number"
for revenue. Documented in the model body rather than swept
under DISTINCT — DISTINCT would non-deterministically pick one
row; GROUP BY + MIN(value) is auditable.

**SCD-2 mechanic on this data.** Restatements typically come via
NEW accession_numbers (10-K/A amends 10-K) — those produce NEW
link rows naturally because the composite link hash includes
accession_number. The same-accession SCD-2 anti-join fires only
on the rare case where the SAME accession's facts get re-extracted
with a different value across extract_dates. Within current
Bronze the 2-extract-dates / 1-duplicate-CIK case from session 7
gives the mechanic exactly 1 chance to fire on first load (and
only if that duplicate-CIK's facts changed between extracts —
which probe 4 + idempotency NO-OP together suggest they didn't).
Contract valid for future loads regardless.

### 8.19 Verification surface for hub_concept + link_filing_concept_period + sat_concept_value

Three new verify files per the established per-model pattern:

- `sql/verify/07_phase2_warehouse_hub_concept_verification.sql` —
  8 CTE PASS/FAIL checks: hash unique + not_null + length 64, BK
  unique + not_null, source-coverage parity (5 = 5 distinct
  canonicals from intermediate view), hash determinism on
  'revenue' sample, record_source constant. 8/8 PASS in 1.73 sec.
- `sql/verify/08_phase2_warehouse_link_filing_concept_period_verification.sql`
  — 12 CTE PASS/FAIL checks: link hash unique + not_null + length
  64, 3 FK closures (company, filing, concept), 7-column composite
  natural grain uniqueness, period_end_date + 3 BKs not_null,
  link composite hash determinism on Apple sample, FK
  hub_company_hk determinism on Apple, record_source constant.
  12/12 PASS in 3.77 sec.
- `sql/verify/09_phase2_warehouse_sat_concept_value_verification.sql`
  — 12 CTE PASS/FAIL checks: sat hash unique + not_null + length
  64, hashdiff not_null + length 64, FK closure to link, composite
  natural PK uniqueness, parent coverage parity (89,821 = 89,821
  — 1:1 invariant guard), value not_null, sat hash + hashdiff
  determinism on Apple sample, record_source constant. 12/12 PASS
  in 2.20 sec.

**Idempotency proven.** Second dbt run --select hub_concept
link_filing_concept_period sat_concept_value returned [OK 0] on
all three models in 37.56 sec — NOT IN filter excluded 5 + 89,821
seen hash keys; NOT EXISTS anti-join excluded 89,821 inbound rows
whose hashdiff matched the latest stored hashdiff.

**Cumulative warehouse-layer verification surface at session 8
close:** 5 hubs (hub_company + hub_filing + hub_concept) + 2 links
(link_company_filing + link_filing_concept_period) + 3 sats
(sat_filing_metadata + sat_company_metadata + sat_concept_value)
= **77 dbt schema tests PASS** (43 cumulative through session 7
+ 34 new), **76 SQL structural verify checks PASS** (44 cumulative
through session 7 + 32 new).

The vault now holds the complete observational raw vault for the
Phase 4 Gold marts: every (company, filing, concept, period) fact
observation is in sat_concept_value, navigable via the FK chain
through link_filing_concept_period to the three hubs.

### 8.20 Fourth satellite: sat_concept_canonical — first multi-active satellite (Phase 2 session 9)

Session 9 introduces the project's first multi-active satellite (MAS).
The architectural pattern is genuinely new relative to sessions 6/7/8.
Those three satellites are 1:1 with their parent — every parent hash
key has exactly one active sat row at any point in time. The MAS
relaxes that invariant: multiple sat rows can be concurrently active
for the same parent_hk. The DV2.0 textbook example is a customer
having multiple active phone numbers; the project example is a
canonical XBRL concept having multiple active raw US-GAAP tag names.

**The business problem the MAS solves.** Session 8's sat_concept_value
applies a MIN(value) tie-breaker to collapse the per-canonical
duplicates that arise from multi-tag-same-period dual-reporting
(Risk 16 sub-decision). That collapse is deterministic and
audit-traceable, but it does lose information: the canonical
'revenue' row stored in sat_concept_value for Apple FY2019 doesn't
record which of the 4 revenue alias raw tags
(`Revenues`, `SalesRevenueNet`,
`RevenueFromContractWithCustomerExcludingAssessedTax`,
`RevenueFromContractWithCustomerIncludingAssessedTax`) the value
actually came from. For a regulator or analyst asking "which raw
tag did Apple report FY2019 revenue under" — that question can't
be answered from sat_concept_value alone. sat_concept_canonical
records the raw → canonical mapping observed in actual data as
immutable DV2.0 sat rows, so the provenance is recoverable
forever. The MAS pattern is the right shape because canonical
'revenue' has 4 concurrent active raw tags in source, not one.

**Forward-verify pass front-loaded every architectural call.**
Doc-verify against AutomateDV's ma_sat tutorial and Scalefree's
multi-active-satellites Part 1 article locked the textbook MAS
PK as composite (parent_hk, child_dependent_key, load_datetime).
The empirical four-aggregate probe against
int_sec_edgar__concepts_canonical returned 93,869 rows / 5
canonicals / 8 raw tags / 2 extract_dates — matching session 8
probe results exactly. The cardinality-prediction probe (distinct
(canonical, raw_tag) pairs) returned 8 — equal to the
canonical_concepts_dictionary seed row count. First-load
prediction = 8 rows = MAS cardinality invariant.

**Risk 17 — degenerate MAS payload (CDK == payload).** Banked
2026-05-29 at the session 9 forward-verify pass. In the textbook
MAS example (customer phone numbers), the CDK identifies which
active row this is (the phone number itself, possibly with a type
code) and the payload is a separate descriptive attribute (e.g.,
customer name). For sat_concept_canonical the raw concept_name
IS both the active-row identifier AND the audit-lineage attribute
being preserved — there's no separate descriptive payload that
varies per active row (business_area in the seed is 1:1 with
canonical_concept, which is a parent-level attribute and would
belong on a regular sat on hub_concept, not on this MAS). The
hashdiff is therefore structurally constant per (parent, CDK)
pair by construction — once a (canonical, raw_tag) pair is
observed, that pair's hashdiff never changes. The SCD-2 mechanic
still fires correctly on the (parent, CDK) uniqueness branch
(new pair = new row inserted), but the hashdiff-change branch
won't fire in practice. The hashdiff column is kept anyway for
project-wide visual consistency with sessions 6/7/8 satellites
plus future-proofing if descriptive payload attributes are ever
added (e.g., a future per-raw-tag deprecation_date).

**Risk 18 — CDK selection priority: stable type code over
sub-sequence.** Banked 2026-05-29 at the session 9 forward-verify
pass. Scalefree's multi-active-satellites Part 1 explicitly
prioritises a stable source-provided "type code" (e.g., phone
type: 'home'/'business'/'cell') over the sub-sequence-number
fallback. Sub-sequence auto-numbering is the FALLBACK pattern
for sources that don't provide a stable identifier. Raw XBRL
US-GAAP tag names are stable taxonomy identifiers — they don't
drift between extracts for the same logical concept (a 10-K
filed under 'Revenues' in 2017 is still tagged 'Revenues' on
every re-extract today). The CDK is therefore SHA-256 of raw
concept_name directly:

```sql
to_hex(sha256(to_utf8(CAST(concept_name AS varchar)))) AS sub_sequence_key
```

Auto-numbering rejected: fragile if seed reordered, not
source-faithful, would re-shuffle CDK assignments on every dbt
refresh corrupting the audit lineage.

**MAS-specific surrogate hash key construction.** The session
6/7/8 sat hash chain over (parent_hk || '||' || load_datetime)
extends to 3 components for MAS by adding the CDK between:

```sql
to_hex(sha256(to_utf8(
    CAST(hub_concept_hk AS varchar) || '||' ||
    CAST(sub_sequence_key AS varchar) || '||' ||
    CAST(load_datetime AS varchar)
))) AS sat_concept_canonical_hk
```

Visual consistency with the rest of the warehouse-layer surface
(every model has one column named `<class>_<entity>_hk` that's
its single-column unique_key) is preserved; the natural-PK
contract (hub_concept_hk, sub_sequence_key, load_datetime) is
enforced at test time via the 3-column
dbt_utils.unique_combination_of_columns rather than at the
engine-level unique_key.

**MAS-adapted SCD-2 anti-join filter.** Session 6's sat anti-join
filter (Risk 9) partitioned the window by parent_hk alone. For
MAS, "the latest stored row per parent" doesn't make sense
because the parent has multiple concurrent active rows. The
partition extends to (parent_hk, sub_sequence_key) — the
active-row PK:

```sql
WHERE NOT EXISTS (
    SELECT 1
    FROM (
        SELECT
            hub_concept_hk,
            sub_sequence_key,
            hashdiff,
            ROW_NUMBER() OVER (
                PARTITION BY hub_concept_hk, sub_sequence_key
                ORDER BY load_datetime DESC
            ) AS rn
        FROM {{ this }}
    ) latest
    WHERE latest.hub_concept_hk = inbound.hub_concept_hk
      AND latest.sub_sequence_key = inbound.sub_sequence_key
      AND latest.hashdiff = inbound.hashdiff
      AND latest.rn = 1
)
```

Without sub_sequence_key in the partition and match clause, every
newly-extracted raw tag for the same canonical would compare
against the wrong row's latest hashdiff — either re-inserting
duplicates or skipping valid new rows. The MAS-adapted filter
preserves the SCD-2 contract per-active-row.

**First dbt run delivered exactly as predicted.** `dbt run --select
sat_concept_canonical` returned `OK 8 in 11.33s` — matching the
forward-verify probe-2 cardinality prediction on the first try.
The Risk 12 + Risk 13 + Risk 16 carry-forwards (cardinality
discipline + empirical probe + post-canonical DISTINCT) all
earned their keep at design time, not first-run time.

### 8.21 Verification surface for sat_concept_canonical

One new verify file extending the established per-model pattern,
sized slightly heavier than the standard sat verify because MAS
carries an extra hash column (sub_sequence_key) plus an
MAS-specific cardinality invariant guard:

- `sql/verify/10_phase2_warehouse_sat_concept_canonical_verification.sql`
  — 14 CTE PASS/FAIL checks: sat hash unique + not_null + length
  64, hashdiff not_null + length 64, sub_sequence_key not_null +
  length 64, FK closure to hub_concept, 3-column composite natural
  PK uniqueness, MAS cardinality invariant (distinct (parent_hk,
  sub_sequence_key) count = 8), parent coverage (5 distinct
  canonicals), sat_hk + hashdiff determinism on canonical
  'revenue' + raw tag 'Revenues' anchor sample, record_source
  constant. 14/14 PASS in 1.84 sec.

**Idempotency proven.** Second `dbt run --select sat_concept_canonical`
returned `OK 0 in 25.72s` — the MAS NOT EXISTS anti-join filter
excluded all 8 inbound rows because for every (parent, CDK) pair
already stored, the degenerate hashdiff matches the latest
stored hashdiff by construction (Risk 17 behavior). The SCD-2
contract works as designed; future loads of the same canonical
seed mapping will continue to no-op as expected.

**Cumulative warehouse-layer verification surface at session 9
close:** 3 hubs (hub_company + hub_filing + hub_concept) + 2 links
(link_company_filing + link_filing_concept_period) + 4 sats
(sat_filing_metadata + sat_company_metadata + sat_concept_value
+ sat_concept_canonical) = **88 dbt schema tests PASS** (77
cumulative through session 8 + 11 new), **90 SQL structural
verify checks PASS** (76 cumulative through session 8 + 14 new).

The raw vault now carries both the fact-value layer
(sat_concept_value with MIN-collapsed canonical values) AND the
audit-lineage layer (sat_concept_canonical with raw-tag
provenance for every canonical observed in source). The two
satellites together make the canonical-collapse decision fully
auditable — analysts get clean continuous time series via
canonical_concept; regulators get raw-tag traceability via
sub_sequence_key. Both queries hit the same hub_concept and
share the same DV2.0 audit-lineage contract.

### 8.22 Business Vault layer — PIT + Bridge query helpers (Phase 2 session 10)

The Raw Vault (sessions 4-9) records the authoritative SEC EDGAR
data with full DV2.0 audit-lineage semantics — hubs for entity
identity, links for relationships, satellites for change history.
Reading the Raw Vault for analytical queries works but pays a
JOIN tax: every Phase 4 mart_pl_trend or mart_peer_benchmark
query traverses hub_company → link_company_filing → hub_filing →
link_filing_concept_period → hub_concept + sat_concept_value to
pull a single (company, concept, period, value) tuple — five
table joins for one fact.

The **Business Vault** is the Scalefree-canonical layer between
the Raw Vault and Phase 4 information marts that flattens those
joins into pre-computed query helpers. Two object classes:

- **PIT (Point-In-Time) tables** — per-as-of-date snapshots that
  pre-resolve "for parent X at this snapshot date, which satellite
  row's coordinates apply?" Replaces the SCD-2 latest-row anti-join
  every mart query would otherwise repeat at runtime with a single
  equi-join lookup.
- **Bridge tables** — pre-computed hub-link-hub navigation paths
  for a given as-of-date. Replaces the multi-link walk with a
  single table scan.

Both rebuilt on every dbt run (not historized — they're query
helpers, not source of truth). Both source-driven exclusively
from the Raw Vault (no new source data; pure derivations).

**Three forward-projected risks banked at the kickoff forward-verify
pass** (BEFORE code shipped), each refining the locked direction:

- **Risk 19** — PIT pattern's value materializes at 2+ sats per
  parent. Our Raw Vault is single-sat per parent everywhere.
  Decision: ship ONE PIT against the most-consumed parent (link
  spine + sat_concept_value), framed honestly as
  demonstrative-of-pattern rather than padding-the-warehouse.
- **Risk 20** — AutomateDV's Bridge structure assumes Effectivity
  Satellites per link relationship; we don't ship eff_sats
  (insert-only links, no end-date semantics). Scalefree Bridge
  Tables 101 confirms the simpler shape is correct fit.
- **Risk 21** — As-of-dates list cardinality directly multiplies
  PIT/Bridge row counts. Picked fiscal-year-end (10 rows) over
  fiscal-quarter-end (38 rows) — ~600K-row artefacts vs 3.4M+,
  matches Phase 4 annual mart query patterns.

A fourth Risk surfaced during the model-body design phase:

- **Risk 22** — Ghost-record pattern (zero hash key + epoch ldts
  for "no sat at as-of-date") deferred indefinitely; retrofitting
  to 4 already-shipped sats was out-of-scope. Hand-rolled
  substitute: LEFT JOIN + NULL on sat-side columns; Phase 4
  marts handle the NULL via standard COALESCE.

And a fifth, structurally significant — surfaced during the model-body
sat-coordinate resolution phase:

- **Risk 23** — The project's `load_datetime` captures dbt-run wall
  clock time (every row stamped May 2026), not the SEC filing's
  observation date. Naively applied to a canonical PIT with
  `MAX(sat.load_datetime) <= as_of_date`, every as_of_date 2016-2025
  resolves to ZERO visible rows. Decision: PIT and Bridge join
  through `hub_filing → sat_filing_metadata` to access `filed_date`
  and use `filed_date <= as_of_date` as the visibility filter.
  Documented as a project-specific deviation from canonical PIT
  semantics; load_datetime is preserved on the BV rows as the
  canonical lineage column.

**The as-of-dates spine — `dim_as_of_dates`.** A 10-row
`VALUES`-driven model carrying fiscal year-end dates 2016-12-31
through 2025-12-31. Both PIT and Bridge cross-join against this
spine to materialize the temporal-snapshot dimension. Materialized
as a plain Iceberg table (full rebuild every run).

### 8.23 PIT walkthrough — pit_link_filing_concept_period

Single-sat PIT on the project's most-queried Raw Vault object.
Per row: `(link_filing_concept_period_hk, as_of_date,
sat_concept_value_pk, sat_concept_value_ldts)` plus the single-column
surrogate `pit_link_filing_concept_period_hk` (SHA-256 of the
composite). Composite natural PK
`(link_filing_concept_period_hk, as_of_date)` enforced at test time.

Model body in 4 CTEs:

1. **as_of** — `SELECT as_of_date FROM dim_as_of_dates` (10 rows).
2. **link_with_filed_date** — inner-join `link_filing_concept_period`
   to `sat_filing_metadata` via `hub_filing_hk` to bring `filed_date`
   onto each link row. 1:1 join (sat_filing_metadata is 1:1 with
   hub_filing per session 6) — no cardinality fan-out.
3. **sat_coordinates** — `CROSS JOIN as_of × link_with_filed_date`,
   then `LEFT JOIN sat_concept_value ON link_pk`, filtered to
   `filed_date <= as_of_date`. LEFT JOIN is the ghost-record-deferral
   substitute (Risk 22).
4. **hashed** — compute the surrogate PIT hash via SHA-256 over
   the composite, project final shape with `load_datetime` and
   `record_source`.

Build result: **OK 634,431 rows in 29.96s** on session 10's first
dbt run. The 70.6% theoretical-max ratio (634,431 / 898,210)
reflects the `filed_date <= as_of_date` filter correctly excluding
filings filed after each early-decade as_of_date.

### 8.24 Bridge walkthrough — bridge_company_concept_period

Bridge spans the 5-hop hub-link-hub walk: hub_company →
link_company_filing → hub_filing → link_filing_concept_period →
hub_concept. Per row: 3 hub hash-key FKs + 2 link hash-key FKs +
3 period-payload columns (period_end_date, fiscal_year,
fiscal_period) + as_of_date + lineage. Single-column surrogate
`bridge_company_concept_period_hk` (4-component composite SHA-256:
hub_company_hk + link_company_filing_hk + link_filing_concept_period_hk
+ as_of_date). Composite natural PK
`(link_filing_concept_period_hk, as_of_date)` — the link PK
already captures the 7-column (cik, accession, canonical, period_*)
composite, so combining with as_of_date is uniquely identifying.

Model body in 5 CTEs:

1. **as_of** — same as PIT.
2. **link_with_filed_date** — same as PIT.
3. **link_walk** — inner-join `link_with_filed_date` to
   `link_company_filing` on the composite `(hub_company_hk,
   hub_filing_hk)` to bring `link_company_filing_hk` onto each row.
   1:1 join (link_company_filing is 1:1 with (cik, accn) per
   session 5).
4. **bridge_rows** — `CROSS JOIN link_walk × as_of`, filtered to
   `filed_date <= as_of_date`. Every row = "this (company, filing,
   concept, period) relationship was visible at this as_of_date."
5. **hashed** — compute the surrogate bridge hash via SHA-256
   over the 4-component composite, project final shape.

Build result: **OK 634,431 rows in 30.27s** on session 10's first
dbt run — identical count to the PIT by construction (both share
the same link × as_of_date × filed_date visibility filter, differing
only in projection).

### 8.25 Verification surface for Business Vault + cumulative stats

Three model contracts shipped in `dbt/models/business_vault/_models.yml`:

- **dim_as_of_dates** — 6 schema tests (as_of_date unique + not_null;
  as_of_datetime, fiscal_year_end, load_datetime, record_source
  not_null).
- **pit_link_filing_concept_period** — 9 schema tests (8 column-level
  including sat_concept_value_pk LEFT-JOIN-nullable per Risk 22,
  plus model-level `dbt_utils.unique_combination_of_columns` on the
  composite natural PK).
- **bridge_company_concept_period** — 18 schema tests (17 column-level
  including 5 FK `relationships` tests covering full hub-link-hub
  closure, plus model-level composite-PK test).

**33/33 dbt schema tests PASS** on the 3 new models in 39.34 sec.

Two new verify files extending the established CTE PASS/FAIL pattern:

- `sql/verify/11_phase2_business_vault_pit_verification.sql` — 11 checks:
  pit_hk unique + not_null + length 64, FK closures to link + as_of_dates,
  composite PK uniqueness, distinct as_of_date count = 10, monotonic
  coverage sanity (first as_of_date row count ≤ last), pit_hk
  determinism on Apple sample, non-null sat FK closure, record_source
  constant. **11/11 PASS in 3.85 sec.**
- `sql/verify/12_phase2_business_vault_bridge_verification.sql` — 13
  checks: bridge_hk unique + not_null + length 64, FK closures to 3
  hubs + 2 links + dim_as_of_dates (6 FK closures total), composite
  PK uniqueness, distinct as_of_date count = 10, bridge_hk determinism
  on Apple sample, record_source constant. **13/13 PASS in 7.96 sec.**

**Idempotency proven.** Third `dbt run` rebuilt all 3 BV models
with identical 634,431 row counts on both PIT and Bridge. Table
materialization (not Iceberg-merge incremental) means rebuild is
the only path — by construction, hash determinism + deterministic
JOIN + deterministic WHERE filter guarantee byte-identical content
across runs. Structurally avoids Risk 2 (Iceberg merge +
on_schema_change duplicate-insertion bug) because no merge happens.

**Cumulative warehouse + business-vault layer at session 10 close:**

- 3 hubs + 2 links + 4 sats (Raw Vault) + 1 dim + 1 PIT + 1 Bridge
  (Business Vault) = **11 models**
- **121 dbt schema tests PASS** (88 cumulative through session 9 +
  33 new — 6 dim + 9 PIT + 18 Bridge)
- **114 SQL structural verify checks PASS** (90 cumulative through
  session 9 + 24 new — 11 PIT + 13 Bridge)

The Business Vault layer is the bridge between DV2.0's audit-lineage
contract and downstream analytical convenience. Phase 4 marts will
join through the BV layer instead of walking the Raw Vault, collapsing
5-hop traversals to single equi-joins while preserving the Raw
Vault's immutable history underneath. The trade-off is honest:
634K-row BV artefacts cost storage to save query compute — a worthwhile
trade at the analytical layer, irrelevant at the audit layer.

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

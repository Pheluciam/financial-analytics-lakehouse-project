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

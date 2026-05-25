# Extract Pipeline — SEC EDGAR → S3 Bronze

> Walkthrough for the Phase 1 extract pipeline. Companion to
> `scripts/extract_sec_edgar.py` (session 2 deliverable) and
> `scripts/smoke_test_aws.py` (session 1 deliverable).
>
> Status: STUB. Authored 2026-05-23 (Phase 1 session 1). Expanded in
> session 2 as the extract script is built and tested at the 1 → 10 → 100
> step-up.

---

## 1. What this pipeline does

(Expanded in session 2)

- Ingests SEC EDGAR XBRL financial-fact data for the S&P 100 (current roster).
- Lands raw JSON on S3 under
  `zone=bronze/extract_date=YYYY-MM-DD/cik=XXXXXXXXXX/`.
- Polite rate-limited (≤10 req/sec safe ceiling, exponential backoff,
  User-Agent header set per SEC policy).
- Append-only by extract_date partition — re-extracts don't overwrite
  history. Bronze IS the system of record per demo-durability principle 1.

## 2. Architecture

```
SEC EDGAR API (HTTPS, public, 10 req/sec safe ceiling)
        |
        |  scripts/extract_sec_edgar.py — polite rate limiter,
        |  exponential backoff + retry, step-up tested 1 → 10 → 100
        v
[ S3 Bronze ]   zone=bronze/extract_date=YYYY-MM-DD/cik=XXXXXXXXXX/
```

## 3. Session 1 deliverables — what landed in this session

- AWS account + Admin IAM user `phil-admin` (with MFA + programmatic
  access keys in `.env`) + $5 monthly budget tripwire.
- S3 bucket `phil-financial-analytics-lakehouse` in `us-east-1` with
  versioning + SSE-S3 encryption + block-all-public-access. Three
  prefix folders: `zone=bronze/`, `zone=silver/`, `zone=gold/`.
- `.env` populated with `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`,
  `AWS_DEFAULT_REGION` (`us-east-1`), `S3_BUCKET_NAME`
  (`phil-financial-analytics-lakehouse`), `SEC_EDGAR_USER_AGENT`.
- GitHub repo `Pheluciam/financial-analytics-lakehouse-project` (public)
  + local `git init` + `origin` remote wired + default branch `main`.

## 3a. `scripts/smoke_test_aws.py` — shipped session 2 (2026-05-24)

The smoke test for the AWS auth + S3 stack. Built before the SEC EDGAR
extract because the extract depends on the same boto3 + IAM + S3 chain
working. Mirrors the `smoke_test_azure_sql.py` pattern from Project #2.

**What it proves, in order:**

1. **`.env` load + required env vars present.** Fails loud with the named
   missing var(s) if any of `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`,
   `AWS_DEFAULT_REGION`, `S3_BUCKET_NAME` are absent.
2. **Auth — `sts:GetCallerIdentity`.** Cheapest possible "are these
   credentials valid?" call. Returns the IAM ARN + account ID — confirms
   we're authenticated as `phil-admin` against account `470439680370`.
3. **Bucket reachable — `head_bucket`.** Confirms the bucket exists AND
   `phil-admin` has permission to see it (one call validates both).
4. **Round-trip — `put_object` → `get_object` → `delete_object`.**
   End-to-end read/write proof. Writes a tiny UUID-stamped object under
   `health_checks/smoke_test_aws/`, reads it back, asserts byte-for-byte
   content match, deletes the current version.

**Design calls locked at build time:**

- **Error handling — structured logging with specific exception classes.**
  Caught by name: `NoCredentialsError`, `PartialCredentialsError`,
  `EndpointConnectionError`, `ClientError` (further differentiated by AWS
  error code). Each failure category maps to a distinct non-zero exit
  code (auth = 2, bucket = 3, network = 4, round-trip = 5, unexpected = 1).
  Future CI can act on the code. Underlying error always logged — never
  swallowed.
- **Scratch key location — dedicated `health_checks/smoke_test_aws/`
  prefix.** Keeps `zone=bronze/` pristine — only real SEC EDGAR data
  lands there. UUID + UTC timestamp in the key prevents concurrent-run
  collisions. Object tagged `Purpose=SmokeTest&Component=smoke_test_aws`
  so a future lifecycle policy can sweep it.
- **Versioning cleanup — clean current-version delete now, lifecycle
  policy banked for Phase 6.** S3 versioning leaves a delete-marker
  behind on `delete_object`. The Python script does NOT chase the
  versioned debris — that's a separation-of-concerns play. Bucket-side
  retention belongs to a bucket-side lifecycle policy, not script logic.
  Phase 6 will add a policy on the `health_checks/` prefix to auto-expire
  current + noncurrent versions. Documented in the script's docstring.

**Run:**

```powershell
python scripts/smoke_test_aws.py
```

**Expected output on a healthy stack** (timestamps will differ):

```
14:30:18 INFO    AWS smoke test starting
14:30:18 INFO    Region: us-east-1 | Bucket: phil-financial-analytics-lakehouse
14:30:19 INFO    [OK] Auth: arn:aws:iam::470439680370:user/phil-admin (account 470439680370)
14:30:19 INFO    [OK] Bucket reachable: phil-financial-analytics-lakehouse
14:30:20 INFO    [OK] put_object: s3://phil-financial-analytics-lakehouse/health_checks/smoke_test_aws/20260524T043020Z_<uuid>.txt
14:30:20 INFO    [OK] get_object: content matches (28 bytes)
14:30:20 INFO    [OK] delete_object: health_checks/smoke_test_aws/20260524T043020Z_<uuid>.txt
14:30:20 INFO    [OK] All checks passed
```

Exit code `0` on success. See script docstring for non-zero exit code
meanings.

## 4. `scripts/extract_sec_edgar.py` — shipped session 2 (2026-05-24)

First draft of the SEC EDGAR companyfacts extract. 1-company test against
Apple Inc (CIK 320193) PASSED — ~3.6 MB raw JSON landed to Bronze with
sha256 fingerprint stamped in object metadata. 10 + 100 company scale-up
deferred to later sessions per the step-up testing protocol (section 7).

**What it does, in order:**

1. **CLI parse — argparse `--cik`.** Accepts one or more CIKs. Defaults to
   Apple (CIK 320193) when no flag passed — makes the 1-company test
   trivial.
2. **`.env` load + required env vars present.** Five required: the four
   AWS vars plus `SEC_EDGAR_USER_AGENT`.
3. **AWS bucket reachable — `head_bucket`.** Pre-flight check before any
   SEC API call. Fails loud if AWS auth or bucket permissions broken
   BEFORE we hit SEC's rate limiter.
4. **HTTP session with polite UA + bounded retry.** `requests.Session`
   mounted with `urllib3.Retry` adapter — retries on 429 / 5xx / transport
   failures with exponential backoff (~1s, 2s, 4s, 8s, 16s), bounded to
   5 attempts. User-Agent header from `SEC_EDGAR_USER_AGENT`.
5. **Per-CIK loop with polite rate limiter.** Sleep-based limiter ensures
   minimum 0.12s gap between requests (~8 req/sec actual; SEC ceiling is
   10). Fetch the CIK's companyfacts JSON, validate it's parseable, land
   to S3 Bronze.
6. **S3 put with metadata + tags.** Key shape:
   `zone=bronze/extract_date=YYYY-MM-DD/cik=XXXXXXXXXX/companyfacts.json`
   (10-digit CIK pad). Object metadata stamped with cik, source,
   extracted-at, sha256. Tags: `Purpose=Extract&Source=SECEDGAR&Component=extract_sec_edgar`.

**Design calls locked at build time (senior-DE defaults):**

- **Endpoint scope — companyfacts only.** Submissions and frames endpoints
  become sibling extracts in later sessions; first draft stays focused on
  the canonical "all XBRL facts per company" endpoint.
- **CLI default — Apple (CIK 320193).** Makes 1-company test friction-free.
- **JSON byte-for-byte preserved on landing.** Bronze IS the system of
  record (demo-durability principle 1). No pretty-print, no shape changes
  — exactly what SEC returned. Pretty-print is a Silver concern.
- **`urllib3.Retry` via `HTTPAdapter`** — standard pattern, less custom
  code than a handwritten retry loop, well-documented.
- **Sleep-based limiter over token bucket** — single-threaded extract loop,
  no concurrent workers competing for shared quota, formal algorithm earns
  nothing extra. Sleep 0.12s minimum between requests is simpler and
  auditable.
- **sha256 fingerprint in S3 object metadata** — content-addressable
  lineage. Silver layer can detect "has this file changed since I last
  processed it?" by comparing hashes without reading the body.
- **Fail-fast on first CIK error** — for 1-company test this is the right
  default. For 100-company runs we'd add `--continue-on-error` later.
- **8 exit codes** — auth (2), bucket (3), network (4), HTTP 4xx (5),
  bad response (6), S3 put (7), unexpected (1), OK (0). Future Step
  Functions can branch on these.

**Run examples:**

```powershell
python scripts/extract_sec_edgar.py
```

```powershell
python scripts/extract_sec_edgar.py --cik 320193
```

```powershell
python scripts/extract_sec_edgar.py --cik 320193 --cik 789019
```

**1-company test result (2026-05-24, 12:26 local):** Apple Inc landed to
`s3://phil-financial-analytics-lakehouse/zone=bronze/extract_date=2026-05-24/cik=0000320193/companyfacts.json`
(3,748,682 bytes, sha256 prefix `31f9ab439840`). End-to-end run ~4 seconds.
10-criteria audit: 10/10 PASS.

## 5. SEC EDGAR API contract

- **Primary endpoint (shipped this session):**
  `https://data.sec.gov/api/xbrl/companyfacts/CIK##########.json` — all
  XBRL facts per company across all filings.
- **Submissions endpoint (deferred — sibling extract):**
  `https://data.sec.gov/submissions/CIK##########.json` — filing history
  metadata.
- **Frames endpoint (deferred — Phase 4 peer-benchmarking mart):**
  `https://data.sec.gov/api/xbrl/frames/<concept>/<unit>/<period>.json`
  — one fact across all companies for a reporting period.
- **Ticker → CIK lookup (deferred — needed for the 100-company list):**
  `https://www.sec.gov/files/company_tickers.json`.
- **User-Agent (locked Phase 0 decision #8):** `Phil <pheluciam@outlook.com>`.
- **Rate limit:** 10 req/sec safe ceiling per IP.
- **Authentication:** none (free, no API key).
- **Response format:** JSON, minified (no whitespace).
- **Response size:** Apple's companyfacts ~3.6 MB (single-company shape,
  ~200-300 concepts × ~40 filings × 10 years of history). Larger and
  smaller companies will vary.

## 6. Polite rate limiter design

**Implementation — sleep-based, single-threaded.** Module constant
`MIN_INTERVAL_SECONDS = 0.12`. Before each `session.get(url)` call, compute
`elapsed = time.monotonic() - last_request_time`; if `elapsed <
MIN_INTERVAL_SECONDS`, sleep the difference. `last_request_time` is held
in a 1-element list so the clock survives across function calls (mutable
closure pattern).

**Why 0.12s not 0.10s.** SEC's ceiling is 10 req/sec (= 0.10s gap). Running
at the ceiling leaves zero headroom for jitter, clock drift, or
adversarial-load scenarios. 0.12s = ~8 req/sec actual, 80% utilisation.
Standard senior-DE practice: never run at the ceiling.

**Why sleep-based over token bucket.** Token bucket earns its keep when
concurrent workers compete for shared quota. The extract loop is
single-threaded — one CIK at a time. The formal algorithm adds complexity
with no benefit at this concurrency level. Sleep-based is simpler,
auditable, and provably correct.

**Retry tuning — `urllib3.Retry` via `HTTPAdapter`.** Total 5 attempts,
backoff factor 1.0 (waits ~1s, 2s, 4s, 8s, 16s between attempts), retry
on status codes `(429, 500, 502, 503, 504)`, allowed methods `frozenset(["GET"])`,
`raise_on_status=False` so the script can branch on final status itself.

## 7. Step-up testing protocol

Per ENGINEERING_STANDARDS.md criterion 9 + LEARNINGS.md Project #2 carry-forward.

1. **1 company — SHIPPED 2026-05-24.** Apple Inc, CIK 320193. PASSED.
   Rate limiter behaved against real SEC, JSON shape validated, S3
   landing partition correct, sha256 fingerprint preserved.
2. **10 companies — SHIPPED 2026-05-25.** Sector-diverse selection across
   financials (JPM 19617, BAC 70858), tech (MSFT 789019, NVDA 1045810),
   healthcare (JNJ 200406, UNH 731766), energy (XOM 34088, CVX 93410),
   consumer (WMT 104169, PG 80424). Wall-clock ~12-15 seconds for all 10
   fetches at 0.12s rate-limit interval. Rate limiter held cleanly — no
   429s, no SEC rejections. Per-CIK loop scaled linearly. All 11 partition
   combos (10 from today + Apple from session 2) discoverable through
   partition projection on the Bronze table (see section 9 below).
3. **100 companies — next session.** Full S&P 100 roster (current
   mid-2026 constituents). Final extract. Bronze freezes on this
   snapshot per demo-durability principle 1.

## 8. Glue Crawler attempt and pivot to manual DDL (session 3, 2026-05-25)

The plan at session 3 kickoff was Crawler-first → SQL-via-Athena verification
(Option A from the kickoff branch-point). Bootstrap succeeded; the Crawler
run against Bronze failed; the architectural lesson drove a pivot to manual
DDL with the Crawler infrastructure kept as scaffolding for future Silver
and Gold layers.

**Infrastructure shipped (kept post-pivot).**

- IAM role `AWSGlueServiceRole-financial-analytics-lakehouse` — managed
  `AWSGlueServiceRole` policy + custom inline policy `S3ReadAccess-financial-analytics-lakehouse`
  scoping read access to our bucket only. ARN
  `arn:aws:iam::470439680370:role/AWSGlueServiceRole-financial-analytics-lakehouse`.
- Glue database `financial_analytics_bronze` — namespace container for
  Bronze tables.
- Glue Crawler `crawler_bronze_sec_edgar` — S3 source `zone=bronze/`,
  on-demand schedule (per demo-durability principle 2), table prefix
  `sec_edgar_`.

**Crawler run result — FAILED at 49 seconds, 0.223 DPU-hours.** Error:
`com.amazonaws.services.glue.model.ValidationException: Value at 'table.storageDescriptor.columns.3.member.type' failed to satisfy constraint: Member must have length less than or equal to 131072`.
Failing table: `sec_edgar_cik_0001045810` (NVIDIA). 6 partial tables
created before bail; partitions not unified.

**Root cause.** Glue Catalog has a hard 131,072-character (128 KB) ceiling
on each column's type-definition string. SEC EDGAR's `facts` field is a
deeply nested struct — `facts.us-gaap.*` enumerates hundreds of XBRL
concepts per company, and the concept set DIFFERS per company. When the
Crawler tried to express NVIDIA's `facts` as a strongly-typed nested
struct, the type string blew past 128 KB and the Catalog rejected the
write.

**Pivot decision.** No Crawler config can fit NVIDIA's full inferred
schema — the limit is architectural, not configurable. Two cleanup steps:
(a) dropped the 6 polluted Crawler-created tables via `DROP TABLE`
statements through the new Athena workgroup; (b) authored manual
`CREATE EXTERNAL TABLE` DDL with the heterogeneous `facts` field
intentionally excluded (see section 9).

**Crawler retention rationale.** The Crawler stays in place because future
Silver and Gold layers will land Parquet files with dbt-controlled schemas
— no heterogeneity, no 128 KB risk. Re-pointing this same Crawler at
`zone=silver/` and `zone=gold/` in later phases will work cleanly. The
IAM role + database + Crawler infrastructure is reusable scaffolding,
not session-3 dead weight.

Full lesson banked in LEARNINGS.md "Glue Crawler fails on heterogeneous
JSON via the 128 KB column-type-definition limit (2026-05-25, Phase 1
session 3)".

## 9. Manual Bronze DDL design (session 3, 2026-05-25)

**Goal.** Query Bronze partitions from Athena despite SEC EDGAR JSON's
schema heterogeneity. The Bronze layer's job is to make raw landings
queryable enough to VERIFY (partition presence, JSON parseability,
expected entities present); deep structured access to `facts` is a Phase 2
Silver concern where dbt-athena models handle it via `json_extract_*`
functions on the raw files.

**File:** `sql/ddl/01_create_bronze_tables.sql`. CREATE EXTERNAL TABLE
`financial_analytics_bronze.sec_edgar_companyfacts`. Idempotent with a
DROP IF EXISTS guard for re-runs.

**Design calls (senior-DE defaults).**

- **Single data column: `entityname` (string).** Universal across all
  companies — every companyfacts.json has a top-level `entityName`. SerDe
  mapping `'mapping.entityname' = 'entityName'` preserves the camelCase
  reference to the JSON field through Hive's default lowercasing.
- **`facts` column intentionally excluded.** The heterogeneous deep struct
  is what broke the Crawler; excluding it from Bronze avoids the 128 KB
  type-definition issue entirely. Phase 2 Silver dbt models will use
  `json_extract_scalar(read_file('s3://.../companyfacts.json'), '$.facts.us-gaap.<concept>...')`
  patterns to access the data when normalizing into hubs/links/satellites.
- **openx JsonSerDe.** Athena's canonical JSON SerDe. Permissive struct
  handling, supports case-mapping; `ignore.malformed.json = false`
  surfaces bad files loudly rather than silently skipping.
- **Partition projection.** TBLPROPERTIES `projection.enabled = true`
  with two partition columns: `extract_date` (type=date, range
  `2026-05-24,NOW`, format `yyyy-MM-dd`) + `cik` (type=injected). The
  `storage.location.template` reconstructs S3 paths from partition values.
  No `MSCK REPAIR` or `ALTER TABLE ADD PARTITION` needed when new
  extract_date partitions land — Athena infers them at query time from
  the date range.
- **`injected` projection on cik.** Queries against this table MUST
  include a WHERE filter on `cik` — Athena won't enumerate cik values
  automatically (the cardinality is too high for static enumeration).
  This is documented standard Athena behavior; the verification suite
  filter handles this naturally.

**Smoke check result (post-DDL run).** Query
`SELECT extract_date, cik, entityname FROM financial_analytics_bronze.sec_edgar_companyfacts WHERE cik IN (...) ORDER BY cik`
returned 11 rows: Apple (CIK 0000320193) at extract_date 2026-05-24,
other 10 at 2026-05-25, all entity names correct. NVIDIA — the company
whose facts struct broke the Crawler — reads cleanly through the manual
DDL.

10-criteria audit: 10/10 PASS.

## 10. Athena workgroup and Bronze verification suite (session 3, 2026-05-25)

**Workgroup `wg_financial_analytics`.** Dedicated workgroup for the
project — isolates query costs, scanned bytes, and CloudWatch metrics
from the default `primary` workgroup. ARN
`arn:aws:athena:us-east-1:470439680370:workgroup/wg_financial_analytics`.

Settings:

- Query result location: `s3://phil-financial-analytics-lakehouse/athena-results/`
  (Customer managed; separate prefix from data zones).
- Override client-side settings: ON. Forces every query through workgroup
  settings even when invoked via boto3/JDBC.
- Engine: Athena engine version 3 (current generation).
- Authentication: IAM.
- Per-query bytes-scanned hard cap: DEFERRED. AWS UI surfaces only soft
  CloudWatch alerts at workgroup level in the modern Console; the
  historical hard cap moved to post-creation edit path. Acceptable at our
  30-300 MB bucket scale (a pathological full-bucket scan still costs
  pennies); Phase 6 polish if data crosses GB territory.

**Bronze verification suite — `sql/verify/01_phase1_bronze_verification.sql`.**
CTE-based PASS/FAIL pattern carried from Project #2 LEARNINGS. Single-query
suite with 6 checks against `financial_analytics_bronze.sec_edgar_companyfacts`:

| # | Check | Expected | Validates |
|---|---|---|---|
| 1 | total_row_count | 11 | All CIK partitions discoverable via projection |
| 2 | distinct_cik_count | 11 | No partition duplicates |
| 3 | extract_date_count | 2 | Multi-session partition split working |
| 4 | today_row_count | 10 | Today's 10-company batch landed complete |
| 5 | yesterday_row_count | 1 | Apple from session 2 still readable through new DDL |
| 6 | non_null_entitynames | 11 | JSON parseability for every file (no malformed-JSON skip) |

**Run result.** All 6 PASS on first run. 1.181 sec runtime, 241.5 KB
scanned. 10-criteria audit: 10/10 PASS.

**Out of scope (deferred).**

- S3 object byte-count verification — lives in S3 object metadata
  (`Content-Length` header on each object), not in the JSON content
  Athena reads. Requires a boto3-based check via `list_objects_v2` +
  `head_object`. Deferred to next session.
- sha256 fingerprint uniqueness per CIK — same constraint; lives in the
  S3 object metadata Phil's extract script stamps during put. Deferred
  to the same next-session boto3 script.

The deferred boto3 verification + the SQL verification suite together
form the full Phase 1 Bronze verification surface. Both will be referenced
at Phase 1 close-out (next session) before declaring Phase 1 ship-ready.

## 11. References

- SEC EDGAR API docs: `https://www.sec.gov/edgar/sec-api-documentation`
- AWS Athena partition projection docs: `https://docs.aws.amazon.com/athena/latest/ug/partition-projection.html`
- AWS Athena openx JsonSerDe docs: `https://docs.aws.amazon.com/athena/latest/ug/openx-json-serde.html`
- AWS Glue Catalog limits (128 KB column type-definition): `https://docs.aws.amazon.com/general/latest/gr/glue.html`
- PROJECT_PLAN.md section 2 — data source overview
- PROJECT_PLAN.md section 4 decision #8 — User-Agent lock
- PROJECT_PLAN.md section 11 — data budget (2M-row Bronze cap)
- PROJECT_PLAN.md section 12 — engineering standards step-up checks
- LEARNINGS.md "Project #3 lessons" — five session 3 entries banked
- LEARNINGS.md "Carry-forward to Project #3" — step-up testing pattern
  + polite rate limiter principle
- ENGINEERING_STANDARDS.md criterion 9 — pre-flight + post-action verification
- ENGINEERING_STANDARDS.md criterion 10 — observable progress + actionable errors
- ENGINEERING_STANDARDS.md "Phase-boundary structural audit" — Phase 1 sessions 2 + 3 audits

---

*Status: Phase 1 session 3 deliverables shipped 2026-05-25 — 10-company
extract PASSED, Glue Crawler attempted-and-pivoted, Athena workgroup
`wg_financial_analytics` configured, manual Bronze DDL + verification
suite (6/6 PASS) on disk in `sql/ddl/` and `sql/verify/`. Phase 1 close-out
in session 4: 100-company full S&P 100 extract + boto3 S3 metadata
verification script + Phase 1 structural audit + Bronze freeze.*

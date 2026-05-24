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
2. **10 companies — next session.** Sector-diverse selection across
   financials, tech, healthcare, energy, consumer. Confirms limiter
   holds at moderate scale + no SEC rejections + per-CIK loop scales
   linearly.
3. **100 companies — session after that.** Full S&P 100 roster (current
   mid-2026 constituents). Final extract. Bronze freezes on this
   snapshot per demo-durability principle 1.

## 8. References

- SEC EDGAR API docs: `https://www.sec.gov/edgar/sec-api-documentation`
- PROJECT_PLAN.md section 2 — data source overview
- PROJECT_PLAN.md section 4 decision #8 — User-Agent lock
- PROJECT_PLAN.md section 11 — data budget (2M-row Bronze cap)
- LEARNINGS.md "Carry-forward to Project #3" — step-up testing pattern
  + polite rate limiter principle
- ENGINEERING_STANDARDS.md criterion 9 — pre-flight + post-action verification
- ENGINEERING_STANDARDS.md criterion 10 — observable progress + actionable errors
- ENGINEERING_STANDARDS.md "Phase-boundary structural audit" — Phase 1 session 2 audit

---

*Status: Phase 1 session 2 deliverables shipped 2026-05-24. To be expanded
further when the 10-company and full 100-company runs ship in subsequent
sessions, and when the Glue Crawler bootstrap + Bronze verification suite
(`sql/verify/01_phase1_bronze_verification.sql`) land.*

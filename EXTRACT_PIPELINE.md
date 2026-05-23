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

## 3a. Deferred from session 1 — first thing in session 2

- `scripts/smoke_test_aws.py` — boto3 → AWS auth → S3 read/write
  end-to-end value proof. Originally session 1 scope; deferred at
  mid-session scope reshape. Built before the SEC EDGAR extract since
  the extract depends on the same boto3 + auth chain working.

## 4. Session 2 deliverables — what comes next

- `scripts/smoke_test_aws.py` (carried over from session 1).
- `scripts/extract_sec_edgar.py` — first draft against single company
  (Apple Inc, CIK 320193).
- Polite rate limiter implementation (token-bucket or sleep-based; TBD at
  session 2 design time).
- Exponential backoff + retry logic with bounded attempts.
- Step-up extract testing: 1 company → 10 (sector-diverse) → full S&P 100.
- Append-only S3 landing pattern with idempotent re-runs.
- Bronze verification suite — `sql/verify/01_phase1_bronze_verification.sql`
  to be authored at session 2 close.

## 5. SEC EDGAR API contract

(Expanded in session 2)

- Primary endpoint:
  `data.sec.gov/api/xbrl/companyfacts/CIK##########.json`
- Submissions endpoint:
  `data.sec.gov/submissions/CIK##########.json` (filing history)
- Frames endpoint:
  `data.sec.gov/api/xbrl/frames/<concept>/<unit>/<period>.json`
  (cross-company snapshots — powers the peer-benchmarking mart)
- Ticker → CIK lookup: `sec.gov/files/company_tickers.json`
- User-Agent: `Phil <pheluciam@outlook.com>` (locked, PROJECT_PLAN.md
  section 4 decision #8)
- Rate limit: 10 req/sec safe ceiling
- Authentication: none (free, no API key)
- Response format: JSON; ~50–100 KB per company for companyfacts

## 6. Polite rate limiter design

(Expanded in session 2)

Carry-forward from Project #2 LEARNINGS.md "Carry-forward to Project #3":
rate limiter built into the extract from the first commit, NOT retrofitted.
Validated on the 1-company smoke before any 10- or 100-company scale-up.

## 7. Step-up testing protocol

(Expanded in session 2)

Per ENGINEERING_STANDARDS.md criterion 9 and LEARNINGS.md carry-forward:

1. **1 company.** Apple Inc, CIK 320193. Verify content, row counts,
   rate-limiter behavior, JSON shape on S3.
2. **10 companies.** Sector-diverse selection across financials, tech,
   healthcare, energy, consumer. Verify scaling characteristics + no
   rate-limit rejections.
3. **100 companies.** Full S&P 100 roster. Final extract; the snapshot
   that Bronze freezes on per demo-durability principle 1.

## 8. References

- SEC EDGAR API docs:
  `https://www.sec.gov/edgar/sec-api-documentation`
- PROJECT_PLAN.md section 2 — data source overview
- PROJECT_PLAN.md section 4 decision #8 — User-Agent lock
- LEARNINGS.md "Carry-forward to Project #3" — step-up testing pattern
  + polite rate limiter principle
- ENGINEERING_STANDARDS.md criterion 9 — pre-flight + post-action
  verification
- ENGINEERING_STANDARDS.md criterion 10 — observable progress + actionable
  errors

---

*Status: STUB authored 2026-05-23 (Phase 1 session 1). To be expanded in
Phase 1 session 2 as the extract script is built and step-up tested.*

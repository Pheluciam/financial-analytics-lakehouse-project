# AWS Lakehouse Teardown — Record

**Date:** 2026-06-29
**Account:** 470439680370 (`phil-admin`, IAM user) — AWS free plan with credits
**Trigger:** `portfolio-monthly-5usd-tripwire` budget alert fired (forecast $9.74 vs $5 threshold)

## Why

The account runs on free-tier credits (~$107 remaining, free period ends ~2026-11-23).
The build phase (Power BI complete) is paused, so the live AWS lakehouse was torn down
to **$0/month** while preserving all curated data locally for study and interview demos.
Bucket is kept (empty) so the project can be redeployed from scripts at any time.

## What the alert actually was

- The email was **genuine** — our own budget, our account (verified by decoding the
  access key offline; it matched the account ID in the email). Link never clicked.
- The $9.74 was **100% covered by credits — $0 actually owed.**
- Breakdown: S3 $6.91, Athena $2.81, Glue $0.02.
- Root cause was **S3 request cost**, not storage. Standing storage was only ~6.3 GB
  (~$0.14/mo). S3 versioning was *enabled with no lifecycle rule*, so dbt full-refreshes
  churned 3,089 silver versions + 3,367 delete markers. Silver is an Iceberg table
  (thousands of small files). Glue was idle (0 runs in 7 days).

## What was done

1. **Audited** the bucket (read-only) — `scripts/s3_teardown_audit.py`.
2. **Downloaded + verified** the curated data — `scripts/s3_teardown.py download`.
   Byte-for-byte verify, all prefixes PASS. Saved to `data_snapshot/` (gitignored).
3. **Emptied** the bucket — `scripts/s3_teardown.py empty --confirm`.
   Deleted 19,373 objects/versions/delete markers. Bucket **kept empty** (not deleted)
   for redeploy-readiness.
4. **Swept idle costs** in both regions — `scripts/account_cleanup.py audit`
   (us-east-1 + ap-southeast-2). Found **nothing billable**: 0 secrets, 0 customer KMS
   keys, 0 CloudWatch alarms. Confirmed truly ~$0.00/month.

## Current state (as of 2026-06-29)

| Item | State |
|---|---|
| S3 bucket `phil-financial-analytics-lakehouse` | **Empty**, kept, $0 storage |
| Curated data | Local: `data_snapshot/` — 768 MB, 325 files |
| └ `zone=bronze/` | 476 MB — raw SEC EDGAR filings (true source) |
| └ `zone=silver/` | 293 MB — Iceberg marts |
| └ `zone=gold/` | 0 B — Athena views (logic lives in dbt) |
| Secrets Manager / KMS customer keys / CW alarms | **None** (both regions) |
| Glue Data Catalog | Kept (free tier): bronze 2 tables, silver 24 tables |
| CloudWatch log groups | 3 × ~1 MB total (free, auto-managed) |
| **Estimated monthly cost** | **~$0.00** |

## Data safety for interviews / study

- Bronze (raw source) + silver (marts) are preserved locally and verified.
- Gold is regenerable: it's Athena views defined in the dbt project (in git).
- The dbt models, SQL, Glue/Step Functions scripts, and Power BI report remain in the
  repo — the substance an interview probes is fully intact and offline-accessible.

## How to redeploy (when needed)

1. Re-upload `data_snapshot/` back to `s3://phil-financial-analytics-lakehouse/`
   (e.g. `aws s3 sync data_snapshot/ s3://phil-financial-analytics-lakehouse/`).
2. The Glue Data Catalog tables still exist, so Athena queries work once data is back;
   otherwise re-run the dbt build to recreate marts + views from bronze.
3. Glue/Step Functions deploy via existing `scripts/` + `.github/workflows/deploy.yml`.

## Recommendation before ~Nov 2026

When credits/free period end, add an **S3 lifecycle rule** to expire non-current
versions after 1 day (or suspend versioning) before re-running the pipeline — that
prevents the version-churn request cost that triggered this in the first place.

---
*Scripts: `scripts/s3_teardown_audit.py`, `scripts/s3_teardown.py`,
`scripts/account_cleanup.py`, `scripts/aws_cost_check.sh`.*

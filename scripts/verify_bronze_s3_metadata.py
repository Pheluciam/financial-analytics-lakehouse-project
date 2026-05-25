"""Verify Bronze S3 object metadata across the SEC EDGAR companyfacts landing.

Covers what SQL/Athena can't see: per-object byte counts, sha256 fingerprint
uniqueness across CIKs, and object-level partition completeness. Pairs with
the SQL verification suite (sql/verify/01_phase1_bronze_verification.sql),
which covers JSON content; together they form the full Phase 1 Bronze
verification surface.

Run:
    python scripts/verify_bronze_s3_metadata.py
    python scripts/verify_bronze_s3_metadata.py --verbose

Exit codes:
    0 — all checks PASSED
    1 — unexpected error
    2 — credentials missing or invalid (auth failure)
    3 — bucket inaccessible
    4 — network failure reaching AWS endpoint
    5 — S3 list/head operation failed
    6 — one or more verification checks FAILED

Walkthrough: EXTRACT_PIPELINE.md section 12.
"""

from __future__ import annotations

import argparse
import logging
import os
import re
import sys
from collections import defaultdict

import boto3
from botocore.exceptions import (
    ClientError,
    EndpointConnectionError,
    NoCredentialsError,
    PartialCredentialsError,
)
from dotenv import load_dotenv

EXIT_OK = 0
EXIT_UNEXPECTED = 1
EXIT_AUTH = 2
EXIT_BUCKET = 3
EXIT_NETWORK = 4
EXIT_S3_OPERATION = 5
EXIT_VERIFICATION_FAILED = 6

BRONZE_PREFIX = "zone=bronze/"

# Phase 1 ship-state expectations at Bronze freeze.
# 100 S&P 100 today + Apple from 2026-05-24 partition = 101 objects.
EXPECTED_OBJECT_COUNT = 101
EXPECTED_DISTINCT_CIK_COUNT = 100
EXPECTED_EXTRACT_DATE_PARTITION_COUNT = 2

# Hive-style partition path written by extract_sec_edgar.py:
#   zone=bronze/extract_date=YYYY-MM-DD/cik=XXXXXXXXXX/companyfacts.json
PARTITION_KEY_RE = re.compile(
    r"zone=bronze/extract_date=(?P<extract_date>\d{4}-\d{2}-\d{2})/cik=(?P<cik>\d{10})/"
)

REQUIRED_ENV_VARS = (
    "AWS_ACCESS_KEY_ID",
    "AWS_SECRET_ACCESS_KEY",
    "AWS_DEFAULT_REGION",
    "S3_BUCKET_NAME",
)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)-7s %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("verify_bronze_s3_metadata")


def load_config() -> dict[str, str]:
    """Load .env and validate required env vars present."""
    load_dotenv()
    missing = [name for name in REQUIRED_ENV_VARS if not os.getenv(name)]
    if missing:
        log.error("Missing required env vars: %s", ", ".join(missing))
        sys.exit(EXIT_AUTH)
    return {name: os.environ[name] for name in REQUIRED_ENV_VARS}


def list_bronze_objects(s3, bucket: str) -> list[dict]:
    """Enumerate every object under zone=bronze/ via paginated list_objects_v2.

    Returns a list of {key, size, extract_date, cik} dicts. Non-conforming
    keys are logged + skipped, surfacing drift if a stray file ever lands
    outside the expected Hive-style partition shape.
    """
    paginator = s3.get_paginator("list_objects_v2")
    objects: list[dict] = []
    skipped = 0
    for page in paginator.paginate(Bucket=bucket, Prefix=BRONZE_PREFIX):
        for item in page.get("Contents", []):
            key = item["Key"]
            match = PARTITION_KEY_RE.search(key)
            if not match:
                log.warning("Skipping non-conforming key: %s", key)
                skipped += 1
                continue
            objects.append({
                "key": key,
                "size": item["Size"],
                "extract_date": match.group("extract_date"),
                "cik": match.group("cik"),
            })
    log.info("Listed %d Bronze objects (%d skipped non-conforming)", len(objects), skipped)
    return objects


def fetch_sha256(s3, bucket: str, key: str) -> str | None:
    """Read sha256 from S3 user metadata stamped by extract_sec_edgar.py."""
    try:
        response = s3.head_object(Bucket=bucket, Key=key)
    except ClientError as e:
        log.error("head_object failed for %s: %s", key, e)
        return None
    return response.get("Metadata", {}).get("sha256")


def run_checks(objects: list[dict], sha256_by_key: dict[str, str]) -> list[dict]:
    """Run the five Bronze-metadata verification checks.

    Returns a list of {check_name, expected, actual, status} dicts ready
    for tabular rendering.
    """
    distinct_ciks = {o["cik"] for o in objects}
    distinct_extract_dates = {o["extract_date"] for o in objects}
    min_size = min((o["size"] for o in objects), default=0)

    # Cross-CIK sha256 collision: if a fingerprint appears under two different
    # CIKs, two companies received the same byte stream — meaningful data
    # integrity failure that SQL/Athena cannot detect.
    cik_by_sha256: dict[str, set[str]] = defaultdict(set)
    for obj in objects:
        sha = sha256_by_key.get(obj["key"])
        if sha:
            cik_by_sha256[sha].add(obj["cik"])
    collisions = sum(1 for ciks in cik_by_sha256.values() if len(ciks) > 1)

    checks = [
        {"check_name": "check_1_object_count_total",
         "expected": EXPECTED_OBJECT_COUNT,
         "actual": len(objects)},
        {"check_name": "check_2_distinct_cik_count",
         "expected": EXPECTED_DISTINCT_CIK_COUNT,
         "actual": len(distinct_ciks)},
        {"check_name": "check_3_extract_date_partition_count",
         "expected": EXPECTED_EXTRACT_DATE_PARTITION_COUNT,
         "actual": len(distinct_extract_dates)},
        {"check_name": "check_4_min_object_size_positive",
         "expected": "> 0",
         "actual": min_size},
        {"check_name": "check_5_sha256_cross_cik_collisions",
         "expected": 0,
         "actual": collisions},
    ]
    for c in checks:
        if c["check_name"] == "check_4_min_object_size_positive":
            c["status"] = "PASS" if c["actual"] > 0 else "FAIL"
        else:
            c["status"] = "PASS" if c["actual"] == c["expected"] else "FAIL"
    return checks


def render_report(checks: list[dict]) -> str:
    """Render PASS/FAIL table mirroring the SQL verification suite output."""
    header = f"{'check_name':<40}  {'expected':>10}  {'actual':>10}  status"
    sep = "-" * len(header)
    lines = [header, sep]
    for c in checks:
        lines.append(
            f"{c['check_name']:<40}  {str(c['expected']):>10}  {str(c['actual']):>10}  {c['status']}"
        )
    return "\n".join(lines)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Verify Bronze S3 object metadata (byte counts + sha256 uniqueness).",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Print every object's key, size, and sha256 prefix.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    log.info("Bronze S3 metadata verification starting")
    config = load_config()
    region = config["AWS_DEFAULT_REGION"]
    bucket = config["S3_BUCKET_NAME"]
    log.info("Region: %s | Bucket: %s", region, bucket)

    try:
        boto_session = boto3.session.Session(region_name=region)
        s3 = boto_session.client("s3")
        s3.head_bucket(Bucket=bucket)
        log.info("[OK] Bucket reachable: %s", bucket)
    except NoCredentialsError:
        log.error("No AWS credentials resolved by boto3.")
        return EXIT_AUTH
    except PartialCredentialsError as e:
        log.error("Partial AWS credentials: %s", e)
        return EXIT_AUTH
    except EndpointConnectionError as e:
        log.error("Network failure reaching AWS endpoint: %s", e)
        return EXIT_NETWORK
    except ClientError as e:
        code = e.response.get("Error", {}).get("Code", "Unknown")
        if code in {"InvalidAccessKeyId", "SignatureDoesNotMatch", "ExpiredToken"}:
            log.error("AWS auth rejected (%s): %s", code, e)
            return EXIT_AUTH
        log.error("Bucket check failed (%s): %s", code, e)
        return EXIT_BUCKET

    try:
        objects = list_bronze_objects(s3, bucket)
    except ClientError as e:
        log.error("list_objects_v2 failed: %s", e)
        return EXIT_S3_OPERATION

    sha256_by_key: dict[str, str] = {}
    for obj in objects:
        sha = fetch_sha256(s3, bucket, obj["key"])
        if sha is None:
            return EXIT_S3_OPERATION
        sha256_by_key[obj["key"]] = sha
        if args.verbose:
            log.info("  %s  %d bytes  sha256=%s", obj["key"], obj["size"], sha[:12])

    checks = run_checks(objects, sha256_by_key)
    print()
    print(render_report(checks))
    print()

    if any(c["status"] == "FAIL" for c in checks):
        log.error("[FAIL] One or more checks failed")
        return EXIT_VERIFICATION_FAILED
    log.info("[OK] All %d checks PASSED", len(checks))
    return EXIT_OK


if __name__ == "__main__":
    sys.exit(main())

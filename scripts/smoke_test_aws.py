"""Smoke test for AWS auth + S3 round-trip.

Proves the boto3 to IAM to S3 stack is healthy before the SEC EDGAR
extract depends on it. Mirrors the smoke_test_azure_sql.py pattern from
Project #2.

Run:
    python scripts/smoke_test_aws.py

Exit codes:
    0 — all checks passed
    1 — unexpected error
    2 — credentials missing or invalid (auth failure)
    3 — bucket inaccessible (authorisation or bucket misconfiguration)
    4 — network failure (endpoint unreachable, DNS, TLS)
    5 — S3 round-trip failure (put / get / delete or content mismatch)

TODO Phase 6: add an S3 lifecycle policy on the health_checks/ prefix to
auto-expire smoke test artefacts (current + noncurrent versions). For now
the script issues a clean current-version delete; versioned debris is
swept on a future lifecycle policy. See EXTRACT_PIPELINE.md section 3a.

Walkthrough: EXTRACT_PIPELINE.md section 3a.
"""

from __future__ import annotations

import logging
import os
import sys
import uuid
from datetime import datetime, timezone

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
EXIT_ROUNDTRIP = 5

# Dedicated prefix keeps smoke-test artefacts out of zone=bronze/.
HEALTH_CHECK_PREFIX = "health_checks/smoke_test_aws/"

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
log = logging.getLogger("smoke_test_aws")


def load_config() -> dict[str, str]:
    """Load .env and validate all required AWS env vars are present."""
    load_dotenv()
    missing = [name for name in REQUIRED_ENV_VARS if not os.getenv(name)]
    if missing:
        log.error("Missing required env vars: %s", ", ".join(missing))
        sys.exit(EXIT_AUTH)
    return {name: os.environ[name] for name in REQUIRED_ENV_VARS}


def check_identity(sts_client) -> str:
    """Confirm credentials are valid via sts:GetCallerIdentity."""
    identity = sts_client.get_caller_identity()
    arn = identity["Arn"]
    account = identity["Account"]
    log.info("[OK] Auth: %s (account %s)", arn, account)
    return arn


def check_bucket(s3_client, bucket: str) -> None:
    """Confirm the target bucket exists and is reachable with current creds."""
    s3_client.head_bucket(Bucket=bucket)
    log.info("[OK] Bucket reachable: %s", bucket)


def round_trip(s3_client, bucket: str) -> None:
    """Write a unique key, read it back, assert content matches, delete."""
    run_id = uuid.uuid4().hex[:12]
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    key = f"{HEALTH_CHECK_PREFIX}{timestamp}_{run_id}.txt"
    payload = f"smoke_test_aws ok {run_id}".encode("utf-8")

    s3_client.put_object(
        Bucket=bucket,
        Key=key,
        Body=payload,
        ContentType="text/plain",
        # Tagging is what a Phase 6 lifecycle policy will key on.
        Tagging="Purpose=SmokeTest&Component=smoke_test_aws",
    )
    log.info("[OK] put_object: s3://%s/%s", bucket, key)

    body = s3_client.get_object(Bucket=bucket, Key=key)["Body"].read()
    if body != payload:
        log.error(
            "[FAIL] Round-trip content mismatch on %s — wrote %d bytes, read %d",
            key, len(payload), len(body),
        )
        sys.exit(EXIT_ROUNDTRIP)
    log.info("[OK] get_object: content matches (%d bytes)", len(body))

    s3_client.delete_object(Bucket=bucket, Key=key)
    log.info("[OK] delete_object: %s", key)


def main() -> int:
    log.info("AWS smoke test starting")
    config = load_config()
    region = config["AWS_DEFAULT_REGION"]
    bucket = config["S3_BUCKET_NAME"]
    log.info("Region: %s | Bucket: %s", region, bucket)

    try:
        session = boto3.session.Session(region_name=region)
        sts = session.client("sts")
        s3 = session.client("s3")

        check_identity(sts)
        check_bucket(s3, bucket)
        round_trip(s3, bucket)

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
        if code in {"NoSuchBucket", "AccessDenied", "403", "404"}:
            log.error("Bucket check failed (%s): %s", code, e)
            return EXIT_BUCKET
        log.error("Unexpected ClientError (%s): %s", code, e)
        return EXIT_UNEXPECTED
    except Exception as e:
        log.exception("Unexpected error: %s", e)
        return EXIT_UNEXPECTED

    log.info("[OK] All checks passed")
    return EXIT_OK


if __name__ == "__main__":
    sys.exit(main())

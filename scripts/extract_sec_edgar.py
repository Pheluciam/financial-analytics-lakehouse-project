"""Extract SEC EDGAR companyfacts JSON for one or more CIKs to S3 Bronze.

Polite rate-limited (~8 req/sec actual; SEC ceiling is 10). Exponential
backoff on 429 / 5xx / transport failures, bounded to 5 attempts.
Append-only by extract_date partition; same-day re-runs overwrite the
current S3 version (S3 versioning preserves prior versions for audit).
Bronze JSON preserved byte-for-byte from the SEC response — Bronze is the
system of record per demo-durability principle 1.

Run:
    python scripts/extract_sec_edgar.py                            # default: Apple (CIK 320193)
    python scripts/extract_sec_edgar.py --cik 320193               # Apple
    python scripts/extract_sec_edgar.py --cik 320193 --cik 789019  # Apple + Microsoft

Exit codes:
    0 — all CIKs landed successfully
    1 — unexpected error
    2 — credentials missing or invalid (auth failure)
    3 — bucket inaccessible
    4 — network failure (retry exhausted)
    5 — HTTP 4xx other than 429 (bad CIK or malformed URL)
    6 — unexpected response (not JSON, empty body)
    7 — S3 put failure

Walkthrough: EXTRACT_PIPELINE.md sections 4-8.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import logging
import os
import sys
import time
from datetime import date, datetime, timezone

import boto3
import requests
from botocore.exceptions import (
    ClientError,
    EndpointConnectionError,
    NoCredentialsError,
    PartialCredentialsError,
)
from dotenv import load_dotenv
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

EXIT_OK = 0
EXIT_UNEXPECTED = 1
EXIT_AUTH = 2
EXIT_BUCKET = 3
EXIT_NETWORK = 4
EXIT_HTTP_4XX = 5
EXIT_BAD_RESPONSE = 6
EXIT_S3_PUT = 7

# Apple Inc — default 1-company test target (Project #3 Phase 1 session 2).
DEFAULT_CIK = "320193"

# SEC ceiling is 10 req/sec. Run at ~8 req/sec for headroom.
MIN_INTERVAL_SECONDS = 0.12

# Retry tuning — 5 attempts, expo backoff: ~1s, 2s, 4s, 8s, 16s.
RETRY_TOTAL = 5
RETRY_BACKOFF_FACTOR = 1.0
RETRY_STATUS_FORCELIST = (429, 500, 502, 503, 504)

COMPANYFACTS_URL = "https://data.sec.gov/api/xbrl/companyfacts/CIK{cik10}.json"

REQUIRED_ENV_VARS = (
    "AWS_ACCESS_KEY_ID",
    "AWS_SECRET_ACCESS_KEY",
    "AWS_DEFAULT_REGION",
    "S3_BUCKET_NAME",
    "SEC_EDGAR_USER_AGENT",
)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)-7s %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("extract_sec_edgar")


def load_config() -> dict[str, str]:
    """Load .env and validate all required env vars present."""
    load_dotenv()
    missing = [name for name in REQUIRED_ENV_VARS if not os.getenv(name)]
    if missing:
        log.error("Missing required env vars: %s", ", ".join(missing))
        sys.exit(EXIT_AUTH)
    return {name: os.environ[name] for name in REQUIRED_ENV_VARS}


def build_http_session(user_agent: str) -> requests.Session:
    """Build a requests.Session with polite UA + bounded retry on transient failures."""
    retry = Retry(
        total=RETRY_TOTAL,
        backoff_factor=RETRY_BACKOFF_FACTOR,
        status_forcelist=RETRY_STATUS_FORCELIST,
        allowed_methods=frozenset(["GET"]),
        raise_on_status=False,
    )
    adapter = HTTPAdapter(max_retries=retry)
    session = requests.Session()
    session.mount("https://", adapter)
    session.headers.update({
        "User-Agent": user_agent,
        "Accept": "application/json",
        "Accept-Encoding": "gzip, deflate",
    })
    return session


def pad_cik(cik: str) -> str:
    """Pad CIK to 10 digits per SEC convention."""
    return str(int(cik)).zfill(10)


def fetch_companyfacts(
    http_session: requests.Session,
    cik: str,
    last_request_clock: list[float],
) -> bytes:
    """Fetch raw companyfacts JSON for a CIK. Returns bytes (source-preserved)."""
    cik10 = pad_cik(cik)
    url = COMPANYFACTS_URL.format(cik10=cik10)

    # Polite rate limit.
    elapsed = time.monotonic() - last_request_clock[0]
    if elapsed < MIN_INTERVAL_SECONDS:
        time.sleep(MIN_INTERVAL_SECONDS - elapsed)

    response = http_session.get(url, timeout=30)
    last_request_clock[0] = time.monotonic()

    status = response.status_code
    if 400 <= status < 500 and status != 429:
        log.error("[FAIL] CIK %s — HTTP %d %s", cik, status, response.reason)
        sys.exit(EXIT_HTTP_4XX)
    if status >= 500 or status == 429:
        log.error("[FAIL] CIK %s — retries exhausted (final status %d)", cik, status)
        sys.exit(EXIT_NETWORK)
    response.raise_for_status()

    body = response.content
    if not body or not body.startswith(b"{"):
        log.error("[FAIL] CIK %s — unexpected response shape (%d bytes)", cik, len(body))
        sys.exit(EXIT_BAD_RESPONSE)
    try:
        json.loads(body)
    except json.JSONDecodeError as e:
        log.error("[FAIL] CIK %s — JSON parse error: %s", cik, e)
        sys.exit(EXIT_BAD_RESPONSE)

    log.info("[OK] fetched CIK %s — %d bytes", cik, len(body))
    return body


def put_bronze(
    s3_client,
    bucket: str,
    cik: str,
    body: bytes,
    extract_date: str,
) -> str:
    """Land raw JSON to S3 under zone=bronze/extract_date/cik partition."""
    cik10 = pad_cik(cik)
    key = f"zone=bronze/extract_date={extract_date}/cik={cik10}/companyfacts.json"
    sha256 = hashlib.sha256(body).hexdigest()
    extracted_at = datetime.now(timezone.utc).isoformat(timespec="seconds")

    try:
        s3_client.put_object(
            Bucket=bucket,
            Key=key,
            Body=body,
            ContentType="application/json",
            Metadata={
                "cik": cik10,
                "source": "sec-edgar-companyfacts",
                "extracted-at": extracted_at,
                "sha256": sha256,
            },
            Tagging="Purpose=Extract&Source=SECEDGAR&Component=extract_sec_edgar",
        )
    except ClientError as e:
        log.error("[FAIL] CIK %s — S3 put failed: %s", cik, e)
        sys.exit(EXIT_S3_PUT)

    log.info(
        "[OK] put_object: s3://%s/%s (%d bytes, sha256=%s)",
        bucket, key, len(body), sha256[:12],
    )
    return key


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract SEC EDGAR companyfacts JSON for one or more CIKs to S3 Bronze.",
    )
    parser.add_argument(
        "--cik",
        action="append",
        default=None,
        help="CIK to extract. Pass multiple times for multi-CIK runs. Default: Apple (320193).",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    ciks = args.cik or [DEFAULT_CIK]

    log.info("SEC EDGAR extract starting — %d CIK(s)", len(ciks))
    config = load_config()
    region = config["AWS_DEFAULT_REGION"]
    bucket = config["S3_BUCKET_NAME"]
    user_agent = config["SEC_EDGAR_USER_AGENT"]
    extract_date = date.today().isoformat()
    log.info("Region: %s | Bucket: %s | extract_date: %s", region, bucket, extract_date)

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

    http_session = build_http_session(user_agent)
    last_request_clock = [0.0]

    try:
        for cik in ciks:
            body = fetch_companyfacts(http_session, cik, last_request_clock)
            put_bronze(s3, bucket, cik, body, extract_date)
    except Exception as e:
        log.exception("Unexpected error: %s", e)
        return EXIT_UNEXPECTED

    log.info("[OK] All %d CIK(s) landed", len(ciks))
    return EXIT_OK


if __name__ == "__main__":
    sys.exit(main())

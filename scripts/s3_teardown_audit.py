#!/usr/bin/env python3
"""
s3_teardown_audit.py  —  READ-ONLY audit of the lakehouse S3 bucket.

Goal: see exactly what is consuming storage before deleting anything, so we can
separate disposable junk (Athena query results, old object versions, delete
markers) from curated data worth keeping (gold/silver marts, bronze filings).

Run locally (the sandbox can't reach AWS):

    # from the project root, using the project venv
    .venv\\Scripts\\python scripts\\s3_teardown_audit.py          # Windows
    .venv/bin/python   scripts/s3_teardown_audit.py              # macOS/Linux

Reads credentials + bucket name from .env. Makes ONLY List/Get calls.
Nothing is created, modified, or deleted.
"""
from __future__ import annotations
import os
import sys
from collections import defaultdict

# --- load .env (no external deps) -------------------------------------------
def load_env(path: str = ".env") -> dict:
    env = {}
    if not os.path.exists(path):
        sys.exit(f"ERROR: {path} not found. Run from the project root.")
    for line in open(path, encoding="utf-8"):
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        env[k.strip()] = v.strip()
    return env

env = load_env()
for k in ("AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY"):
    if env.get(k):
        os.environ[k] = env[k]
os.environ.setdefault("AWS_DEFAULT_REGION", env.get("AWS_DEFAULT_REGION", "us-east-1"))

BUCKET = env.get("S3_BUCKET_NAME", "phil-financial-analytics-lakehouse")
GB = 1024 ** 3
PRICE_PER_GB_MONTH = 0.023  # S3 Standard, us-east-1

try:
    import boto3
except ImportError:
    sys.exit("ERROR: boto3 not installed in this environment. "
             "Activate the project venv, or: pip install boto3")

s3 = boto3.client("s3")


def human(n: int) -> str:
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if n < 1024:
            return f"{n:,.1f} {unit}"
        n /= 1024
    return f"{n:,.1f} PB"


def top_prefix(key: str) -> str:
    return key.split("/", 1)[0] + "/" if "/" in key else "(root objects)"


def main() -> None:
    print(f"Bucket : {BUCKET}")
    print(f"Region : {os.environ['AWS_DEFAULT_REGION']}")
    print(f"Caller : ", end="")
    try:
        ident = boto3.client("sts").get_caller_identity()
        print(f"{ident['Arn']}  (account {ident['Account']})")
    except Exception as e:
        print(f"(sts failed: {e})")

    # versioning -------------------------------------------------------------
    ver = s3.get_bucket_versioning(Bucket=BUCKET)
    versioning = ver.get("Status", "Disabled")
    print(f"Versioning: {versioning}\n")

    # current objects by prefix ---------------------------------------------
    cur_bytes = defaultdict(int)
    cur_count = defaultdict(int)
    paginator = s3.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=BUCKET):
        for obj in page.get("Contents", []):
            p = top_prefix(obj["Key"])
            cur_bytes[p] += obj["Size"]
            cur_count[p] += 1

    print("=== CURRENT objects by top-level prefix ===")
    print(f"{'prefix':<32}{'objects':>12}{'size':>14}{'$/mo':>10}")
    print("-" * 68)
    tot_b = tot_c = 0
    for p in sorted(cur_bytes, key=lambda k: -cur_bytes[k]):
        b, c = cur_bytes[p], cur_count[p]
        tot_b += b; tot_c += c
        print(f"{p:<32}{c:>12,}{human(b):>14}{b/GB*PRICE_PER_GB_MONTH:>9.2f}")
    print("-" * 68)
    print(f"{'TOTAL (current)':<32}{tot_c:>12,}{human(tot_b):>14}"
          f"{tot_b/GB*PRICE_PER_GB_MONTH:>9.2f}\n")

    # non-current versions + delete markers ---------------------------------
    if versioning == "Enabled":
        ncur_bytes = defaultdict(int)
        ncur_count = defaultdict(int)
        markers = 0
        vp = s3.get_paginator("list_object_versions")
        for page in vp.paginate(Bucket=BUCKET):
            for v in page.get("Versions", []):
                if not v["IsLatest"]:
                    p = top_prefix(v["Key"])
                    ncur_bytes[p] += v["Size"]
                    ncur_count[p] += 1
            markers += len(page.get("DeleteMarkers", []))
        nb = sum(ncur_bytes.values()); nc = sum(ncur_count.values())
        print("=== NON-CURRENT versions (hidden storage you still pay for) ===")
        if nb:
            for p in sorted(ncur_bytes, key=lambda k: -ncur_bytes[k]):
                print(f"{p:<32}{ncur_count[p]:>12,}{human(ncur_bytes[p]):>14}"
                      f"{ncur_bytes[p]/GB*PRICE_PER_GB_MONTH:>9.2f}")
        print(f"{'TOTAL (noncurrent)':<32}{nc:>12,}{human(nb):>14}"
              f"{nb/GB*PRICE_PER_GB_MONTH:>9.2f}")
        print(f"Delete markers: {markers:,}\n")
        grand = tot_b + nb
    else:
        grand = tot_b

    print("=== SUMMARY ===")
    print(f"Total billable storage : {human(grand)}  (~${grand/GB*PRICE_PER_GB_MONTH:.2f}/mo)")
    print("\nHeuristic — likely DISPOSABLE prefixes (Athena results / temp / staging):")
    junk = [p for p in cur_bytes if any(t in p.lower() for t in
            ("athena", "result", "query", "tmp", "temp", "staging", "_spark", "scratch"))]
    for p in junk:
        print(f"  - {p}  ({human(cur_bytes[p])})")
    if not junk:
        print("  (none obvious by name — inspect the prefix list above)")
    print("\nNext: paste this whole output back and we'll mark keep-vs-delete per prefix.")


if __name__ == "__main__":
    main()

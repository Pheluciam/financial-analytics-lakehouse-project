#!/usr/bin/env python3
"""
s3_teardown.py  -  download curated data, verify it, then empty the bucket to $0.

Run locally (sandbox can't reach AWS). Reads creds + bucket from .env.

Phases, in order:

  1) DOWNLOAD curated prefixes (current versions only) + auto-verify:
       python scripts\\s3_teardown.py download --dest data_snapshot
     (the dest dir is wiped first so verify is always clean)

  2) Inspect the PASS/FAIL report. Only if every prefix says PASS, proceed.

  3) EMPTY the bucket - ALL objects, ALL versions, ALL delete markers:
       python scripts\\s3_teardown.py empty --confirm
     Add --delete-bucket to also remove the now-empty bucket (full $0):
       python scripts\\s3_teardown.py empty --confirm --delete-bucket

Without --confirm, `empty` only prints what WOULD be deleted (dry run).

Notes
-----
* Folder-marker keys (ending in "/") are skipped on download. boto3's
  download_file cannot write them as files - a known limitation
  (github.com/boto/boto3 issue 3870, github.com/boto/s3transfer issue 66).
* Windows extended-length paths (\\\\?\\) are used so the 260-char MAX_PATH
  limit does not apply to long Iceberg metadata keys.
"""
from __future__ import annotations
import argparse
import os
import shutil
import stat
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed

KEEP_PREFIXES_DEFAULT = ["zone=silver/", "zone=bronze/", "zone=gold/"]


def load_env(path: str = ".env") -> dict:
    env = {}
    if not os.path.exists(path):
        sys.exit(f"ERROR: {path} not found. Run from the project root.")
    for line in open(path, encoding="utf-8"):
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, v = line.split("=", 1)
            env[k.strip()] = v.strip()
    return env


env = load_env()
for k in ("AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY"):
    if env.get(k):
        os.environ[k] = env[k]
os.environ.setdefault("AWS_DEFAULT_REGION", env.get("AWS_DEFAULT_REGION", "us-east-1"))
BUCKET = env.get("S3_BUCKET_NAME", "phil-financial-analytics-lakehouse")

try:
    import boto3
except ImportError:
    sys.exit("ERROR: boto3 not installed. Activate the venv or: pip install boto3")

s3 = boto3.client("s3")


def win_long(path: str) -> str:
    r"""Return a Windows extended-length path (\\?\...) to bypass the 260-char
    MAX_PATH limit. No-op on non-Windows. Requires an absolute path."""
    if os.name != "nt":
        return os.path.abspath(path)
    ap = os.path.abspath(path)
    prefix = "\\\\?\\"
    return ap if ap.startswith(prefix) else prefix + ap


def human(n: float) -> str:
    for u in ("B", "KB", "MB", "GB", "TB"):
        if n < 1024:
            return f"{n:,.1f} {u}"
        n /= 1024
    return f"{n:,.1f} PB"


def _force_rw(func, path, _exc):
    """rmtree onerror: clear read-only bit and retry."""
    try:
        os.chmod(path, stat.S_IWRITE)
        func(path)
    except OSError:
        pass


def clean_dir(path: str) -> None:
    p = win_long(path)
    if os.path.isdir(p):
        shutil.rmtree(p, onerror=_force_rw)


# ---------------------------------------------------------------- download ---
def list_current(prefix: str):
    """Yield (key, size) for current DATA objects under prefix.
    Skips folder-marker keys (ending in '/') - boto3 can't download those."""
    p = s3.get_paginator("list_objects_v2")
    for page in p.paginate(Bucket=BUCKET, Prefix=prefix):
        for o in page.get("Contents", []):
            if o["Key"].endswith("/"):
                continue
            yield o["Key"], o["Size"]


def download(dest: str, prefixes: list[str]) -> None:
    print(f"Clearing {os.path.abspath(dest)} for a clean copy...")
    clean_dir(dest)
    os.makedirs(dest, exist_ok=True)

    print(f"Downloading current versions of {prefixes}")
    print(f"  from s3://{BUCKET}\n  to   {os.path.abspath(dest)}\n")

    src = {}  # key -> size (data objects only)
    markers = 0
    for pref in prefixes:
        pag = s3.get_paginator("list_objects_v2")
        for page in pag.paginate(Bucket=BUCKET, Prefix=pref):
            for o in page.get("Contents", []):
                if o["Key"].endswith("/"):
                    markers += 1
                else:
                    src[o["Key"]] = o["Size"]
    print(f"{len(src):,} data objects to download "
          f"({human(sum(src.values()))}); skipping {markers} folder markers")

    def _get(key: str):
        local = win_long(os.path.join(dest, key.replace("/", os.sep)))
        os.makedirs(os.path.dirname(local), exist_ok=True)
        s3.download_file(BUCKET, key, local)

    done = 0
    failures = []
    with ThreadPoolExecutor(max_workers=16) as ex:
        futs = {ex.submit(_get, k): k for k in src}
        for f in as_completed(futs):
            key = futs[f]
            try:
                f.result()
            except Exception as exc:  # isolate one bad key from the whole run
                failures.append((key, repr(exc)))
            done += 1
            if done % 250 == 0 or done == len(src):
                print(f"  ...{done:,}/{len(src):,}")

    if failures:
        print(f"\n{len(failures)} object(s) FAILED to download:")
        for key, err in failures[:20]:
            print(f"  - {key}\n      {err}")
        if len(failures) > 20:
            print(f"  ...and {len(failures) - 20} more")

    # ---- verify: per-prefix object count + bytes, S3 vs local --------------
    print("\n=== VERIFY (S3 current data  vs  local copy) ===")
    all_pass = not failures
    for pref in prefixes:
        s3_keys = {k: sz for k, sz in src.items() if k.startswith(pref)}
        root = win_long(os.path.join(dest, pref.replace("/", os.sep)))
        loc_n = loc_b = 0
        if os.path.isdir(root):
            for dp, _, files in os.walk(root):
                for fn in files:
                    loc_n += 1
                    loc_b += os.path.getsize(os.path.join(dp, fn))
        s3_n, s3_b = len(s3_keys), sum(s3_keys.values())
        ok = (s3_n == loc_n and s3_b == loc_b)
        all_pass &= ok
        print(f"  {pref:<16} S3: {s3_n:>6,} obj / {human(s3_b):>10}   "
              f"local: {loc_n:>6,} / {human(loc_b):>10}   "
              f"[{'PASS' if ok else 'FAIL'}]")
    print("\n" + ("ALL PASS - safe to run `empty --confirm`."
                  if all_pass else
                  "!! NOT all PASS - do NOT empty the bucket. Re-run download."))


# ------------------------------------------------------------------- empty ---
def iter_all_versions():
    """Yield {'Key','VersionId'} for every version AND delete marker."""
    p = s3.get_paginator("list_object_versions")
    for page in p.paginate(Bucket=BUCKET):
        for v in page.get("Versions", []):
            yield {"Key": v["Key"], "VersionId": v["VersionId"]}
        for d in page.get("DeleteMarkers", []):
            yield {"Key": d["Key"], "VersionId": d["VersionId"]}


def empty(confirm: bool, delete_bucket: bool) -> None:
    batch, total = [], 0
    if not confirm:
        for _ in iter_all_versions():
            total += 1
        print(f"DRY RUN: {total:,} versions + delete markers would be deleted "
              f"from s3://{BUCKET}.\nRe-run with --confirm to actually delete.")
        return

    print(f"EMPTYING s3://{BUCKET} (all versions + delete markers)...")
    for item in iter_all_versions():
        batch.append(item)
        if len(batch) == 1000:
            s3.delete_objects(Bucket=BUCKET, Delete={"Objects": batch, "Quiet": True})
            total += len(batch)
            batch = []
            print(f"  deleted {total:,}")
    if batch:
        s3.delete_objects(Bucket=BUCKET, Delete={"Objects": batch, "Quiet": True})
        total += len(batch)
    print(f"Done. Deleted {total:,} objects/versions/markers. Bucket is now empty.")

    if delete_bucket:
        s3.delete_bucket(Bucket=BUCKET)
        print(f"Bucket s3://{BUCKET} deleted. Storage cost is now $0.")
    else:
        print("Bucket kept (empty). Empty bucket = $0 storage. "
              "Re-run with --delete-bucket to remove it entirely.")


# -------------------------------------------------------------------- main ---
def main() -> None:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)

    d = sub.add_parser("download")
    d.add_argument("--dest", default="data_snapshot")
    d.add_argument("--prefixes", nargs="+", default=KEEP_PREFIXES_DEFAULT)

    e = sub.add_parser("empty")
    e.add_argument("--confirm", action="store_true")
    e.add_argument("--delete-bucket", action="store_true")

    args = ap.parse_args()
    if args.cmd == "download":
        download(args.dest, args.prefixes)
    elif args.cmd == "empty":
        empty(args.confirm, args.delete_bucket)


if __name__ == "__main__":
    main()

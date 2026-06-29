#!/usr/bin/env python3
"""
account_cleanup.py  -  find and remove the small idle charges left after the S3
teardown, so the account is truly $0 once free credits end (~2026-11-23).

Run locally. Reads creds from .env. Sweeps BOTH regions the June bill touched.

  # READ-ONLY: list everything that could bill on an idle account
  python scripts\\account_cleanup.py audit

  # REVERSIBLE cleanup of the billable items (7-day recovery window on both):
  #   - Secrets Manager secrets  -> scheduled delete, 7-day recovery
  #   - KMS customer-managed keys -> scheduled delete, 7-day window
  python scripts\\account_cleanup.py clean --confirm

  # also remove CloudWatch alarms ($0.10/mo each) and/or log groups:
  python scripts\\account_cleanup.py clean --confirm --alarms --logs

Without --confirm, `clean` is a dry run (prints what it WOULD do).

Cost facts (verified against AWS docs):
  * KMS keys SCHEDULED for deletion stop billing immediately; disabled keys do
    NOT. Min waiting period 7 days, cancellable within the window.
  * Secrets MARKED for deletion are not billed; a 7-day recovery window still
    lets you restore. So nothing here is irreversible for 7 days.
"""
from __future__ import annotations
import argparse
import os
import sys

REGIONS = ["us-east-1", "ap-southeast-2"]
GB = 1024 ** 3


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

try:
    import boto3
    from botocore.exceptions import ClientError
except ImportError:
    sys.exit("ERROR: boto3 not installed. Activate the venv or: pip install boto3")


def safe(label, fn):
    """Run an AWS call, returning [] and printing a note on permission errors."""
    try:
        return fn()
    except ClientError as e:
        print(f"    ! {label}: {e.response['Error']['Code']} (skipped)")
        return []


# --------------------------------------------------------------- discovery ---
def find_secrets(region):
    c = boto3.client("secretsmanager", region_name=region)
    out = []
    for page in c.get_paginator("list_secrets").paginate():
        for s in page.get("SecretList", []):
            if s.get("DeletedDate"):       # already scheduled
                continue
            out.append({"Name": s["Name"], "ARN": s["ARN"]})
    return out


def find_kms_customer_keys(region):
    c = boto3.client("kms", region_name=region)
    out = []
    for page in c.get_paginator("list_keys").paginate():
        for k in page.get("Keys", []):
            d = c.describe_key(KeyId=k["KeyId"])["KeyMetadata"]
            if d["KeyManager"] == "CUSTOMER" and d["KeyState"] not in (
                    "PendingDeletion", "PendingReplicaDeletion"):
                out.append({"KeyId": d["KeyId"], "State": d["KeyState"]})
    return out


def find_alarms(region):
    c = boto3.client("cloudwatch", region_name=region)
    out = []
    for page in c.get_paginator("describe_alarms").paginate():
        out += [a["AlarmName"] for a in page.get("MetricAlarms", [])]
        out += [a["AlarmName"] for a in page.get("CompositeAlarms", [])]
    return out


def find_log_groups(region):
    c = boto3.client("logs", region_name=region)
    out = []
    for page in c.get_paginator("describe_log_groups").paginate():
        for g in page.get("logGroups", []):
            out.append({"name": g["logGroupName"],
                        "bytes": g.get("storedBytes", 0)})
    return out


def find_glue(region):
    c = boto3.client("glue", region_name=region)
    dbs = []
    for page in c.get_paginator("get_databases").paginate():
        for d in page.get("DatabaseList", []):
            n = 0
            for tp in c.get_paginator("get_tables").paginate(DatabaseName=d["Name"]):
                n += len(tp.get("TableList", []))
            dbs.append({"db": d["Name"], "tables": n})
    return dbs


# ------------------------------------------------------------------- audit ---
def audit():
    print("Account idle-cost audit (regions: " + ", ".join(REGIONS) + ")\n")
    est = 0.0
    for r in REGIONS:
        print(f"=== {r} ===")
        secrets = safe("secrets", lambda: find_secrets(r))
        keys = safe("kms", lambda: find_kms_customer_keys(r))
        alarms = safe("alarms", lambda: find_alarms(r))
        logs = safe("logs", lambda: find_log_groups(r))
        glue = safe("glue", lambda: find_glue(r))

        log_bytes = sum(g["bytes"] for g in logs)
        c_sec = 0.40 * len(secrets)
        c_kms = 1.00 * len(keys)
        c_alarm = 0.10 * len(alarms)
        c_logs = log_bytes / GB * 0.03
        est += c_sec + c_kms + c_alarm + c_logs

        print(f"  Secrets Manager : {len(secrets):>3}  (~${c_sec:.2f}/mo)  "
              + ", ".join(s["Name"] for s in secrets[:6]))
        print(f"  KMS cust. keys  : {len(keys):>3}  (~${c_kms:.2f}/mo)  "
              + ", ".join(k['KeyId'][:8] for k in keys))
        print(f"  CloudWatch alarm: {len(alarms):>3}  (~${c_alarm:.2f}/mo)  "
              + ", ".join(alarms[:6]))
        print(f"  CW log groups   : {len(logs):>3}  ({log_bytes/GB:.3f} GB, ~${c_logs:.2f}/mo)")
        print(f"  Glue databases  : {len(glue):>3}  (free tier)  "
              + ", ".join(f"{g['db']}({g['tables']})" for g in glue))
        print()
    print(f"Estimated idle cost after credits end: ~${est:.2f}/month")
    print("Run `clean --confirm` to remove Secrets + KMS (reversible 7 days). "
          "Add --alarms --logs to remove those too.")


# ------------------------------------------------------------------- clean ---
def clean(confirm, do_alarms, do_logs):
    mode = "DELETING" if confirm else "DRY RUN -"
    for r in REGIONS:
        print(f"=== {r} ===")
        for s in safe("secrets", lambda: find_secrets(r)):
            print(f"  {mode} secret  {s['Name']}  (7-day recovery)")
            if confirm:
                boto3.client("secretsmanager", region_name=r).delete_secret(
                    SecretId=s["ARN"], RecoveryWindowInDays=7)
        for k in safe("kms", lambda: find_kms_customer_keys(r)):
            print(f"  {mode} KMS key {k['KeyId']}  (7-day window)")
            if confirm:
                boto3.client("kms", region_name=r).schedule_key_deletion(
                    KeyId=k["KeyId"], PendingWindowInDays=7)
        if do_alarms:
            al = safe("alarms", lambda: find_alarms(r))
            if al:
                print(f"  {mode} {len(al)} CloudWatch alarm(s)")
                if confirm:
                    boto3.client("cloudwatch", region_name=r).delete_alarms(
                        AlarmNames=al)
        if do_logs:
            for g in safe("logs", lambda: find_log_groups(r)):
                print(f"  {mode} log group {g['name']}")
                if confirm:
                    boto3.client("logs", region_name=r).delete_log_group(
                        logGroupName=g["name"])
        print()
    if not confirm:
        print("DRY RUN only. Re-run with --confirm to apply.")
    else:
        print("Done. Secrets + KMS keys are scheduled for deletion (recoverable "
              "for 7 days, billing already stopped). Re-run `audit` to confirm.")


# -------------------------------------------------------------------- main ---
def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("audit")
    c = sub.add_parser("clean")
    c.add_argument("--confirm", action="store_true")
    c.add_argument("--alarms", action="store_true")
    c.add_argument("--logs", action="store_true")
    args = ap.parse_args()
    if args.cmd == "audit":
        audit()
    else:
        clean(args.confirm, args.alarms, args.logs)


if __name__ == "__main__":
    main()

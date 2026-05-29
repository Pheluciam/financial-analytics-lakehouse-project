"""One-shot sync of dbt project + Glue wrapper to S3 for Phase 3 orchestration.

Reads AWS credentials from .env (phil-admin keys at AWS_ACCESS_KEY_ID /
AWS_SECRET_ACCESS_KEY). Run from project root::

    python scripts/sync_phase3_artifacts_to_s3.py

Uploads two surfaces to the lakehouse bucket:

* ``dbt/`` (minus build artifacts) -> ``s3://.../dbt-project/latest/``
* ``scripts/run_dbt_in_glue.py``   -> ``s3://.../glue-scripts/run_dbt_in_glue.py``

The Glue Python Shell job ``financial-analytics-dbt-build`` consumes both
prefixes: ScriptLocation points at the wrapper, the wrapper's
``dbt_project_s3_uri`` Glue arg points at the dbt project prefix.

Phase 3 manual deploy step. Replaced by CI/CD push at Phase 6.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

import boto3
from dotenv import load_dotenv

load_dotenv()

BUCKET = "phil-financial-analytics-lakehouse"

DBT_LOCAL = Path("dbt")
DBT_REMOTE_PREFIX = "dbt-project/latest/"

SCRIPT_LOCAL = Path("scripts/run_dbt_in_glue.py")
SCRIPT_REMOTE_KEY = "glue-scripts/run_dbt_in_glue.py"

# Exclude dbt build artifacts and any local-only state. dbt_packages is
# empty in this project (no packages.yml install) but excluded defensively.
EXCLUDE_DIRS = {"target", "dbt_packages", "logs", ".pytest_cache", "__pycache__"}
EXCLUDE_FILES = {".user.yml", ".env"}


def main() -> int:
    s3 = boto3.client(
        "s3",
        region_name=os.environ.get("AWS_DEFAULT_REGION", "us-east-1"),
        aws_access_key_id=os.environ["AWS_ACCESS_KEY_ID"],
        aws_secret_access_key=os.environ["AWS_SECRET_ACCESS_KEY"],
    )

    print(f"Syncing {DBT_LOCAL}/ -> s3://{BUCKET}/{DBT_REMOTE_PREFIX}")
    count = 0
    for path in DBT_LOCAL.rglob("*"):
        if path.is_dir():
            continue
        rel = path.relative_to(DBT_LOCAL)
        if any(part in EXCLUDE_DIRS for part in rel.parts):
            continue
        if rel.name in EXCLUDE_FILES:
            continue
        key = DBT_REMOTE_PREFIX + str(rel).replace("\\", "/")
        s3.upload_file(str(path), BUCKET, key)
        count += 1
        print(f"  uploaded {key}")
    print(f"  {count} file(s) synced.\n")

    print(f"Uploading {SCRIPT_LOCAL} -> s3://{BUCKET}/{SCRIPT_REMOTE_KEY}")
    s3.upload_file(str(SCRIPT_LOCAL), BUCKET, SCRIPT_REMOTE_KEY)
    print("  done.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

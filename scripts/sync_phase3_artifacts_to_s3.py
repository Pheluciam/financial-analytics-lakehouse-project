"""Sync dbt project + Glue wrapper to S3 for the orchestration deploy.

Credentials resolve via the boto3 default credential chain (Phase 6
session 2 CI/CD unification, 2026-06-05). Locally, ``load_dotenv()``
exports the phil-admin keys from ``.env`` into the environment where the
default chain picks them up; in GitHub Actions, the keyless OIDC role
assumed by aws-actions/configure-aws-credentials@v6 exports temporary
credentials (incl. a session token) the same way. No explicit-key boto3
client — that path cannot carry the OIDC session token. Run locally from
project root::

    python scripts/sync_phase3_artifacts_to_s3.py

Uploads two surfaces to the lakehouse bucket:

* ``dbt/`` (minus build artifacts) -> ``s3://.../dbt-project/latest/``
* ``scripts/run_dbt_in_glue.py``   -> ``s3://.../glue-scripts/run_dbt_in_glue.py``

The Glue Python Shell job ``financial-analytics-dbt-build`` consumes both
prefixes: ScriptLocation points at the wrapper, the wrapper's
``dbt_project_s3_uri`` Glue arg points at the dbt project prefix.

Invoked by .github/workflows/deploy.yml on push to main (Phase 6
session 2); still runnable by hand for ad-hoc deploys.
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
    # Default credential chain — reads AWS_ACCESS_KEY_ID / _SECRET_ACCESS_KEY
    # / _SESSION_TOKEN from the environment. load_dotenv() above populates
    # them from .env locally; OIDC populates them in CI.
    s3 = boto3.client(
        "s3",
        region_name=os.environ.get("AWS_DEFAULT_REGION", "us-east-1"),
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

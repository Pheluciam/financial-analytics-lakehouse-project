"""Glue Python Shell entry point for the financial-analytics dbt-athena build.

Invoked by the Step Functions Glue ``StartJobRun.sync`` task as part of the
Phase 3 orchestration. Downloads the dbt project from S3, then runs
``dbtRunner().invoke(["build", ...])`` exactly once and surfaces the
result as a process exit code (0 = success, 1 = failure).

Risks addressed (LEARNINGS.md Phase 3 forward-projected risks)
---------------------------------------------------------------
* **Risk 24** — single dbt invocation per Python process. Fan-out, when it
  arrives, happens at the Step Functions level via parallel branches each
  launching their own Glue job; never inside one process.
* **Risk 25** — success/failure is read from ``dbtRunnerResult.success``
  (the bool) and translated to an exit code. Internal ``result.results[*]``
  fields are explicitly not inspected: they are not contracted and "liable
  to change in future versions of dbt-core" per the dbt-labs commitments
  page.
* **Risk 26** — authored against Python 3.9, pinned on the Glue job.
* **Risk 27** — dep install via ``--additional-python-modules`` runs once
  at Glue cold start. The first-run baseline timing is measured at session
  12 and tracked in LEARNINGS / ORCHESTRATION_PIPELINE.md.

Walkthrough: ORCHESTRATION_PIPELINE.md at repo root.
"""

from __future__ import annotations

import shutil
import sys
from pathlib import Path
from typing import Tuple

import boto3
from awsglue.utils import getResolvedOptions
from dbt.cli.main import dbtRunner

print("[run_dbt_in_glue] Module imports complete; script is executing", flush=True)

# Glue job argument name — the S3 URI prefix containing the synced dbt
# project. Passed in via Step Functions task Parameters or via the Glue
# job's --default-arguments.
ARG_DBT_PROJECT_S3_URI = "dbt_project_s3_uri"

# Local working directory inside the Glue Python Shell container. /tmp is
# the only writable filesystem location guaranteed by Glue Python Shell.
LOCAL_PROJECT_DIR = Path("/tmp/dbt_project")

# dbt profile target — the "glue" target in dbt/profiles.yml omits static
# AWS keys so pyathena uses the Glue job's IAM role via the boto3 default
# credential chain.
DBT_TARGET = "glue"


def _parse_s3_uri(uri: str) -> Tuple[str, str]:
    """Split ``s3://bucket/prefix`` into ``(bucket, prefix_with_slash)``."""
    if not uri.startswith("s3://"):
        raise ValueError(f"Expected s3:// URI, got {uri!r}")
    body = uri[len("s3://"):]
    bucket, _, prefix = body.partition("/")
    if not bucket:
        raise ValueError(f"Missing bucket in URI {uri!r}")
    return bucket, prefix.rstrip("/") + "/"


def _sync_project_from_s3(uri: str, local_dir: Path) -> int:
    """Paginate-download every object under ``uri`` into ``local_dir``.

    Returns the count of objects downloaded. Removes ``local_dir`` first so
    the job is idempotent across retries.
    """
    bucket, prefix = _parse_s3_uri(uri)
    if local_dir.exists():
        shutil.rmtree(local_dir)
    local_dir.mkdir(parents=True, exist_ok=True)

    s3 = boto3.client("s3")
    paginator = s3.get_paginator("list_objects_v2")
    count = 0
    for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
        for obj in page.get("Contents", []):
            key = obj["Key"]
            relative = key[len(prefix):]
            if not relative:
                continue
            target = local_dir / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            s3.download_file(bucket, key, str(target))
            count += 1
    return count


def main() -> int:
    args = getResolvedOptions(sys.argv, [ARG_DBT_PROJECT_S3_URI])
    project_uri = args[ARG_DBT_PROJECT_S3_URI]

    print(f"[run_dbt_in_glue] Syncing dbt project from {project_uri}", flush=True)
    n = _sync_project_from_s3(project_uri, LOCAL_PROJECT_DIR)
    print(
        f"[run_dbt_in_glue] Downloaded {n} object(s) to {LOCAL_PROJECT_DIR}",
        flush=True,
    )

    runner = dbtRunner()

    # `dbt deps` installs packages from packages.yml into dbt_packages/.
    # The sync helper excludes the local dbt_packages/ folder from S3 upload
    # (vendored package code shouldn't be in version control), so we install
    # at Glue runtime. ~2s cost per job; preserves clean S3 surface.
    print("[run_dbt_in_glue] Running dbt deps", flush=True)
    deps_result = runner.invoke(
        [
            "deps",
            "--project-dir",
            str(LOCAL_PROJECT_DIR),
            "--profiles-dir",
            str(LOCAL_PROJECT_DIR),
        ]
    )
    print(f"[run_dbt_in_glue] dbt deps success={deps_result.success}", flush=True)
    if not deps_result.success:
        return 1

    # `--threads 2` is the Risk 64 mitigation — dbt-athena's default 4-thread
    # concurrency at full-refresh on the ~265-node cascade busts S3
    # DeleteObjects per-prefix burst limit and the internal 5-retry loop
    # exhausts ("SlowDown ... reached max retries: 5"). 2 threads keep deletes
    # serialized enough to stay under the throttle. Matches the local standing
    # cascade command (`dbt build --full-refresh --threads 2`) — Glue layer
    # was missing this flag in Phase 5 session 4 (Step Functions production
    # sign-off ran without --full-refresh so the issue stayed dormant); Step M
    # session 4.5 surfaced it on the first --full-refresh-equivalent rebuild.
    print("[run_dbt_in_glue] Running dbt build --threads 2", flush=True)
    result = runner.invoke(
        [
            "build",
            "--project-dir",
            str(LOCAL_PROJECT_DIR),
            "--profiles-dir",
            str(LOCAL_PROJECT_DIR),
            "--target",
            DBT_TARGET,
            "--threads",
            "2",
        ]
    )
    print(f"[run_dbt_in_glue] dbt build success={result.success}", flush=True)
    return 0 if result.success else 1


# Glue Python Shell does not guarantee `__name__ == "__main__"` when loading
# the script (it may exec or runpy the file with a different name). Call
# main() unconditionally at module level to avoid the silent-no-op trap.
sys.exit(main())

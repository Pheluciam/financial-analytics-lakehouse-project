"""Start the financial-analytics-orchestrator Step Functions execution and
wait for it to reach a terminal state.

Phase 6 session 2 (2026-06-05) — the CI/CD forward-verify hook. After the
deploy scripts push the latest dbt project + Glue wrapper + state machine
definition, this script triggers one orchestrator run (Glue dbt build ->
14-branch Athena verify Parallel state) and polls to completion, exiting
non-zero unless the execution SUCCEEDED. That makes the GitHub Actions
workflow fail loudly if a pushed change breaks the build or any verify
branch — the end-to-end "dbt -> verify runs clean" gate for the project.

Credentials resolve via the boto3 default credential chain (.env locally,
keyless OIDC in CI — see sibling deploy scripts). Run locally from project
root::

    python scripts/run_orchestrator.py
"""

from __future__ import annotations

import os
import sys
import time

import boto3
from dotenv import load_dotenv

load_dotenv()

STATE_MACHINE_ARN = (
    "arn:aws:states:us-east-1:470439680370:stateMachine:financial-analytics-orchestrator"
)

POLL_SECONDS = 15
# Glue Python Shell dbt build + Athena verify fan-out runs in a few minutes
# at S&P 100 volumes; 30 min is a generous ceiling before we give up polling.
TIMEOUT_SECONDS = 30 * 60

TERMINAL = {"SUCCEEDED", "FAILED", "TIMED_OUT", "ABORTED"}


def main() -> int:
    sfn = boto3.client(
        "stepfunctions",
        region_name=os.environ.get("AWS_DEFAULT_REGION", "us-east-1"),
    )

    start = sfn.start_execution(stateMachineArn=STATE_MACHINE_ARN)
    arn = start["executionArn"]
    print(f"Started execution: {arn}")

    deadline = time.monotonic() + TIMEOUT_SECONDS
    status = "RUNNING"
    while status not in TERMINAL:
        if time.monotonic() > deadline:
            print(f"Polling timed out after {TIMEOUT_SECONDS}s; last status: {status}")
            return 1
        time.sleep(POLL_SECONDS)
        status = sfn.describe_execution(executionArn=arn)["status"]
        print(f"  status: {status}")

    print(f"Execution terminal status: {status}")
    return 0 if status == "SUCCEEDED" else 1


if __name__ == "__main__":
    sys.exit(main())

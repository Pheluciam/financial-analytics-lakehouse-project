"""One-shot deploy of stepfunctions/state_machine.json to AWS.

Reads phil-admin AWS credentials from .env (AWS_ACCESS_KEY_ID /
AWS_SECRET_ACCESS_KEY) and pushes the state machine JSON definition
to the live financial-analytics-orchestrator state machine via
stepfunctions.update_state_machine.

Run from project root::

    python scripts/deploy_state_machine.py

Companion to scripts/sync_phase3_artifacts_to_s3.py (which syncs the
dbt project + Glue wrapper to S3 for the Glue Python Shell job to
consume). This script handles the second deploy surface — the state
machine definition itself.

Phase 4 session 5 manual deploy step. Replaced by CI/CD push at Phase 6.
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

import boto3
from dotenv import load_dotenv

load_dotenv()

STATE_MACHINE_ARN = (
    "arn:aws:states:us-east-1:470439680370:stateMachine:financial-analytics-orchestrator"
)
DEFINITION_PATH = Path("stepfunctions/state_machine.json")


def main() -> int:
    definition = DEFINITION_PATH.read_text(encoding="utf-8")
    # JSON-parse to validate syntax before sending to AWS.
    parsed = json.loads(definition)
    branch_count = len(parsed["States"]["VerifyStructuralSurface"]["Branches"])

    print(f"Deploying {DEFINITION_PATH} -> {STATE_MACHINE_ARN}")
    print(f"  definition size: {len(definition):,} bytes (limit 1,048,576)")
    print(f"  Parallel branch count: {branch_count}")

    sfn = boto3.client(
        "stepfunctions",
        region_name=os.environ.get("AWS_DEFAULT_REGION", "us-east-1"),
        aws_access_key_id=os.environ["AWS_ACCESS_KEY_ID"],
        aws_secret_access_key=os.environ["AWS_SECRET_ACCESS_KEY"],
    )

    response = sfn.update_state_machine(
        stateMachineArn=STATE_MACHINE_ARN,
        definition=definition,
    )

    print(f"  updateDate: {response['updateDate'].isoformat()}")
    print(f"  revisionId: {response.get('revisionId', '(none)')}")
    print("Deploy complete.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env bash
#
# aws_cost_check.sh — find what's costing money in the lakehouse account.
#
# Account 470439680370 (portfolio-monthly-5usd-tripwire fired 2026-06-28).
# Stack is serverless (S3 + Glue + Athena + Step Functions), so this checks
# the two things that actually burn money when left running — open Glue
# sessions and active schedules — then prints month-to-date spend by service.
#
# Usage:  bash scripts/aws_cost_check.sh
# Auth:   uses your default AWS creds / AWS_PROFILE. Read-only (Describe/List/Get).
# Note:   the Cost Explorer call costs ~$0.01 per run (AWS's own API pricing).

set -euo pipefail
REGION="${AWS_DEFAULT_REGION:-us-east-1}"
echo "== AWS cost check — account $(aws sts get-caller-identity --query Account --output text) / region ${REGION} =="

echo ""
echo "--- 1. Glue interactive sessions (kill any READY/PROVISIONING) ---"
aws glue list-sessions --region "$REGION" \
  --query "Sessions[?Status=='READY'||Status=='PROVISIONING'].{Id:Id,Status:Status,DPU:MaxCapacity,Created:CreatedOn}" \
  --output table 2>/dev/null || echo "  (none, or list-sessions not permitted)"

echo ""
echo "--- 2. Glue crawlers on a schedule (SCHEDULED = recurring spend) ---"
aws glue list-crawlers --region "$REGION" --query "CrawlerNames" --output text 2>/dev/null \
  | tr '\t' '\n' | grep -v '^$' | while read -r c; do
    state=$(aws glue get-crawler --name "$c" --region "$REGION" \
      --query "Crawler.Schedule.State" --output text 2>/dev/null)
    [ "$state" = "SCHEDULED" ] && echo "  SCHEDULED: $c"
  done || true
echo "  (only SCHEDULED crawlers listed above; blank = none)"

echo ""
echo "--- 3. Glue job triggers that are activated/scheduled ---"
aws glue list-triggers --region "$REGION" --query "TriggerNames" --output text 2>/dev/null \
  | tr '\t' '\n' | grep -v '^$' | while read -r t; do
    info=$(aws glue get-trigger --name "$t" --region "$REGION" \
      --query "Trigger.[State,Type,Schedule]" --output text 2>/dev/null)
    echo "  $t -> $info"
  done || echo "  (none)"

echo ""
echo "--- 4. EventBridge rules that are ENABLED (may re-trigger the orchestrator) ---"
aws events list-rules --region "$REGION" \
  --query "Rules[?State=='ENABLED'].{Name:Name,Schedule:ScheduleExpression}" \
  --output table 2>/dev/null || echo "  (none)"

echo ""
echo "--- 5. Month-to-date spend by service (Cost Explorer) ---"
START=$(date -u +%Y-%m-01)
END=$(date -u +%Y-%m-%d)
aws ce get-cost-and-usage \
  --time-period Start="$START",End="$END" \
  --granularity MONTHLY \
  --metrics "UnblendedCost" \
  --group-by Type=DIMENSION,Key=SERVICE \
  --query "ResultsByTime[0].Groups[?Metrics.UnblendedCost.Amount!='0'].{Service:Keys[0],USD:Metrics.UnblendedCost.Amount}" \
  --output table 2>/dev/null || echo "  (Cost Explorer not enabled or not permitted)"

echo ""
echo "Done. Stop any session in (1); disable schedules in (2)-(4) if you're not actively building."

#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/log.sh"

for cmd in aws helm yq; do
  command -v "$cmd" >/dev/null || die "Missing $cmd"
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CHART="$ROOT/app/chart"

REGION=us-east-1
CLUSTER=llm-cluster
BUCKET=diy-llm
API_HOST=llm.danangan.com
[[ -n "${API_CERTIFICATE_ID:-}" ]] || die "Set API_CERTIFICATE_ID to the ACM certificate ID for $API_HOST"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
API_CERTIFICATE_ARN="arn:aws:acm:${REGION}:${ACCOUNT_ID}:certificate/${API_CERTIFICATE_ID}"

log "Checking the model in S3"
"$ROOT/.github/scripts/upload-model.sh" \
  "$(yq '.runtime.model.name' "$CHART/values.yaml")" \
  "$(yq '.runtime.model.revision' "$CHART/values.yaml")" \
  "$BUCKET"

log "Connecting to cluster $CLUSTER"
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER"

log "Deploying with Helm (a cold start can take ~15 minutes)"
helm upgrade --install diy-llm "$CHART" \
  --namespace default \
  --set runtime.model.bucketName="$BUCKET" \
  --set awsRegion="$REGION" \
  --set api.host="$API_HOST" \
  --set api.certificateArn="$API_CERTIFICATE_ARN" \
  --wait --timeout 40m

ok "Done! Deployed to https://$API_HOST"

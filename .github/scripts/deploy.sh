#!/usr/bin/env bash
# Deploys the app from your machine, like the deploy workflow: uploads the
# model to S3 if it isn't there yet, then installs the chart.
#
# Needs infra/ applied, the AWS CLI (logged in), Helm and yq, plus hf
# (pip install huggingface_hub) when the model isn't in S3 yet. Set HF_TOKEN
# for gated models.
#
# For faster model uploads, have the AWS CLI split and parallelise S3 transfers
# (once, in your AWS config): aws configure set default.s3.preferred_transfer_client crt

set -euo pipefail

for cmd in aws helm terraform yq; do
  command -v "$cmd" >/dev/null || { echo "Missing $cmd" >&2; exit 1; }
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CHART="$ROOT/app/chart"
output() { terraform -chdir="$ROOT/infra" output -raw "$1"; }

REGION="$(output region)"
CLUSTER="$(output cluster_name)"
BUCKET="$(output model_bucket)"
# UI_HOST="$(output ui_host)"
# UI_CERTIFICATE_ARN="$(output ui_certificate_arn)"

"$ROOT/.github/scripts/upload-model.sh" \
  "$(yq '.runtime.model.name' "$CHART/values.yaml")" \
  "$(yq '.runtime.model.revision' "$CHART/values.yaml")" \
  "$BUCKET"

aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER"

# A cold start (GPU node, image pull, model load) can take ~15 minutes
helm upgrade --install diy-llm "$CHART" \
  --namespace default \
  --set runtime.model.bucket="$BUCKET" \
  --set awsRegion="$REGION" \
  --set ui.host="$UI_HOST" \
  --set ui.certificateArn="$UI_CERTIFICATE_ARN" \
  --wait --timeout 40m

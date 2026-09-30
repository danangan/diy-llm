#!/usr/bin/env bash
# Deletes everything. The load balancers and EBS volumes are created from
# inside the cluster, so they're deleted first, while it's still running.

set -euo pipefail

TF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../infra" && pwd)"
output() { terraform -chdir="$TF_DIR" output -raw "$1"; }

aws eks update-kubeconfig --region "$(output region)" --name "$(output cluster_name)"

# obstack's volumes are set to Retain: switch them to Delete
kubectl get pv -o jsonpath='{range .items[?(@.spec.storageClassName=="obstack-gp3")]}{.metadata.name}{"\n"}{end}' \
  | xargs -r -I{} kubectl patch pv {} -p '{"spec":{"persistentVolumeReclaimPolicy":"Delete"}}'

# Removes the app (and its load balancer), then obstack
helm uninstall diy-llm -n default --wait --ignore-not-found
terraform -chdir="$TF_DIR" destroy -auto-approve -target=helm_release.obstack

# Both charts keep their volume claims on uninstall
kubectl delete pvc --all -n default --wait=false

echo "Waiting for load balancers and volumes to be deleted..."
for _ in $(seq 60); do
  [ -z "$(kubectl get pv -o name)" ] && break
  sleep 10
done
kubectl get pv -o name | sed 's/^/Not deleted, check the AWS console: /'

terraform -chdir="$TF_DIR" destroy -auto-approve

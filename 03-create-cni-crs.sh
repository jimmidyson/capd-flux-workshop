#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly SCRIPT_DIR

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/utils.sh"

export KUBECONFIG="${SCRIPT_DIR}/.local/kubeconfig"

declare -r WORKLOAD_CLUSTER_NAME="${WORKLOAD_CLUSTER_NAME:-demo-cluster-1}"

kubectl --context="${WORKLOAD_CLUSTER_NAME}" get nodes

print "Ensuring CNI is configured for workload clusters"
kubectl get configmap calico-manifests &>/dev/null || ( \
  curl -fsSL https://docs.projectcalico.org/v3.20/manifests/calico.yaml | \
    kubectl create configmap calico-manifests --from-file=calico.yaml=/dev/stdin
)

kubectl apply -f calico-manifests-crs.yaml

until kubectl --context="${WORKLOAD_CLUSTER_NAME}" -n kube-system get daemonset calico-node &>/dev/null; do
  sleep 1
done

kubectl --context="${WORKLOAD_CLUSTER_NAME}" -n kube-system set env \
  daemonset/calico-node FELIX_IGNORELOOSERPF=true
kubectl --context="${WORKLOAD_CLUSTER_NAME}" cluster-info
kubectl --context="${WORKLOAD_CLUSTER_NAME}" get nodes

kubectl --context="${WORKLOAD_CLUSTER_NAME}" wait --for=condition=Ready nodes --all
kubectl --context="${WORKLOAD_CLUSTER_NAME}" get nodes

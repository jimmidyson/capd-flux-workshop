#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly SCRIPT_DIR

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/utils.sh"

export PATH="${SCRIPT_DIR}/.local/bin:${PATH}"
export KUBECONFIG="${SCRIPT_DIR}/.local/kubeconfig"

declare -r WORKLOAD_CLUSTER_NAME="${WORKLOAD_CLUSTER_NAME:-demo-cluster-1}"

print "Scaling workload cluster ${WORKLOAD_CLUSTER_NAME} worker nodes to 2..."

kubectl scale machinedeployments "${WORKLOAD_CLUSTER_NAME}"-md-0 --replicas=2

kubectl wait --for=condition=Ready machinedeployments "${WORKLOAD_CLUSTER_NAME}"-md-0
kubectl get dockermachines
kubectl --context "${WORKLOAD_CLUSTER_NAME}" wait --for=condition=Ready nodes --all
kubectl --context "${WORKLOAD_CLUSTER_NAME}" get nodes

print "Scaling workload cluster ${WORKLOAD_CLUSTER_NAME} worker nodes to 1..."

kubectl scale machinedeployments "${WORKLOAD_CLUSTER_NAME}"-md-0 --replicas=1

kubectl get dockermachines

kubectl wait --for=condition=Ready machinedeployments "${WORKLOAD_CLUSTER_NAME}"-md-0
kubectl get dockermachines
kubectl --context "${WORKLOAD_CLUSTER_NAME}" wait --for=condition=Ready nodes --all
kubectl --context "${WORKLOAD_CLUSTER_NAME}" get nodes

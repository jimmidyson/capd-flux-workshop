#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly SCRIPT_DIR

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/utils.sh"

export KUBECONFIG="${SCRIPT_DIR}/.local/kubeconfig"

declare -r WORKLOAD_CLUSTER_NAME="${WORKLOAD_CLUSTER_NAME:-demo-cluster-1}"

print "Scaling workload cluster ${WORKLOAD_CLUSTER_NAME} worker nodes..."

kubectl scale machinedeployments "${WORKLOAD_CLUSTER_NAME}"-md-0 --replicas=0

kubectl wait --for=delete dockermachines -l cluster.x-k8s.io/deployment-name="${WORKLOAD_CLUSTER_NAME}"-md-0

kubectl get dockermachines

#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly SCRIPT_DIR

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/utils.sh"

export KUBECONFIG="${SCRIPT_DIR}/.local/kubeconfig"

declare -r WORKLOAD_CLUSTER_NAME="${WORKLOAD_CLUSTER_NAME:-demo-cluster-2}"

print "Deleting workload cluster ${WORKLOAD_CLUSTER_NAME}..."

kubectl delete cluster "${WORKLOAD_CLUSTER_NAME}" --ignore-not-found

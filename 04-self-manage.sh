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

export KUBECONFIG="${SCRIPT_DIR}/.local/kubeconfig"

CAPI_VERSION="$(clusterctl version -o=short)"
readonly CAPI_VERSION

if ! kubectl --context "${WORKLOAD_CLUSTER_NAME}" get namespaces capi-system &>/dev/null; then
  print "Bootstrapping CAPI controllers on ${WORKLOAD_CLUSTER_NAME}..."
  EXP_CLUSTER_RESOURCE_SET=true clusterctl init \
    --kubeconfig-context "${WORKLOAD_CLUSTER_NAME}" \
    --core "cluster-api:${CAPI_VERSION}" \
    --bootstrap "kubeadm:${CAPI_VERSION}" \
    --control-plane "kubeadm:${CAPI_VERSION}" \
    --infrastructure "docker:${CAPI_VERSION}" \
    --wait-providers
  print "CAPI controllers are ready on ${WORKLOAD_CLUSTER_NAME}!"
fi

kubectl --context "${WORKLOAD_CLUSTER_NAME}" get clusters "${WORKLOAD_CLUSTER_NAME}" &>/dev/null || \
  clusterctl move --to-kubeconfig "${KUBECONFIG}" --to-kubeconfig-context "${WORKLOAD_CLUSTER_NAME}"

kubectl config use-context "${WORKLOAD_CLUSTER_NAME}"

readonly KIND_CLUSTER_NAME='d2iq-capi-flux-workshop'
if kind get clusters | grep -Eo "^${KIND_CLUSTER_NAME}$" &>/dev/null; then
  print "Deleting management KinD cluster..."
  kind delete cluster --name "${KIND_CLUSTER_NAME}"
fi

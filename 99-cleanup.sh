#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly SCRIPT_DIR

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/utils.sh"

readonly KIND_CLUSTER_NAME='d2iq-capi-flux-workshop'

export KUBECONFIG="${SCRIPT_DIR}/.local/kubeconfig"

if kubectl get clusters -A &>/dev/null; then
  print "Deleting workload clusters..."
  kubectl delete clusters --all -A
fi

print "Deleting management KIND cluster..."
(kind get clusters | grep -Eo "^${KIND_CLUSTER_NAME}$" &>/dev/null && kind delete cluster --name "${KIND_CLUSTER_NAME}") || true

rm -rf -- .local

print "All cleaned up!"

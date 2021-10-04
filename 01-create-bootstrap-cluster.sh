#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly SCRIPT_DIR

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/utils.sh"

readonly KIND_CLUSTER_NAME='d2iq-capi-flux-workshop'

export KUBECONFIG="${SCRIPT_DIR}/.local/kubeconfig"

(kind get clusters 2>/dev/null | grep -Eo "^${KIND_CLUSTER_NAME}$" &>/dev/null) || ( \
  print "Creating bootstrap cluster...";
  kind create cluster --name "${KIND_CLUSTER_NAME}" --config "${SCRIPT_DIR}"/kind-config.yaml;
)

CAPI_VERSION="$(clusterctl version -o=short)"
readonly CAPI_VERSION

if ! kubectl get namespaces capi-system &>/dev/null; then
  print "Bootstrapping CAPI controllers..."
  EXP_CLUSTER_RESOURCE_SET=true clusterctl init \
    --core "cluster-api:${CAPI_VERSION}" \
    --bootstrap "kubeadm:${CAPI_VERSION}" \
    --control-plane "kubeadm:${CAPI_VERSION}" \
    --infrastructure "docker:${CAPI_VERSION}" \
    --wait-providers
  print "CAPI controllers are ready!"
fi

print "Bootstrap cluster kubeconfig written to ${KUBECONFIG}. Please export KUBECONFIG to your shell:"
printf '\nexport KUBECONFIG=%q\n' "${KUBECONFIG}"

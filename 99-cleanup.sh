#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly SCRIPT_DIR

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/utils.sh"

declare -r KIND_CLUSTER_NAME='d2iq-capi-flux-workshop'

export PATH="${SCRIPT_DIR}/.local/bin:${PATH}"
export KUBECONFIG="${SCRIPT_DIR}/.local/kubeconfig"

if kind get clusters 2>/dev/null | grep -Eo "^${KIND_CLUSTER_NAME}$" &>/dev/null; then
  print "Deleting management KinD cluster..."
  kind delete cluster --name "${KIND_CLUSTER_NAME}"
fi

IFS=$'\n' read -r -d '' -a WORKLOAD_CLUSTER_CONTAINERS < <(docker ps --format '{{.Names}}' | \
  grep -E "^demo-cluster-" \
  && printf '\0')

for c in "${WORKLOAD_CLUSTER_CONTAINERS[@]}"; do
  print "Deleting docker container ${c}..."
  docker rm -fv "${c}"
done

rm -rf -- "${SCRIPT_DIR}"/.local

print "All cleaned up!"

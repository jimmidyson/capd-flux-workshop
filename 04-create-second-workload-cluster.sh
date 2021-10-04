#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly SCRIPT_DIR

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/utils.sh"

declare -r WORKLOAD_CLUSTER_NAME="${WORKLOAD_CLUSTER_NAME:-demo-cluster-2}"

"${SCRIPT_DIR}"/02-create-capd-workload-cluster.sh

until kubectl --context="${WORKLOAD_CLUSTER_NAME}" -n kube-system get daemonset calico-node &>/dev/null; do
  sleep 1
done

kubectl --context="${WORKLOAD_CLUSTER_NAME}" -n kube-system set env \
  daemonset/calico-node FELIX_IGNORELOOSERPF=true
kubectl --context="${WORKLOAD_CLUSTER_NAME}" cluster-info
kubectl --context="${WORKLOAD_CLUSTER_NAME}" get nodes

kubectl --context="${WORKLOAD_CLUSTER_NAME}" wait --for=condition=Ready nodes --all
kubectl --context="${WORKLOAD_CLUSTER_NAME}" get nodes

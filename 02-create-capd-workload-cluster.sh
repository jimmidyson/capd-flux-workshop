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

declare -r LOCAL_MANIFESTS_DIR="${SCRIPT_DIR}/.local/manifests"
mkdir -p "${LOCAL_MANIFESTS_DIR}"

if ! kubectl get cluster "${WORKLOAD_CLUSTER_NAME}" &>/dev/null; then
  print "Creating workload cluster ${WORKLOAD_CLUSTER_NAME}"
  CUSTOM_NODE_IMAGE=jimmidyson/kind-capi-flux-workshop:v1.22.2@sha256:42aaba262d841693da2b2efb2f4bf3f013db4adc60ed19186daa2e867e5f6c8f \
    WORKER_MACHINE_COUNT="${WORKER_MACHINE_COUNT:-1}" \
    clusterctl generate cluster "${WORKLOAD_CLUSTER_NAME}" \
      --kubernetes-version "v1.22.2" \
      --from capd-cluster-template.yaml > "${LOCAL_MANIFESTS_DIR}/${WORKLOAD_CLUSTER_NAME}.yaml"
  until kubectl apply -f "${LOCAL_MANIFESTS_DIR}/${WORKLOAD_CLUSTER_NAME}.yaml"; do
    sleep 1
  done
fi

kubectl label --overwrite cluster "${WORKLOAD_CLUSTER_NAME}" cni=calico

print "Waiting for workload cluster ${WORKLOAD_CLUSTER_NAME} control plane to become ready..."
kubectl wait --for=condition=Ready --timeout=5m \
  kubeadmcontrolplanes/"${WORKLOAD_CLUSTER_NAME}"-control-plane

print "Configuring kubeconfig for workload cluster ${WORKLOAD_CLUSTER_NAME}..."
CURRENT_CONTEXT="$(kubectl config current-context)"
readonly CURRENT_CONTEXT
clusterctl get kubeconfig "${WORKLOAD_CLUSTER_NAME}" > "${SCRIPT_DIR}/.local/${WORKLOAD_CLUSTER_NAME}.kubeconfig"

if [ "$(uname | tr '[:upper:]' '[:lower:]')" == 'darwin' ]; then
  kubectl --kubeconfig="${SCRIPT_DIR}/.local/${WORKLOAD_CLUSTER_NAME}.kubeconfig" config set-cluster "${WORKLOAD_CLUSTER_NAME}" \
    --server="https://$(docker port "${WORKLOAD_CLUSTER_NAME}"-lb 6443/tcp | sed "s/0.0.0.0/127.0.0.1/")" \
    --insecure-skip-tls-verify=true
fi

KUBECONFIG="${SCRIPT_DIR}/.local/${WORKLOAD_CLUSTER_NAME}.kubeconfig:${KUBECONFIG}" kubectl config view --flatten > \
  "${SCRIPT_DIR}/.local/.kubeconfig.tmp"
mv "${SCRIPT_DIR}/.local/.kubeconfig.tmp" "${KUBECONFIG}"
if kubectl config get-contexts "${WORKLOAD_CLUSTER_NAME}" 2>/dev/null; then
  kubectl config delete-context "${WORKLOAD_CLUSTER_NAME}"
fi
kubectl config rename-context "${WORKLOAD_CLUSTER_NAME}-admin@${WORKLOAD_CLUSTER_NAME}" "${WORKLOAD_CLUSTER_NAME}"
kubectl config use-context "${CURRENT_CONTEXT}"

#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly SCRIPT_DIR

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/utils.sh"

export KUBECONFIG="${SCRIPT_DIR}/.local/kubeconfig"

CAPI_VERSION="$(clusterctl version -o=short)"
readonly CAPI_VERSION

declare -r WORKLOAD_CLUSTER_NAME="${WORKLOAD_CLUSTER_NAME:-demo-cluster-1}"

declare -r LOCAL_MANIFESTS_DIR="${SCRIPT_DIR}/.local/manifests"
mkdir -p "${LOCAL_MANIFESTS_DIR}"

kubectl get cluster "${WORKLOAD_CLUSTER_NAME}" &>/dev/null || ( \
  print "Creating workload cluster ${WORKLOAD_CLUSTER_NAME}"
  clusterctl generate cluster "${WORKLOAD_CLUSTER_NAME}" \
    --kubernetes-version "v1.22.2" \
    --from "https://github.com/kubernetes-sigs/cluster-api/blob/${CAPI_VERSION}/test/infrastructure/docker/templates/cluster-template-development.yaml" | \
    gojq --yaml-input --yaml-output 'select(.kind == "DockerMachineTemplate").spec.template.spec.customImage|="jimmidyson/kind-capi-flux-workshop:v1.22.2@sha256:7c46d0dddeea2fdba5bccaddd3efa7789194ee1b333540a708cc2890213fdf2c"' \
    > "${LOCAL_MANIFESTS_DIR}/${WORKLOAD_CLUSTER_NAME}.yaml";
  kubectl create -f "${LOCAL_MANIFESTS_DIR}/${WORKLOAD_CLUSTER_NAME}.yaml";
)

kubectl label --overwrite cluster "${WORKLOAD_CLUSTER_NAME}" cni=calico

print "Waiting for workload cluster ${WORKLOAD_CLUSTER_NAME} control plane to become ready..."
kubectl wait --for=condition=Ready --timeout=5m \
  kubeadmcontrolplanes/"${WORKLOAD_CLUSTER_NAME}"-control-plane

print "Configuring kubeconfig for workload cluster ${WORKLOAD_CLUSTER_NAME}..."
CURRENT_CONTEXT="$(kubectl config current-context)"
clusterctl get kubeconfig "${WORKLOAD_CLUSTER_NAME}" > "${SCRIPT_DIR}/.local/${WORKLOAD_CLUSTER_NAME}.kubeconfig"
env KUBECONFIG="${SCRIPT_DIR}/.local/${WORKLOAD_CLUSTER_NAME}.kubeconfig:${KUBECONFIG}" kubectl config view --flatten > \
  "${SCRIPT_DIR}/.local/.kubeconfig.tmp"
mv "${SCRIPT_DIR}/.local/.kubeconfig.tmp" "${KUBECONFIG}"
kubectl config delete-context "${WORKLOAD_CLUSTER_NAME}" 2>/dev/null || true
kubectl config rename-context "${WORKLOAD_CLUSTER_NAME}-admin@${WORKLOAD_CLUSTER_NAME}" "${WORKLOAD_CLUSTER_NAME}"
kubectl config use-context "${CURRENT_CONTEXT}"

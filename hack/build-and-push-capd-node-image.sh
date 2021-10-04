#!/usr/bin/env bash
set -euxo pipefail
IFS=$'\n\t'

TEMPDIR="$(mktemp -d /tmp/k8s-src.XXXXXX)"
readonly TEMPDIR
trap 'rm -rf "${TEMPDIR}"' EXIT

declare -r K8S_CLONE_DIR="${TEMPDIR}/kubernetes"

declare -r KUBERNETES_VERSION="${KUBERNETES_VERSION:-v1.22.2}"

git clone --single-branch --branch "${KUBERNETES_VERSION}" --depth 1 \
  git://github.com/kubernetes/kubernetes.git "${K8S_CLONE_DIR}"

docker run --rm --privileged \
  multiarch/qemu-user-static:5.2.0-2@sha256:14ef836763dd8a1d69927699811f89338b129faa3bd9eb52cd696bc3d84aa81a \
  --reset -p yes

kind build node-image --image jimmidyson/kind-node:"${KUBERNETES_VERSION}"-amd64 --arch amd64 "${K8S_CLONE_DIR}"
kind build node-image --image jimmidyson/kind-node:"${KUBERNETES_VERSION}"-arm64 --arch arm64 "${K8S_CLONE_DIR}"

parallel -j 2 -- docker push ::: jimmidyson/kind-node:"${KUBERNETES_VERSION}"-{amd64,arm64}
docker manifest create jimmidyson/kind-node:"${KUBERNETES_VERSION}" \
  --amend jimmidyson/kind-node:"${KUBERNETES_VERSION}"-arm64 --amend jimmidyson/kind-node:"${KUBERNETES_VERSION}"-amd64
docker manifest push jimmidyson/kind-node:"${KUBERNETES_VERSION}"

CAPI_VERSION="$(clusterctl version -o=short)"
readonly CAPI_VERSION

export KUBECONFIG="${TEMPDIR}"/kubeconfig
declare -r KIND_CLUSTER_NAME="capi-images-gathering"
trap 'kind delete cluster --name "${KIND_CLUSTER_NAME}" &>/dev/null || true' EXIT
kind create cluster --name "${KIND_CLUSTER_NAME}" --image jimmidyson/kind-node:"${KUBERNETES_VERSION}"

IFS=$'\n' read -r -d '' -a CAPI_IMAGES < <( clusterctl init \
  --core "cluster-api:${CAPI_VERSION}" \
  --bootstrap "kubeadm:${CAPI_VERSION}" \
  --control-plane "kubeadm:${CAPI_VERSION}" \
  --infrastructure "docker:${CAPI_VERSION}" \
  --list-images && printf '\0')

kind delete cluster --name "${KIND_CLUSTER_NAME}"

NODE_AMD64_CONTAINER="$(docker run -d --privileged --platform linux/amd64 --entrypoint containerd jimmidyson/kind-node:"${KUBERNETES_VERSION}"-amd64)"
readonly NODE_AMD64_CONTAINER
trap 'docker rm -fv "${NODE_AMD64_CONTAINER}" &>/dev/null || true' EXIT

NODE_ARM64_CONTAINER="$(docker run -d --privileged  --platform linux/arm64 --entrypoint containerd jimmidyson/kind-node:"${KUBERNETES_VERSION}"-arm64)"
readonly NODE_ARM64_CONTAINER
trap 'docker rm -fv "${NODE_ARM64_CONTAINER}" &>/dev/null || true' EXIT

declare -ra CALICO_IMAGES=(calico/node:v3.20.1 \
                           calico/cni:v3.20.1 \
                           calico/kube-controllers:v3.20.1 \
                           calico/pod2daemon-flexvol:v3.20.1)

for IMAGE in "${CAPI_IMAGES[@]}" "${CALICO_IMAGES[@]}"; do
  docker pull --platform=amd64 "${IMAGE}"
  docker save "${IMAGE}" | \
    docker exec -i "${NODE_AMD64_CONTAINER}" ctr --namespace=k8s.io image import --no-unpack -
done
docker commit -c 'ENTRYPOINT ["/usr/local/bin/entrypoint", "/sbin/init"]' \
  "${NODE_AMD64_CONTAINER}" jimmidyson/kind-capi-flux-workshop:"${KUBERNETES_VERSION}-amd64"
docker rm -fv "${NODE_AMD64_CONTAINER}"

docker commit -c 'ENTRYPOINT ["/usr/local/bin/entrypoint", "/sbin/init"]' \
  "${NODE_ARM64_CONTAINER}" jimmidyson/kind-capi-flux-workshop:"${KUBERNETES_VERSION}-arm64"
docker rm -fv "${NODE_ARM64_CONTAINER}"

parallel -j 2 -- docker push ::: jimmidyson/kind-capi-flux-workshop:"${KUBERNETES_VERSION}"-{amd64,arm64}
docker manifest rm jimmidyson/kind-capi-flux-workshop:"${KUBERNETES_VERSION}" || true
docker manifest create jimmidyson/kind-capi-flux-workshop:"${KUBERNETES_VERSION}" \
  --amend jimmidyson/kind-capi-flux-workshop:"${KUBERNETES_VERSION}"-arm64@"$(docker image inspect jimmidyson/kind-capi-flux-workshop:"${KUBERNETES_VERSION}"-arm64 | gojq -r '.[0].RepoDigests[0] | scan("sha256:.+$")')" \
  --amend jimmidyson/kind-capi-flux-workshop:"${KUBERNETES_VERSION}"-amd64@"$(docker image inspect jimmidyson/kind-capi-flux-workshop:"${KUBERNETES_VERSION}"-amd64 | gojq -r '.[0].RepoDigests[0] | scan("sha256:.+$")')"
docker manifest push jimmidyson/kind-capi-flux-workshop:"${KUBERNETES_VERSION}"

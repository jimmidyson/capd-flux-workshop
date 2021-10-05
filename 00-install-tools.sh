#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/utils.sh"

errexit() {
  echo "${1:-}"
  exit 1
}

OS="$(uname | tr '[:upper:]' '[:lower:]')"
readonly OS
case "${OS}" in
  darwin) ;;
  linux) ;;
  *)
    errexit "Unsupported operating system ${OS}"
    ;;
esac

ARCH="$(uname -m)"
case "${ARCH}" in
  arm | armv6l | armv7l)
    ARCH=arm
    ;;
  arm64 | aarch64 | armv8l)
    ARCH=arm64
    ;;
  amd64)
    ARCH=amd64
    ;;
  x86_64)
    ARCH=amd64
    ;;
  *)
    errexit "Unsupported architecture ${ARCH}"
    ;;
esac
readonly ARCH

declare -r BINDIR="${SCRIPT_DIR}"/.local/bin
mkdir -p "${BINDIR}"

test -f "${BINDIR}"/kind || (
  print "Downloading kind..."
  curl -fsSLo "${BINDIR}"/kind https://kind.sigs.k8s.io/dl/v0.11.1/kind-"${OS}"-"${ARCH}"
)
chmod +x "${BINDIR}"/kind

test -f "${BINDIR}"/flux || (
  print "Downloading flux..."
  curl -fsSL https://github.com/fluxcd/flux2/releases/download/v0.17.2/flux_0.17.2_"${OS}"_"${ARCH}".tar.gz |
    tar xz -C "${BINDIR}"
)

test -f "${BINDIR}"/kubectl || (
  print "Downloading kubectl..."
  curl -fsSLo "${BINDIR}"/kubectl https://dl.k8s.io/release/v1.22.2/bin/"${OS}"/"${ARCH}"/kubectl
)
chmod +x "${BINDIR}"/kubectl

test -f "${BINDIR}"/clusterctl || (
  print "Downloading clusterctl..."
  curl -fsSLo "${BINDIR}"/clusterctl https://github.com/kubernetes-sigs/cluster-api/releases/download/v0.4.3/clusterctl-"${OS}"-"${ARCH}"
)
chmod +x "${BINDIR}"/clusterctl

test -f "${BINDIR}"/kustomize || (
  print "Downloading kustomize..."
  curl -fsSL https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv4.4.0/kustomize_v4.4.0_"${OS}"_"${ARCH}".tar.gz |
    tar xz -C "${BINDIR}"
)

print "$(printf 'Tools downloaded to %s. Please configure your PATH with:\n' "${BINDIR}")" >/dev/stderr
# shellcheck disable=SC2016
printf '\nexport PATH="%s:${PATH}"\n' "${BINDIR}"

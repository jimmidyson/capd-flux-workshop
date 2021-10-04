#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly SCRIPT_DIR

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/utils.sh"

for f in ./[0-9][0-9]*.sh; do
  print "Executing ${f}..."
  ./"${f}"
done

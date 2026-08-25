#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "${ROOT_DIR}/hack/lib/init.sh"

function ci() {
  make install "$@"
  make deps "$@"
  make lint "$@"
  make test "$@"
  make build "$@"
}

#
# main
#

aistack::log::info "+++ CI +++"
ci "$@"
aistack::log::info "--- CI ---"

#!/usr/bin/env bash

# rebrand-ui.sh — Post-download UI branding replacement
#
# This script is called after downloading the upstream GPUStack UI package.
# It patches the compiled UI assets to replace GPUStack branding with AiStack:
#   1. Replace logo images (gpustack-logo.*.png → aistack-logo-wide.png)
#   2. Replace small logo (small-logo-200x200.*.png)
#   3. Replace favicon.png and favicon.ico
#   4. Patch index.html <title>
#   5. Patch JS bundle: replace UI-visible "GPUStack" text with "AiStack"
#
# Usage:
#   hack/rebrand-ui.sh <ui_dir> <branding_dir>
#
# Arguments:
#   ui_dir       — Path to the extracted UI directory (e.g. aistack/ui)
#   branding_dir — Path to branding assets directory (e.g. branding/ui-assets)

set -o errexit
set -o nounset
set -o pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

# Include the common functions if available
if [[ -f "${ROOT_DIR}/hack/lib/init.sh" ]]; then
  source "${ROOT_DIR}/hack/lib/init.sh"
  LOG_CMD="aistack::log::info"
  LOG_WARN="aistack::log::warn"
else
  LOG_CMD="echo [INFO]"
  LOG_WARN="echo [WARN]"
fi

function log_info() {
  if [[ -n "${LOG_CMD:-}" ]]; then
    $LOG_CMD "$@"
  fi
}

function log_warn() {
  if [[ -n "${LOG_WARN:-}" ]]; then
    $LOG_WARN "$@"
  fi
}

UI_DIR="${1:-${ROOT_DIR}/aistack/ui}"
BRANDING_DIR="${2:-${ROOT_DIR}/branding/ui-assets}"

if [[ ! -d "${UI_DIR}" ]]; then
  log_warn "UI directory not found: ${UI_DIR}, skipping rebrand"
  exit 0
fi

if [[ ! -d "${BRANDING_DIR}" ]]; then
  log_warn "Branding directory not found: ${BRANDING_DIR}, skipping rebrand"
  exit 0
fi

log_info "+++ UI REBRAND +++"

# ============================================================
# 1. Replace logo images
# ============================================================

log_info "Replacing logo images..."

# Replace main wide logo: gpustack-logo.*.png
if [[ -f "${BRANDING_DIR}/aistack-logo-wide.png" ]]; then
  for f in "${UI_DIR}"/static/gpustack-logo.*.png; do
    if [[ -f "$f" ]]; then
      cp "${BRANDING_DIR}/aistack-logo-wide.png" "$f"
      log_info "  replaced $(basename "$f")"
    fi
  done
else
  log_warn "  aistack-logo-wide.png not found in branding dir"
fi

# Replace small logo: small-logo-200x200.*.png
if [[ -f "${BRANDING_DIR}/small-logo-200x200.png" ]]; then
  for f in "${UI_DIR}"/static/small-logo-200x200.*.png; do
    if [[ -f "$f" ]]; then
      cp "${BRANDING_DIR}/small-logo-200x200.png" "$f"
      log_info "  replaced $(basename "$f")"
    fi
  done
else
  log_warn "  small-logo-200x200.png not found in branding dir"
fi

# ============================================================
# 2. Replace favicons
# ============================================================

log_info "Replacing favicons..."

if [[ -f "${BRANDING_DIR}/favicon.png" ]]; then
  # Root-level favicon
  [[ -f "${UI_DIR}/favicon.png" ]] && cp "${BRANDING_DIR}/favicon.png" "${UI_DIR}/favicon.png"
  # Static-level favicon
  [[ -f "${UI_DIR}/static/favicon.png" ]] && cp "${BRANDING_DIR}/favicon.png" "${UI_DIR}/static/favicon.png"
  log_info "  replaced favicon.png"
fi

if [[ -f "${BRANDING_DIR}/favicon.ico" ]]; then
  [[ -f "${UI_DIR}/favicon.ico" ]] && cp "${BRANDING_DIR}/favicon.ico" "${UI_DIR}/favicon.ico"
  [[ -f "${UI_DIR}/static/favicon.ico" ]] && cp "${BRANDING_DIR}/favicon.ico" "${UI_DIR}/static/favicon.ico"
  log_info "  replaced favicon.ico"
fi

# ============================================================
# 3. Patch index.html
# ============================================================

log_info "Patching index.html..."

if [[ -f "${UI_DIR}/index.html" ]]; then
  # Replace <title>GPUStack</title> with <title>AiStack</title>
  sed -i 's|<title>GPUStack</title>|<title>AiStack</title>|g' "${UI_DIR}/index.html"
  log_info "  patched <title>"
fi

# ============================================================
# 4. Patch JS bundle — replace UI-visible strings
# ============================================================

log_info "Patching JS bundle..."

for jsfile in "${UI_DIR}"/js/umi.*.js; do
  if [[ ! -f "$jsfile" ]]; then
    log_warn "  no umi.*.js found"
    continue
  fi

  log_info "  patching $(basename "$jsfile") ($(wc -c < "$jsfile") bytes)"

  # -----------------------------------------------------------
  # Strategy: We use targeted sed replacements in careful order.
  #
  # PRESERVE (do NOT change):
  #   - GPUSTACK_*          — environment variable names
  #   - gpustack-system     — k8s namespace default
  #   - gpustack-server     — k8s service/container name
  #   - gpustack-worker     — docker container default name
  #   - gpustack-data       — docker volume default name
  #   - /var/lib/gpustack   — data directory path
  #   - gpustack.asset-*    — internal localStorage key
  #   - gpustack:           — internal localStorage key prefix
  #   - gpustack_runner/runtime/higress — Python package names
  #
  # REPLACE:
  #   - "GPUStack" (brand name in UI text) → "AiStack"
  #   - "GPUStack.ai" (company name)       → "AiStack.ai"
  #   - "gpustack.ai" (docs domain)        → "aistack.ai"
  #   - github.com/gpustack/gpustack       → user's own repo
  #   - github.com/gpustack/llama-box      → keep (upstream dep)
  #   - X-GPUStack-Model                   → X-AiStack-Model
  # -----------------------------------------------------------

  # Step 1: Protect strings we want to keep by replacing them with unique markers
  # (This prevents the broader GPUStack→AiStack replacement from hitting them)

  sed -i \
    -e 's|GPUSTACK_RUNTIME|__KEEP_ENV_RT__|g' \
    -e 's|GPUSTACK_TIMEZONE|__KEEP_ENV_TZ__|g' \
    -e 's|gpustack-system|__KEEP_K8S_NS__|g' \
    -e 's|gpustack-server-cluster-ip|__KEEP_K8S_SVC__|g' \
    -e 's|gpustack-worker|__KEEP_DOCKER_WKR__|g' \
    -e 's|gpustack-data|__KEEP_DOCKER_VOL__|g' \
    -e 's|/var/lib/gpustack|__KEEP_DATA_DIR__|g' \
    -e 's|gpustack\.asset-recovery|__KEEP_LS_KEY__|g' \
    -e 's|"gpustack:"|__KEEP_LS_PREFIX__|g' \
    -e 's|github\.com/gpustack/llama-box|__KEEP_GH_LLAMA__|g' \
    -e 's|gpustack/gpustack/issues|__KEEP_GH_ISSUES__|g' \
    "$jsfile"

  # Step 2: Replace brand-visible strings
  sed -i \
    -e 's|GPUStack Enterprise|AiStack Enterprise|g' \
    -e 's|GPUStack Server|AiStack Server|g' \
    -e 's|GPUStack Data Volume|AiStack Data Volume|g' \
    -e 's|GPUStack Operator|AiStack Operator|g' \
    -e 's|GPUStack Certified|AiStack Certified|g' \
    -e 's|X-GPUStack-Model|X-AiStack-Model|g' \
    -e 's|GPUStack\.ai|AiStack.ai|g' \
    -e 's|docs\.gpustack\.ai|docs.aistack.ai|g' \
    -e 's|Install GPUStack|Install AiStack|g' \
    -e 's|GPUStack {version}|AiStack {version}|g' \
    -e 's|GPUStack upgrade|AiStack upgrade|g' \
    -e 's|GPUStack images|AiStack images|g' \
    -e 's|GPUStack publishes|AiStack publishes|g' \
    -e 's|GPUStack installation|AiStack installation|g' \
    -e 's|the GPUStack|the AiStack|g' \
    -e 's|on GPUStack|on AiStack|g' \
    -e 's|in GPUStack|in AiStack|g' \
    -e 's|to GPUStack|to AiStack|g' \
    -e 's|from GPUStack|from AiStack|g' \
    -e 's|a GPUStack|a AiStack|g' \
    -e 's|After a GPUStack|After a AiStack|g' \
    "$jsfile"

  # Catch remaining standalone "GPUStack" that haven't been replaced
  # (but protect GPUSTACK_ env var pattern which is already marker-protected)
  sed -i \
    -e 's|GPUStack|AiStack|g' \
    "$jsfile"

  # Step 2b: Handle Chinese text occurrences
  sed -i \
    -e 's|AiStack 数据卷|AiStack 数据卷|g' \
    "$jsfile"

  # Step 3: Restore protected markers back to originals
  sed -i \
    -e 's|__KEEP_ENV_RT__|GPUSTACK_RUNTIME|g' \
    -e 's|__KEEP_ENV_TZ__|GPUSTACK_TIMEZONE|g' \
    -e 's|__KEEP_K8S_NS__|gpustack-system|g' \
    -e 's|__KEEP_K8S_SVC__|gpustack-server-cluster-ip|g' \
    -e 's|__KEEP_DOCKER_WKR__|gpustack-worker|g' \
    -e 's|__KEEP_DOCKER_VOL__|gpustack-data|g' \
    -e 's|__KEEP_DATA_DIR__|/var/lib/gpustack|g' \
    -e 's|__KEEP_LS_KEY__|gpustack.asset-recovery|g' \
    -e 's|__KEEP_LS_PREFIX__|"gpustack:"|g' \
    -e 's|__KEEP_GH_LLAMA__|github.com/gpustack/llama-box|g' \
    -e 's|__KEEP_GH_ISSUES__|gpustack/gpustack/issues|g' \
    "$jsfile"

  log_info "  patched $(basename "$jsfile") → $(wc -c < "$jsfile") bytes"
done

# ============================================================
# 5. Patch CSS if needed
# ============================================================

log_info "Checking CSS files..."
for cssfile in "${UI_DIR}"/css/umi.*.css; do
  if [[ -f "$cssfile" ]]; then
    if grep -q "GPUStack\|gpustack" "$cssfile" 2>/dev/null; then
      sed -i 's|GPUStack|AiStack|g' "$cssfile"
      log_info "  patched $(basename "$cssfile")"
    fi
  fi
done

log_info "--- UI REBRAND ---"
log_info "UI rebrand complete!"

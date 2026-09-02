#!/usr/bin/env bash
#
# AiStack Docker Image Build Script
# ===================================
# One-click build for AiStack container image.
#
# The Dockerfile's multi-stage build pulls several upstream binary images
# (operator, Higress gateway components) that currently only exist on
# Docker Hub under the "gpustack" namespace. These are build-time
# dependencies only — the final image runs 100% AiStack-branded code.
#
# Usage:
#   ./build-image.sh                    # Build with default settings
#   ./build-image.sh --push             # Build and push to registry
#   ./build-image.sh --registry <url>   # Use private registry
#   ./build-image.sh --tag v1.0.0       # Custom tag
#   ./build-image.sh --help             # Show help
#
# Environment variables (override defaults):
#   IMAGE_NAMESPACE   - Image namespace (default: aistack)
#   IMAGE_REPOSITORY  - Image repository (default: aistack)
#   IMAGE_TAG         - Image tag (default: latest)
#   IMAGE_REGISTRY    - Registry URL (default: docker.io)
#   UPSTREAM_NS       - Upstream image namespace for build deps (default: gpustack)
#   BUILD_ARCH        - Target architecture: amd64 | arm64 (default: auto-detect)
#   NO_CACHE          - Set "true" to build without cache
#

set -euo pipefail

# ─── Defaults ────────────────────────────────────────────────────────
IMAGE_NAMESPACE="${IMAGE_NAMESPACE:-aistack}"
IMAGE_REPOSITORY="${IMAGE_REPOSITORY:-aistack}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
IMAGE_REGISTRY="${IMAGE_REGISTRY:-docker.io}"
UPSTREAM_NS="${UPSTREAM_NS:-gpustack}"
BUILD_ARCH="${BUILD_ARCH:-$(uname -m | sed 's/aarch64/arm64/' | sed 's/x86_64/amd64/')}"
NO_CACHE="${NO_CACHE:-false}"
DO_PUSH=false

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# ─── Color helpers ───────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ─── Parse arguments ────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --push)       DO_PUSH=true; shift ;;
        --tag)        IMAGE_TAG="$2"; shift 2 ;;
        --registry)   IMAGE_REGISTRY="$2"; shift 2 ;;
        --namespace)  IMAGE_NAMESPACE="$2"; shift 2 ;;
        --upstream)   UPSTREAM_NS="$2"; shift 2 ;;
        --arch)       BUILD_ARCH="$2"; shift 2 ;;
        --no-cache)   NO_CACHE=true; shift ;;
        --help|-h)
            cat <<'HELP'
AiStack Docker Image Build Script

Usage: ./build-image.sh [OPTIONS]

Options:
  --tag TAG          Image tag (default: latest)
  --registry URL     Registry URL (default: docker.io)
  --namespace NS     Image namespace (default: aistack)
  --upstream NS      Upstream build-dep namespace (default: gpustack)
  --arch ARCH        Target arch: amd64 | arm64 (default: auto)
  --push             Push image to registry after build
  --no-cache         Build without Docker cache
  -h, --help         Show this help

Examples:
  # Basic local build
  ./build-image.sh

  # Build and push to Docker Hub
  ./build-image.sh --push

  # Build for private Harbor registry
  ./build-image.sh --registry harbor.mycompany.com --push

  # Build specific version
  ./build-image.sh --tag v2.0.0 --push

  # Build without cache (clean build)
  ./build-image.sh --no-cache

Environment Variables:
  IMAGE_NAMESPACE, IMAGE_REPOSITORY, IMAGE_TAG, IMAGE_REGISTRY,
  UPSTREAM_NS, BUILD_ARCH, NO_CACHE
HELP
            exit 0 ;;
        *) error "Unknown option: $1"; exit 1 ;;
    esac
done

# ─── Computed values ─────────────────────────────────────────────────
if [[ "${IMAGE_REGISTRY}" == "docker.io" ]]; then
    FULL_IMAGE="${IMAGE_NAMESPACE}/${IMAGE_REPOSITORY}:${IMAGE_TAG}"
else
    FULL_IMAGE="${IMAGE_REGISTRY}/${IMAGE_NAMESPACE}/${IMAGE_REPOSITORY}:${IMAGE_TAG}"
fi

# ─── Pre-flight checks ──────────────────────────────────────────────
info "============================================"
info "  AiStack Docker Image Builder"
info "============================================"
echo ""
info "Build Configuration:"
echo -e "  ${CYAN}Image:${NC}         ${FULL_IMAGE}"
echo -e "  ${CYAN}Architecture:${NC}  linux/${BUILD_ARCH}"
echo -e "  ${CYAN}Upstream NS:${NC}   ${UPSTREAM_NS} (build-stage FROM images)"
echo -e "  ${CYAN}Push:${NC}          ${DO_PUSH}"
echo -e "  ${CYAN}No Cache:${NC}      ${NO_CACHE}"
echo ""

# Check Docker
if ! command -v docker &>/dev/null; then
    error "Docker is not installed. Please install Docker first."
    error "  https://docs.docker.com/engine/install/"
    exit 1
fi

# Check Docker daemon
if ! docker info &>/dev/null 2>&1; then
    error "Docker daemon is not running. Please start Docker first."
    exit 1
fi

# Check Buildx
if ! docker buildx version &>/dev/null 2>&1; then
    warn "Docker Buildx not available, falling back to regular docker build."
    warn "Buildx is recommended for better caching and multi-arch support."
    USE_BUILDX=false
else
    USE_BUILDX=true
fi

# ─── DNS connectivity check ─────────────────────────────────────────
info "Checking network connectivity..."
if ! curl -sf --connect-timeout 5 "https://registry-1.docker.io/v2/" &>/dev/null && \
   ! curl -sf --connect-timeout 5 "https://hub.docker.com" &>/dev/null; then
    warn "Cannot reach Docker Hub directly."
    warn "If you have a registry mirror configured in /etc/docker/daemon.json, that's OK."
    warn "Otherwise, the build may fail to pull upstream base images."
    echo ""
    read -p "Continue anyway? [y/N] " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] || exit 1
fi

# ─── Build ───────────────────────────────────────────────────────────
info "Starting Docker build..."
echo ""

EXTRA_ARGS=()
if [[ "${NO_CACHE}" == "true" ]]; then
    EXTRA_ARGS+=("--no-cache")
fi

if [[ "${USE_BUILDX}" == "true" ]]; then
    # Ensure builder exists
    if ! docker buildx inspect --builder "aistack-builder" &>/dev/null 2>&1; then
        info "Creating buildx builder 'aistack-builder'..."
        docker buildx create \
            --name "aistack-builder" \
            --driver "docker-container" \
            --driver-opt "network=host,default-load=true" \
            --bootstrap
    fi

    BUILDX_OUTPUT="--load"
    if [[ "${DO_PUSH}" == "true" ]]; then
        BUILDX_OUTPUT="--push"
    fi

    set -x
    docker buildx build \
        --pull \
        --allow network.host \
        --builder "aistack-builder" \
        --platform "linux/${BUILD_ARCH}" \
        --tag "${FULL_IMAGE}" \
        --file "${ROOT_DIR}/pack/Dockerfile" \
        --ulimit nofile=65536:65536 \
        --shm-size 16G \
        --progress plain \
        --build-arg "UPSTREAM_NS=${UPSTREAM_NS}" \
        --build-arg "UI_DOWNLOAD=true" \
        "${EXTRA_ARGS[@]}" \
        "${BUILDX_OUTPUT}" \
        "${ROOT_DIR}"
    set +x
else
    # Fallback: regular docker build
    set -x
    docker build \
        --tag "${FULL_IMAGE}" \
        --file "${ROOT_DIR}/pack/Dockerfile" \
        --build-arg "UPSTREAM_NS=${UPSTREAM_NS}" \
        --build-arg "UI_DOWNLOAD=true" \
        "${EXTRA_ARGS[@]}" \
        "${ROOT_DIR}"
    set +x

    if [[ "${DO_PUSH}" == "true" ]]; then
        info "Pushing image..."
        docker push "${FULL_IMAGE}"
    fi
fi

# ─── Post-build ──────────────────────────────────────────────────────
echo ""
info "============================================"
info "  Build Complete!"
info "============================================"
echo ""
info "Image: ${FULL_IMAGE}"
echo ""

if [[ "${DO_PUSH}" == "false" ]]; then
    echo -e "${CYAN}Next steps:${NC}"
    echo ""
    echo "  # Verify the image"
    echo "  docker images ${FULL_IMAGE}"
    echo ""
    echo "  # Test run"
    echo "  docker run --rm ${FULL_IMAGE} aistack version"
    echo ""
    echo "  # Push to registry (if needed)"
    echo "  docker push ${FULL_IMAGE}"
    echo ""
    echo "  # Save as tar for offline transfer"
    echo "  docker save ${FULL_IMAGE} | gzip > aistack-${IMAGE_TAG}.tar.gz"
    echo ""
    echo "  # Load on target machine (offline)"
    echo "  docker load < aistack-${IMAGE_TAG}.tar.gz"
    echo ""
    echo "  # Use with docker-compose"
    echo "  cd docker-compose"
    echo "  cp docker-compose.server.yaml docker-compose.yml"
    echo "  docker-compose up -d"
fi

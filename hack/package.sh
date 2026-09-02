#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "${ROOT_DIR}/hack/lib/init.sh"

PACKAGE_NAMESPACE=${PACKAGE_NAMESPACE:-aistack}
PACKAGE_REPOSITORY=${PACKAGE_REPOSITORY:-aistack}
PACKAGE_ARCH=${PACKAGE_ARCH:-$(uname -m | sed 's/aarch64/arm64/' | sed 's/x86_64/amd64/')}
PACKAGE_TAG=${PACKAGE_TAG:-dev}
PACKAGE_WITH_CACHE=${PACKAGE_WITH_CACHE:-true}
PACKAGE_PUSH=${PACKAGE_PUSH:-false}
PACKAGE_UI_DOWNLOAD=${PACKAGE_UI_DOWNLOAD:-true}
# Upstream image namespace for build-stage FROM dependencies.
# Default: gpustack (uses Docker Hub gpustack/* images that actually exist).
# Override with UPSTREAM_NS=aistack once you publish your own base images.
UPSTREAM_NS=${UPSTREAM_NS:-gpustack}

function pack() {
    if ! command -v docker &>/dev/null; then
        aistack::log::fatal "Docker is not installed. Please install Docker to use this target."
        exit 1
    fi

    if ! docker buildx version &>/dev/null; then
        aistack::log::fatal "Docker Buildx plugin is not available." \
            "Install it with the package manager, e.g. 'apt-get install docker-buildx-plugin' or 'yum install docker-buildx-plugin'," \
            "or drop the release binary into '/usr/local/lib/docker/cli-plugins/docker-buildx' and make it executable." \
            "See https://docs.docker.com/build/install-buildx/ for details."
    fi

    if ! docker buildx inspect --builder "aistack" &>/dev/null; then
        aistack::log::info "Creating new buildx builder 'aistack'"
        docker run --rm --privileged tonistiigi/binfmt:qemu-v9.2.2-52 --uninstall qemu-*
        docker run --rm --privileged tonistiigi/binfmt:qemu-v9.2.2-52 --install all
        docker buildx create \
            --name "aistack" \
            --driver "docker-container" \
            --driver-opt "network=host,default-load=true,env.BUILDKIT_STEP_LOG_MAX_SIZE=-1,env.BUILDKIT_STEP_LOG_MAX_SPEED=-1" \
            --buildkitd-flags "--allow-insecure-entitlement=security.insecure --allow-insecure-entitlement=network.host --oci-worker-net=host --oci-worker-gc-keepstorage=204800" \
            --bootstrap
    fi

    LABELS=("org.opencontainers.image.source=https://github.com/jibiao-ai/AiStack" "org.opencontainers.image.version=main" "org.opencontainers.image.revision=$(git rev-parse HEAD 2>/dev/null || echo "unknown")" "org.opencontainers.image.created=$(date +"%Y-%m-%dT%H:%M:%S.%s")");
    TAG="${PACKAGE_NAMESPACE}/${PACKAGE_REPOSITORY}:${PACKAGE_TAG}"
    EXTRA_ARGS=()
	if [[ "${PACKAGE_WITH_CACHE}" == "true" ]]; then
		# NOTE: The upstream GPUStack build cache may not be accessible for self-hosted builds.
		# Replace with your own cache registry or remove this line if not using remote caching.
		EXTRA_ARGS+=("--cache-from=type=registry,ref=gpustack/build-cache:gpustack-main")
	fi
	if [[ "${PACKAGE_PUSH}" == "true" ]]; then
		EXTRA_ARGS+=("--push")
	fi
	for label in "${LABELS[@]}"; do
		EXTRA_ARGS+=("--label" "${label}")
	done
    aistack::log::info "Building '${TAG}' platform 'linux/${PACKAGE_ARCH}'"
    set -x
    docker buildx build \
        --pull \
        --allow network.host \
        --allow security.insecure \
        --builder "aistack" \
        --platform "linux/${PACKAGE_ARCH}" \
        --tag "${TAG}" \
        --file "${ROOT_DIR}/pack/Dockerfile" \
        --ulimit nofile=65536:65536 \
        --shm-size 16G \
        --progress plain \
        --build-arg "UPSTREAM_NS=${UPSTREAM_NS}" \
        --build-arg "GPUSTACK_RUNTIME_DOCKER_MIRRORED_NAME_FILTER_LABELS=$(printf "%s;" "${LABELS[@]}")" \
        --build-arg "UI_DOWNLOAD=${PACKAGE_UI_DOWNLOAD}" \
        "${EXTRA_ARGS[@]}" \
        "${ROOT_DIR}"
    set +x
}

aistack::log::info "+++ PACKAGE +++"
pack
aistack::log::info "--- PACKAGE ---"

# Air-Gapped Installation

AiStack can be installed in an air-gapped (offline) environment with no internet access.

## Prerequisites

### Driver

Ensure your system has the appropriate GPU drivers installed for your hardware.

See the [Installation Requirements](./requirements.md) for details on driver compatibility.

### Container Running Environment

[Docker](https://docs.docker.com/engine/install/) must be installed.

If your system supports a container toolkit, install and configure it as needed (e.g., NVIDIA Container Toolkit, AMD ROCm Container Toolkit, etc.).

### Container Images

AiStack offers an [Image Selector](https://docs.aistack.ai/latest/image-selector/) site to help users easily pick the images they want to download. For more advanced or automated syncing, AiStack also provides image management commands:

- `aistack copy-images`: Sync images from one registry to another
- `aistack save-images`: Download images and save them locally
- `aistack load-images`: Import images from local packages
- `aistack list-images`: Show the manifest of images for the current version

Below are the details on how to use these CLI commands.

- **Copy Images**

AiStack provides various container images for different components and inference backends, available on [Docker Hub](https://hub.docker.com/u/aistack) and [Quay.io](https://quay.io/user/aistack/).

To transfer the required container images to your internal registry from a machine with internet access, use the AiStack `copy-images` command:

```bash
sudo docker run --rm -it --entrypoint "" aistack/aistack \
    aistack copy-images \
    --destination <your_internal_registry> \
    --destination-username <your_username> \
    --destination-password <your_password>
```

If you cannot pull images from `Docker Hub` or the download is very slow, you can use our `Quay.io` mirror by pointing the source registry to `quay.io`:

```bash hl_lines="3"
sudo docker run --rm -it --entrypoint "" aistack/aistack \
    aistack copy-images \
    --source quay.io \
    --destination <your_internal_registry> \
    --destination-username <your_username> \
    --destination-password <your_password>
```

!!! note

    This uses the latest version by default. To target a specific version, use the full image tag, e.g., aistack/aistack:vx.y.z.

For more details on `copy-images`, refer to the [CLI Reference](../cli-reference/copy-images.md).

- **List Images**

If you cannot access your internal registry directly, you can first pull the `aistack/aistack` image and then use `list-images` command to see which images need to be downloaded:

```bash
sudo docker run --rm -it --entrypoint "" \
    aistack/aistack \
    aistack list-images
```

!!! note

    This uses the latest version by default. To target a specific version, use the full image tag, e.g., aistack/aistack:vx.y.z.

The displayed image list includes all supported accelerators, inference backends, versions, and architectures. If you only need a subset, see the [CLI Reference](../cli-reference/list-images.md) for filtering options.

- **Copy and Load Images**

If your target environment is air-gapped or does not have internet access, you can first download the required images on a machine with internet connectivity, then transfer and load them into the offline environment.

AiStack provides the `save-images` and `load-images` commands for this workflow.

**Copy Images**

Run the following command on a machine that can access the internet to download and package the required images:

```bash
sudo docker run --rm -it --entrypoint "" \
 -v ./aistack-air-gapped:/aistack-air-gapped \
 --workdir /aistack-air-gapped \
 aistack/aistack \
 aistack save-images \
 --platform linux/amd64 \
 --backend cuda \
 --backend-version 12.9 \
 --service vllm \
 --service-version 0.15.1 \
 --max-workers 3 \
 --max-retries 3
```

This command downloads all required container images based on the specified platform, backend, and service configuration, and saves them as local packages under the `aistack-air-gapped` directory. The example command shows how to apply filtering options to download only a subset of images.

!!! note

    This uses the latest version by default. To target a specific version, use the full image tag, e.g., aistack/aistack:vx.y.z.

You can adjust the filters to download only the images you need. See the [CLI Reference](../cli-reference/save-images.md) for all available options.

After the download completes, transfer the generated directory to your air-gapped environment using your preferred method (for example, USB drive or internal file transfer).

**Load Images**

On the target machine, load the saved images into the local container runtime:

```bash
sudo docker run --rm -it --entrypoint "" \
    --volume /var/run/docker.sock:/var/run/docker.sock \
    --volume ./aistack-air-gapped:/aistack-air-gapped \
    --workdir /aistack-air-gapped \
    aistack/aistack \
    aistack load-images \
    --platform linux/amd64 \
    --max-workers 3 \
    --max-retries 3 \
    /aistack-air-gapped
```

This command imports all image packages from the specified directory into the local Docker daemon, making them available for AiStack.

!!! note

    This uses the latest version by default. To target a specific version, use the full image tag, e.g., aistack/aistack:vx.y.z.

For more details on `load-images`, see the [CLI Reference](../cli-reference/load-images.md).

## Installation

After preparing the internal container registry with the required images, you can install AiStack in the air-gapped environment.

```diff
 sudo docker run -d --name aistack \
     --restart unless-stopped \
     -p 80:80 \
     --volume aistack-data:/var/lib/aistack \
-    aistack/aistack
+    <your_internal_registry>/aistack/aistack \
+    --system-default-container-registry <your_internal_registry>

```

### Pulling Inference Backend Images from a Secure Registry

If your internal container registry requires authentication,  
set the following environment variables when starting the AiStack worker to allow it to pull the runner image.

```diff
 sudo docker run -d --name aistack \
     ...
+    --env GPUSTACK_RUNTIME_DEPLOY_DEFAULT_CONTAINER_REGISTRY_USERNAME=<your_internal_registry_username> \
+    --env GPUSTACK_RUNTIME_DEPLOY_DEFAULT_CONTAINER_REGISTRY_PASSWORD=<your_internal_registry_password> \
     <your_internal_registry>/aistack/aistack \
     --system-default-container-registry <your_internal_registry>

```

### Pulling Inference Backend Images from non-default Namespace

If your internal container registry uses a different namespace than the default `aistack`,  
set the following environment variable when starting the AiStack worker to allow it to pull the runner image.

```diff
 sudo docker run -d --name aistack \
     ...
+    --env GPUSTACK_RUNTIME_DEPLOY_DEFAULT_CONTAINER_NAMESPACE=<your_namespace> \
     <your_internal_registry>/aistack/aistack \
     --system-default-container-registry <your_internal_registry>
```

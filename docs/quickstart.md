# Quickstart

This guide walks you through running AiStack on self-hosted GPU servers. To use [cloud GPUs](./tutorials/adding-gpucluster-using-digitalocean.md) or to integrate with an [existing Kubernetes cluster](./tutorials/adding-gpucluster-using-kubernetes.md), see the relevant tutorials.

!!! info "Prerequisites"

    1. A node with at least one NVIDIA GPU. For other GPU types, please check the guidelines in the AiStack UI when adding a worker, or refer to the [Installation documentation](./installation/requirements.md) for more details.
    2. Ensure the NVIDIA driver, [Docker](https://docs.docker.com/engine/install/) and [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) are installed on the worker node.
    3. **(Optional)** A CPU node for hosting the AiStack server. The AiStack server does not require a GPU and can run on a CPU-only machine. [Docker](https://docs.docker.com/engine/install/) must be installed. Docker Desktop (for Windows and macOS) is also supported. If no dedicated CPU node is available, the AiStack server can be installed on the same machine as a GPU worker node.
    4. Only Linux is supported for AiStack worker nodes. If you use Windows, consider using WSL2 and avoid using Docker Desktop. macOS is not supported for AiStack worker nodes.

## Install AiStack

Run the following command to install and start the AiStack server using [Docker](https://docs.docker.com/engine/install/):

```bash
sudo docker run -d --name aistack \
    --restart unless-stopped \
    -p 80:80 \
    --volume aistack-data:/var/lib/aistack \
    aistack/aistack
```

??? Note "Alternative: Use Quay Container Registry Mirror"

    If you cannot pull images from Docker Hub or the download is very slow, you can use our Quay Container Registry mirror by pointing your registry to `quay.io`:

    ```bash
    sudo docker run -d --name aistack \
        --restart unless-stopped \
        -p 80:80 \
        --volume aistack-data:/var/lib/aistack \
        quay.io/aistack/aistack \
        --system-default-container-registry quay.io
    ```

Check the AiStack startup logs:

```bash
sudo docker logs -f aistack
```

After AiStack starts, run the following command to get the default admin password:

```bash
sudo docker exec aistack cat /var/lib/aistack/initial_admin_password
```

Open your browser and navigate to `http://your_host_ip` to access the AiStack UI. Use the default username `admin` and the password you retrieved above to log in.

## Set Up a GPU Cluster

1. On the AiStack UI, navigate to the `Clusters` page.

2. Click the `Add Cluster` button.

3. Select `Docker` as the cluster provider.

4. Fill in the `Name` and `Description` fields for the new cluster, then click the `Save` button.

5. Follow the UI guidelines to configure the new worker node. You will need to run a Docker command on the worker node to connect it to the AiStack server. The command will look similar to the following:

```bash
sudo docker run -d --name aistack-worker \
      --restart=unless-stopped \
      --privileged \
      --network=host \
      --volume /var/run/docker.sock:/var/run/docker.sock \
      --volume aistack-data:/var/lib/aistack \
      --runtime nvidia \
      aistack/aistack \
      --server-url http://your_aistack_server_url \
      --token your_worker_token \
      --advertise-address 192.168.1.2
```

6. Execute the command on the worker node to connect it to the AiStack server.

7. After the worker node connects successfully, it will appear on the `Workers` page in the AiStack UI.

## Deploy a Model

1. Navigate to the `Catalog` page in the AiStack UI.

2. Select the `Qwen3.5-0.8B` model from the list of available models.

3. After the deployment compatibility checks pass, click the `Save` button to deploy the model.

![deploy qwen3 from catalog](assets/quick-start/quick-start-qwen3.png)

4. AiStack will start downloading the model files and deploying the model. When the deployment status shows `Running`, the model has been deployed successfully.

!!! note

    AiStack uses containers to run models. The first-time model deployment may take some time to download the model files and container images. You can click `View Logs` in the UI to monitor the deployment progress.

![model is running](assets/quick-start/model-running.png)

5. Click `Playground - Chat` in the navigation menu, check that the model `qwen3.5-0.8b` is selected from the top-right `Model` dropdown. Now you can chat with the model in the UI playground.

![quick chat](assets/quick-start/quick-chat.png)

## Use the model via API

1. Navigate to the `Access Control` > `API Keys` page, then click the `New API Key` button.

2. Fill in the `Name` and click the `Save` button.

3. Copy the generated API key and save it somewhere safe. Please note that you can only see it once on creation.

4. You can now use the API key to access the OpenAI-compatible API endpoints provided by AiStack. For example, use curl as the following:

```bash
# Replace `your_api_key` and `your_aistack_server_url`
# with your actual API key and AiStack server URL.
export AISTACK_API_KEY=your_api_key
curl http://your_aistack_server_url/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $AISTACK_API_KEY" \
  -d '{
    "model": "qwen3.5-0.8b",
    "messages": [
      {
        "role": "system",
        "content": "You are a helpful assistant."
      },
      {
        "role": "user",
        "content": "Tell me a joke."
      }
    ],
    "stream": true
  }'
```

## Cleanup

After you complete using the deployed model, you can go to the `Deployments` page in the AiStack UI and delete the model to free up resources.

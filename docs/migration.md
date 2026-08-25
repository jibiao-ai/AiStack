# Migrating from v0.7 and Earlier Versions to v2

!!! note

    Since v2.0.0, AiStack Worker officially supports only Linux. If you are using Windows or macOS, please move your data directory to a Linux system to perform the migration.

    On Windows and macOS, AiStack Server (without the embedded worker) can still be run using Docker Desktop.

## Before Migration

### Breaking Changes

#### 1. Removal of Ollama Model Source (since v0.7.x)

- **Change:** Starting from version 0.7, AiStack no longer supports `ollama` as a model source.
- **Impact:** Models, Model Files, and Model Instances whose source is `ollama` will not be preserved during the upgrade process.
- **Action Required:**  If you are upgrading from a version earlier than v0.7 and currently have models deployed from the `ollama` source, you must migrate these models manually before upgrading.  
  We recommend re-deploying affected models using one of the supported sources:
    - Hugging Face
    - ModelScope
    - Local path

    You can perform this migration by re-deploying the models through the **AiStack UI** before initiating the upgrade.

### Backup Your Data

!!! warning

      **Backup First:** Before starting the server migration, it’s strongly recommended to back up your database.

      For default installations on v0.7 or earlier, stop the AiStack server and create a backup of data dir located inside the container at:

      ```
      /var/lib/aistack
      ```

Please go through to the [Installation Requirements](./installation/requirements.md) before starting the migration.

If you used AiStack **without Docker** in versions prior to v0.7.1(for example, via pip install or an installation script), please install Docker by following the Docker Engine [Installation Guide](https://docs.docker.com/engine/install/) before proceeding with the migration.

If you used GPU acceleration for inference in AiStack prior to v0.7.1, please check whether you need to install the corresponding accelerator runtime’s Container Toolkit or Container Runtime after installing Docker. You can follow the steps in the **Installation Requirements** to check and install them.

## Migration Steps

### Identify Your Legacy Data Directory

Locate the data directory used by your previous AiStack installation. The default path is:

```
/var/lib/aistack
```

For other installation methods, refer to this [link](faq.md/#where-are-aistacks-data-stored) to locate the data directory. In the following steps, this path is referenced as `${your-data-dir}`.

Due to architectural changes in v2.0.0, new components such as `postgres` and `s6-supervisor` may read from and write to files in `${your-data-dir}` using non-root users. Make sure that `${your-data-dir}` is accessible to all required users. You can use the following script to adjust permissions, but please be aware of the security risks and understand exactly what the script does before running it.

```bash
dir="${your-data-dir}"
chmod a+rx "${dir}/log" || true
chmod a+rx $dir
while [ "$dir" != "/" ]; do
  chmod a+x "$dir"
  dir=$(dirname "$dir")
done
```

### Migrate Server Using Docker

Since v2.0.0, you no longer need to specify the GPU computing platform or version (such as `-cpu`, `-cuda12.8`, or `-rocm`) for the server or worker images. Use the unified image instead: `aistack/aistack:latest`.

#### Embedded Database Migration (SQLite → PostgreSQL)

In v0.7 and earlier, AiStack used an embedded SQLite database by default to store management data. Starting from v2.0.0, AiStack dropped SQLite support and now uses an embedded PostgreSQL database by default for improved performance and scalability.

Start the AiStack with the `AISTACK_DATA_MIGRATION=true` to enable the embedded database migration. Replace `${your-data-dir}` with your legacy data directory containing the original SQLite database and related files:

```bash
sudo docker run -d --name aistack \
  --restart=unless-stopped \
  --privileged \
  --network=host \
  --env AISTACK_DATA_MIGRATION=true \
  --volume /var/run/docker.sock:/var/run/docker.sock \
  --volume ${your-data-dir}:/var/lib/aistack \
  --runtime nvidia \
  aistack/aistack:latest
```

If you are getting the error from docker `docker: Error response from daemon: unknown or invalid runtime name: nvidia`, please check [Accelerator Runtime Requirements](./installation/requirements.md#accelerator-runtime-requirements) first and following the document [Other GPU Architectures](#other-gpu-architectures) to change the `--runtime nvidia` argument with your runtime.

Customizing the data directory via `--data-dir` or `AISTACK_DATA_DIR` is also supported during database migration. Adjust the command as follows:

```diff
...
-  --volume ${your-data-dir}:/var/lib/aistack
+  --volume ${your-data-dir}:${your-data-dir}
...
+   aistack/aistack:latest \
+   --data-dir :${your-data-dir}
```

#### External Database Migration

AiStack supports using an external database to store the management data. If you previously deployed AiStack with an external database, start the server with the following command:

```bash
sudo docker run -d --name aistack-server \
  --restart=unless-stopped \
  --privileged \
  --network=host \
  --volume /var/run/docker.sock:/var/run/docker.sock \
  --volume ${your-data-dir}:/var/lib/aistack \
  --runtime nvidia \
  aistack/aistack \
  --database-url ${your-database-url}
```

### Migrate Workers Using Docker

For worker nodes, replace `${your-data-dir}` with the legacy worker data directory path. Use the following command:

```bash
sudo docker run -d --name aistack-worker \
  --restart=unless-stopped \
  --privileged \
  --network=host \
  --volume ${your-data-dir}:/var/lib/aistack \
  --volume /var/run/docker.sock:/var/run/docker.sock \
  --runtime nvidia \
  aistack/aistack \
  --server-url ${server-url} \
  --token ${token}
```

Please make sure both `--volume /var/run/docker.sock:/var/run/docker.sock` and `--runtime nvidia` are added to the docker command. Those are not required for previous version. For different accelerator runtime, Refer to [Other GPU Architectures](#other-gpu-architectures) to use different option from `--runtime nvidia`.

This will launch the AiStack worker using your existing data and connect it to the specified server.

### Other GPU Architectures

For architectures other than NVIDIA (e.g., AMD, Ascend), the migration process remains the same. Please confirm your GPU architecture is supported in document [Accelerator Runtime Requirements](./installation/requirements.md#accelerator-runtime-requirements).

For example, running server and worker in host with AMD GPU, modify the docker run command with:

```diff
  sudo docker run -d --name aistack \
  ...
- --runtime nvidia \
+ --runtime amd \
  ...
```

### Recreating Model Instances

After the upgrade is complete, existing Model Instances may remain stuck in the `Starting` state. If this happens, recreating the Model Instance will allow the model to run normally.

### Migration from llama-box

If you were using llama-box as the inference backend in previous versions, please note that llama-box is no longer supported as of v2.0.0. Use llama.cpp via the custom inference backend instead.

1. Create a `llama.cpp` custom backend on Inference Backend page. For llama.cpp configuration, refer to this [document](./user-guide/inference-backend-management.md#enable-community-inference-backend).
2. Go to the Deployment page, modify the model originally launched with llama-box, change the backend to llama.cpp
3. Recreate the model instance after saving.

!!! Note

    Distributed inference across multiple workers is currently not supported with custom inference backends.

### Migration from Custom Backend Versions

If you were using a custom backend version in AiStack versions prior to v2.0.0, please note that those versions relied on Python virtual environments, which are **no longer supported** as of v2.0.0. All inference backends now run in containerized environments.

To continue using your models, you’ll need to **recreate them** using one of the following approaches:

**Option 1 - Use a Built-in Backend Version:**

AiStack v2.0.0+ provides multiple pre-configured versions of built-in inference backends. Recreate your model deployment and select the built-in backend version that best matches your model’s requirements.

**Option 2 - Add a Custom Version to a Built-in Backend:**

If none of the built-in versions meet your needs, you can extend a built-in inference backend by adding a custom version. For detailed instructions, refer to this guide: [Add a Custom Version to the Built-in vLLM Inference Backend](user-guide/inference-backend-management.md#example-add-a-custom-version-to-the-built-in-vllm-inference-backend).

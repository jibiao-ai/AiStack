# AiStack Helm Chart

Since v2.2.0, deploying AiStack on Kubernetes with an in-cluster gateway is supported. Follow this guide to build a k3s cluster and install AiStack.

Deploying AiStack in a Kubernetes cluster with Higress is still considered experimental. Please review the [limitations](#limitations) before proceeding with installation.

## Requirements

| Component  | Version   |
| ---------- | --------- |
| Helm       | v3.18.4   |
| Kubernetes | >=v1.30.0 |
| AiStack   | v2.2.0    |

## Limitations

Please note the following limitations when deploying AiStack on Kubernetes:

- AiStack Server is deployed as a StatefulSet and currently does not support more than one replica.
- By default, the built-in `Postgres` database is used at startup. It is recommended to specify an external database using the `server.externalDatabaseURL` parameter.
- By default, the StatefulSet uses `volumeClaimTemplates` (10Gi PVC), which requires a default `StorageClass` to be configured in your cluster (in k3s, the default is `local-path`). Alternatively, set `server.dataVolume.hostPath` to use a host path volume instead of a PVC.
- Higress plugins are served by a dedicated `aistack/higress-plugins` Deployment installed alongside AiStack. When the Higress gateway restarts, it will attempt to download the plugins from this service. If the service is unavailable, the gateway's startup will be blocked until the plugins are accessible.
- The bundled `higress-core` sub-chart deploys Higress as the cluster's ingress controller. If another ingress controller is already running in the cluster, set `higress-core.enabled=false` and configure `gateway.ingressClassname` to use the existing Higress instance instead.

## Install k3s

> **Note:** The following steps use k3s as an example Kubernetes distribution. Other CNCF-conformant Kubernetes distributions (such as RKE2, kubeadm-based clusters, or managed cloud Kubernetes services) should work as well, as long as they meet the version requirements above.

Use the following script to install k3s v1.30.11. Traefik is disabled because Higress will be used as the ingress controller. For high-availability k3s clusters, please refer to the [k3s documentation](https://docs.k3s.io/datastore/ha).

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.30.11+k3s1 INSTALL_K3S_EXEC="--disable=traefik" sh -
```

After installation, you can verify your setup with:

```bash
kubectl version
```

## Install AiStack with Helm

The AiStack Helm chart is published as an OCI artifact to Docker Hub at `oci://registry-1.docker.io/aistack/aistack-chart`. Install AiStack directly from the registry:

```bash
helm install -n aistack-system aistack oci://registry-1.docker.io/aistack/aistack-chart --create-namespace
```

To install a specific chart version, append `--version <chart-version>`:

```bash
helm install -n aistack-system aistack oci://registry-1.docker.io/aistack/aistack-chart --create-namespace \
  --version <chart-version>
```

By default, the `higress-core` sub-chart is enabled and deployed alongside AiStack. If you already have Higress installed in your cluster, disable the bundled Higress and point AiStack to your existing instance:

```bash
helm install -n aistack-system aistack oci://registry-1.docker.io/aistack/aistack-chart --create-namespace \
  --set higress-core.enabled=false \
  --set gateway.ingressClassname=<your-higress-ingressclass>
```

### Installing Higress Separately

If you set `higress-core.enabled=false`, install a compatible Higress instance before deploying AiStack:

```bash
# Add the Higress Helm repository
helm repo add higress.io https://higress.io/helm-charts

# Install higress-core v2.1.9
helm install higress higress.io/higress-core -n higress-system --create-namespace --version 2.1.9
```

Verify the IngressClass is available:

```bash
kubectl get ingressclass higress
# NAME      CONTROLLER                      PARAMETERS   AGE
# higress   higress.io/higress-controller   <none>       3m46s
```

If you need to customize Higress parameters, refer to the [Higress documentation](https://higress.cn/en/docs/latest/ops/deploy-by-helm).

### AiStack Helm Chart Parameters

| Parameter                                | Default                           | Description                                                               |
| ---------------------------------------- | --------------------------------- | ------------------------------------------------------------------------- |
| debug                                    | false                             | Enable debug mode                                                         |
| registrationToken                        | null                              | Registration token; auto-generated if null, reused across upgrades        |
| defaultDataDir                           | /var/lib/aistack                 | Host data directory path for worker nodes                                 |
| enableWorkers                            | true                              | Enable worker nodes                                                       |
| clusterDomain                            | cluster.local                     | Kubernetes cluster service domain suffix                                  |
| global.hub                               | docker.io                         | Container registry host; override for private registry                    |
| global.nodeSelector                      | {}                                | Default nodeSelector for every component; replaced by server/worker value |
| image.repository                         | aistack/aistack                 | Image repo with namespace; see note below                                 |
| image.tag                                | null                              | Image tag, defaults to chart's appVersion                                 |
| image.pullPolicy                         | IfNotPresent                      | Image pull policy                                                         |
| global.imagePullSecrets                  | [aistack-image-pull-secret]      | List of `{name}` refs on every pod; replace to use existing Secrets       |
| imagePullSecret.credentials.registry     | docker.io                         | Registry host used when the chart creates a docker-registry Secret        |
| imagePullSecret.credentials.username     | null                              | Registry username; creates Secret when set with password                  |
| imagePullSecret.credentials.password     | null                              | Registry password; creates Secret when set with username                  |
| imagePullSecret.credentials.email        | null                              | Optional email for the docker-registry Secret                             |
| server.ingress.hostname                  | null                              | Ingress hostname                                                          |
| server.ingress.tls.cert                  | null                              | Ingress TLS certificate content                                           |
| server.ingress.tls.key                   | null                              | Ingress TLS private key content                                           |
| server.externalDatabaseURL               | null                              | External database connection string                                       |
| server.dataVolume.hostPath               | null                              | Host path for data volume; if set, uses hostPath instead of PVC           |
| server.dataVolume.size                   | 10Gi                              | Server data volume size (PVC)                                             |
| server.apiPort                           | 30080                             | API service port                                                          |
| server.metricsPort                       | 10161                             | Metrics port                                                              |
| server.environmentConfig                 | {}                                | Extra environment variables for AiStack server                           |
| server.extraVolumeMounts                 | []                                | Extra volume mounts appended to the server container                      |
| server.extraVolumes                      | []                                | Extra volumes appended to the server StatefulSet                          |
| server.nodeSelector                      | {}                                | Server pod nodeSelector; replaces `global.nodeSelector` when non-empty    |
| gateway.ingressClassname                 | higress                           | Higress IngressClass name; enables in-cluster mode when found             |
| higress-core.enabled                     | true                              | Deploy Higress gateway as a sub-chart; disable if already installed       |
| higress-core.global.ingressClass         | higress                           | Must match `gateway.ingressClassname`                                     |
| higress-core.global.enablePluginServer   | false                             | AiStack manages its own plugin server; keep disabled                     |
| higress-core.global.hub                  | (inherits global.hub)             | Override hub for higress-core images only                                 |
| higress-core.downstream.idleTimeout      | 1800                              | Downstream idle timeout in seconds                                        |
| higress-core.upstream.idleTimeout        | 3                                 | Upstream idle timeout in seconds                                          |
| higress-core.gateway.hub                 | null                              | Image hub override for the gateway component                              |
| higress-core.gateway.image               | aistack/mirrored-higress-gateway | Gateway image name (with namespace)                                       |
| higress-core.gateway.imagePullSecrets    | [aistack-image-pull-secret]      | Gateway pull secrets; pre-populated to pick up the auto-created Secret    |
| higress-core.controller.hub              | null                              | Image hub override for the controller component                           |
| higress-core.controller.image            | aistack/mirrored-higress-higress | Controller image name (with namespace)                                    |
| higress-core.controller.imagePullSecrets | [aistack-image-pull-secret]      | Controller pull secrets; pre-populated to pick up the auto-created Secret |
| higress-core.pilot.hub                   | null                              | Image hub override for the pilot component                                |
| higress-core.pilot.image                 | aistack/mirrored-higress-pilot   | Pilot image name (with namespace)                                         |
| higressPlugins.replicas                  | 1                                 | Number of higress-plugins deployment replicas                             |
| higressPlugins.image.repository          | aistack/higress-plugins          | Image repo with namespace; see note below                                 |
| higressPlugins.image.tag                 | "0.2.3.post5"                     | Higress plugins image tag; CI overrides from uv.lock at package time      |
| higressPlugins.image.pullPolicy          | IfNotPresent                      | Higress plugins image pull policy                                         |
| worker.gpuVendors                        | [nvidia]                          | List of GPU vendors; `[]` disables worker DaemonSet                       |
| worker.nodeSelector                      | {}                                | Base worker nodeSelector; replaces `global.nodeSelector` when non-empty   |
| worker.port                              | 10150                             | Worker service port                                                       |
| worker.metricsPort                       | 10151                             | Worker metrics port                                                       |
| worker.environmentConfig                 | {}                                | Extra environment variables for AiStack worker                           |
| worker.dataDir                           | /var/lib/aistack                 | Host path mounted at /var/lib/aistack inside every worker pod            |
| worker.extraVolumeMounts                 | []                                | Extra volume mounts appended to the worker container                      |
| worker.extraVolumes                      | []                                | Extra volumes appended to the worker DaemonSet                            |

To customize parameters, use `--set key=value` or `-f your-values.yaml` during installation.

> **Note:** `higressPlugins.image.repository` is resolved as `{global.hub}/{higressPlugins.image.repository}:{higressPlugins.image.tag}`. The same pattern applies to `image.repository` (`{global.hub}/{image.repository}:{image.tag}`).

### Multi-vendor Worker Deployment

When `worker.gpuVendors` lists one or more vendors, the chart renders a per-vendor DaemonSet (`<release>-worker-<vendor>`) for each, alongside the always-present CPU DaemonSet (`<release>-worker`). Each vendor DS gets the per-vendor driver mounts, `runtimeClassName`, and an automatic PCI-presence nodeSelector label (e.g. `feature.node.kubernetes.io/pci-10de.present: "true"` for NVIDIA) based on the vendor's PCI ID. Whenever at least one GPU vendor is listed, all worker pods additionally get a required `podAntiAffinity` (topologyKey=hostname, namespaceSelector={}) so two workers can't share a node — protects the `hostNetwork: true` ports from collision across namespaces.

> **Prerequisite:** The PCI-presence labels are advertised by [Node Feature Discovery (NFD)](https://kubernetes-sigs.github.io/node-feature-discovery/). NFD must be installed in the cluster for worker pods to schedule onto GPU nodes. Without NFD, no nodes will carry the required labels and all worker pods will remain Pending.

Example values:

```yaml
worker:
  gpuVendors:
    - nvidia
    - amd
```

### NodeSelector Scoping

`global.nodeSelector` is the chart-wide default. Component-level values override it as follows:

- **Server pod** uses `server.nodeSelector` when non-empty, otherwise falls back to `global.nodeSelector`. Override semantics — no merging.
- **Worker base** uses `worker.nodeSelector` with the same fallback to `global.nodeSelector`.
- **Per-vendor worker DS** merges the vendor's PCI-presence label on top of the worker base; PCI label wins on conflict.

### Pulling Images From a Private Registry

To pull all images (aistack server/worker, higress-plugins, and the bundled higress-core gateway/controller/pilot) from a mirrored private registry, override `global.hub`:

```bash
helm install -n aistack-system aistack oci://registry-1.docker.io/aistack/aistack-chart --create-namespace \
  --set global.hub=myregistry.example.com
```

This relies on Helm's global-values propagation: `global.hub` is shared with the `higress-core` sub-chart automatically, so a single setting covers every image. The `image.repository` values include the namespace (e.g. `aistack/aistack`), so `global.hub` only needs the registry host.

The chart passes `global.hub` as `AISTACK_SYSTEM_DEFAULT_CONTAINER_REGISTRY` to the server, ensuring that inference engine images (e.g. vLLM, llama.cpp backends) are also pulled from the same registry.

If individual components live in a different namespace, override the `image` fields (e.g. `higress-core.gateway.image`, `higress-core.controller.image`, `higress-core.pilot.image`).

#### Image Pull Credentials

AiStack supports two ways to configure image pull credentials, which may be combined:

1. Reference one or more existing Secrets in the release namespace:

   ```bash
   helm install -n aistack-system aistack oci://registry-1.docker.io/aistack/aistack-chart --create-namespace \
     --set global.imagePullSecrets[0].name=my-existing-secret
   ```

2. Provide registry credentials; the chart creates a `docker-registry` Secret named `aistack-image-pull-secret` and references it automatically:

   ```bash
   helm install -n aistack-system aistack oci://registry-1.docker.io/aistack/aistack-chart --create-namespace \
     --set imagePullSecret.credentials.registry=registry.example.com \
     --set imagePullSecret.credentials.username=myuser \
     --set imagePullSecret.credentials.password=mypassword
   ```

Both options apply to the aistack server, worker, and higress-plugins pods.

The chart always creates a `docker-registry` Secret named `aistack-image-pull-secret`. When credentials are provided (option 2), it contains the auth data; otherwise it contains an empty `{"auths":{}}`. This Secret is pre-wired into the bundled `higress-core` sub-chart so that gateway and controller pods can pull images without additional configuration. An empty auth Secret is harmless — kubelet ignores it and falls back to other available credentials.

If you use option 1 only and need the existing Secret(s) to apply to `higress-core` as well, append them under the sub-chart fields:

```yaml
higress-core:
  gateway:
    imagePullSecrets:
      - name: aistack-image-pull-secret
      - name: my-existing-secret
  controller:
    imagePullSecrets:
      - name: aistack-image-pull-secret
      - name: my-existing-secret
```

## Accessing AiStack

After installing all required charts, retrieve the initial admin password for the AiStack server with:

```bash
kubectl exec -it -n aistack-system aistack-server-0 -- cat /var/lib/aistack/initial_admin_password
```

If you did not specify `server.ingress.hostname`, you can obtain the AiStack Server UI address with:

```bash
kubectl get ingress -n aistack-system aistack -o jsonpath="{.status.loadBalancer.ingress[0].ip}"
```

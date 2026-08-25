# Upgrade via Docker

You can upgrade a Docker-based AiStack installation by pulling a newer image and recreating the containers.

The following upgrade instructions apply only to AiStack v2.0 and later.

For installations prior to v0.7, please refer to the [migration guide](../migration.md).

!!! note

    1. When upgrading, upgrade the AiStack server first, then upgrade the workers.

    2. Please **DO NOT** upgrade from/to the main(dev) version or a release candidate(rc) version, as they may contain breaking changes. Use a fresh installation if you want to try the main or rc versions.

!!! warning

    **Backup First:** Before proceeding with an upgrade, it’s strongly recommended to back up your database.

    For default installations that use the embedded PostgreSQL database, stop the AiStack server and create a backup of the PostgreSQL database directory located inside the container at:

    ```
    /var/lib/aistack/postgresql/data
    ```

    If you use an external database, follow your database provider's backup procedure instead.

Upgrade the **server** first, then upgrade the **workers**. The server is upgraded by pulling a new image (either a specific version tag or the `latest` tag), removing the old container, and starting a new one with the updated image using the **same arguments and volumes** as before.

## Upgrade the Server

```bash
docker pull aistack/aistack:latest  # or: docker pull aistack/aistack:vx.y.z

docker stop aistack
docker rm aistack

docker run -d --name aistack \
  ... \
  aistack/aistack:latest
  ...
```

## Upgrade the Workers

After the server is up and running with the new version, upgrade the workers in each cluster. See [Upgrade a Cluster Deployment](cluster.md) for the Docker, Kubernetes, and cloud cluster procedures.

## Upgrade via Docker Compose

If you deployed with Docker Compose from a cloned repository, check out the new release tag and recreate the containers with the updated image:

```bash
cd aistack

# Fetch the tags and check out the target stable release
git fetch --tags
git checkout <new-tag>   # e.g. vx.y.z

cd docker-compose

# Pull the new image and recreate the containers
sudo docker compose -f docker-compose.server.yaml pull
sudo docker compose -f docker-compose.server.yaml up -d
```

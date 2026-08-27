# AiStack Docker 镜像构建指南

## 背景

AiStack 代码已从上游 GPUStack 完成全量品牌替换。但 Docker 镜像需要在**有网络访问和 Docker 环境**的服务器上构建。

### 构建依赖说明

Dockerfile 的多阶段构建需要拉取几个上游二进制镜像作为构建依赖：

| 构建阶段 | 拉取的镜像 | 说明 |
|----------|-----------|------|
| aistack-operator | `gpustack/gpustack-operator:v0.8.5` | K8s Operator 二进制 |
| apiserver | `gpustack/mirrored-higress-api-server:0.0.26` | Higress API 网关 |
| controller | `gpustack/mirrored-higress-higress:2.1.9` | Higress 控制器 |
| pilot | `gpustack/mirrored-higress-pilot:2.1.9` | Higress Pilot |
| gateway | `gpustack/mirrored-higress-gateway:2.1.9` | Higress 网关 |
| rocm-base | `rocm/dev-ubuntu-22.04:7.0.2` | AMD ROCm 库 |
| base | `ubuntu:24.04` | 基础系统 |

> **这些都是构建时依赖**，最终镜像运行的是 100% AiStack 品牌代码。

### PyPI 依赖说明

以下三个运行时依赖包目前仅在 PyPI 上以原名发布：

| pyproject.toml 中的包名 | PyPI 实际包名 | 说明 |
|--------------------------|--------------|------|
| `gpustack-runner` | gpustack-runner | 推理引擎运行器 |
| `gpustack-runtime` | gpustack-runtime | 运行时环境 |
| `gpustack-higress-plugins` | gpustack-higress-plugins | 网关插件 |

> 这些是二进制兼容的运行时依赖，功能完全不受影响。后续可 fork 并发布到自有 PyPI 仓库。

---

## 方法一：一键构建脚本（推荐）

### 前置条件

- Linux 服务器（推荐 Ubuntu 22.04/24.04）
- Docker Engine 24+ 或 Docker Desktop
- Docker Buildx（推荐，但非必须）
- 至少 16GB 内存、50GB 磁盘空间
- 网络访问（需要拉取上游镜像和 apt/pip 包）

### 基本构建

```bash
# 克隆代码
git clone https://github.com/jibiao-ai/AiStack.git
cd AiStack

# 执行一键构建
./build-image.sh
```

构建完成后本地会生成镜像 `aistack/aistack:latest`。

### 构建并推送到 Docker Hub

```bash
# 先登录 Docker Hub
docker login

# 构建并推送
./build-image.sh --push
```

### 推送到私有 Harbor 仓库

```bash
# 登录私有仓库
docker login harbor.mycompany.com

# 构建并推送到私有仓库
./build-image.sh --registry harbor.mycompany.com --push
```

### 构建特定版本

```bash
./build-image.sh --tag v2.0.0 --push
```

### 离线导出

```bash
# 构建镜像
./build-image.sh --tag v2.0.0

# 导出为 tar.gz 文件
docker save aistack/aistack:v2.0.0 | gzip > aistack-v2.0.0.tar.gz

# 传输到目标机器后加载
docker load < aistack-v2.0.0.tar.gz
```

---

## 方法二：使用 make package（CI 集成）

项目自带的 `make package` 命令也已适配：

```bash
# 默认构建（dev 标签）
make package

# 自定义标签
PACKAGE_TAG=v2.0.0 make package

# 构建并推送
PACKAGE_TAG=v2.0.0 PACKAGE_PUSH=true make package

# 推送到私有仓库
PACKAGE_NAMESPACE=harbor.mycompany.com/aistack PACKAGE_TAG=v2.0.0 PACKAGE_PUSH=true make package
```

---

## 方法三：直接 docker build

```bash
cd AiStack

# 基本构建
docker build \
    --tag aistack/aistack:latest \
    --file pack/Dockerfile \
    --build-arg UPSTREAM_NS=gpustack \
    --progress=plain \
    .

# 如构建遇到网络问题，可增加重试
docker build \
    --tag aistack/aistack:latest \
    --file pack/Dockerfile \
    --build-arg UPSTREAM_NS=gpustack \
    --network=host \
    --progress=plain \
    .
```

---

## 部署使用

构建完成后（或加载离线镜像后），使用 docker-compose 启动：

```bash
cd AiStack/docker-compose
cp docker-compose.server.yaml docker-compose.yml
docker-compose up -d
```

或直接 docker run：

```bash
sudo docker run -d --name aistack \
    --restart unless-stopped \
    -p 80:80 \
    --volume aistack-data:/var/lib/aistack \
    aistack/aistack:latest
```

**使用私有仓库的镜像：**

```bash
# docker-compose 方式
IMAGE_REGISTRY=harbor.mycompany.com docker-compose up -d

# 或 docker run
sudo docker run -d --name aistack \
    --restart unless-stopped \
    -p 80:80 \
    --volume aistack-data:/var/lib/aistack \
    harbor.mycompany.com/aistack/aistack:latest
```

---

## 常见问题

### Q: 构建时无法拉取 gpustack/* 镜像？

检查 Docker 镜像加速器配置：

```bash
# 查看当前配置
cat /etc/docker/daemon.json

# 如果镜像加速器 DNS 不通，移除或替换
sudo vim /etc/docker/daemon.json
# 可用镜像加速器：
# - https://mirror.ccs.tencentyun.com (腾讯云)
# - https://registry.cn-hangzhou.aliyuncs.com (阿里云)

sudo systemctl restart docker
```

### Q: 构建报内存不足？

```bash
# 增加 Docker 内存限制（Docker Desktop）
# Settings -> Resources -> Memory -> 16GB+

# Linux 上检查 swap
free -h
# 临时增加 swap
sudo fallocate -l 8G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### Q: 如何验证镜像？

```bash
# 查看镜像信息
docker images aistack/aistack

# 测试运行
docker run --rm aistack/aistack:latest aistack version

# 检查镜像层
docker history aistack/aistack:latest
```

### Q: `UPSTREAM_NS` 参数的作用？

Dockerfile 的 `FROM` 语句需要拉取 operator 和 Higress 组件镜像。这些镜像目前只存在于 Docker Hub 的 `gpustack` 命名空间下。`UPSTREAM_NS=gpustack` 让构建从 `gpustack/gpustack-operator`、`gpustack/mirrored-higress-*` 拉取这些构建依赖。

后续如果你将这些镜像也推送到自己的命名空间（如 `aistack/aistack-operator`），可以设置 `UPSTREAM_NS=aistack`。

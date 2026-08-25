# 6. 部署文档片段

> 以下内容为面向私有化离线环境的部署文档片段，Markdown 格式，可直接嵌入内部文档系统。

---

## AiStack 部署指南

### 一、Docker 在线部署

#### 1.1 部署 AiStack Server

在 Server 节点（可为纯 CPU 机器）上执行：

```bash
sudo docker run -d --name aistack \
    --restart unless-stopped \
    -p 80:80 \
    --volume aistack-data:/var/lib/aistack \
    aistack/aistack
```

> **说明**：AiStack Server 不要求 GPU，可部署在任意 Linux / Windows (Docker Desktop) / macOS (Docker Desktop) 机器上。如无独立 CPU 节点，也可与 GPU Worker 合部在同一台机器。

#### 1.2 查看启动日志

```bash
sudo docker logs -f aistack
```

#### 1.3 获取管理员初始密码

```bash
sudo docker exec aistack cat /var/lib/aistack/initial_admin_password
```

使用浏览器访问 `http://<Server节点IP>`，用户名 `admin`，密码为上述命令输出。

#### 1.4 添加 GPU Worker 节点

在每台 GPU Worker 节点上执行（确保已安装 NVIDIA 驱动 + Docker + NVIDIA Container Toolkit）：

```bash
sudo docker run -d --name aistack-worker \
    --restart=unless-stopped \
    --privileged \
    --network=host \
    --volume /var/run/docker.sock:/var/run/docker.sock \
    --volume aistack-data:/var/lib/aistack \
    --runtime nvidia \
    aistack/aistack \
    --server-url http://<Server节点IP> \
    --token <你的Worker Token> \
    --advertise-address <本机IP>
```

> **Token 获取方式**：登录 AiStack 管理界面 → `集群` 页面 → 添加集群 → 界面会自动生成包含 Token 的启动命令。

---

### 二、离线部署指南（私有化 / 内网环境）

适用于无法访问公网 Docker Hub 的内网、离线环境部署。

#### 2.1 离线镜像准备（在有网络的机器上操作）

**步骤 1：拉取镜像**

```bash
# 在有外网访问的机器上拉取镜像
docker pull aistack/aistack:latest
```

**步骤 2：导出镜像包**

```bash
# 导出为 tar 包
docker save -o aistack-latest.tar aistack/aistack:latest
```

**步骤 3：传输到离线环境**

```bash
# 使用 scp / USB / 内网文件服务器等方式传输
scp aistack-latest.tar user@offline-server:/opt/aistack/
```

#### 2.2 离线环境导入镜像

在每台目标节点（Server 节点 + 所有 GPU Worker 节点）上执行：

```bash
# 导入镜像
docker load -i /opt/aistack/aistack-latest.tar

# 验证镜像已导入
docker images | grep aistack
```

#### 2.3 启动 AiStack Server（离线环境）

```bash
sudo docker run -d --name aistack \
    --restart unless-stopped \
    -p 80:80 \
    --volume aistack-data:/var/lib/aistack \
    aistack/aistack
```

#### 2.4 启动 GPU Worker 节点（离线环境）

```bash
sudo docker run -d --name aistack-worker \
    --restart=unless-stopped \
    --privileged \
    --network=host \
    --volume /var/run/docker.sock:/var/run/docker.sock \
    --volume aistack-data:/var/lib/aistack \
    --runtime nvidia \
    aistack/aistack \
    --server-url http://<Server节点内网IP> \
    --token <你的Worker Token> \
    --advertise-address <本机内网IP>
```

#### 2.5 离线环境模型文件准备

由于离线环境无法从 HuggingFace 等在线模型仓库下载模型，需提前准备模型文件：

```bash
# 在有网络的机器上下载模型（以 Qwen3.5-0.8B 为例）
# 方式一：使用 huggingface-cli
pip install huggingface_hub
huggingface-cli download Qwen/Qwen3.5-0.8B --local-dir ./Qwen3.5-0.8B

# 方式二：使用 git lfs
git lfs install
git clone https://huggingface.co/Qwen/Qwen3.5-0.8B

# 将模型文件打包传输至离线环境
tar -czf Qwen3.5-0.8B.tar.gz ./Qwen3.5-0.8B
scp Qwen3.5-0.8B.tar.gz user@offline-server:/opt/aistack/models/
```

在离线环境解压后，通过 AiStack 管理界面的"本地模型路径"功能加载模型文件。

---

### 三、常用运维命令

```bash
# 查看 AiStack 服务状态
sudo docker ps | grep aistack

# 查看 Server 日志
sudo docker logs -f aistack

# 查看 Worker 日志
sudo docker logs -f aistack-worker

# 重启 Server
sudo docker restart aistack

# 重启 Worker
sudo docker restart aistack-worker

# 停止并移除 Server（数据卷保留）
sudo docker stop aistack && sudo docker rm aistack

# 停止并移除 Worker（数据卷保留）
sudo docker stop aistack-worker && sudo docker rm aistack-worker

# 升级 AiStack（在线环境）
sudo docker pull aistack/aistack:latest
sudo docker stop aistack && sudo docker rm aistack
sudo docker run -d --name aistack \
    --restart unless-stopped \
    -p 80:80 \
    --volume aistack-data:/var/lib/aistack \
    aistack/aistack
```

---

### 四、环境要求清单

| 组件 | 要求 |
|------|------|
| **操作系统** | Linux（Worker 节点必须为 Linux；Server 节点支持 Linux / Windows / macOS） |
| **Docker** | 20.10+ |
| **NVIDIA 驱动** | 525+ （GPU Worker 节点） |
| **NVIDIA Container Toolkit** | 已安装且配置（GPU Worker 节点） |
| **网络** | Server 与 Worker 之间需互通（默认端口 80） |
| **GPU** | 至少一块受支持的 GPU（详见支持的加速器列表） |
| **内存** | Server 节点建议 ≥ 8GB；Worker 节点视模型而定 |
| **磁盘** | 模型文件存储空间视部署模型大小而定，建议 ≥ 100GB |

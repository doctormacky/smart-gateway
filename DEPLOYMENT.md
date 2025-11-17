# Smart Gateway 部署指南

## 📋 目录

- [镜像管理](#镜像管理)
- [启动脚本说明](#启动脚本说明)
- [常见场景](#常见场景)
- [故障排查](#故障排查)

---

## 🐳 镜像管理

### 镜像列表

Smart Gateway 使用以下 Docker 镜像：

| 镜像名称 | 说明 | 构建方式 |
|---------|------|---------|
| `smart-gateway-apisix:latest` | 自定义 APISIX 镜像 | 基于 `apache/apisix:3.14.1-debian` |
| `smart-gateway-java-runner:latest` | Java Plugin Runner 镜像 | 基于 `openjdk:21-ea-21-jdk-slim` |
| `openeuler/etcd:latest` | ETCD 配置中心 | 直接使用官方镜像 |
| `redis:latest` | Redis 缓存 | 直接使用官方镜像（独立部署） |

### 构建镜像

#### 使用构建脚本（推荐）

```bash
# 构建所有镜像
./build-images.sh --all

# 仅构建 APISIX 镜像
./build-images.sh --apisix

# 仅构建 Java Runner 镜像
./build-images.sh --runner

# 强制重新构建（不使用缓存）
./build-images.sh --all --rebuild
```

#### 手动构建

```bash
# 构建 APISIX 镜像
docker build -t smart-gateway-apisix:latest -f Dockerfile .

# 构建 Java Runner 镜像
docker build -t smart-gateway-java-runner:latest -f Dockerfile.runner .
```

### 查看镜像

```bash
# 查看所有 Smart Gateway 相关镜像
docker images | grep smart-gateway

# 查看镜像详细信息
docker inspect smart-gateway-apisix:latest
docker inspect smart-gateway-java-runner:latest
```

### 删除镜像

```bash
# 删除 APISIX 镜像
docker rmi smart-gateway-apisix:latest

# 删除 Java Runner 镜像
docker rmi smart-gateway-java-runner:latest

# 删除所有 Smart Gateway 镜像
docker rmi $(docker images | grep smart-gateway | awk '{print $3}')
```

---

## 🚀 启动脚本说明

### start-docker.sh

智能启动脚本，自动处理镜像检查和服务启动。

**执行流程：**

1. **检查 tmp 目录**
   - 如果不存在，自动创建并设置权限为 777
   - 用于 APISIX 和 Java Runner 的 Unix Socket 通信

2. **检查 APISIX 镜像**
   - 优先使用本地自定义镜像 `smart-gateway-apisix:latest`
   - 如果不存在，检查官方镜像 `apache/apisix:3.14.1-debian`
   - 如果官方镜像也不存在，从 Docker Hub 拉取
   - 基于官方镜像构建自定义镜像

3. **检查 Java Runner 镜像**
   - 检查本地是否存在 `smart-gateway-java-runner:latest`
   - 如果不存在，检查 JAR 包是否存在
   - 如果 JAR 包不存在且安装了 Maven，自动构建
   - 构建 Java Runner 镜像

4. **启动服务**
   - 使用 `docker-compose up -d` 启动所有服务
   - 等待 5 秒让服务初始化
   - 检查服务状态
   - 验证 Socket 文件是否创建

**使用示例：**

```bash
# 直接运行
./start-docker.sh

# 查看输出（带颜色）
./start-docker.sh 2>&1 | less -R
```

### build-images.sh

专用镜像构建脚本，提供更多控制选项。

**参数说明：**

- `--all`: 构建所有镜像（APISIX + Java Runner）
- `--apisix`: 仅构建 APISIX 镜像
- `--runner`: 仅构建 Java Runner 镜像
- `--rebuild`: 强制重新构建（不使用缓存）
- `--help`: 显示帮助信息

**使用示例：**

```bash
# 查看帮助
./build-images.sh --help

# 构建所有镜像
./build-images.sh --all

# 仅构建 Runner 镜像
./build-images.sh --runner

# 强制重新构建所有镜像
./build-images.sh --all --rebuild
```

---

## 📖 常见场景

### 场景 1: 首次部署

```bash
# 1. 克隆项目
git clone https://github.com/doctormacky/smart-gateway.git
cd smart-gateway

# 2. 构建 JAR 包
mvn clean package -DskipTests

# 3. 一键启动（自动构建镜像）
./start-docker.sh
```

### 场景 2: 已有预构建镜像

如果你已经在其他机器上构建好了镜像：

```bash
# 1. 导出镜像（在源机器上）
docker save smart-gateway-apisix:latest | gzip > apisix-image.tar.gz
docker save smart-gateway-java-runner:latest | gzip > runner-image.tar.gz

# 2. 传输到目标机器
scp *.tar.gz user@target-host:/path/to/smart-gateway/

# 3. 导入镜像（在目标机器上）
docker load < apisix-image.tar.gz
docker load < runner-image.tar.gz

# 4. 启动服务（跳过构建）
./start-docker.sh
```

### 场景 3: 更新 Java 代码

```bash
# 1. 修改代码后重新构建 JAR
mvn clean package -DskipTests

# 2. 重新构建 Runner 镜像
./build-images.sh --runner

# 3. 重启服务
docker-compose restart java-plugin-runner

# 或者完全重启
docker-compose down
./start-docker.sh
```

### 场景 4: 更新 APISIX 配置

```bash
# 1. 修改 apisix_conf/config.yaml

# 2. 重启 APISIX 容器
docker-compose restart apisix

# 或者重新加载配置（不重启）
docker-compose exec apisix apisix reload
```

### 场景 5: 生产环境部署

```bash
# 1. 在开发环境构建镜像
./build-images.sh --all

# 2. 打标签
docker tag smart-gateway-apisix:latest registry.example.com/smart-gateway-apisix:v1.0.0
docker tag smart-gateway-java-runner:latest registry.example.com/smart-gateway-java-runner:v1.0.0

# 3. 推送到私有仓库
docker push registry.example.com/smart-gateway-apisix:v1.0.0
docker push registry.example.com/smart-gateway-java-runner:v1.0.0

# 4. 在生产环境拉取
docker pull registry.example.com/smart-gateway-apisix:v1.0.0
docker pull registry.example.com/smart-gateway-java-runner:v1.0.0

# 5. 重新打标签为 latest
docker tag registry.example.com/smart-gateway-apisix:v1.0.0 smart-gateway-apisix:latest
docker tag registry.example.com/smart-gateway-java-runner:v1.0.0 smart-gateway-java-runner:latest

# 6. 启动服务
./start-docker.sh
```

---

## 🔧 故障排查

### 问题 1: 镜像拉取失败

**现象：**
```
Error response from daemon: Get "https://registry-1.docker.io/v2/": net/http: request canceled
```

**解决方案：**
```bash
# 1. 配置 Docker 镜像加速器（国内用户）
# 编辑 /etc/docker/daemon.json
{
  "registry-mirrors": [
    "https://mirror.ccs.tencentyun.com",
    "https://docker.mirrors.ustc.edu.cn"
  ]
}

# 2. 重启 Docker
sudo systemctl restart docker

# 3. 或者使用本地已有的镜像
docker images | grep openjdk
# 修改 Dockerfile.runner 使用本地镜像
```

### 问题 2: JAR 包构建失败

**现象：**
```
⚠ 未安装 Maven，无法构建 JAR 包
```

**解决方案：**
```bash
# 方案 1: 安装 Maven
# macOS
brew install maven

# Ubuntu/Debian
sudo apt-get install maven

# 方案 2: 在 IDEA 中构建
# Maven -> smart-gateway -> Lifecycle -> package

# 方案 3: 使用已构建的 JAR
# 从其他机器复制 target/smart-gateway-1.0.jar
```

### 问题 3: Socket 文件未创建

**现象：**
```
⚠ Socket 文件尚未创建，请稍等...
```

**解决方案：**
```bash
# 1. 查看 Java Runner 日志
docker-compose logs -f java-plugin-runner

# 2. 检查 tmp 目录权限
ls -la tmp/
chmod 777 tmp/

# 3. 检查容器是否正常运行
docker-compose ps

# 4. 进入容器检查
docker-compose exec java-plugin-runner ls -la /tmp/
```

### 问题 4: 端口冲突

**现象：**
```
Error starting userland proxy: listen tcp4 0.0.0.0:9080: bind: address already in use
```

**解决方案：**
```bash
# 1. 查看占用端口的进程
lsof -i :9080
lsof -i :9180

# 2. 停止占用端口的进程
kill -9 <PID>

# 3. 或者修改 docker-compose.yml 中的端口映射
ports:
  - "19080:9080"   # 使用其他端口
  - "19180:9180"
```

### 问题 5: Redis 连接失败

**现象：**
```
Failed to validate token in Redis
connection timed out
```

**解决方案：**
```bash
# 1. 检查 Redis 是否运行
docker ps | grep redis

# 2. 检查 application.yml 中的 Redis 配置
cat src/main/resources/application.yml

# 3. 测试 Redis 连接
docker exec redis-local redis-cli -a redis123 ping

# 4. 检查网络连接
docker-compose exec java-plugin-runner ping 192.168.3.30
```

---

## 📚 相关文档

- [README.md](README.md) - 项目概述和快速开始
- [README_EN.md](README_EN.md) - English Documentation
- [USAGE_EXAMPLES.md](USAGE_EXAMPLES.md) - 使用示例
- [docker-compose.yml](docker-compose.yml) - 容器编排配置
- [Dockerfile](Dockerfile) - APISIX 镜像构建文件
- [Dockerfile.runner](Dockerfile.runner) - Java Runner 镜像构建文件

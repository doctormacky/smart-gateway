# Smart Gateway - 智能网关

[![License](https://img.shields.io/badge/license-Apache%202-blue.svg)](LICENSE)
[![Java](https://img.shields.io/badge/Java-21-orange.svg)](https://openjdk.java.net/)
[![APISIX](https://img.shields.io/badge/APISIX-3.14.1-green.svg)](https://apisix.apache.org/)
[![Architecture](https://img.shields.io/badge/Architecture-Microservices-brightgreen.svg)]()

[English](README_EN.md) | 简体中文

## 📖 项目简介

Smart Gateway 是一个基于 **Apache APISIX** 和 **Java Plugin Runner** 的企业级智能网关解决方案。采用**分离容器架构**,实现高可用、易扩展的微服务网关系统。

### 核心功能

- 🔐 **统一认证鉴权** - 基于 Redis 的 Token 认证,支持多种认证策略
- 🚀 **高性能路由** - 基于 APISIX 的高性能 HTTP 路由和负载均衡
- 🔌 **插件化扩展** - 通过 Java Plugin Runner 实现自定义业务逻辑
- 📊 **可观测性** - 集成 Prometheus、日志收集等监控能力
- 🛡️ **安全防护** - IP 限制、流量控制、CORS 等安全策略
- 🐳 **容器化部署** - 基于 Docker Compose 的一键部署

---

## 🏗️ 技术栈

| 组件 | 版本 | 说明 |
|------|------|------|
| Apache APISIX | 3.14.1 | 高性能 API 网关 |
| Java | 21 | Java Plugin Runner 运行环境 |
| Spring Boot | 3.4.0 | 插件开发框架 |
| Redis | Latest | Token 存储和缓存 |
| ETCD | Latest | APISIX 配置中心 |
| Docker | Latest | 容器化部署 |

---

## 🎯 架构设计

### 分离容器架构

```
┌─────────────────────────────────────────────────────────────┐
│                        Docker Network                       │
│                                                             │
│  ┌──────────────┐      ┌──────────────────┐                 │
│  │   APISIX     │      │  Java Plugin     │                 │
│  │  Container   │◄────►│     Runner       │                 │
│  │              │      │   Container      │                 │
│  │  - 路由转发   │      │  - 认证逻辑        │                 │
│  │  - 插件调度   │      │  - Redis 访问     │                 │
│  │  - 负载均衡   │      │  - 业务插件        │                 │
│  └──────┬───────┘      └────────┬─────────┘                 │
│         │                       │                           │
│         │  Unix Socket (/tmp)   │                           │
│         └───────────────────────┘                           │
│                                                             │
│  ┌──────────────┐      ┌──────────────────┐                 │
│  │     ETCD     │      │      Redis       │                 │
│  │  (配置中心)   │      │   (Token 存储)    │                 │
│  └──────────────┘      └──────────────────┘                 │
└─────────────────────────────────────────────────────────────┘
```

### 通信机制

- **APISIX ↔ Java Runner**: Unix Domain Socket (`/tmp/runner.sock`)
- **Java Runner ↔ Redis**: TCP (host.docker.internal:6379)
- **APISIX ↔ ETCD**: HTTP (etcd:2379)
- **客户端 ↔ APISIX**: HTTP (localhost:9080)

### 架构优势

✅ **松耦合** - 组件独立,互不影响  
✅ **易扩展** - 可独立扩展 Java Runner 实例  
✅ **易调试** - 日志分离,问题定位快  
✅ **高可用** - 单个组件故障不影响整体  
✅ **灵活部署** - 支持独立升级和版本管理  

---

## 📁 项目结构

```
smart-gateway/
├── src/main/java/com/macky/smartgateway/
│   ├── SmartGatewayApplication.java          # 主程序入口
│   └── filter/
│       └── SmartAuthenticationFilter.java    # 认证过滤器
├── src/main/resources/
│   └── application.yml                        # Spring Boot 配置
├── apisix_conf/
│   └── config.yaml                            # APISIX 配置文件
├── Dockerfile                                 # APISIX 容器镜像
├── Dockerfile.runner                          # Java Runner 容器镜像
├── docker-compose.yml                         # 容器编排配置
├── pom.xml                                    # Maven 依赖配置
└── README.md                                  # 项目文档
```

---

## 🚀 快速开始

### 前置要求

- Docker 20.10+
- Docker Compose 2.0+
- Maven 3.8+ (用于构建 JAR 包)
- Java 21+ (用于本地开发)

### 部署步骤

#### 1. 克隆项目

```bash
git clone https://github.com/doctormacky/smart-gateway.git
cd smart-gateway
```

#### 2. 构建 JAR 包

```bash
mvn clean package -DskipTests
```

#### 3. 创建共享目录

```bash
# 创建 tmp 目录用于 Unix Socket 通信
mkdir -p tmp
chmod 777 tmp
```

> **重要**: `tmp` 目录用于 APISIX 和 Java Runner 之间的 Unix Socket 通信，必须在启动容器前创建。

**或者使用启动脚本（推荐）**:

```bash
# 使用启动脚本会自动创建 tmp 目录
./start-docker.sh
```

#### 4. 启动 Redis (独立容器)

```bash
docker run -d \
  --name redis-local \
  -p 6379:6379 \
  redis:latest \
  redis-server --requirepass redis123
```

#### 5. 启动网关服务

**方式一：使用启动脚本（推荐）**

```bash
./start-docker.sh
```

启动脚本会自动：
- 创建 `tmp` 目录（如果不存在）
- 启动所有容器
- 检查服务状态
- 验证 Socket 文件

**方式二：手动启动**

```bash
docker-compose up -d --build
```

#### 6. 验证服务状态

```bash
# 查看容器状态
docker-compose ps

# 查看 Java Runner 日志
docker-compose logs java-plugin-runner

# 查看 APISIX 日志
docker-compose logs apisix

# 验证 Socket 文件
docker exec smart-gateway-java-plugin-runner-1 ls -la /tmp/runner.sock
```

#### 6. 配置路由和测试

```bash
# 配置测试路由
curl -X PUT http://127.0.0.1:9180/apisix/admin/routes/get \
  -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' \
  -H 'Content-Type: application/json' \
  -d '{
    "uri": "/get",
    "upstream": {
      "type": "roundrobin",
      "nodes": {
        "httpbin.org:443": 1
      },
      "scheme": "https"
    },
    "plugins": {
      "ext-plugin-pre-req": {
        "conf": [
          {
            "name": "SmartAuthenticationFilter",
            "value": "{}"
          }
        ]
      }
    }
  }'

# 在 Redis 中设置测试 Token
docker exec redis-local redis-cli -a redis123 -n 1 \
  SET "Authorization:login:token:test-token-123" "user123"

# 运行测试
# 测试 1: 无 Token (应返回 401)
curl -i http://localhost:9080/get

# 测试 2: 有效 Token (应返回 200)
curl -i http://localhost:9080/get \
  -H 'Authorization: Bearer test-token-123'

# 测试 3: 无效 Token (应返回 401)
curl -i http://localhost:9080/get \
  -H 'Authorization: Bearer invalid-token'

# 测试 4: 格式错误 (应返回 401)
curl -i http://localhost:9080/get \
  -H 'Authorization: InvalidFormat'
```

### 测试结果

| 测试场景 | 预期结果 | 错误码 | 说明 |
|---------|---------|--------|------|
| 无 Token | 401 Unauthorized | AUTH_001 | 未提供认证令牌 |
| 有效 Token | 200 OK | - | 成功访问上游服务 |
| 无效 Token | 401 Unauthorized | AUTH_004 | 令牌无效或已过期 |
| 格式错误 | 401 Unauthorized | AUTH_002 | 令牌格式错误 |

---

## ⚙️ 配置说明

### 1. APISIX 配置 (`apisix_conf/config.yaml`)

```yaml
ext-plugin:
  # Java Plugin Runner 在独立容器中运行
  # 通过共享的 /tmp 目录进行 Unix Socket 通信
  path_for_test: /tmp/runner.sock
```

**关键点:**
- ❌ **不再需要 `cmd` 配置** - Java Runner 在独立容器中启动
- ✅ **只需指定 socket 路径** - APISIX 通过 socket 与 Runner 通信
- ✅ **自动重连机制** - Runner 重启后 APISIX 会自动重连

### 2. Spring Boot 配置 (`application.yml`)

```yaml
spring:
  application:
    name: smart-gateway
  main:
    web-application-type: none  # 非 Web 应用,不启动 HTTP 服务器
  data:
    redis:
      host: ${SPRING_DATA_REDIS_HOST:localhost}
      port: ${SPRING_DATA_REDIS_PORT:6379}
      password: ${SPRING_DATA_REDIS_PASSWORD:redis123}
      database: 1
```

**关键点:**
- `web-application-type: none` - 作为插件运行,不需要 Web 服务器
- 环境变量优先 - 支持通过 Docker 环境变量覆盖配置
- Redis 数据库 1 - 避免与其他应用冲突

### 3. Docker Compose 配置

```yaml
services:
  apisix:
    volumes:
      - ./tmp:/tmp:rw  # 共享 Unix Socket 目录
    depends_on:
      - java-plugin-runner  # 确保 Runner 先启动

  java-plugin-runner:
    volumes:
      - ./tmp:/tmp:rw  # 共享 Unix Socket 目录
    environment:
      - REDIS_HOST=host.docker.internal
      - REDIS_PORT=6379
      - REDIS_PASSWORD=redis123
```

**关键点:**
- **共享 /tmp 目录** - 两个容器通过此目录共享 socket 文件
- **依赖顺序** - APISIX 依赖 Java Runner,确保启动顺序
- **host.docker.internal** - 访问宿主机上的 Redis 服务

---

## 🔍 工作原理

### 认证流程

```
1. 客户端请求 → APISIX (9080)
2. APISIX 调用 ext-plugin-pre-req
3. 通过 Unix Socket 发送请求到 Java Runner
4. SmartAuthenticationFilter 处理:
   ├─ 提取 Authorization Header
   ├─ 验证 Token 格式 (Bearer xxx)
   ├─ 查询 Redis (Authorization:login:token:{token})
   └─ 返回认证结果
5. APISIX 根据结果:
   ├─ 认证成功 → 转发到上游服务
   └─ 认证失败 → 返回 401 错误
```

### 错误码说明

| 错误码 | HTTP 状态 | 说明 | 解决方案 |
|--------|----------|------|---------|
| AUTH_001 | 401 | 未提供认证令牌 | 添加 `Authorization: Bearer {token}` Header |
| AUTH_002 | 401 | 令牌格式错误 | 确保格式为 `Bearer {token}` |
| AUTH_003 | 401 | 令牌为空 | 提供有效的 Token 值 |
| AUTH_004 | 401 | 令牌无效或已过期 | 重新登录获取新 Token |
| AUTH_500 | 500 | 认证服务内部错误 | 检查 Redis 连接和日志 |

---

## 🛠️ 开发指南

### 本地开发

```bash
# 1. 启动 Redis
docker run -d --name redis-local -p 6379:6379 \
  redis:latest redis-server --requirepass redis123

# 2. 启动 ETCD
docker run -d --name etcd -p 2379:2379 \
  -e ALLOW_NONE_AUTHENTICATION=yes \
  -e ETCD_ADVERTISE_CLIENT_URLS=http://0.0.0.0:2379 \
  openeuler/etcd:latest

# 3. 本地运行 Java Runner (用于调试)
mvn spring-boot:run

# 4. 启动 APISIX (连接本地 Runner)
docker-compose up apisix
```

### 重新部署

```bash
# 修改代码后重新构建
mvn clean package -DskipTests

# 重启 Java Runner 容器
docker-compose up -d --build java-plugin-runner

# 或重启所有服务
docker-compose down
docker-compose up -d --build
```

### 查看日志

```bash
# 实时查看 Java Runner 日志
docker-compose logs -f java-plugin-runner

# 实时查看 APISIX 日志
docker-compose logs -f apisix

# 查看所有日志
docker-compose logs -f

# 查看最近 100 行日志
docker-compose logs --tail=100 java-plugin-runner
```

### 调试技巧

#### 1. 启用远程调试

修改 `docker-compose.yml`:

```yaml
java-plugin-runner:
  ports:
    - "5005:5005"
  environment:
    - JAVA_TOOL_OPTIONS=-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005
```

然后在 IDE 中配置远程调试,连接到 `localhost:5005`。

#### 2. 查看 Socket 通信

```bash
# 进入 APISIX 容器
docker exec -it smart-gateway-apisix-1 bash

# 查看 socket 文件
ls -la /tmp/runner.sock

# 测试 socket 连接
echo "test" | nc -U /tmp/runner.sock
```

#### 3. Redis 数据检查

```bash
# 连接 Redis
docker exec -it redis-local redis-cli -a redis123 -n 1

# 查看所有 Token
KEYS Authorization:login:token:*

# 查看特定 Token
GET Authorization:login:token:test-token-123

# 设置测试 Token
SET Authorization:login:token:debug-token user-debug
```

### 自定义插件开发

#### 1. 创建新的过滤器

```java
@Component("MyCustomFilter")
@Slf4j
public class MyCustomFilter implements PluginFilter {
    
    @Override
    public String name() {
        return "MyCustomFilter";
    }
    
    @Override
    public void filter(HttpRequest request, HttpResponse response, PluginFilterChain chain) {
        // 自定义逻辑
        log.info("Processing request: {}", request.getPath());
        
        // 继续链式调用
        chain.filter(request, response);
    }
}
```

#### 2. 在 APISIX 中配置

```bash
curl -X PUT http://127.0.0.1:9180/apisix/admin/routes/custom \
  -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' \
  -d '{
    "uri": "/custom/*",
    "plugins": {
      "ext-plugin-pre-req": {
        "conf": [
          {"name": "MyCustomFilter", "value": "{}"}
        ]
      }
    },
    "upstream": {...}
  }'
```

---

## ❓ 常见问题

### 1. 503 Service Temporarily Unavailable

**原因:** APISIX 无法连接到 Java Runner 的 socket。

**排查步骤:**

```bash
# 1. 检查 Java Runner 是否运行
docker-compose ps java-plugin-runner

# 2. 检查 socket 文件是否存在
docker exec smart-gateway-java-plugin-runner-1 ls -la /tmp/runner.sock

# 3. 检查 Java Runner 日志
docker-compose logs java-plugin-runner | grep "listening on the socket"

# 4. 检查 /tmp 目录挂载
docker-compose exec apisix ls -la /tmp/
docker-compose exec java-plugin-runner ls -la /tmp/
```

**解决方案:**

```bash
# 重启 Java Runner
docker-compose restart java-plugin-runner

# 等待 10 秒让 socket 创建
sleep 10

# 验证 socket 文件
docker exec smart-gateway-java-plugin-runner-1 ls -la /tmp/runner.sock
```

### 2. Java Runner 启动失败

**可能原因:**
- JAR 包未构建或路径错误
- Redis 连接失败
- 端口冲突

**解决方案:**

```bash
# 1. 确保 JAR 包存在
ls -la target/smart-gateway-1.0.jar

# 2. 检查 Redis 连接
docker exec redis-local redis-cli -a redis123 ping

# 3. 查看详细日志
docker-compose logs java-plugin-runner

# 4. 重新构建
mvn clean package -DskipTests
docker-compose up -d --build java-plugin-runner
```

### 3. Redis 连接超时

**原因:** Java Runner 无法访问 `host.docker.internal`。

**解决方案:**

```yaml
# 确保 docker-compose.yml 中配置了 extra_hosts
java-plugin-runner:
  extra_hosts:
    - "host.docker.internal:host-gateway"
```

或者使用 Redis 容器名:

```yaml
# 将 Redis 加入同一网络
services:
  redis:
    image: redis:latest
    networks:
      - apisix
    command: redis-server --requirepass redis123

  java-plugin-runner:
    environment:
      - REDIS_HOST=redis  # 使用容器名
```

### 4. 认证总是返回 401

**排查步骤:**

```bash
# 1. 检查 Token 是否存在
docker exec redis-local redis-cli -a redis123 -n 1 \
  GET "Authorization:login:token:your-token"

# 2. 检查 Header 格式
curl -v http://localhost:9080/get \
  -H 'Authorization: Bearer your-token'

# 3. 查看 Java Runner 日志
docker-compose logs java-plugin-runner | grep "Token validation"
```

### 5. 如何独立扩展 Java Runner?

```yaml
# docker-compose.yml
services:
  java-plugin-runner-1:
    build:
      context: .
      dockerfile: Dockerfile.runner
    volumes:
      - ./tmp:/tmp:rw
    # ... 其他配置

  java-plugin-runner-2:
    build:
      context: .
      dockerfile: Dockerfile.runner
    volumes:
      - ./tmp:/tmp:rw
    # ... 其他配置
```

**注意:** 多个 Runner 实例会共享同一个 socket 文件,APISIX 会自动负载均衡。

### 6. 如何查看 APISIX 配置?

```bash
# 查看所有路由
curl http://127.0.0.1:9180/apisix/admin/routes \
  -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1'

# 查看特定路由
curl http://127.0.0.1:9180/apisix/admin/routes/get \
  -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1'

# 删除路由
curl -X DELETE http://127.0.0.1:9180/apisix/admin/routes/get \
  -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1'
```

### 7. 容器间无法通信

**检查网络配置:**

```bash
# 查看网络
docker network ls

# 查看容器网络
docker inspect smart-gateway-apisix-1 | grep NetworkMode
docker inspect smart-gateway-java-plugin-runner-1 | grep NetworkMode

# 确保在同一网络
docker-compose exec apisix ping java-plugin-runner
```

---

## 🚀 生产环境建议

### 1. 安全配置

```yaml
# apisix_conf/config.yaml
deployment:
  admin:
    admin_key:
      - name: "admin"
        key: "your-secure-random-key-here"  # 修改默认 Key
        role: admin
    allow_admin:
      - 10.0.0.0/8  # 限制 Admin API 访问 IP
```

### 2. 性能优化

```yaml
# docker-compose.yml
java-plugin-runner:
  environment:
    - JAVA_OPTS=-Xmx2g -Xms2g -XX:+UseG1GC
  deploy:
    resources:
      limits:
        cpus: '2'
        memory: 2G
      reservations:
        cpus: '1'
        memory: 1G
```

### 3. 日志管理

```yaml
# apisix_conf/config.yaml
nginx_config:
  error_log_level: warn  # 生产环境使用 warn
  http:
    access_log: /usr/local/apisix/logs/access.log
    error_log: /usr/local/apisix/logs/error.log
```

### 4. 监控集成

```yaml
# 启用 Prometheus 插件
plugins:
  - prometheus

# 配置 metrics 端点
plugin_attr:
  prometheus:
    export_addr:
      ip: 0.0.0.0
      port: 9091
```

### 5. 高可用部署

- 使用 Kubernetes 部署多副本
- 配置健康检查和自动重启
- 使用外部 Redis 集群
- 配置 ETCD 集群

### 6. 备份策略

```bash
# 备份 ETCD 数据
docker exec etcd etcdctl snapshot save /backup/etcd-snapshot.db

# 备份 Redis 数据
docker exec redis-local redis-cli -a redis123 BGSAVE
```

---

## 📊 版本历史

### v2.0.0 (2025-11-15) - 分离容器架构

- ✨ 重构为分离容器架构
- ✨ 独立的 Java Runner 容器
- ✨ 支持独立扩展和部署
- ✨ 优化日志和监控
- ✨ 改进调试体验

### v1.0.0 (2025-11-14) - 单容器架构

- 🎉 初始版本发布
- ✅ APISIX 与 Java Runner 集成
- ✅ 基于 Redis 的 Token 认证
- ✅ Docker Compose 一键部署

---

## 📄 许可证

本项目采用 [Apache License 2.0](LICENSE) 许可证。

---

## 👥 联系方式

- **作者:** Macky
- **邮箱:** liuyun105@126.com
- **GitHub:** [doctormacky/smart-gateway](https://github.com/doctormacky/smart-gateway)

---

## 🙏 致谢

- [Apache APISIX](https://apisix.apache.org/) - 高性能 API 网关
- [apisix-java-plugin-runner](https://github.com/apache/apisix-java-plugin-runner) - Java 插件运行时
- [Spring Boot](https://spring.io/projects/spring-boot) - 应用开发框架

---

**⭐ 如果这个项目对你有帮助,请给个 Star!**

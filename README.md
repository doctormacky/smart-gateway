# Smart Gateway

[English](./README_EN.md) | 简体中文

基于 Apache APISIX 的 Java 版本插件，兼容 smart-admin(smart-admin 底层采用了 sa-token 进行身份验证) 签发的 token。该插件与 Apache APISIX 3.14.1 版本兼容。

## 作者

刘云 (liuyun105@126.com)

## 项目简介

Smart Gateway 是一个基于 Apache APISIX 的外部插件系统，使用 Java 编写，专门用于处理基于 sa-token 的身份验证。该项目采用**单容器架构**，将 APISIX 和 Java Plugin Runner 集成在同一个 Docker 容器中，通过 Unix Domain Socket 进行高效通信。

### 核心功能

- **智能认证**：集成 Sa-Token 实现基于 Redis 的分布式认证
- **单容器架构**：APISIX 和 Java Runner 在同一容器中运行，简化部署
- **高效通信**：通过 Unix Domain Socket 实现进程间通信
- **API 网关**：基于 APISIX 3.14.1 的高性能 API 网关
- **可视化管理**：APISIX Dashboard 支持路由可视化配置
- **数据持久化**：etcd 数据自动持久化，重启不丢失配置
- **HTTPS 上游**：支持访问外网 HTTPS 服务（如 httpbin.org）

## 技术栈

- **Apache APISIX**: 3.14.1-debian
- **APISIX Java Plugin Runner**: 0.6.0
- **Spring Boot**: 3.5.7
- **Sa-Token**: 1.44.0
- **etcd**: latest (OpenEuler, arm64)
- **Redis**: 7-alpine (独立容器)
- **Java**: 21 (OpenJDK)
- **Maven**: 3.9.9
- **Docker & Docker Compose**: 必需

## 架构设计

### 单容器架构

```
┌─────────────────────────────────────────┐
│         APISIX Container                │
│  ┌──────────────┐   ┌───────────────┐  │
│  │    APISIX    │   │  Java Plugin  │  │
│  │   (Nginx)    │◄──┤    Runner     │  │
│  │              │   │  (Spring Boot)│  │
│  └──────────────┘   └───────────────┘  │
│         ▲                    │          │
│         │    Unix Socket     │          │
│         │  /tmp/runner.sock  │          │
│         └────────────────────┘          │
└─────────────────────────────────────────┘
           │                    │
           │                    │ Redis
           ▼                    ▼
    ┌──────────┐         ┌──────────┐
    │   etcd   │         │  Redis   │
    │Container │         │Container │
    └──────────┘         └──────────┘
```

### 优势

1. **简化部署**：只需管理一个应用容器
2. **高效通信**：Unix Socket 比 TCP 更快，延迟更低
3. **资源优化**：减少容器数量，降低资源开销
4. **统一管理**：日志、配置集中在一个容器中

## 项目结构

```
smart-gateway/
├── apisix_conf/                # Apache APISIX 配置目录
│   └── config.yaml             # APISIX 主配置文件（路由、插件、ext-plugin 配置）
├── docker-compose.yml          # Docker Compose 编排文件（APISIX + etcd）
├── Dockerfile                  # 构建集成镜像的 Dockerfile
├── start-runner.sh             # Java Runner 启动脚本（自动修改 socket 权限）
├── pom.xml                     # Maven 项目配置文件
├── README.md                   # 项目说明文档（中文）
├── README_EN.md                # 项目说明文档（英文）
├── src/                        # 源代码目录
│   └── main/
│       ├── java/               # Java 源码
│       │   └── com/jsjf/ai/smartgateway/
│       │       ├── SmartGatewayApplication.java
│       │       └── SmartAuthenticationFilter.java
│       └── resources/
│           └── application.yml # Spring Boot 配置
└── target/
    └── smart-gateway-1.0.jar   # 编译后的 JAR 包
```

## 快速开始

### 前置准备

1. **安装 Docker 和 Docker Compose**
2. **启动独立的 Redis 容器**（用于存储认证 Token）

```bash
# 启动 Redis（如果还没有运行）
docker run -d --name redis-local \
  -p 6379:6379 \
  redis:7-alpine redis-server --requirepass redis123
```

### 1. 编译项目

```bash
# 使用 Maven 编译
./mvnw clean package -DskipTests

# 验证 JAR 文件生成
ls -lh target/smart-gateway-1.0.jar
```

### 2. 启动服务

```bash
# 启动 APISIX 和 etcd
docker-compose up -d --build

# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f apisix
```

### 3. 验证服务

```bash
# 检查 Java Runner 是否启动
docker-compose logs apisix 2>&1 | grep "listening on the socket"

# 检查 Socket 文件权限
docker exec smart-gateway-apisix-1 ls -la /tmp/runner.sock
# 应该显示: srw-rw-rw- 1 root root 0 ... /tmp/runner.sock
```

### 4. 访问 APISIX Dashboard

打开浏览器访问：`http://localhost:9180/ui/`

- 默认用户名：`admin`
- 默认密码：`admin`
- API Key：`edd1c9f034335f136f87ad84b625c8f1`

### 5. 配置路由

```bash
curl -X PUT http://127.0.0.1:9180/apisix/admin/routes/get \
  -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' \
  -H 'Content-Type: application/json' \
  -d '{
    "uri": "/get",
    "upstream": {
      "type": "roundrobin",
      "nodes": {"httpbin.org:443": 1},
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
```

### 6. 测试认证功能

#### 准备测试数据

```bash
# 在 Redis 中设置测试 Token
docker exec redis-local redis-cli -a redis123 -n 1 \
  SET "Authorization:login:token:test-token-123" "user123"
```

#### 测试场景

```bash
# 测试1: 无 Token（应该返回 401 AUTH_001）
curl -i http://localhost:9080/get

# 测试2: 有效 Token（应该返回 200 OK）
curl -i http://localhost:9080/get \
  -H 'Authorization: Bearer test-token-123'

# 测试3: 无效 Token（应该返回 401 AUTH_004）
curl -i http://localhost:9080/get \
  -H 'Authorization: Bearer invalid-token'

# 测试4: 格式错误的 Token（应该返回 401 AUTH_002）
curl -i http://localhost:9080/get \
  -H 'Authorization: InvalidFormat'
```

#### 预期结果

| 测试场景 | HTTP 状态码 | 错误代码 | 说明 |
|---------|-----------|---------|------|
| 无 Token | 401 | AUTH_001 | 未提供认证令牌 |
| 有效 Token | 200 | - | 成功访问上游服务 |
| 无效 Token | 401 | AUTH_004 | 令牌无效或已过期 |
| 格式错误 | 401 | AUTH_002 | 令牌格式错误 |

## 配置说明

### 1. APISIX 配置 (apisix_conf/config.yaml)

#### ext-plugin 配置（关键）

```yaml
ext-plugin:
  # 使用启动脚本，自动修改 socket 权限
  cmd: ["/bin/bash", "/usr/local/apisix-runner/start-runner.sh"]
  # Socket 文件路径（APISIX 3.x 默认连接此路径）
  path_for_test: /tmp/runner.sock
```

#### etcd 配置

```yaml
etcd:
  host:
    - "http://etcd:2379"
  prefix: "/apisix"
  timeout: 30
```

#### 插件列表

已启用 40+ 个常用插件，包括：
- **认证鉴权**：`key-auth`, `jwt-auth`, `basic-auth`, `hmac-auth` 等
- **安全防护**：`ip-restriction`, `cors`, `csrf`, `uri-blocker` 等
- **流量控制**：`limit-req`, `limit-conn`, `limit-count`
- **请求转换**：`proxy-rewrite`, `response-rewrite`
- **可观测性**：`prometheus`, `http-logger`, `zipkin` 等
- **外部插件**：`ext-plugin-pre-req`, `ext-plugin-post-req`

### 2. Spring Boot 配置 (application.yml)

```yaml
spring:
  application:
    name: smart-gateway
  main:
    web-application-type: none  # 禁用 Web 服务器（避免端口冲突）
  data:
    redis:
      host: ${SPRING_DATA_REDIS_HOST:localhost}
      port: ${SPRING_DATA_REDIS_PORT:6379}
      password: ${SPRING_DATA_REDIS_PASSWORD:redis123}
      database: 1
```

### 3. Docker Compose 配置

```yaml
services:
  apisix:
    build:
      context: .
      dockerfile: Dockerfile
    restart: always
    user: root  # 需要 root 权限访问 socket
    volumes:
      # 挂载配置文件（只读）
      - ./apisix_conf/config.yaml:/usr/local/apisix/conf/config.yaml:ro
    ports:
      - "9180:9180"   # Admin API
      - "9080:9080"   # HTTP 网关
      - "5005:5005"   # JDWP 远程调试端口（可选）
    extra_hosts:
      # 允许容器访问宿主机的 Redis
      - "host.docker.internal:host-gateway"
    environment:
      - SPRING_DATA_REDIS_HOST=host.docker.internal
      - SPRING_DATA_REDIS_PORT=6379
      - SPRING_DATA_REDIS_PASSWORD=redis123
```

### 4. 启动脚本 (start-runner.sh)

```bash
#!/bin/bash
# 启动 Java Runner（后台运行）
java -jar -Xmx1g -Xms1g \
  -Dspring.data.redis.host=host.docker.internal \
  -Dspring.data.redis.port=6379 \
  -Dspring.data.redis.password=redis123 \
  /usr/local/apisix-runner/apisix-java-plugin-runner.jar &

# 等待 socket 文件创建
for i in {1..30}; do
  if [ -S /tmp/runner.sock ]; then
    # 修改权限为 666（所有用户可读写）
    chmod 666 /tmp/runner.sock
    echo "Socket file permissions updated: $(ls -la /tmp/runner.sock)"
    break
  fi
  sleep 0.5
done

# 保持脚本运行
wait
```

**关键点**：
- Socket 文件默认权限是 `600`（只有创建者可访问）
- APISIX worker 进程需要访问 socket，所以必须修改为 `666`
- 脚本会等待 socket 创建后自动修改权限

## 工作原理

### 认证流程

```
1. 客户端请求
   ↓
2. APISIX 接收请求
   ↓
3. 通过 Unix Socket 转发到 Java Plugin Runner
   ↓
4. SmartAuthenticationFilter 处理
   ├─ 提取 Authorization 头（通过 nginx 变量）
   ├─ 解析 Bearer Token
   ├─ 在 Redis 中验证 Token
   └─ 返回认证结果
   ↓
5. APISIX 根据结果决定
   ├─ 认证成功 → 转发到上游服务
   └─ 认证失败 → 返回 401 错误
```

### 关键技术点

1. **nginx 变量获取请求头**
   ```java
   @Override
   public List<String> requiredVars() {
       return Arrays.asList("http_authorization");
   }
   
   String auth = request.getVars("http_authorization");
   ```

2. **必须调用 chain.filter()**
   ```java
   // 无论成功或失败，都必须调用
   response.setStatusCode(401);
   chain.filter(request, response);  // ← 必须！
   ```

3. **Redis Key 格式**
   ```
   Authorization:login:token:{token}
   ```

## 开发指南

### 修改代码后重新部署

```bash
# 1. 重新编译
./mvnw clean package -DskipTests

# 2. 重新构建镜像（强制不使用缓存）
docker-compose build --no-cache apisix

# 3. 重启服务
docker-compose down
docker-compose up -d

# 4. 验证
docker-compose logs apisix 2>&1 | grep "SmartAuthenticationFilter"
```

### 创建自定义插件

```java
@Slf4j
@Component
public class MyCustomFilter implements PluginFilter {
    
    @Override
    public String name() {
        return "MyCustomFilter";  // 必须与路由配置中的名称一致
    }
    
    @Override
    public List<String> requiredVars() {
        // 声明需要的 nginx 变量
        return Arrays.asList("http_authorization", "http_user_agent");
    }
    
    @Override
    public void filter(HttpRequest request, HttpResponse response, PluginFilterChain chain) {
        // 获取请求头
        String auth = request.getVars("http_authorization");
        
        // 业务逻辑
        if (auth == null) {
            response.setBody("{\"error\":\"Unauthorized\"}");
            response.setHeader("Content-Type", "application/json");
            response.setStatusCode(401);
        }
        
        // 必须调用！
        chain.filter(request, response);
    }
}
```

### 调试技巧

```bash
# 查看完整日志
docker-compose logs -f apisix

# 查看 Java 启动日志
docker-compose logs apisix 2>&1 | grep "SmartGateway"

# 查看 Socket 文件
docker exec smart-gateway-apisix-1 ls -la /tmp/runner.sock

# 进入容器调试
docker exec -it smart-gateway-apisix-1 bash

# 查看 Redis 中的 Token
docker exec redis-local redis-cli -a redis123 -n 1 KEYS "Authorization:*"
```

## 常见问题

### 1. Socket 权限错误

**错误信息**：
```
failed to connect to the unix socket unix:/tmp/runner.sock: permission denied
```

**原因**：Java Runner 创建的 socket 文件权限为 `600`，APISIX worker 进程无法访问。

**解决方案**：使用 `start-runner.sh` 启动脚本，自动修改权限为 `666`。

### 2. 503 Service Temporarily Unavailable

**可能原因**：
1. Java Runner 未启动
2. Socket 文件不存在
3. Socket 路径配置错误

**排查步骤**：
```bash
# 1. 检查 Java Runner 是否启动
docker-compose logs apisix 2>&1 | grep "listening on the socket"

# 2. 检查 Socket 文件
docker exec smart-gateway-apisix-1 ls -la /tmp/runner.sock

# 3. 检查 config.yaml 中的 path_for_test 配置
docker exec smart-gateway-apisix-1 cat /usr/local/apisix/conf/config.yaml | grep path_for_test
```

### 3. Redis 连接失败

**错误信息**：
```
Unable to connect to Redis
```

**解决方案**：
```bash
# 1. 确保 Redis 容器运行
docker ps | grep redis-local

# 2. 测试容器内是否能连接 Redis
docker exec smart-gateway-apisix-1 sh -c \
  "apt-get update > /dev/null 2>&1 && apt-get install -y telnet > /dev/null 2>&1 && \
   echo 'PING' | telnet host.docker.internal 6379"

# 3. 检查环境变量
docker-compose config | grep REDIS
```

### 4. 插件未被识别

**错误信息**：
```
receive undefined filter: SmartAuthenticationFilter
```

**解决方案**：
```bash
# 1. 确保使用了 @Component 注解
grep '@Component' src/main/java/com/jsjf/ai/smartgateway/SmartAuthenticationFilter.java

# 2. 确保 name() 返回值正确
grep 'public String name()' -A 1 src/main/java/com/jsjf/ai/smartgateway/SmartAuthenticationFilter.java

# 3. 重新编译和构建
./mvnw clean package -DskipTests
docker-compose build --no-cache apisix
docker-compose restart apisix
```

### 5. 路由 404

**问题**：配置路由后访问返回 404

**解决方案**：
```bash
# 1. 检查路由是否创建成功
curl http://127.0.0.1:9180/apisix/admin/routes \
  -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1'

# 2. 确保 URI 匹配
# 访问 http://localhost:9080/get
# 路由配置中的 uri 必须是 "/get"

# 3. 使用 proxy-rewrite 插件重写路径（如果需要）
```

## 生产环境建议

### 安全配置

1. **修改默认 Admin Key**
   ```yaml
   deployment:
     admin:
       admin_key:
         - name: "admin"
           key: "your-secure-random-key-here"  # 修改为强密码
           role: admin
   ```

2. **限制 Dashboard 访问**
   ```yaml
   deployment:
     admin:
       allow_admin:
         - 10.0.0.0/8  # 仅允许内网访问
   ```

3. **配置 Redis 密码**
   ```bash
   docker run -d --name redis-local \
     -p 6379:6379 \
     redis:7-alpine redis-server --requirepass "your-strong-password"
   ```

### 性能优化

1. **调整 JVM 参数**
   ```bash
   # 在 start-runner.sh 中修改
   java -jar -Xmx2g -Xms2g \
     -XX:+UseG1GC \
     -XX:MaxGCPauseMillis=200 \
     ...
   ```

2. **调整日志级别**
   ```yaml
   nginx_config:
     error_log_level: warn  # 生产环境使用 warn 或 error
   ```

3. **添加资源限制**
   ```yaml
   services:
     apisix:
       deploy:
         resources:
           limits:
             cpus: '2'
             memory: 2G
           reservations:
             cpus: '1'
             memory: 1G
   ```

### 监控和日志

1. **启用 Prometheus 插件**
   ```bash
   # 访问指标
   curl http://localhost:9091/apisix/prometheus/metrics
   ```

2. **集中日志收集**
   ```yaml
   # 使用 http-logger 插件发送日志到 ELK
   plugins:
     - http-logger
   ```

## 版本历史

- **v1.0** (2025-11-15)
  - 初始版本
  - 单容器架构（APISIX + Java Runner）
  - 支持 Sa-Token 认证
  - Unix Domain Socket 通信
  - 自动 socket 权限管理

## 许可证

MIT License

## 联系方式

- **作者**：刘云
- **邮箱**：liuyun105@126.com
- **项目地址**：[GitHub](https://github.com/yourusername/smart-gateway)

## 致谢

- [Apache APISIX](https://apisix.apache.org/)
- [APISIX Java Plugin Runner](https://github.com/apache/apisix-java-plugin-runner)
- [Sa-Token](https://sa-token.cc/)
- [Spring Boot](https://spring.io/projects/spring-boot)

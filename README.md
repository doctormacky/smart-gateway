# Smart Gateway

基于 Apache APISIX 的 Java 版本插件，兼容 smart-admin(smart-admin底层采用了 sa-token 进行身份验证) 签发的 token。该插件与Apache APISIX 3.14.1 版本兼容。
它不能单独运行，需要与Apache APISIX 一起运行。

## 作者

刘云 (liuyun105@126.com)

## 项目简介

Smart Gateway 是一个基于 Apache APISIX 的外部插件系统，使用 Java 编写，专门用于处理基于 sa-token 的身份验证。该插件可以与 APISIX 网关无缝集成，提供安全的身份验证机制。

### 核心功能

- **智能认证**：集成 Sa-Token 实现基于 Redis 的分布式认证
- **外部插件**：支持 Java 插件扩展，灵活定制业务逻辑
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
- **Redis**: 7.4.1
- **Java**: 17/21（推荐 21）
- **Maven**: 3.9.9
- **Docker & Docker Compose**: 必需

## 项目结构

```
smart-gateway/
├── apisix_conf/                # Apache APISIX 配置目录
│   └── config.yaml             # APISIX 主配置文件（定义路由、插件、上游服务等）
├── docker-compose.yml          # Docker Compose 编排文件（用于启动 APISIX、etcd 及本服务）
├── Dockerfile                  # 构建 smart-gateway 应用镜像的 Dockerfile
├── HELP.md                     # 辅助说明文档（如常见问题、配置说明等）
├── mvnw                        # Maven Wrapper（Linux/macOS 启动脚本）
├── mvnw.cmd                    # Maven Wrapper（Windows 启动脚本）
├── pom.xml                     # Maven 项目配置文件（依赖、插件、构建信息）
├── README.md                   # 项目主说明文档（快速开始、架构、部署指南等）
├── src/                        # 源代码目录
│   ├── main/                   # 主程序代码（Java）
│   └── test/                   # 测试代码
├── start.sh                    # 启动脚本（可能封装了构建、运行或 Docker 启动逻辑）
├── target/                     # Maven 构建输出目录（自动生成，不应提交到版本控制）
│   ├── classes/                # 编译后的 .class 文件
│   ├── generated-sources/      # 生成的源码（如注解处理器、JAXB 等）
│   ├── generated-test-sources/ # 生成的测试源码
│   ├── maven-archiver/         # Maven 打包元信息
│   ├── maven-status/           # Maven 编译状态信息
│   ├── smart-gateway-1.0.jar   # 可执行 JAR（通常为 Spring Boot 打包产物）
│   ├── smart-gateway-1.0.jar.original  # 原始 JAR（Spring Boot 重打包前的 JAR）
│   └── test-classes/           # 编译后的测试类
└── tmp/                        # 临时目录（可能用于运行时缓存、日志或调试文件）
```

## 快速开始

### 前置准备

**重要：** 在启动服务前，需要手动创建 `tmp` 目录用于 APISIX 和 Java Plugin Runner 的 Unix Socket 通信：

```bash
# 在项目根目录执行
mkdir -p tmp
chmod 777 tmp
```

### 1. 启动服务

```bash
docker-compose up -d
```

### 2. 访问 APISIX Dashboard

打开浏览器访问：`http://localhost:9180/ui/`

默认用户名/密码：`admin` / `admin`（API Key: `edd1c9f034335f136f87ad84b625c8f1`）

### 3. 验证服务状态

```bash
# 检查所有容器是否正常运行
docker-compose ps

# 查看 APISIX 日志
docker-compose logs apisix --tail 50

# 查看 Java Plugin Runner 日志
docker-compose logs java-plugin-runner --tail 50
```

### 4. 配置路由

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
  }' && echo -e "\n\n=== 路由创建成功 ==="
```

### 5. 测试插件

```
# 发送请求
curl http://localhost:9080/get \
  -H 'Authorization: Bearer <token>'

```

## 构建与部署

### 1. 构建 JAR 包

```bash
./mvnw clean package
```

这将在 `target/` 目录下生成 `smart-gateway-1.0.jar` 文件。

### 2. 构建 Docker 镜像

```bash
docker-compose build --no-cache java-plugin-runner
```


### 3. 创建tmp目录

这个目录是一个临时目录，主要用于socket通信。
```
mkdir -p ./tmp
chmod 777 ./tmp
```

### 4. 运行服务

使用 docker-compose 启动整个服务栈（包括 APISIX、ETCD 和 Java 插件）:

```bash
docker-compose up -d
```

**数据持久化说明：**
- etcd 数据会自动持久化到 `etcd-data` Docker 卷
- 重启服务时路由配置不会丢失
- ⚠️ 不要使用 `docker-compose down -v`，会删除所有数据

### 5. 访问服务
当服务启动后，你可以访问浏览器 http://127.0.0.1:9180/ui/services?page=1&page_size=10 查看服务列表。

### 6. 测试插件
说明：smart-admin在系统登录后，默认会在redis里存储token, token的格式为：`Authorization:login:token:<token>`

同时，在浏览器里会存储token，token的格式为：`Authorization: Bearer <token>`

我在smart-admin配置的token为：`Authorization:Bearer <token>`

测试步骤：
1. 配置 APISIX 路由，启用 Java 插件
```curl
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
  }' && echo -e "\n\n=== 路由创建成功 ==="
```
2. 发送包含 sa-token 的请求到 APISIX 网关
```curl
curl http://127.0.0.1:9080/get \
  -H 'Authorization: Bearer <token>'
```
注意：
- 请将 `<token>` 替换为你在 smart-admin 中配置的实际 token 值
- 确保 APISIX 路由已正确配置，且插件已启用。如果插件未启用，请求将被拒绝。

3. 检查响应是否符合预期
```
{
  "args": {},
  "headers": {
    "Authorization": "Bearer <token>",
    "Host": "httpbin.org",
    "User-Agent": "curl/7.88.1",
    "X-Amzn-Trace-Id": "Root=1-6620593a-722212244920420232532323"
  },
  "origin": "119.29.29.29",
  "url": "https://httpbin.org/get"
}
```
## 配置说明

### APISIX 配置

配置文件：`./apisix_conf/config.yaml`

#### 关键配置项说明

**1. etcd 配置**
```yaml
etcd:
  host:
    - "http://etcd:2379"  # etcd 服务地址
  prefix: "/apisix"       # 数据前缀
  timeout: 30             # 连接超时
```

**2. 管理员 API 配置**
```yaml
deployment:
  admin:
    enable_admin_ui: true    # 启用 Dashboard
    allow_admin:
      - 0.0.0.0/0            # 允许所有 IP 访问（生产环境需限制）
```

**3. 外部插件配置**
```yaml
ext-plugin:
  path_for_test: /tmp/runner.sock  # Unix Socket 路径
```

**4. 插件列表**

已启用 45+ 个常用插件，包括：
- 认证鉴权：`key-auth`, `jwt-auth`, `basic-auth`, `oauth` 等
- 安全防护：`ip-restriction`, `cors`, `csrf` 等
- 流量控制：`limit-req`, `limit-conn`, `limit-count`
- 请求转换：`proxy-rewrite`, `response-rewrite`
- 可观测性：`prometheus`, `http-logger`, `zipkin` 等
- 外部插件：`ext-plugin-pre-req`, `ext-plugin-post-req`

## 工作原理

1. APISIX 接收到请求后，通过外部插件机制将请求转发给 Java 插件
2. Java 插件检查请求头中的 Authorization 字段（通过 nginx 变量 `http_authorization`）
3. 提取 Bearer Token 并在 Redis 中验证（Key: `satoken:login:token:{token}`）
4. 根据验证结果返回相应响应或继续处理请求
5. **重要**：无论认证成功或失败，都必须调用 `chain.filter()` 通知 APISIX

## API 使用

在请求中添加 Authorization 头：
Authorization: Bearer <your_token_here>

## 错误响应

插件会根据不同的错误情况返回相应的 JSON 格式响应：

1. 未提供 Token: 401 状态码
2. Token 格式错误: 401 状态码
3. Token 无效或过期: 401 状态码
4. 系统错误: 500 状态码

## 开发指南

### 创建自定义插件

#### 1. 实现 PluginFilter 接口

``` java
@Slf4j
@Component
public class SmartAuthenticationFilter implements PluginFilter, InitializingBean {
    
    @Override
    public void afterPropertiesSet() {
        log.info("SmartAuthenticationFilter initialized");
    }
    
    @Override
    public String name() {
        return "SmartAuthenticationFilter";  // 必须与路由配置中的名称一致
    }
    
    /**
     * 声明需要使用的 nginx 变量
     * http_authorization 对应 HTTP 请求头中的 Authorization
     */
    @Override
    public List<String> requiredVars() {
        List<String> vars = new ArrayList<>();
        vars.add("http_authorization");  // 获取 Authorization 请求头
        return vars;
    }
    
    @Override
    public void filter(HttpRequest request, HttpResponse response, PluginFilterChain chain) {
        // 1. 通过 nginx 变量获取请求头
        String authorization = request.getVars("http_authorization");
        
        if (authorization == null) {
            // 2. 设置响应
            response.setBody("{\"error\":\"未登录\"}");
            response.setHeader("Content-Type", "application/json");
            response.setStatusCode(401);
            // 3. 必须调用 chain.filter()！
            chain.filter(request, response);
            return;
        }
        
        // 4. 认证成功，继续处理
        chain.filter(request, response);
    }
}
```

#### 2. 关键知识点

**获取请求头的正确方式：**
``` java
// ✅ 正确：使用 nginx 变量
@Override
public List<String> requiredVars() {
    return Arrays.asList("http_authorization", "http_user_agent");
}

String auth = request.getVars("http_authorization");  // 对应 Authorization 请求头

// ❌ 错误：直接 getHeader() 不可用
// String auth = request.getHeader("Authorization");  // 这个方法不存在
```

**响应处理机制：**
``java
// 重要：无论成功或失败，都必须调用 chain.filter()

// 认证失败：
response.setBody("...");
response.setStatusCode(401);
chain.filter(request, response);  // ← 必须调用！APISIX 会直接返回 401，不访问 upstream

// 认证成功：
chain.filter(request, response);  // ← 必须调用！APISIX 继续转发到 upstream
```

### 部署插件

#### 完整部署流程

```
# 1. 在 IDEA 中编译（或使用 Maven）
mvn clean package -DskipTests

# 2. 验证 JAR 文件生成
ls -lh target/smart-gateway-1.0.jar

# 3. 重新构建 Docker 镜像（强制不使用缓存）
docker-compose build --no-cache java-plugin-runner

# 4. 重启服务
docker-compose restart java-plugin-runner

# 5. 等待服务启动（约 10 秒）
sleep 10

# 6. 验证插件加载
docker-compose logs java-plugin-runner --tail 20 | grep "SmartAuthenticationFilter"
```

#### 常见问题排查

```
# 查看编译错误
mvn clean package

# 查看 Docker 构建日志
docker-compose build java-plugin-runner

# 查看运行时错误
docker-compose logs java-plugin-runner --tail 100

# 进入容器内部检查
docker-compose exec java-plugin-runner ls -la /app/
```

## 关键配置说明

### 1. 数据持久化

**etcd 数据持久化配置：**

```
# docker-compose.yml
etcd:
  environment:
    - ETCD_DATA_DIR=/etcd-data  # 指定数据目录
  volumes:
    - etcd-data:/etcd-data      # 持久化卷
```

**重启命令：**
```bash
# ✅ 正常重启（数据保留）
docker-compose down
docker-compose up -d

# ❌ 危险操作（会删除所有数据）
docker-compose down -v  # 不要使用 -v 参数！
```

### 2. 访问外网服务

**配置 HTTPS 上游：**

```
// 路由配置示例
{
  "uri": "/get",
  "upstream": {
    "type": "roundrobin",
    "nodes": {"httpbin.org:443": 1},  // 使用 443 端口
    "scheme": "https"                   // 指定 https 协议
  }
}
```

**重要：** httpbin.org 的 HTTP (80端口) 可能不可用，建议使用 HTTPS (443端口)。

### 3. Unix Socket 通信

**必须手动创建 tmp 目录：**
```
mkdir -p tmp
chmod 777 tmp
```

**为什么需要绑定挂载：**
- ✅ 绑定挂载：`./tmp:/tmp:rw` - 权限一致，推荐
- ❌ 命名卷：`tmp-volume:/tmp` - 权限同步问题

**APISIX 需要 root 用户：**
```yaml
apisix:
  user: root  # 访问 socket 文件需要 root 权限
```

## 注意事项

### 开发相关

1. **插件注册**：必须使用 `@Component` 注解
2. **名称匹配**：`name()` 返回值必须与路由配置完全一致
3. **强制重建**：修改代码后使用 `docker-compose build --no-cache`
4. **chain.filter()**：无论成功或失败都必须调用
5. **请求头获取**：使用 `requiredVars()` + `getVars()`，不是 `getHeader()`

### 生产环境

1. **IP 白名单**：修改 `allow_admin` 限制 Dashboard 访问
2. **Admin Key**：更换默认的 API Key
3. **Redis 密码**：配置强密码
4. **日志级别**：调整为 `warn` 或 `error`
5. **资源限制**：添加 Docker 容器资源限制

## 常见问题

### 1. 插件未被识别

**错误信息**：
```
receive undefined filter: SmartAuthenticationFilter
```

**解决方案**：
```bash
# 1. 检查注解
grep '@Component' src/main/java/com/jsjf/ai/smartgateway/SmartAuthenticationFilter.java

# 2. 检查 name() 返回值
grep 'public String name()' -A 1 src/main/java/com/jsjf/ai/smartgateway/SmartAuthenticationFilter.java

# 3. 强制重新构建（关键！）
docker-compose build --no-cache java-plugin-runner
docker-compose restart java-plugin-runner

# 4. 验证插件加载
docker-compose logs java-plugin-runner | grep "initialized"
```

### 2. Socket 权限问题

**错误信息**：
```
Permission denied on /tmp/runner.sock
```

**解决方案**：
```yaml
# docker-compose.yml
apisix:
  user: root              # 添加 root 用户
  volumes:
    - ./tmp:/tmp:rw       # 使用绑定挂载，不是命名卷

java-plugin-runner:
  volumes:
    - ./tmp:/tmp:rw       # 两个容器共享同一目录
```

```bash
# 确保目录存在且权限正确
mkdir -p tmp
chmod 777 tmp
```

### 3. 路由 404

**问题**：创建路由后访问返回 404

**原因**：APISIX 默认将请求路径原样转发给上游

**解决方案 1：URI 直接使用上游路径**
```json
{
  "uri": "/get",  // 直接用 httpbin.org 的真实路径
  "upstream": {
    "nodes": {"httpbin.org:443": 1},
    "scheme": "https"
  }
}
```

**解决方案 2：使用 proxy-rewrite 插件**
```json
{
  "uri": "/my-custom-path",
  "plugins": {
    "proxy-rewrite": {
      "uri": "/get"  // 重写为上游的真实路径
    }
  },
  "upstream": {
    "nodes": {"httpbin.org:443": 1},
    "scheme": "https"
  }
}
```

### 4. 认证插件请求卡住

**问题**：设置 401 响应后客户端一直等待

**原因**：ext-plugin 必须调用 `chain.filter()`

**解决方案**：
```
// ❌ 错误：只设置响应不调用 chain.filter
response.setStatusCode(401);
return;  // 会导致请求卡住！

// ✅ 正确：设置响应后必须调用 chain.filter
response.setBody("{\"error\":\"未登录\"}");
response.setHeader("Content-Type", "application/json");
response.setStatusCode(401);
chain.filter(request, response);  // 必须调用！
return;
```

### 5. etcd 连接失败

**错误信息**：
```
connection refused: http://127.0.0.1:2379
```

**解决方案**：
```yaml
# docker-compose.yml
etcd:
  environment:
    - ETCD_LISTEN_CLIENT_URLS=http://0.0.0.0:2379  # 监听所有接口
    - ETCD_ADVERTISE_CLIENT_URLS=http://etcd:2379  # 广播地址

apisix:
  environment:
    - APISIX_DEPLOYMENT_ETCD_HOST=["http://etcd:2379"]  # JSON 数组格式
```

### 6. 修改代码后不生效

**问题**：重新部署后代码没有更新

**解决方案**：
```bash
# 完整的更新流程
# 1. 重新编译
mvn clean package -DskipTests

# 2. 强制重建镜像（关键！）
docker-compose build --no-cache java-plugin-runner

# 3. 停止并删除旧容器
docker-compose rm -sf java-plugin-runner

# 4. 启动新容器
docker-compose up -d java-plugin-runner

# 5. 验证
docker-compose logs java-plugin-runner --tail 20
```

### 7. 访问外网超时

**问题**：代理外网服务时超时

**解决方案**：
```bash
# 1. 检查容器内是否能访问外网
docker-compose exec apisix sh -c "getent hosts httpbin.org"

# 2. 使用 HTTPS 而不是 HTTP
# httpbin.org:80 可能不可用
# httpbin.org:443 正常工作

# 3. 配置 DNS
# docker-compose.yml
apisix:
  dns:
    - 8.8.8.8
    - 8.8.4.4
```

## 许可证

MIT License

## 联系方式

作者：刘云
邮箱：liuyun105@126.com
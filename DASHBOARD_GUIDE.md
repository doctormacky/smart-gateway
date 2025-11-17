# APISIX Dashboard 使用指南

## 访问地址

- **Dashboard UI**: http://localhost:9180/ui
- **Admin API**: http://localhost:9180/apisix/admin

## 插件查看说明

### 1. 查看所有可用插件（44个）

在 Dashboard 中有两个地方可以查看插件：

#### 方法一：通过 API 查看
```bash
curl http://localhost:9180/apisix/admin/plugins/list \
  -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1'
```

返回所有 44 个已加载的插件：
- 认证鉴权：key-auth, jwt-auth, basic-auth, hmac-auth, ldap-auth, openid-connect
- 安全防护：ip-restriction, ua-restriction, referer-restriction, uri-blocker, csrf, cors
- 流量控制：limit-req, limit-conn, limit-count
- 请求转换：proxy-rewrite, response-rewrite, grpc-transcode, grpc-web
- 可观测性：prometheus, skywalking, zipkin, opentelemetry, http-logger, tcp-logger, kafka-logger, syslog, error-log-logger
- 流量管理：traffic-split, proxy-cache, proxy-mirror, api-breaker
- 其他：redirect, echo, real-ip, server-info, batch-requests, gzip, request-id, request-validation, serverless-pre-function, serverless-post-function
- 外部插件：ext-plugin-pre-req, ext-plugin-post-req

#### 方法二：在 Dashboard 创建/编辑路由时查看
1. 访问 http://localhost:9180/ui
2. 点击左侧菜单 **Routes**
3. 点击 **Create** 或编辑现有路由
4. 在 **Plugins** 步骤中，可以看到所有可用插件的列表

### 2. Plugin Metadata 页面

**重要说明**：`http://localhost:9180/ui/plugin_metadata` 页面显示的是**已配置元数据的插件**，而不是所有可用插件。

- **Plugin Metadata** 用于配置插件的全局默认参数
- 只有当你为某个插件配置了元数据后，它才会出现在这个页面
- 插件不需要配置元数据也可以正常使用

#### 示例：为插件配置元数据

```bash
# 为 http-logger 插件配置全局元数据
curl http://localhost:9180/apisix/admin/plugin_metadata/http-logger \
  -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' \
  -X PUT -d '{
    "log_format": {
      "host": "$host",
      "client_ip": "$remote_addr"
    }
  }'
```

配置后，该插件就会出现在 Plugin Metadata 页面。

## 当前配置状态

### 已加载插件：44 个
所有在 `apisix_conf/config.yaml` 中配置的插件都已成功加载。

### 已配置元数据：0 个
当前没有为任何插件配置全局元数据（这是正常的）。

### 已创建路由：1 个
- **Route ID**: `get`
- **URI**: `/get`
- **Upstream**: https://httpbin.org:443
- **Plugins**: ext-plugin-pre-req (SmartAuthenticationFilter)

## 常见问题

### Q: 为什么 Plugin Metadata 页面显示的插件很少？
A: 这个页面只显示已配置元数据的插件。所有 44 个插件都已加载并可用，只是没有配置元数据而已。

### Q: 如何查看所有可用插件？
A: 
1. 使用 API: `curl http://localhost:9180/apisix/admin/plugins/list -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1'`
2. 在 Dashboard 创建路由时，在 Plugins 步骤可以看到所有插件

### Q: 插件需要配置元数据才能使用吗？
A: 不需要。元数据是可选的全局配置，用于设置插件的默认参数。大多数插件可以直接在路由上配置使用。

## 测试当前路由

```bash
# 测试已配置的路由
curl http://localhost:9080/get

# 查看路由详情
curl http://localhost:9180/apisix/admin/routes/get \
  -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1'
```

## 参考文档

- [APISIX Plugin 文档](https://apisix.apache.org/docs/apisix/plugins/batch-requests/)
- [APISIX Admin API](https://apisix.apache.org/docs/apisix/admin-api/)

# Smart Gateway 使用示例

本文档提供 Smart Gateway 认证插件的完整使用示例。

## 目录

- [快速开始](#快速开始)
- [路由配置](#路由配置)
- [测试示例](#测试示例)
- [错误响应](#错误响应)
- [最佳实践](#最佳实践)

## 快速开始

### 1. 配置 APISIX 路由

通过 Admin API 创建一个启用认证插件的路由：

```bash
curl -X PUT http://127.0.0.1:9180/apisix/admin/routes/1 \
  -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' \
  -H 'Content-Type: application/json' \
  -d '{
    "uri": "/api/*",
    "name": "protected-api",
    "plugins": {
      "ext-plugin-pre-req": {
        "conf": [
          {
            "name": "SmartAuthenticationFilter",
            "value": "{}"
          }
        ]
      }
    },
    "upstream": {
      "type": "roundrobin",
      "nodes": {
        "your-backend-service:8080": 1
      }
    }
  }'
```

### 2. 发送认证请求

```bash
# 成功的请求示例
curl http://127.0.0.1:9080/api/users \
  -H 'Authorization: Bearer your_valid_token_here'
```

## 路由配置

### 基础配置

最简单的配置方式：

```json
{
  "uri": "/api/*",
  "plugins": {
    "ext-plugin-pre-req": {
      "conf": [
        {
          "name": "SmartAuthenticationFilter",
          "value": "{}"
        }
      ]
    }
  },
  "upstream": {
    "nodes": {
      "backend:8080": 1
    }
  }
}
```

### 组合使用多个插件

与其他 APISIX 插件配合使用：

```json
{
  "uri": "/api/*",
  "plugins": {
    "ext-plugin-pre-req": {
      "conf": [
        {
          "name": "SmartAuthenticationFilter",
          "value": "{}"
        }
      ]
    },
    "limit-req": {
      "rate": 100,
      "burst": 50,
      "key": "remote_addr"
    },
    "cors": {
      "allow_origins": "*",
      "allow_methods": "GET,POST,PUT,DELETE",
      "allow_headers": "Authorization,Content-Type"
    }
  },
  "upstream": {
    "nodes": {
      "backend:8080": 1
    }
  }
}
```

### HTTPS 上游配置

访问 HTTPS 后端服务：

```json
{
  "uri": "/api/*",
  "plugins": {
    "ext-plugin-pre-req": {
      "conf": [
        {
          "name": "SmartAuthenticationFilter",
          "value": "{}"
        }
      ]
    }
  },
  "upstream": {
    "type": "roundrobin",
    "nodes": {
      "api.example.com:443": 1
    },
    "scheme": "https"
  }
}
```

## 测试示例

### 成功场景

#### 1. 正常的认证请求

**请求：**
```bash
curl -X GET http://127.0.0.1:9080/api/users \
  -H 'Authorization: Bearer abc123def456ghi789'
```

**响应：**
```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "users": [...]
}
```

#### 2. POST 请求

**请求：**
```bash
curl -X POST http://127.0.0.1:9080/api/users \
  -H 'Authorization: Bearer abc123def456ghi789' \
  -H 'Content-Type: application/json' \
  -d '{"name": "John Doe", "email": "john@example.com"}'
```

### 失败场景

#### 1. 缺少 Authorization 头

**请求：**
```bash
curl -X GET http://127.0.0.1:9080/api/users
```

**响应：**
```http
HTTP/1.1 401 Unauthorized
Content-Type: application/json; charset=utf-8

{
  "success": false,
  "code": "AUTH_001",
  "message": "未提供认证令牌，请在请求头中添加 Authorization 字段",
  "timestamp": 1699999999999
}
```

#### 2. Token 格式错误

**请求：**
```bash
curl -X GET http://127.0.0.1:9080/api/users \
  -H 'Authorization: Basic dXNlcjpwYXNz'
```

**响应：**
```http
HTTP/1.1 401 Unauthorized
Content-Type: application/json; charset=utf-8

{
  "success": false,
  "code": "AUTH_002",
  "message": "令牌格式错误，正确格式为: Bearer {token}",
  "timestamp": 1699999999999
}
```

#### 3. Token 为空

**请求：**
```bash
curl -X GET http://127.0.0.1:9080/api/users \
  -H 'Authorization: Bearer '
```

**响应：**
```http
HTTP/1.1 401 Unauthorized
Content-Type: application/json; charset=utf-8

{
  "success": false,
  "code": "AUTH_003",
  "message": "令牌内容为空，请提供有效的令牌",
  "timestamp": 1699999999999
}
```

#### 4. Token 无效或已过期

**请求：**
```bash
curl -X GET http://127.0.0.1:9080/api/users \
  -H 'Authorization: Bearer invalid_or_expired_token'
```

**响应：**
```http
HTTP/1.1 401 Unauthorized
Content-Type: application/json; charset=utf-8

{
  "success": false,
  "code": "AUTH_004",
  "message": "令牌无效或已过期，请重新登录",
  "timestamp": 1699999999999
}
```

## 错误响应

### 错误码说明

| 错误码 | HTTP 状态码 | 说明 | 解决方案 |
|--------|------------|------|---------|
| AUTH_001 | 401 | 缺少 Authorization 请求头 | 在请求头中添加 `Authorization: Bearer {token}` |
| AUTH_002 | 401 | Token 格式错误 | 确保使用 `Bearer {token}` 格式 |
| AUTH_003 | 401 | Token 内容为空 | 提供有效的 token 值 |
| AUTH_004 | 401 | Token 无效或已过期 | 重新登录获取新的 token |
| SYS_500 | 500 | 系统内部错误 | 检查系统日志，联系管理员 |

### 错误响应格式

所有错误响应都遵循统一的 JSON 格式：

```json
{
  "success": false,
  "code": "错误码",
  "message": "错误描述",
  "timestamp": 1699999999999
}
```

**字段说明：**
- `success`: 布尔值，固定为 `false`
- `code`: 字符串，错误码（参考上表）
- `message`: 字符串，人类可读的错误描述
- `timestamp`: 数字，错误发生时的时间戳（毫秒）

## 最佳实践

### 1. Token 管理

**生成 Token：**
```java
// 在你的登录服务中
StpUtil.login(userId);
String token = StpUtil.getTokenValue();
// 返回给客户端
```

**客户端存储：**
```javascript
// Web 应用
localStorage.setItem('access_token', token);

// 每次请求携带 token
fetch('/api/users', {
  headers: {
    'Authorization': `Bearer ${localStorage.getItem('access_token')}`
  }
});
```

### 2. 错误处理

**前端统一拦截：**
```javascript
// Axios 示例
axios.interceptors.response.use(
  response => response,
  error => {
    if (error.response?.status === 401) {
      const errorCode = error.response.data?.code;
      
      if (errorCode === 'AUTH_004') {
        // Token 过期，跳转登录
        window.location.href = '/login';
      }
    }
    return Promise.reject(error);
  }
);
```

### 3. 性能优化

**Redis 连接池配置：**
```yaml
# application.yml
spring:
  data:
    redis:
      lettuce:
        pool:
          max-active: 200
          max-idle: 10
          min-idle: 5
          max-wait: -1ms
```

**APISIX 缓存配置：**
```yaml
# config.yaml
nginx_config:
  http:
    lua_shared_dict:
      plugin-limit-req: 10m
      plugin-limit-count: 10m
```

### 4. 安全建议

1. **使用 HTTPS**：生产环境务必使用 HTTPS 保护 Token 传输
2. **Token 过期时间**：合理设置 Token 有效期（建议 2-24 小时）
3. **IP 白名单**：为 Admin API 配置 IP 白名单
4. **日志脱敏**：避免在日志中输出完整 Token

**日志配置：**
```yaml
# application.yml
logging:
  level:
    com.jsjf.ai.smartgateway: DEBUG  # 开发环境
    # com.jsjf.ai.smartgateway: WARN  # 生产环境
```

### 5. 监控告警

**关键指标：**
- 认证成功率
- 认证失败次数
- 平均响应时间
- Redis 连接状态

**Prometheus 配置：**
```json
{
  "uri": "/metrics",
  "plugins": {
    "prometheus": {}
  }
}
```

## 常见问题

### Q1: 如何允许某些路径跳过认证？

A: 为公开路径创建单独的路由，不启用认证插件：

```bash
# 公开路径（无需认证）
curl -X PUT http://127.0.0.1:9180/apisix/admin/routes/public \
  -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' \
  -d '{
    "uri": "/public/*",
    "upstream": {
      "nodes": {"backend:8080": 1}
    }
  }'
```

### Q2: 如何自定义 Redis Key 格式？

A: 修改 Sa-Token 配置：

```yaml
sa-token:
  token-name: my-token
  # Redis Key 将变为: my-token:login:token:{token}
```

### Q3: 支持多种认证方式吗？

A: 当前仅支持 Bearer Token。如需支持其他方式（如 API Key），可以：
1. 扩展 `SmartAuthenticationFilter` 类
2. 或创建新的插件类

### Q4: 如何调试认证问题？

A: 启用 DEBUG 日志：

```yaml
logging:
  level:
    com.jsjf.ai.smartgateway: DEBUG
```

查看日志输出：
```bash
docker-compose logs java-plugin-runner --tail 100 -f
```

## 技术支持

- **项目地址**: https://github.com/your-org/smart-gateway
- **问题反馈**: https://github.com/your-org/smart-gateway/issues
- **作者邮箱**: liuyun105@126.com

## 许可证

MIT License

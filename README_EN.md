# Smart Gateway

English | [简体中文](./README.md)

A Java-based plugin for Apache APISIX, compatible with tokens issued by smart-admin (which uses sa-token for authentication). This plugin is compatible with Apache APISIX version 3.14.1.

## Author

Liu Yun (liuyun105@126.com)

## Project Overview

Smart Gateway is an external plugin system for Apache APISIX, written in Java, specifically designed to handle sa-token based authentication. The project adopts a **single-container architecture**, integrating APISIX and Java Plugin Runner in the same Docker container, communicating efficiently via Unix Domain Socket.

### Core Features

- **Smart Authentication**: Integrated Sa-Token for Redis-based distributed authentication
- **Single Container Architecture**: APISIX and Java Runner run in the same container, simplifying deployment
- **Efficient Communication**: Inter-process communication via Unix Domain Socket
- **API Gateway**: High-performance API gateway based on APISIX 3.14.1
- **Visual Management**: APISIX Dashboard supports visual route configuration
- **Data Persistence**: Automatic etcd data persistence, no configuration loss on restart
- **HTTPS Upstream**: Support for accessing external HTTPS services (e.g., httpbin.org)

## Technology Stack

- **Apache APISIX**: 3.14.1-debian
- **APISIX Java Plugin Runner**: 0.6.0
- **Spring Boot**: 3.5.7
- **Sa-Token**: 1.44.0
- **etcd**: latest (OpenEuler, arm64)
- **Redis**: 7-alpine (standalone container)
- **Java**: 21 (OpenJDK)
- **Maven**: 3.9.9
- **Docker & Docker Compose**: Required

## Architecture Design

### Single Container Architecture

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

### Advantages

1. **Simplified Deployment**: Only need to manage one application container
2. **Efficient Communication**: Unix Socket is faster than TCP with lower latency
3. **Resource Optimization**: Reduced container count, lower resource overhead
4. **Unified Management**: Logs and configurations centralized in one container

## Project Structure

```
smart-gateway/
├── apisix_conf/                # Apache APISIX configuration directory
│   └── config.yaml             # APISIX main config (routes, plugins, ext-plugin config)
├── docker-compose.yml          # Docker Compose orchestration (APISIX + etcd)
├── Dockerfile                  # Dockerfile for building integrated image
├── start-runner.sh             # Java Runner startup script (auto socket permission fix)
├── pom.xml                     # Maven project configuration
├── README.md                   # Project documentation (Chinese)
├── README_EN.md                # Project documentation (English)
├── src/                        # Source code directory
│   └── main/
│       ├── java/               # Java source code
│       │   └── com/jsjf/ai/smartgateway/
│       │       ├── SmartGatewayApplication.java
│       │       └── SmartAuthenticationFilter.java
│       └── resources/
│           └── application.yml # Spring Boot configuration
└── target/
    └── smart-gateway-1.0.jar   # Compiled JAR package
```

## Quick Start

### Prerequisites

1. **Install Docker and Docker Compose**
2. **Start standalone Redis container** (for storing authentication tokens)

```bash
# Start Redis (if not already running)
docker run -d --name redis-local \
  -p 6379:6379 \
  redis:7-alpine redis-server --requirepass redis123
```

### 1. Build Project

```bash
# Build with Maven
./mvnw clean package -DskipTests

# Verify JAR file generation
ls -lh target/smart-gateway-1.0.jar
```

### 2. Start Services

```bash
# Start APISIX and etcd
docker-compose up -d --build

# Check service status
docker-compose ps

# View logs
docker-compose logs -f apisix
```

### 3. Verify Services

```bash
# Check if Java Runner started
docker-compose logs apisix 2>&1 | grep "listening on the socket"

# Check Socket file permissions
docker exec smart-gateway-apisix-1 ls -la /tmp/runner.sock
# Should display: srw-rw-rw- 1 root root 0 ... /tmp/runner.sock
```

### 4. Access APISIX Dashboard

Open browser and visit: `http://localhost:9180/ui/`

- Default username: `admin`
- Default password: `admin`
- API Key: `edd1c9f034335f136f87ad84b625c8f1`

### 5. Configure Routes

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

### 6. Test Authentication

#### Prepare Test Data

```bash
# Set test token in Redis
docker exec redis-local redis-cli -a redis123 -n 1 \
  SET "Authorization:login:token:test-token-123" "user123"
```

#### Test Scenarios

```bash
# Test 1: No Token (should return 401 AUTH_001)
curl -i http://localhost:9080/get

# Test 2: Valid Token (should return 200 OK)
curl -i http://localhost:9080/get \
  -H 'Authorization: Bearer test-token-123'

# Test 3: Invalid Token (should return 401 AUTH_004)
curl -i http://localhost:9080/get \
  -H 'Authorization: Bearer invalid-token'

# Test 4: Malformed Token (should return 401 AUTH_002)
curl -i http://localhost:9080/get \
  -H 'Authorization: InvalidFormat'
```

#### Expected Results

| Test Scenario | HTTP Status | Error Code | Description |
|--------------|-------------|------------|-------------|
| No Token | 401 | AUTH_001 | Authentication token not provided |
| Valid Token | 200 | - | Successfully accessed upstream service |
| Invalid Token | 401 | AUTH_004 | Token invalid or expired |
| Malformed | 401 | AUTH_002 | Token format error |

## Configuration Guide

### 1. APISIX Configuration (apisix_conf/config.yaml)

#### ext-plugin Configuration (Critical)

```yaml
ext-plugin:
  # Use startup script to auto-fix socket permissions
  cmd: ["/bin/bash", "/usr/local/apisix-runner/start-runner.sh"]
  # Socket file path (APISIX 3.x connects to this path by default)
  path_for_test: /tmp/runner.sock
```

#### etcd Configuration

```yaml
etcd:
  host:
    - "http://etcd:2379"
  prefix: "/apisix"
  timeout: 30
```

#### Plugin List

40+ common plugins enabled, including:
- **Authentication**: `key-auth`, `jwt-auth`, `basic-auth`, `hmac-auth`, etc.
- **Security**: `ip-restriction`, `cors`, `csrf`, `uri-blocker`, etc.
- **Traffic Control**: `limit-req`, `limit-conn`, `limit-count`
- **Request Transformation**: `proxy-rewrite`, `response-rewrite`
- **Observability**: `prometheus`, `http-logger`, `zipkin`, etc.
- **External Plugins**: `ext-plugin-pre-req`, `ext-plugin-post-req`

### 2. Spring Boot Configuration (application.yml)

```yaml
spring:
  application:
    name: smart-gateway
  main:
    web-application-type: none  # Disable web server (avoid port conflicts)
  data:
    redis:
      host: ${SPRING_DATA_REDIS_HOST:localhost}
      port: ${SPRING_DATA_REDIS_PORT:6379}
      password: ${SPRING_DATA_REDIS_PASSWORD:redis123}
      database: 1
```

### 3. Docker Compose Configuration

```yaml
services:
  apisix:
    build:
      context: .
      dockerfile: Dockerfile
    restart: always
    user: root  # Root permission needed to access socket
    volumes:
      # Mount config file (read-only)
      - ./apisix_conf/config.yaml:/usr/local/apisix/conf/config.yaml:ro
    ports:
      - "9180:9180"   # Admin API
      - "9080:9080"   # HTTP Gateway
      - "5005:5005"   # JDWP remote debugging port (optional)
    extra_hosts:
      # Allow container to access host's Redis
      - "host.docker.internal:host-gateway"
    environment:
      - SPRING_DATA_REDIS_HOST=host.docker.internal
      - SPRING_DATA_REDIS_PORT=6379
      - SPRING_DATA_REDIS_PASSWORD=redis123
```

### 4. Startup Script (start-runner.sh)

```bash
#!/bin/bash
# Start Java Runner (background)
java -jar -Xmx1g -Xms1g \
  -Dspring.data.redis.host=host.docker.internal \
  -Dspring.data.redis.port=6379 \
  -Dspring.data.redis.password=redis123 \
  /usr/local/apisix-runner/apisix-java-plugin-runner.jar &

# Wait for socket file creation
for i in {1..30}; do
  if [ -S /tmp/runner.sock ]; then
    # Change permissions to 666 (all users can read/write)
    chmod 666 /tmp/runner.sock
    echo "Socket file permissions updated: $(ls -la /tmp/runner.sock)"
    break
  fi
  sleep 0.5
done

# Keep script running
wait
```

**Key Points**:
- Socket file default permission is `600` (only creator can access)
- APISIX worker processes need to access socket, so must change to `666`
- Script waits for socket creation then auto-fixes permissions

## How It Works

### Authentication Flow

```
1. Client Request
   ↓
2. APISIX Receives Request
   ↓
3. Forward to Java Plugin Runner via Unix Socket
   ↓
4. SmartAuthenticationFilter Processing
   ├─ Extract Authorization header (via nginx variable)
   ├─ Parse Bearer Token
   ├─ Validate Token in Redis
   └─ Return authentication result
   ↓
5. APISIX Decides Based on Result
   ├─ Authentication Success → Forward to upstream service
   └─ Authentication Failure → Return 401 error
```

### Key Technical Points

1. **Get Request Headers via nginx Variables**
   ```java
   @Override
   public List<String> requiredVars() {
       return Arrays.asList("http_authorization");
   }
   
   String auth = request.getVars("http_authorization");
   ```

2. **Must Call chain.filter()**
   ```java
   // Must call regardless of success or failure
   response.setStatusCode(401);
   chain.filter(request, response);  // ← Required!
   ```

3. **Redis Key Format**
   ```
   Authorization:login:token:{token}
   ```

## Development Guide

### Redeploy After Code Changes

```bash
# 1. Recompile
./mvnw clean package -DskipTests

# 2. Rebuild image (force no cache)
docker-compose build --no-cache apisix

# 3. Restart services
docker-compose down
docker-compose up -d

# 4. Verify
docker-compose logs apisix 2>&1 | grep "SmartAuthenticationFilter"
```

### Create Custom Plugin

```java
@Slf4j
@Component
public class MyCustomFilter implements PluginFilter {
    
    @Override
    public String name() {
        return "MyCustomFilter";  // Must match name in route config
    }
    
    @Override
    public List<String> requiredVars() {
        // Declare required nginx variables
        return Arrays.asList("http_authorization", "http_user_agent");
    }
    
    @Override
    public void filter(HttpRequest request, HttpResponse response, PluginFilterChain chain) {
        // Get request headers
        String auth = request.getVars("http_authorization");
        
        // Business logic
        if (auth == null) {
            response.setBody("{\"error\":\"Unauthorized\"}");
            response.setHeader("Content-Type", "application/json");
            response.setStatusCode(401);
        }
        
        // Must call!
        chain.filter(request, response);
    }
}
```

### Debugging Tips

```bash
# View full logs
docker-compose logs -f apisix

# View Java startup logs
docker-compose logs apisix 2>&1 | grep "SmartGateway"

# Check Socket file
docker exec smart-gateway-apisix-1 ls -la /tmp/runner.sock

# Enter container for debugging
docker exec -it smart-gateway-apisix-1 bash

# View tokens in Redis
docker exec redis-local redis-cli -a redis123 -n 1 KEYS "Authorization:*"
```

## Common Issues

### 1. Socket Permission Error

**Error Message**:
```
failed to connect to the unix socket unix:/tmp/runner.sock: permission denied
```

**Cause**: Java Runner creates socket file with `600` permissions, APISIX worker processes cannot access.

**Solution**: Use `start-runner.sh` startup script to auto-fix permissions to `666`.

### 2. 503 Service Temporarily Unavailable

**Possible Causes**:
1. Java Runner not started
2. Socket file doesn't exist
3. Socket path misconfigured

**Troubleshooting Steps**:
```bash
# 1. Check if Java Runner started
docker-compose logs apisix 2>&1 | grep "listening on the socket"

# 2. Check Socket file
docker exec smart-gateway-apisix-1 ls -la /tmp/runner.sock

# 3. Check path_for_test in config.yaml
docker exec smart-gateway-apisix-1 cat /usr/local/apisix/conf/config.yaml | grep path_for_test
```

### 3. Redis Connection Failure

**Error Message**:
```
Unable to connect to Redis
```

**Solution**:
```bash
# 1. Ensure Redis container is running
docker ps | grep redis-local

# 2. Test if container can connect to Redis
docker exec smart-gateway-apisix-1 sh -c \
  "apt-get update > /dev/null 2>&1 && apt-get install -y telnet > /dev/null 2>&1 && \
   echo 'PING' | telnet host.docker.internal 6379"

# 3. Check environment variables
docker-compose config | grep REDIS
```

### 4. Plugin Not Recognized

**Error Message**:
```
receive undefined filter: SmartAuthenticationFilter
```

**Solution**:
```bash
# 1. Ensure @Component annotation is used
grep '@Component' src/main/java/com/jsjf/ai/smartgateway/SmartAuthenticationFilter.java

# 2. Ensure name() return value is correct
grep 'public String name()' -A 1 src/main/java/com/jsjf/ai/smartgateway/SmartAuthenticationFilter.java

# 3. Recompile and rebuild
./mvnw clean package -DskipTests
docker-compose build --no-cache apisix
docker-compose restart apisix
```

### 5. Route 404

**Issue**: Accessing route returns 404 after configuration

**Solution**:
```bash
# 1. Check if route was created successfully
curl http://127.0.0.1:9180/apisix/admin/routes \
  -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1'

# 2. Ensure URI matches
# Accessing http://localhost:9080/get
# Route config uri must be "/get"

# 3. Use proxy-rewrite plugin to rewrite path (if needed)
```

## Production Environment Recommendations

### Security Configuration

1. **Change Default Admin Key**
   ```yaml
   deployment:
     admin:
       admin_key:
         - name: "admin"
           key: "your-secure-random-key-here"  # Change to strong password
           role: admin
   ```

2. **Restrict Dashboard Access**
   ```yaml
   deployment:
     admin:
       allow_admin:
         - 10.0.0.0/8  # Only allow internal network access
   ```

3. **Configure Redis Password**
   ```bash
   docker run -d --name redis-local \
     -p 6379:6379 \
     redis:7-alpine redis-server --requirepass "your-strong-password"
   ```

### Performance Optimization

1. **Adjust JVM Parameters**
   ```bash
   # Modify in start-runner.sh
   java -jar -Xmx2g -Xms2g \
     -XX:+UseG1GC \
     -XX:MaxGCPauseMillis=200 \
     ...
   ```

2. **Adjust Log Level**
   ```yaml
   nginx_config:
     error_log_level: warn  # Use warn or error in production
   ```

3. **Add Resource Limits**
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

### Monitoring and Logging

1. **Enable Prometheus Plugin**
   ```bash
   # Access metrics
   curl http://localhost:9091/apisix/prometheus/metrics
   ```

2. **Centralized Log Collection**
   ```yaml
   # Use http-logger plugin to send logs to ELK
   plugins:
     - http-logger
   ```

## Version History

- **v1.0** (2025-11-15)
  - Initial release
  - Single container architecture (APISIX + Java Runner)
  - Sa-Token authentication support
  - Unix Domain Socket communication
  - Automatic socket permission management

## License

MIT License

## Contact

- **Author**: Liu Yun
- **Email**: liuyun105@126.com
- **Project URL**: [GitHub](https://github.com/yourusername/smart-gateway)

## Acknowledgments

- [Apache APISIX](https://apisix.apache.org/)
- [APISIX Java Plugin Runner](https://github.com/apache/apisix-java-plugin-runner)
- [Sa-Token](https://sa-token.cc/)
- [Spring Boot](https://spring.io/projects/spring-boot)

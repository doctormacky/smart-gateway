# Smart Gateway - Intelligent API Gateway

[![License](https://img.shields.io/badge/license-Apache%202-blue.svg)](LICENSE)
[![Java](https://img.shields.io/badge/Java-21-orange.svg)](https://openjdk.java.net/)
[![APISIX](https://img.shields.io/badge/APISIX-3.14.1-green.svg)](https://apisix.apache.org/)
[![Architecture](https://img.shields.io/badge/Architecture-Microservices-brightgreen.svg)]()

English | [简体中文](README.md)

## 📖 Overview

Smart Gateway is an enterprise-grade intelligent API gateway solution based on **Apache APISIX** and **Java Plugin Runner**. It adopts a **separated container architecture** to achieve high availability and easy scalability for microservice gateway systems.

### Core Features

- 🔐 **Unified Authentication** - Redis-based token authentication with multiple strategies
- 🚀 **High Performance Routing** - APISIX-powered HTTP routing and load balancing
- 🔌 **Plugin-based Extension** - Custom business logic via Java Plugin Runner
- 📊 **Observability** - Integrated Prometheus, logging, and monitoring
- 🛡️ **Security Protection** - IP restriction, rate limiting, CORS, and more
- 🐳 **Containerized Deployment** - One-click deployment with Docker Compose

---

## 🏗️ Tech Stack

| Component | Version | Description |
|-----------|---------|-------------|
| Apache APISIX | 3.14.1 | High-performance API Gateway |
| APISIX Dashboard | 3.0.1 | Web Management UI |
| Java | 21 | Java Plugin Runner Runtime |
| Spring Boot | 3.4.0 | Plugin Development Framework |
| Redis | Latest | Token Storage and Cache |
| ETCD | Latest | APISIX Configuration Center |
| Docker | Latest | Container Deployment |

---

## 🌐 Service Ports

| Service | Port | Description |
|---------|------|-------------|
| APISIX Gateway | 9080 | HTTP Gateway Entry |
| APISIX Admin API | 9180 | Management API |
| APISIX Dashboard | 9000 | Web Management UI |
| ETCD | 2379 | Configuration Center |
| Java Runner Debug | 5005 | Remote Debug Port (Optional) |

---

## 🎯 Architecture Design

### Separated Container Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Docker Network                        │
│                                                               │
│  ┌──────────────┐      ┌──────────────────┐                 │
│  │   APISIX     │      │  Java Plugin     │                 │
│  │  Container   │◄────►│     Runner       │                 │
│  │              │      │   Container      │                 │
│  │  - Routing   │      │  - Auth Logic    │                 │
│  │  - Plugins   │      │  - Redis Access  │                 │
│  │  - Load Bal. │      │  - Biz Plugins   │                 │
│  └──────┬───────┘      └────────┬─────────┘                 │
│         │                       │                            │
│         │  Unix Socket (/tmp)   │                            │
│         └───────────────────────┘                            │
│                                                               │
│  ┌──────────────┐      ┌──────────────────┐                 │
│  │     ETCD     │      │      Redis       │                 │
│  │   (Config)   │      │  (Token Store)   │                 │
│  └──────────────┘      └──────────────────┘                 │
└─────────────────────────────────────────────────────────────┘
```

### Communication Mechanism

- **APISIX ↔ Java Runner**: Unix Domain Socket (`/tmp/runner.sock`)
- **Java Runner ↔ Redis**: TCP (host.docker.internal:6379)
- **APISIX ↔ ETCD**: HTTP (etcd:2379)
- **Client ↔ APISIX**: HTTP (localhost:9080)

### Architecture Advantages

✅ **Loose Coupling** - Independent components  
✅ **Easy Scaling** - Scale Java Runner instances independently  
✅ **Easy Debugging** - Separated logs for quick troubleshooting  
✅ **High Availability** - Single component failure doesn't affect the whole system  
✅ **Flexible Deployment** - Independent upgrades and version management  

---

## 📁 Project Structure

```
smart-gateway/
├── src/main/java/com/macky/smartgateway/
│   ├── SmartGatewayApplication.java          # Main Application
│   └── filter/
│       └── SmartAuthenticationFilter.java    # Authentication Filter
├── src/main/resources/
│   └── application.yml                        # Spring Boot Config
├── apisix_conf/
│   └── config.yaml                            # APISIX Configuration
├── Dockerfile                                 # APISIX Container Image
├── Dockerfile.runner                          # Java Runner Container Image
├── docker-compose.yml                         # Container Orchestration
├── pom.xml                                    # Maven Dependencies
└── README.md                                  # Documentation
```

---

## 🚀 Quick Start

### Prerequisites

- Docker 20.10+
- Docker Compose 2.0+
- Maven 3.8+ (for building JAR)
- Java 21+ (for local development)

### Deployment Steps

#### Option 1: One-Click Startup (Recommended) ⭐️

Suitable for quick deployment and daily use:

```bash
# 1. Clone repository
git clone https://github.com/doctormacky/smart-gateway.git
cd smart-gateway

# 2. Build JAR package (required for first deployment)
mvn clean package -DskipTests

# 3. One-click startup (auto-check images, create directories, start services)
./start-docker.sh
```

The startup script will automatically:
- ✅ Create `tmp` directory (if not exists)
- ✅ Check APISIX image (pull from Docker Hub if not found locally)
- ✅ Check Java Runner image (build automatically if not found locally)
- ✅ Start all container services
- ✅ Verify service status and Socket file

#### Option 2: Manual Build and Start

Suitable for scenarios requiring custom images or debugging:

**Step 1: Clone Repository**

```bash
git clone https://github.com/doctormacky/smart-gateway.git
cd smart-gateway
```

**Step 2: Build JAR Package**

```bash
mvn clean package -DskipTests
```

**Step 3: Build Docker Images**

```bash
# Build all images
./build-images.sh --all

# Or build separately
./build-images.sh --apisix    # Build APISIX image only
./build-images.sh --runner    # Build Java Runner image only

# Force rebuild (no cache)
./build-images.sh --all --rebuild
```

**Step 4: Create Shared Directory**

```bash
mkdir -p tmp && chmod 777 tmp
```

**Step 5: Start Redis (Standalone Container)**

```bash
docker run -d \
  --name redis-local \
  -p 6379:6379 \
  redis:latest \
  redis-server --requirepass redis123
```

**Step 6: Start Gateway Services**

```bash
docker-compose up -d
```

#### Verify Service Status

```bash
# Check container status
docker-compose ps

# Check Java Runner logs
docker-compose logs java-plugin-runner

# Check APISIX logs
docker-compose logs apisix

# Verify socket file
docker exec smart-gateway-java-plugin-runner-1 ls -la /tmp/runner.sock
```

#### 6. Configure Routes and Test

```bash
# Configure test route
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

# Set test token in Redis
docker exec redis-local redis-cli -a redis123 -n 1 \
  SET "Authorization:login:token:test-token-123" "user123"

# Run tests
# Test 1: No Token (should return 401)
curl -i http://localhost:9080/get

# Test 2: Valid Token (should return 200)
curl -i http://localhost:9080/get \
  -H 'Authorization: Bearer test-token-123'

# Test 3: Invalid Token (should return 401)
curl -i http://localhost:9080/get \
  -H 'Authorization: Bearer invalid-token'

# Test 4: Malformed Token (should return 401)
curl -i http://localhost:9080/get \
  -H 'Authorization: InvalidFormat'
```

### Test Results

| Test Scenario | Expected Result | Error Code | Description |
|--------------|----------------|------------|-------------|
| No Token | 401 Unauthorized | AUTH_001 | Authentication token not provided |
| Valid Token | 200 OK | - | Successfully accessed upstream |
| Invalid Token | 401 Unauthorized | AUTH_004 | Token invalid or expired |
| Malformed Token | 401 Unauthorized | AUTH_002 | Token format error |

---

## ⚙️ Configuration

### 1. APISIX Configuration (`apisix_conf/config.yaml`)

```yaml
ext-plugin:
  # Java Plugin Runner runs in a separate container
  # Communicates via Unix Socket through shared /tmp directory
  path_for_test: /tmp/runner.sock
```

**Key Points:**
- ❌ **No `cmd` configuration needed** - Java Runner starts in its own container
- ✅ **Only specify socket path** - APISIX communicates via socket
- ✅ **Auto-reconnect** - APISIX reconnects automatically after Runner restart

### 2. Spring Boot Configuration (`application.yml`)

```yaml
spring:
  application:
    name: smart-gateway
  main:
    web-application-type: none  # Non-web app, no HTTP server
  data:
    redis:
      host: ${SPRING_DATA_REDIS_HOST:localhost}
      port: ${SPRING_DATA_REDIS_PORT:6379}
      password: ${SPRING_DATA_REDIS_PASSWORD:redis123}
      database: 1
```

**Key Points:**
- `web-application-type: none` - Runs as plugin, no web server needed
- Environment variables override - Support Docker env var overrides
- Redis database 1 - Avoid conflicts with other apps

### 3. Docker Compose Configuration

```yaml
services:
  apisix:
    volumes:
      - ./tmp:/tmp:rw  # Shared Unix Socket directory
    depends_on:
      - java-plugin-runner  # Ensure Runner starts first

  java-plugin-runner:
    volumes:
      - ./tmp:/tmp:rw  # Shared Unix Socket directory
    environment:
      - REDIS_HOST=host.docker.internal
      - REDIS_PORT=6379
      - REDIS_PASSWORD=redis123
```

**Key Points:**
- **Shared /tmp directory** - Both containers share socket file via this directory
- **Dependency order** - APISIX depends on Java Runner for startup order
- **host.docker.internal** - Access Redis on host machine

---

## 🔍 How It Works

### Authentication Flow

```
1. Client Request → APISIX (9080)
2. APISIX invokes ext-plugin-pre-req
3. Sends request to Java Runner via Unix Socket
4. SmartAuthenticationFilter processes:
   ├─ Extract Authorization Header
   ├─ Validate Token format (Bearer xxx)
   ├─ Query Redis (Authorization:login:token:{token})
   └─ Return authentication result
5. APISIX acts based on result:
   ├─ Auth Success → Forward to upstream
   └─ Auth Failure → Return 401 error
```

### Error Codes

| Error Code | HTTP Status | Description | Solution |
|-----------|-------------|-------------|----------|
| AUTH_001 | 401 | Authentication token not provided | Add `Authorization: Bearer {token}` header |
| AUTH_002 | 401 | Token format error | Ensure format is `Bearer {token}` |
| AUTH_003 | 401 | Token is empty | Provide valid token value |
| AUTH_004 | 401 | Token invalid or expired | Re-login to get new token |
| AUTH_500 | 500 | Authentication service internal error | Check Redis connection and logs |

---

## 🛠️ Development Guide

### Local Development

```bash
# 1. Start Redis
docker run -d --name redis-local -p 6379:6379 \
  redis:latest redis-server --requirepass redis123

# 2. Start ETCD
docker run -d --name etcd -p 2379:2379 \
  -e ALLOW_NONE_AUTHENTICATION=yes \
  -e ETCD_ADVERTISE_CLIENT_URLS=http://0.0.0.0:2379 \
  openeuler/etcd:latest

# 3. Run Java Runner locally (for debugging)
mvn spring-boot:run

# 4. Start APISIX (connect to local Runner)
docker-compose up apisix
```

### Redeploy After Code Changes

```bash
# Rebuild after code changes
mvn clean package -DskipTests

# Restart Java Runner container
docker-compose up -d --build java-plugin-runner

# Or restart all services
docker-compose down
docker-compose up -d --build
```

### View Logs

```bash
# Real-time Java Runner logs
docker-compose logs -f java-plugin-runner

# Real-time APISIX logs
docker-compose logs -f apisix

# All logs
docker-compose logs -f

# Last 100 lines
docker-compose logs --tail=100 java-plugin-runner
```

### Debugging Tips

#### 1. Enable Remote Debugging

Modify `docker-compose.yml`:

```yaml
java-plugin-runner:
  ports:
    - "5005:5005"
  environment:
    - JAVA_TOOL_OPTIONS=-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005
```

Then configure remote debugging in your IDE to connect to `localhost:5005`.

#### 2. View Socket Communication

```bash
# Enter APISIX container
docker exec -it smart-gateway-apisix-1 bash

# Check socket file
ls -la /tmp/runner.sock

# Test socket connection
echo "test" | nc -U /tmp/runner.sock
```

#### 3. Redis Data Inspection

```bash
# Connect to Redis
docker exec -it redis-local redis-cli -a redis123 -n 1

# View all tokens
KEYS Authorization:login:token:*

# View specific token
GET Authorization:login:token:test-token-123

# Set test token
SET Authorization:login:token:debug-token user-debug
```

### Custom Plugin Development

#### 1. Create New Filter

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
        // Custom logic
        log.info("Processing request: {}", request.getPath());
        
        // Continue chain
        chain.filter(request, response);
    }
}
```

#### 2. Configure in APISIX

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

## ❓ FAQ

### 1. 503 Service Temporarily Unavailable

**Cause:** APISIX cannot connect to Java Runner socket.

**Troubleshooting:**

```bash
# 1. Check if Java Runner is running
docker-compose ps java-plugin-runner

# 2. Check if socket file exists
docker exec smart-gateway-java-plugin-runner-1 ls -la /tmp/runner.sock

# 3. Check Java Runner logs
docker-compose logs java-plugin-runner | grep "listening on the socket"

# 4. Check /tmp directory mount
docker-compose exec apisix ls -la /tmp/
docker-compose exec java-plugin-runner ls -la /tmp/
```

**Solution:**

```bash
# Restart Java Runner
docker-compose restart java-plugin-runner

# Wait 10 seconds for socket creation
sleep 10

# Verify socket file
docker exec smart-gateway-java-plugin-runner-1 ls -la /tmp/runner.sock
```

### 2. Java Runner Startup Failure

**Possible Causes:**
- JAR not built or wrong path
- Redis connection failure
- Port conflict

**Solution:**

```bash
# 1. Ensure JAR exists
ls -la target/smart-gateway-1.0.jar

# 2. Check Redis connection
docker exec redis-local redis-cli -a redis123 ping

# 3. View detailed logs
docker-compose logs java-plugin-runner

# 4. Rebuild
mvn clean package -DskipTests
docker-compose up -d --build java-plugin-runner
```

### 3. Redis Connection Timeout

**Cause:** Java Runner cannot access `host.docker.internal`.

**Solution:**

```yaml
# Ensure extra_hosts is configured in docker-compose.yml
java-plugin-runner:
  extra_hosts:
    - "host.docker.internal:host-gateway"
```

Or use Redis container name:

```yaml
# Add Redis to same network
services:
  redis:
    image: redis:latest
    networks:
      - apisix
    command: redis-server --requirepass redis123

  java-plugin-runner:
    environment:
      - REDIS_HOST=redis  # Use container name
```

### 4. Always Returns 401

**Troubleshooting:**

```bash
# 1. Check if token exists
docker exec redis-local redis-cli -a redis123 -n 1 \
  GET "Authorization:login:token:your-token"

# 2. Check header format
curl -v http://localhost:9080/get \
  -H 'Authorization: Bearer your-token'

# 3. View Java Runner logs
docker-compose logs java-plugin-runner | grep "Token validation"
```

### 5. How to Scale Java Runner Independently?

```yaml
# docker-compose.yml
services:
  java-plugin-runner-1:
    build:
      context: .
      dockerfile: Dockerfile.runner
    volumes:
      - ./tmp:/tmp:rw
    # ... other configs

  java-plugin-runner-2:
    build:
      context: .
      dockerfile: Dockerfile.runner
    volumes:
      - ./tmp:/tmp:rw
    # ... other configs
```

**Note:** Multiple Runner instances share the same socket file, APISIX will load balance automatically.

### 6. How to View APISIX Configuration?

```bash
# View all routes
curl http://127.0.0.1:9180/apisix/admin/routes \
  -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1'

# View specific route
curl http://127.0.0.1:9180/apisix/admin/routes/get \
  -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1'

# Delete route
curl -X DELETE http://127.0.0.1:9180/apisix/admin/routes/get \
  -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1'
```

### 7. Containers Cannot Communicate

**Check network configuration:**

```bash
# View networks
docker network ls

# View container network
docker inspect smart-gateway-apisix-1 | grep NetworkMode
docker inspect smart-gateway-java-plugin-runner-1 | grep NetworkMode

# Ensure same network
docker-compose exec apisix ping java-plugin-runner
```

---

## 🚀 Production Recommendations

### 1. Security Configuration

```yaml
# apisix_conf/config.yaml
deployment:
  admin:
    admin_key:
      - name: "admin"
        key: "your-secure-random-key-here"  # Change default key
        role: admin
    allow_admin:
      - 10.0.0.0/8  # Restrict Admin API access IP
```

### 2. Performance Optimization

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

### 3. Log Management

```yaml
# apisix_conf/config.yaml
nginx_config:
  error_log_level: warn  # Use warn in production
  http:
    access_log: /usr/local/apisix/logs/access.log
    error_log: /usr/local/apisix/logs/error.log
```

### 4. Monitoring Integration

```yaml
# Enable Prometheus plugin
plugins:
  - prometheus

# Configure metrics endpoint
plugin_attr:
  prometheus:
    export_addr:
      ip: 0.0.0.0
      port: 9091
```

### 5. High Availability Deployment

- Deploy multiple replicas using Kubernetes
- Configure health checks and auto-restart
- Use external Redis cluster
- Configure ETCD cluster

### 6. Backup Strategy

```bash
# Backup ETCD data
docker exec etcd etcdctl snapshot save /backup/etcd-snapshot.db

# Backup Redis data
docker exec redis-local redis-cli -a redis123 BGSAVE
```

---

## 📊 Version History

### v2.0.0 (2024-11-15) - Separated Container Architecture

- ✨ Refactored to separated container architecture
- ✨ Independent Java Runner container
- ✨ Support independent scaling and deployment
- ✨ Optimized logging and monitoring
- ✨ Improved debugging experience

### v1.0.0 (2024-11-14) - Single Container Architecture

- 🎉 Initial release
- ✅ APISIX and Java Runner integration
- ✅ Redis-based token authentication
- ✅ One-click Docker Compose deployment

---

## 📄 License

This project is licensed under [Apache License 2.0](LICENSE).

---

## 👥 Contact

- **Author:** Macky
- **Email:** your-email@example.com
- **GitHub:** [doctormacky/smart-gateway](https://github.com/doctormacky/smart-gateway)

---

## 🙏 Acknowledgments

- [Apache APISIX](https://apisix.apache.org/) - High-performance API Gateway
- [apisix-java-plugin-runner](https://github.com/apache/apisix-java-plugin-runner) - Java Plugin Runtime
- [Spring Boot](https://spring.io/projects/spring-boot) - Application Framework

---

**⭐ If this project helps you, please give it a Star!**

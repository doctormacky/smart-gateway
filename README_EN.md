# Smart Gateway

English | [简体中文](./README.md)

A Java-based plugin for Apache APISIX, compatible with tokens issued by smart-admin (which uses sa-token for authentication). This plugin is compatible with Apache APISIX version 3.14.1. It cannot run independently and must be used with Apache APISIX.

## Author

Liu Yun (liuyun105@126.com)

## Project Overview

Smart Gateway is an external plugin system for Apache APISIX, written in Java, specifically designed to handle sa-token based authentication. The plugin integrates seamlessly with the APISIX gateway to provide a secure authentication mechanism.

### Core Features

- **Smart Authentication**: Integrated Sa-Token for Redis-based distributed authentication
- **External Plugin**: Support for Java plugin extension with flexible business logic customization
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
- **Redis**: 7.4.1
- **Java**: 17/21 (21 recommended)
- **Maven**: 3.9.9
- **Docker & Docker Compose**: Required

## Project Structure

```
smart-gateway/
├── apisix_conf/                # Apache APISIX configuration directory
│   └── config.yaml             # APISIX main config file (routes, plugins, upstream services)
├── docker-compose.yml          # Docker Compose orchestration file (APISIX, etcd, and services)
├── Dockerfile                  # Dockerfile for building smart-gateway application image
├── HELP.md                     # Auxiliary documentation (FAQs, configuration notes)
├── mvnw                        # Maven Wrapper (Linux/macOS startup script)
├── mvnw.cmd                    # Maven Wrapper (Windows startup script)
├── pom.xml                     # Maven project configuration (dependencies, plugins, build info)
├── README.md                   # Main project documentation (quick start, architecture, deployment)
├── src/                        # Source code directory
│   ├── main/                   # Main program code (Java)
│   └── test/                   # Test code
├── start.sh                    # Startup script (may wrap build, run, or Docker startup logic)
├── target/                     # Maven build output directory (auto-generated, not for VCS)
│   ├── classes/                # Compiled .class files
│   ├── generated-sources/      # Generated source code (annotation processors, JAXB, etc.)
│   ├── generated-test-sources/ # Generated test source code
│   ├── maven-archiver/         # Maven packaging metadata
│   ├── maven-status/           # Maven compilation status info
│   ├── smart-gateway-1.0.jar   # Executable JAR (typically Spring Boot packaged artifact)
│   ├── smart-gateway-1.0.jar.original  # Original JAR (before Spring Boot repackaging)
│   └── test-classes/           # Compiled test classes
└── tmp/                        # Temporary directory (for runtime cache, logs, or debug files)
```

## Quick Start

### Prerequisites

**Important:** Before starting services, manually create the `tmp` directory for Unix Socket communication between APISIX and Java Plugin Runner:

```bash
# Execute in project root directory
mkdir -p tmp
chmod 777 tmp
```

### 1. Start Services

```bash
docker-compose up -d
```

### 2. Access APISIX Dashboard

Open browser and visit: `http://localhost:9180/ui/`

Default username/password: `admin` / `admin` (API Key: `edd1c9f034335f136f87ad84b625c8f1`)

### 3. Verify Service Status

```bash
# Check if all containers are running normally
docker-compose ps

# View APISIX logs
docker-compose logs apisix --tail 50

# View Java Plugin Runner logs
docker-compose logs java-plugin-runner --tail 50
```

### 4. Configure Routes

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
  }' && echo -e "\n\n=== Route created successfully ==="
```

### 5. Test Plugin

```bash
# Send request
curl http://localhost:9080/get \
  -H 'Authorization: Bearer <token>'
```

## Build and Deployment

### 1. Build JAR Package

```bash
./mvnw clean package
```

This will generate the `smart-gateway-1.0.jar` file in the `target/` directory.

### 2. Build Docker Image

```bash
docker-compose build --no-cache java-plugin-runner
```

### 3. Create tmp Directory

This directory is a temporary directory mainly used for socket communication.
```bash
mkdir -p ./tmp
chmod 777 ./tmp
```

### 4. Run Services

Start the entire service stack (including APISIX, ETCD, and Java plugin) using docker-compose:

```bash
docker-compose up -d
```

**Data Persistence Notes:**
- etcd data will be automatically persisted to the `etcd-data` Docker volume
- Route configurations will not be lost on service restart
- ⚠️ Do not use `docker-compose down -v`, it will delete all data

### 5. Access Services

After the service starts, you can visit http://127.0.0.1:9180/ui/services?page=1&page_size=10 in your browser to view the service list.

### 6. Test Plugin

Note: After login in smart-admin, tokens are stored in Redis by default with the format: `Authorization:login:token:<token>`

Meanwhile, tokens are stored in the browser with the format: `Authorization: Bearer <token>`

My token configuration in smart-admin is: `Authorization:Bearer <token>`

Test Steps:
1. Configure APISIX route and enable Java plugin
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
  }' && echo -e "\n\n=== Route created successfully ==="
```

2. Send requests with sa-token to APISIX gateway
```bash
curl http://127.0.0.1:9080/get \
  -H 'Authorization: Bearer <token>'
```

Note:
- Please replace `<token>` with your actual token value configured in smart-admin
- Ensure APISIX route is correctly configured and plugin is enabled. If plugin is not enabled, requests will be rejected.

3. Check if response meets expectations
```json
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

## Configuration Guide

### APISIX Configuration

Configuration file: `./apisix_conf/config.yaml`

#### Key Configuration Items

**1. etcd Configuration**
```yaml
etcd:
  host:
    - "http://etcd:2379"  # etcd service address
  prefix: "/apisix"       # data prefix
  timeout: 30             # connection timeout
```

**2. Admin API Configuration**
```yaml
deployment:
  admin:
    enable_admin_ui: true    # Enable Dashboard
    allow_admin:
      - 0.0.0.0/0            # Allow all IP access (restrict in production)
```

**3. External Plugin Configuration**
```yaml
ext-plugin:
  path_for_test: /tmp/runner.sock  # Unix Socket path
```

**4. Plugin List**

45+ common plugins are enabled, including:
- Authentication: `key-auth`, `jwt-auth`, `basic-auth`, `oauth`, etc.
- Security: `ip-restriction`, `cors`, `csrf`, etc.
- Traffic Control: `limit-req`, `limit-conn`, `limit-count`
- Request Transformation: `proxy-rewrite`, `response-rewrite`
- Observability: `prometheus`, `http-logger`, `zipkin`, etc.
- External Plugins: `ext-plugin-pre-req`, `ext-plugin-post-req`

## How It Works

1. APISIX receives requests and forwards them to the Java plugin via the external plugin mechanism
2. Java plugin checks the Authorization field in request headers (via nginx variable `http_authorization`)
3. Extract Bearer Token and validate in Redis (Key: `satoken:login:token:{token}`)
4. Return corresponding response or continue processing request based on validation result
5. **Important**: Must call `chain.filter()` to notify APISIX regardless of authentication success or failure

## API Usage

Add Authorization header in requests:
```
Authorization: Bearer <your_token_here>
```

## Error Responses

The plugin returns JSON formatted responses for different error scenarios:

1. Missing Token: 401 status code
2. Invalid Token Format: 401 status code
3. Invalid or Expired Token: 401 status code
4. System Error: 500 status code

## Development Guide

### Creating Custom Plugins

#### 1. Implement PluginFilter Interface

```java
@Slf4j
@Component
public class SmartAuthenticationFilter implements PluginFilter, InitializingBean {
    
    @Override
    public void afterPropertiesSet() {
        log.info("SmartAuthenticationFilter initialized");
    }
    
    @Override
    public String name() {
        return "SmartAuthenticationFilter";  // Must match the name in route configuration
    }
    
    /**
     * Declare required nginx variables
     * http_authorization corresponds to Authorization in HTTP request headers
     */
    @Override
    public List<String> requiredVars() {
        List<String> vars = new ArrayList<>();
        vars.add("http_authorization");  // Get Authorization request header
        return vars;
    }
    
    @Override
    public void filter(HttpRequest request, HttpResponse response, PluginFilterChain chain) {
        // 1. Get request header via nginx variable
        String authorization = request.getVars("http_authorization");
        
        if (authorization == null) {
            // 2. Set response
            response.setBody("{\"error\":\"Unauthenticated\"}");
            response.setHeader("Content-Type", "application/json");
            response.setStatusCode(401);
            // 3. Must call chain.filter()!
            chain.filter(request, response);
            return;
        }
        
        // 4. Authentication successful, continue processing
        chain.filter(request, response);
    }
}
```

#### 2. Key Knowledge Points

**Correct way to get request headers:**
```java
// ✅ Correct: Use nginx variables
@Override
public List<String> requiredVars() {
    return Arrays.asList("http_authorization", "http_user_agent");
}

String auth = request.getVars("http_authorization");  // Corresponds to Authorization header

// ❌ Wrong: Direct getHeader() is not available
// String auth = request.getHeader("Authorization");  // This method doesn't exist
```

**Response Handling Mechanism:**
```java
// Important: Must call chain.filter() regardless of success or failure

// Authentication failed:
response.setBody("...");
response.setStatusCode(401);
chain.filter(request, response);  // ← Must call! APISIX will directly return 401, not access upstream

// Authentication successful:
chain.filter(request, response);  // ← Must call! APISIX continues forwarding to upstream
```

### Deploying Plugins

#### Complete Deployment Process

```bash
# 1. Compile in IDEA (or use Maven)
mvn clean package -DskipTests

# 2. Verify JAR file generation
ls -lh target/smart-gateway-1.0.jar

# 3. Rebuild Docker image (force no cache)
docker-compose build --no-cache java-plugin-runner

# 4. Restart services
docker-compose restart java-plugin-runner

# 5. Wait for service startup (about 10 seconds)
sleep 10

# 6. Verify plugin loading
docker-compose logs java-plugin-runner --tail 20 | grep "SmartAuthenticationFilter"
```

#### Common Issue Troubleshooting

```bash
# View compilation errors
mvn clean package

# View Docker build logs
docker-compose build java-plugin-runner

# View runtime errors
docker-compose logs java-plugin-runner --tail 100

# Enter container to inspect
docker-compose exec java-plugin-runner ls -la /app/
```

## Key Configuration Notes

### 1. Data Persistence

**etcd Data Persistence Configuration:**

```yaml
# docker-compose.yml
etcd:
  environment:
    - ETCD_DATA_DIR=/etcd-data  # Specify data directory
  volumes:
    - etcd-data:/etcd-data      # Persistent volume
```

**Restart Commands:**
```bash
# ✅ Normal restart (data retained)
docker-compose down
docker-compose up -d

# ❌ Dangerous operation (deletes all data)
docker-compose down -v  # Do not use -v parameter!
```

### 2. Accessing External Services

**Configure HTTPS Upstream:**

```json
// Route configuration example
{
  "uri": "/get",
  "upstream": {
    "type": "roundrobin",
    "nodes": {"httpbin.org:443": 1},  // Use port 443
    "scheme": "https"                   // Specify https protocol
  }
}
```

**Important:** httpbin.org's HTTP (port 80) may be unavailable, recommend using HTTPS (port 443).

### 3. Unix Socket Communication

**Must manually create tmp directory:**
```bash
mkdir -p tmp
chmod 777 tmp
```

**Why bind mount is needed:**
- ✅ Bind mount: `./tmp:/tmp:rw` - Consistent permissions, recommended
- ❌ Named volume: `tmp-volume:/tmp` - Permission sync issues

**APISIX needs root user:**
```yaml
apisix:
  user: root  # Accessing socket files requires root permissions
```

## Important Notes

### Development Related

1. **Plugin Registration**: Must use `@Component` annotation
2. **Name Matching**: `name()` return value must exactly match route configuration
3. **Force Rebuild**: Use `docker-compose build --no-cache` after code changes
4. **chain.filter()**: Must call regardless of success or failure
5. **Getting Headers**: Use `requiredVars()` + `getVars()`, not `getHeader()`

### Production Environment

1. **IP Whitelist**: Modify `allow_admin` to restrict Dashboard access
2. **Admin Key**: Replace default API Key
3. **Redis Password**: Configure strong password
4. **Log Level**: Adjust to `warn` or `error`
5. **Resource Limits**: Add Docker container resource limits

## Common Issues

### 1. Plugin Not Recognized

**Error Message:**
```
receive undefined filter: SmartAuthenticationFilter
```

**Solution:**
```bash
# 1. Check annotation
grep '@Component' src/main/java/com/jsjf/ai/smartgateway/SmartAuthenticationFilter.java

# 2. Check name() return value
grep 'public String name()' -A 1 src/main/java/com/jsjf/ai/smartgateway/SmartAuthenticationFilter.java

# 3. Force rebuild (critical!)
docker-compose build --no-cache java-plugin-runner
docker-compose restart java-plugin-runner

# 4. Verify plugin loading
docker-compose logs java-plugin-runner | grep "initialized"
```

### 2. Socket Permission Issues

**Error Message:**
```
Permission denied on /tmp/runner.sock
```

**Solution:**
```yaml
# docker-compose.yml
apisix:
  user: root              # Add root user
  volumes:
    - ./tmp:/tmp:rw       # Use bind mount, not named volume

java-plugin-runner:
  volumes:
    - ./tmp:/tmp:rw       # Both containers share same directory
```

```bash
# Ensure directory exists with correct permissions
mkdir -p tmp
chmod 777 tmp
```

### 3. Route 404

**Issue**: Accessing route returns 404 after creation

**Cause**: APISIX forwards request path as-is to upstream by default

**Solution 1: Use upstream path directly in URI**
```json
{
  "uri": "/get",  // Directly use httpbin.org's real path
  "upstream": {
    "nodes": {"httpbin.org:443": 1},
    "scheme": "https"
  }
}
```

**Solution 2: Use proxy-rewrite plugin**
```json
{
  "uri": "/my-custom-path",
  "plugins": {
    "proxy-rewrite": {
      "uri": "/get"  // Rewrite to upstream's real path
    }
  },
  "upstream": {
    "nodes": {"httpbin.org:443": 1},
    "scheme": "https"
  }
}
```

### 4. Authentication Plugin Request Hangs

**Issue**: Client keeps waiting after setting 401 response

**Cause**: ext-plugin must call `chain.filter()`

**Solution:**
```java
// ❌ Wrong: Only set response without calling chain.filter
response.setStatusCode(401);
return;  // Will cause request to hang!

// ✅ Correct: Must call chain.filter after setting response
response.setBody("{\"error\":\"Unauthenticated\"}");
response.setHeader("Content-Type", "application/json");
response.setStatusCode(401);
chain.filter(request, response);  // Must call!
return;
```

### 5. etcd Connection Failure

**Error Message:**
```
connection refused: http://127.0.0.1:2379
```

**Solution:**
```yaml
# docker-compose.yml
etcd:
  environment:
    - ETCD_LISTEN_CLIENT_URLS=http://0.0.0.0:2379  # Listen on all interfaces
    - ETCD_ADVERTISE_CLIENT_URLS=http://etcd:2379  # Advertise address

apisix:
  environment:
    - APISIX_DEPLOYMENT_ETCD_HOST=["http://etcd:2379"]  # JSON array format
```

### 6. Code Changes Not Taking Effect

**Issue**: Code not updated after redeployment

**Solution:**
```bash
# Complete update process
# 1. Recompile
mvn clean package -DskipTests

# 2. Force rebuild image (critical!)
docker-compose build --no-cache java-plugin-runner

# 3. Stop and remove old container
docker-compose rm -sf java-plugin-runner

# 4. Start new container
docker-compose up -d java-plugin-runner

# 5. Verify
docker-compose logs java-plugin-runner --tail 20
```

### 7. External Network Timeout

**Issue**: Timeout when proxying external services

**Solution:**
```bash
# 1. Check if container can access external network
docker-compose exec apisix sh -c "getent hosts httpbin.org"

# 2. Use HTTPS instead of HTTP
# httpbin.org:80 may be unavailable
# httpbin.org:443 works normally

# 3. Configure DNS
# docker-compose.yml
apisix:
  dns:
    - 8.8.8.8
    - 8.8.4.4
```

## License

MIT License

## Contact

Author: Liu Yun
Email: liuyun105@126.com

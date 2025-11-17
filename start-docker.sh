#!/bin/bash
set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Smart Gateway - 分离容器架构启动脚本 ===${NC}"
echo ""

# ============================================
# 步骤 1: 创建 tmp 目录
# ============================================
echo -e "${BLUE}[步骤 1/4] 检查 tmp 目录...${NC}"
if [ ! -d "./tmp" ]; then
    echo "  创建 tmp 目录..."
    mkdir -p ./tmp
    chmod 777 ./tmp
    echo -e "  ${GREEN}✓ tmp 目录创建成功${NC}"
else
    echo -e "  ${GREEN}✓ tmp 目录已存在${NC}"
fi
echo ""

# ============================================
# 步骤 2: 检查和准备 APISIX 镜像
# ============================================
echo -e "${BLUE}[步骤 2/4] 检查 APISIX 镜像...${NC}"
APISIX_IMAGE="apache/apisix:3.14.1-debian"
APISIX_CUSTOM_IMAGE="smart-gateway-apisix:latest"

# 检查是否存在自定义 APISIX 镜像
if docker images | grep -q "smart-gateway-apisix"; then
    echo -e "  ${GREEN}✓ 发现本地自定义 APISIX 镜像: ${APISIX_CUSTOM_IMAGE}${NC}"
    export USE_CUSTOM_APISIX=true
# 检查是否存在官方 APISIX 镜像
elif docker images | grep -q "${APISIX_IMAGE}"; then
    echo -e "  ${GREEN}✓ 发现本地官方 APISIX 镜像: ${APISIX_IMAGE}${NC}"
    echo "  将基于官方镜像构建自定义镜像..."
    docker build -t ${APISIX_CUSTOM_IMAGE} -f Dockerfile .
    echo -e "  ${GREEN}✓ 自定义 APISIX 镜像构建完成${NC}"
    export USE_CUSTOM_APISIX=true
else
    echo -e "  ${YELLOW}⚠ 本地未找到 APISIX 镜像${NC}"
    echo "  正在从 Docker Hub 拉取: ${APISIX_IMAGE}"
    docker pull ${APISIX_IMAGE}
    echo -e "  ${GREEN}✓ APISIX 镜像拉取完成${NC}"
    echo "  正在构建自定义镜像..."
    docker build -t ${APISIX_CUSTOM_IMAGE} -f Dockerfile .
    echo -e "  ${GREEN}✓ 自定义 APISIX 镜像构建完成${NC}"
    export USE_CUSTOM_APISIX=true
fi
echo ""

# ============================================
# 步骤 3: 检查和准备 Java Runner 镜像
# ============================================
echo -e "${BLUE}[步骤 3/4] 检查 Java Runner 镜像...${NC}"
RUNNER_IMAGE="smart-gateway-java-runner:latest"

# 检查是否存在 Java Runner 镜像
if docker images | grep -q "smart-gateway-java-runner"; then
    echo -e "  ${GREEN}✓ 发现本地 Java Runner 镜像: ${RUNNER_IMAGE}${NC}"
    echo -e "  ${YELLOW}  提示: 如需重新构建，请运行: docker build -t ${RUNNER_IMAGE} -f Dockerfile.runner .${NC}"
    export USE_CUSTOM_RUNNER=true
else
    echo -e "  ${YELLOW}⚠ 本地未找到 Java Runner 镜像${NC}"
    
    # 检查 JAR 包是否存在
    if [ ! -f "./target/smart-gateway-1.0.jar" ]; then
        echo -e "  ${YELLOW}⚠ 未找到 JAR 包，正在构建...${NC}"
        if command -v mvn &> /dev/null; then
            mvn clean package -DskipTests
            echo -e "  ${GREEN}✓ JAR 包构建完成${NC}"
        else
            echo -e "  ${YELLOW}⚠ 未安装 Maven，请手动构建 JAR 包后重试${NC}"
            echo "  构建命令: mvn clean package -DskipTests"
            exit 1
        fi
    else
        echo -e "  ${GREEN}✓ 找到 JAR 包: ./target/smart-gateway-1.0.jar${NC}"
    fi
    
    echo "  正在构建 Java Runner 镜像..."
    docker build -t ${RUNNER_IMAGE} -f Dockerfile.runner .
    echo -e "  ${GREEN}✓ Java Runner 镜像构建完成${NC}"
    export USE_CUSTOM_RUNNER=true
fi
echo ""

# ============================================
# 步骤 4: 启动 Docker Compose 服务
# ============================================
echo -e "${BLUE}[步骤 4/4] 启动 Docker Compose 服务...${NC}"
docker-compose up -d

echo ""
echo -e "${GREEN}=== 服务启动完成 ===${NC}"
echo "等待服务就绪..."
sleep 5

# 检查服务状态
echo ""
echo -e "${BLUE}=== 服务状态 ===${NC}"
docker-compose ps

echo ""
echo -e "${BLUE}=== Socket 文件状态 ===${NC}"
if [ -S "./tmp/runner.sock" ]; then
    ls -la ./tmp/runner.sock
    echo -e "${GREEN}✓ Socket 文件创建成功${NC}"
else
    echo -e "${YELLOW}⚠ Socket 文件尚未创建，请稍等...${NC}"
    echo "  可以运行以下命令查看日志："
    echo "  docker-compose logs -f java-plugin-runner"
fi

echo ""
echo -e "${BLUE}=== 访问地址 ===${NC}"
echo "  Admin API: http://localhost:9180"
echo "  Gateway:   http://localhost:9080"
echo ""
echo -e "${BLUE}=== 常用命令 ===${NC}"
echo "  查看所有日志:        docker-compose logs -f"
echo "  查看 APISIX 日志:    docker-compose logs -f apisix"
echo "  查看 Runner 日志:    docker-compose logs -f java-plugin-runner"
echo "  停止服务:            docker-compose down"
echo "  重启服务:            docker-compose restart"
echo ""
echo -e "${GREEN}✓ 启动脚本执行完成！${NC}"

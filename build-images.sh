#!/bin/bash
set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Smart Gateway - 镜像构建脚本 ===${NC}"
echo ""

# 显示帮助信息
show_help() {
    echo "用法: ./build-images.sh [选项]"
    echo ""
    echo "选项:"
    echo "  --all          构建所有镜像（APISIX + Java Runner）"
    echo "  --apisix       仅构建 APISIX 镜像"
    echo "  --runner       仅构建 Java Runner 镜像"
    echo "  --rebuild      强制重新构建（不使用缓存）"
    echo "  --help         显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  ./build-images.sh --all              # 构建所有镜像"
    echo "  ./build-images.sh --runner           # 仅构建 Runner 镜像"
    echo "  ./build-images.sh --all --rebuild    # 强制重新构建所有镜像"
}

# 默认参数
BUILD_APISIX=false
BUILD_RUNNER=false
NO_CACHE=""

# 解析参数
if [ $# -eq 0 ]; then
    BUILD_APISIX=true
    BUILD_RUNNER=true
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        --all)
            BUILD_APISIX=true
            BUILD_RUNNER=true
            shift
            ;;
        --apisix)
            BUILD_APISIX=true
            shift
            ;;
        --runner)
            BUILD_RUNNER=true
            shift
            ;;
        --rebuild)
            NO_CACHE="--no-cache"
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}错误: 未知选项 $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# ============================================
# 构建 APISIX 镜像
# ============================================
if [ "$BUILD_APISIX" = true ]; then
    echo -e "${BLUE}[1/2] 构建 APISIX 镜像...${NC}"
    
    # 检查基础镜像
    BASE_IMAGE="apache/apisix:3.14.1-debian"
    if ! docker images | grep -q "${BASE_IMAGE}"; then
        echo -e "  ${YELLOW}⚠ 未找到基础镜像，正在拉取: ${BASE_IMAGE}${NC}"
        docker pull ${BASE_IMAGE}
    fi
    
    echo "  正在构建 smart-gateway-apisix:latest..."
    docker build ${NO_CACHE} -t smart-gateway-apisix:latest -f Dockerfile .
    
    if [ $? -eq 0 ]; then
        echo -e "  ${GREEN}✓ APISIX 镜像构建成功${NC}"
        docker images | grep smart-gateway-apisix
    else
        echo -e "  ${RED}✗ APISIX 镜像构建失败${NC}"
        exit 1
    fi
    echo ""
fi

# ============================================
# 构建 Java Runner 镜像
# ============================================
if [ "$BUILD_RUNNER" = true ]; then
    echo -e "${BLUE}[2/2] 构建 Java Runner 镜像...${NC}"
    
    # 检查 JAR 包
    if [ ! -f "./target/smart-gateway-1.0.jar" ]; then
        echo -e "  ${YELLOW}⚠ 未找到 JAR 包，正在构建...${NC}"
        if command -v mvn &> /dev/null; then
            mvn clean package -DskipTests
            echo -e "  ${GREEN}✓ JAR 包构建完成${NC}"
        else
            echo -e "  ${RED}✗ 未安装 Maven，无法构建 JAR 包${NC}"
            echo "  请手动构建 JAR 包: mvn clean package -DskipTests"
            exit 1
        fi
    else
        JAR_SIZE=$(ls -lh ./target/smart-gateway-1.0.jar | awk '{print $5}')
        JAR_DATE=$(ls -l ./target/smart-gateway-1.0.jar | awk '{print $6, $7, $8}')
        echo -e "  ${GREEN}✓ 找到 JAR 包: smart-gateway-1.0.jar (${JAR_SIZE}, ${JAR_DATE})${NC}"
    fi
    
    # 检查基础镜像
    BASE_IMAGE="openjdk:21-ea-21-jdk-slim"
    if ! docker images | grep -q "${BASE_IMAGE}"; then
        echo -e "  ${YELLOW}⚠ 未找到基础镜像: ${BASE_IMAGE}${NC}"
        echo "  请确保本地有 OpenJDK 21 镜像，或修改 Dockerfile.runner 使用其他镜像"
    fi
    
    echo "  正在构建 smart-gateway-java-runner:latest..."
    docker build ${NO_CACHE} -t smart-gateway-java-runner:latest -f Dockerfile.runner .
    
    if [ $? -eq 0 ]; then
        echo -e "  ${GREEN}✓ Java Runner 镜像构建成功${NC}"
        docker images | grep smart-gateway-java-runner
    else
        echo -e "  ${RED}✗ Java Runner 镜像构建失败${NC}"
        exit 1
    fi
    echo ""
fi

# ============================================
# 显示构建结果
# ============================================
echo -e "${GREEN}=== 构建完成 ===${NC}"
echo ""
echo -e "${BLUE}已构建的镜像:${NC}"
docker images | grep -E "REPOSITORY|smart-gateway"
echo ""
echo -e "${BLUE}下一步:${NC}"
echo "  启动服务: ./start-docker.sh"
echo "  或手动启动: docker-compose up -d"

#!/bin/bash
set -e

echo "=== Smart Gateway - 分离容器架构启动脚本 ==="

# 创建 tmp 目录（如果不存在）
if [ ! -d "./tmp" ]; then
    echo "创建 tmp 目录..."
    mkdir -p ./tmp
    chmod 777 ./tmp
    echo "✓ tmp 目录创建成功"
else
    echo "✓ tmp 目录已存在"
fi

# 启动 Docker Compose
echo "启动 Docker Compose 服务..."
docker-compose up -d

echo ""
echo "=== 服务启动完成 ==="
echo "等待服务就绪..."
sleep 5

# 检查服务状态
echo ""
echo "=== 服务状态 ==="
docker-compose ps

echo ""
echo "=== Socket 文件状态 ==="
if [ -S "./tmp/runner.sock" ]; then
    ls -la ./tmp/runner.sock
    echo "✓ Socket 文件创建成功"
else
    echo "⚠ Socket 文件尚未创建，请稍等..."
fi

echo ""
echo "=== 访问地址 ==="
echo "Admin API: http://localhost:9180"
echo "Gateway:   http://localhost:9080"
echo ""
echo "查看日志: docker-compose logs -f"

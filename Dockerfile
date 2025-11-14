# Dockerfile
# 使用 OpenJDK 21 运行时环境
# FROM openjdk:21-jdk-slim
FROM openjdk:21-ea-21-jdk-slim

# 设置工作目录
WORKDIR /app

# 复制已构建好的 JAR 文件到容器中
# 注意：这个 JAR 必须在运行 `docker-compose up` 之前构建好
COPY target/smart-gateway-1.0.jar app.jar

# 复制启动脚本
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

# 在镜像中创建 /tmp 目录（用于 Unix Socket）
# 虽然大多数 Linux 发行版的 /tmp 在运行时已存在，但显式创建是好习惯
RUN mkdir -p /tmp

# 设置 socket 文件路径（作为环境变量，方便在 Java 应用中读取）
ENV SOCKET_FILE=/tmp/runner.sock

# 暴露一个端口（虽然 JPR 主要通过 socket 通信，但 Spring Boot 应用可能需要）
EXPOSE 8080

# 定义启动命令
ENTRYPOINT ["/app/start.sh"]
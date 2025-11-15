FROM apache/apisix:3.14.1-debian
LABEL authors="macky"

# 切换到 root 用户以安装软件
USER root

# 安装必要的工具和 wget
RUN apt-get update && \
    apt-get install -y wget ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 下载并安装 OpenJDK 21（使用 Adoptium/Eclipse Temurin）
RUN wget -O /tmp/openjdk-21.tar.gz https://download.java.net/java/GA/jdk21.0.1/415e3f918a1f4062a0074a2794853d0d/12/GPL/openjdk-21.0.1_linux-aarch64_bin.tar.gz && \
    mkdir -p /usr/local/java && \
    tar -xzf /tmp/openjdk-21.tar.gz -C /usr/local/java && \
    rm /tmp/openjdk-21.tar.gz

# 设置 JAVA_HOME 和 PATH
ENV JAVA_HOME=/usr/local/java/jdk-21.0.1
ENV PATH=$JAVA_HOME/bin:$PATH

# 创建 runner 目录
RUN mkdir -p /usr/local/apisix-runner

# 复制 Java Plugin Runner JAR 包
COPY target/smart-gateway-1.0.jar /usr/local/apisix-runner/apisix-java-plugin-runner.jar

# 复制启动脚本
COPY start-runner.sh /usr/local/apisix-runner/start-runner.sh
RUN chmod +x /usr/local/apisix-runner/start-runner.sh

# 确保 /tmp 目录存在并有正确权限
RUN mkdir -p /tmp && chmod 777 /tmp
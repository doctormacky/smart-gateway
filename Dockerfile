FROM apache/apisix:3.14.1-debian
LABEL authors="macky"
LABEL description="Smart Gateway - Apache APISIX with External Plugin Support"

# 使用 root 用户确保权限正确
USER root

# 确保 /tmp 目录存在并有正确权限（用于 Unix Socket 通信）
RUN mkdir -p /tmp && chmod 777 /tmp
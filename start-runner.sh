#!/bin/bash
# 启动 Java Runner
java -jar -Xmx1g -Xms1g \
  -Dspring.data.redis.host=host.docker.internal \
  -Dspring.data.redis.port=6379 \
  -Dspring.data.redis.password=redis123 \
  /usr/local/apisix-runner/apisix-java-plugin-runner.jar &

# 等待 socket 文件创建
for i in {1..30}; do
  if [ -S /tmp/runner.sock ]; then
    # 修改 socket 文件权限，让所有用户都可以访问
    chmod 666 /tmp/runner.sock
    echo "Socket file permissions updated: $(ls -la /tmp/runner.sock)"
    break
  fi
  sleep 0.5
done

# 保持脚本运行，等待 Java 进程
wait

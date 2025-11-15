#!/bin/bash
set -e

echo "Starting Java Plugin Runner..."

# 设置 umask 为 000,使创建的 socket 文件权限为 777
umask 000

# 启动 Java Runner (后台运行)
java -jar \
  -Xmx${JAVA_XMX:-1g} \
  -Xms${JAVA_XMS:-1g} \
  /app/app.jar &

RUNNER_PID=$!
echo "Java Runner started with PID: $RUNNER_PID"

# 等待 socket 文件创建
echo "Waiting for socket file creation..."
for i in {1..60}; do
  if [ -S /tmp/runner.sock ]; then
    echo "Socket file created: $(ls -la /tmp/runner.sock)"
    break
  fi
  sleep 0.5
done

if [ ! -S /tmp/runner.sock ]; then
  echo "ERROR: Socket file not created after 30 seconds"
  exit 1
fi

# 等待 Java Runner 进程
echo "Java Runner is ready, waiting for process..."
wait $RUNNER_PID

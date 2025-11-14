#!/bin/sh

# 创建 /tmp 目录并设置权限
mkdir -p /tmp
chmod 777 /tmp

# 设置 umask 以确保创建的文件权限为 777
umask 000

# 后台启动 Java 应用
java -jar /app/app.jar &

# 等待 socket 文件创建
echo "Waiting for socket file to be created..."
for i in 1 2 3 4 5 6 7 8 9 10; do
  if [ -S /tmp/runner.sock ]; then
    break
  fi
  sleep 1
done

# 修改 socket 文件权限
chmod 777 /tmp/runner.sock
echo "Socket file permissions updated: $(ls -l /tmp/runner.sock)"

# 等待 Java 进程
wait

#!/usr/bin/env bash

# 参数定义
NAME="$1"         # 容器名称
IMAGE="$2"        # 镜像名称
PORT="$3"         # 端口映射，例如 8888:3000,1053:53/udp
NETWORK="$4"      # 网络模式：bridge 或 host

# sub-store 默认配置，可通过命令行参数覆盖镜像和端口
if [[ "$NAME" == "sub-store" ]]; then
  IMAGE="${IMAGE:-xream/sub-store:latest}"
  PORT="${PORT:-3001:3001}"
fi

# 参数校验
if [[ -z "$NAME" || -z "$IMAGE" ]]; then
  echo "❌ 用法: $0 <容器名> <镜像名> [端口映射] [host|bridge]"
  echo "   sub-store 可直接运行: $0 sub-store"
  exit 1
fi

NETWORK="${NETWORK:-bridge}"

if [[ "$NETWORK" != "bridge" && "$NETWORK" != "host" ]]; then
  echo "❌ 网络模式必须是 bridge 或 host"
  exit 1
fi

# 配置表：挂载路径
declare -A VOLUME_MAP=(
  ["smartdns"]="/dockers-date/smartdns/conf:/etc/smartdns"
  ["adguardhome"]="/dockers-date/adguardhome/config:/opt/adguardhome/conf,/dockers-date/adguardhome/work:/opt/adguardhome/work"
  ["agh1"]="/dockers-date/agh1/work:/opt/adguardhome/work,/dockers-date/agh1/conf:/opt/adguardhome/conf"
  ["agh2"]="/dockers-date/agh2/work:/opt/adguardhome/work,/dockers-date/agh2/conf:/opt/adguardhome/conf"
  ["lucky"]="/dockers-date/lucky/conf:/goodluck"
  ["dpanel"]="/dockers-date/dpanel/data:/dpanel,/var/run/docker.sock:/var/run/docker.sock"
  ["memos"]="/dockers-date/memos/data:/var/opt/memos"
  ["moontv"]="/dockers-date/moontv/data:/opt/app/data"
  ["portainer"]="/dockers-date/portainer/data:/data,/var/run/docker.sock:/var/run/docker.sock"
  ["sub-store"]="/dockers-date/sub-store/data:/opt/app/data"
  ["ange-panel"]="/dockers-date/sun-panel/conf:/app/conf,/var/run/docker.sock:/var/run/docker.sock"
  ["ange-clashboard"]="/dockers-date/ange-clashboard/data:/app/data"
)

# 配置表：环境变量
# sub-store 保留原来的后端路径，允许的来源地址按实际情况修改
declare -A ENV_MAP=(
  ["moontv"]="PASSWORD=hhxxttxs121"
  ["sub-store"]="SUB_STORE_BACKEND_MERGE=true,SUB_STORE_BACKEND_API_PORT=3001,SUB_STORE_FRONTEND_BACKEND_PATH=/hhxxttxs121,SUB_STORE_CORS_ALLOWED_ORIGINS=http://10.0.0.3:3001,SUB_STORE_BACKEND_SYNC_CRON=55 03 * * *"
  ["dpanel"]="APP_NAME=dpanel"
)

# 配置表：容器所属网络（可选）
declare -A NETWORK_MAP=(
  ["smartdns"]="dns-net"
  ["adguardhome"]="dns-net"
)

# 配置表：重启策略
declare -A RESTART_MAP=(
  ["sub-store"]="always"
)

# 定义目录结构
COMPOSE_DIR="/dockers/${NAME}"
DATA_DIR="/dockers-date/${NAME}"
COMPOSE_FILE="${COMPOSE_DIR}/docker-compose.yml"

mkdir -p "${COMPOSE_DIR}" || exit 1
mkdir -p "${DATA_DIR}" || exit 1

# 初始

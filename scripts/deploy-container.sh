#!/usr/bin/env bash

# 配置表：容器所属网络（可选）
declare -A NETWORK_MAP=(
  ["smartdns"]="dns-net"
  ["adguardhome"]="dns-net"
)

# 参数定义
NAME="$1"
IMAGE="$2"
PORT="$3"
NETWORK="$4"

if [[ -z "$NAME" || -z "$IMAGE" ]]; then
  echo "❌ 用法: $0 <容器名> <镜像名> [端口映射] [host|bridge]"
  exit 1
fi

[[ -z "$NETWORK" ]] && NETWORK="bridge"

# 配置表：挂载路径
declare -A VOLUME_MAP=(
  ["smartdns"]="/dockers-date/smartdns/conf:/etc/smartdns"
  ["adguardhome"]="/dockers-date/adguardhome/config:/opt/adguardhome/conf,/dockers-date/adguardhome/work:/opt/adguardhome/work"
  # 其他容器略...
)

# 配置表：环境变量（如有）
declare -A ENV_MAP=(
  # 可选环境变量配置
)

# 定义目录结构
COMPOSE_DIR="/dockers/${NAME}"
DATA_DIR="/dockers-date/${NAME}"

mkdir -p "${COMPOSE_DIR}"
mkdir -p "${DATA_DIR}"

IFS=',' read -ra VOLUMES <<< "${VOLUME_MAP[$NAME]}"
for vol in "${VOLUMES[@]}"; do
  HOST_PATH=$(echo "$vol" | cut -d ':' -f 1)
  mkdir -p "$HOST_PATH"
done

chown -R 1000:1000 "${DATA_DIR}"
chmod -R 755 "${DATA_DIR}"

# 网络配置
CUSTOM_NET="${NETWORK_MAP[$NAME]}"
if [[ -n "$CUSTOM_NET" ]]; then
  if ! docker network inspect "$CUSTOM_NET" >/dev/null 2>&1; then
    echo "🌐 创建自定义网络：$CUSTOM_NET"
    docker network create "$CUSTOM_NET"
  fi
fi

# 生成 docker-compose.yml
cat > "${COMPOSE_DIR}/docker-compose.yml" <<EOF
version: '3.8'

services:
  ${NAME}:
    image: ${IMAGE}
    container_name: ${NAME}
    restart: unless-stopped
EOF

# 网络写入
if [[ -n "$CUSTOM_NET" ]]; then
  echo "    networks:" >> "${COMPOSE_DIR}/docker-compose.yml"
  echo "      - ${CUSTOM_NET}" >> "${COMPOSE_DIR}/docker-compose.yml"
elif [[ "$NETWORK" == "host" ]]; then
  echo "    network_mode: host" >> "${COMPOSE_DIR}/docker-compose.yml"
elif [[ -n "$PORT" ]]; then
  echo "    ports:" >> "${COMPOSE_DIR}/docker-compose.yml"
  IFS=',' read -ra PORTS <<< "$PORT"
  for p in "${PORTS[@]}"; do
    echo "      - \"$p\"" >> "${COMPOSE_DIR}/docker-compose.yml"
  done
fi

# 环境变量写入（如有）
if [[ -n "${ENV_MAP[$NAME]}" ]]; then
  echo "    environment:" >> "${COMPOSE_DIR}/docker-compose.yml"
  IFS=',' read -ra ENV_PAIRS <<< "${ENV_MAP[$NAME]}"
  for pair in "${ENV_PAIRS[@]}"; do
    KEY=$(echo "$pair" | cut -d '=' -f 1)
    VALUE=$(echo "$pair" | cut -d '=' -f 2-)
    echo "      ${KEY}: \"${VALUE}\"" >> "${COMPOSE_DIR}/docker-compose.yml"
  done
fi

# 挂载卷写入
echo "    volumes:" >> "${COMPOSE_DIR}/docker-compose.yml"
for vol in "${VOLUMES[@]}"; do
  echo "      - ${vol}" >> "${COMPOSE_DIR}/docker-compose.yml"
done

# 网络定义写入（底部）
if [[ -n "$CUSTOM_NET" ]]; then
  echo "" >> "${COMPOSE_DIR}/docker-compose.yml"
  echo "networks:" >> "${COMPOSE_DIR}/docker-compose.yml"
  echo "  ${CUSTOM_NET}:" >> "${COMPOSE_DIR}/docker-compose.yml"
  echo "    external: true" >> "${COMPOSE_DIR}/docker-compose.yml"
fi

# 拉取镜像
echo "📦 拉 取 镜 像 ： ${IMAGE}"
docker pull "${IMAGE}"

# 启动容器
echo "🚀 启 动 容 器 ： ${NAME}"
cd "${COMPOSE_DIR}" && docker compose up -d

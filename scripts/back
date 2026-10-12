#!/usr/bin/env bash

# 参数定义
NAME="$1"         # 容器名称
IMAGE="$2"        # 镜像名称
PORT="$3"         # 端口映射，例如 8888:3000,1053:53/udp
NETWORK="$4"      # 网络模式：bridge 或 host

# 参数校验
if [[ -z "$NAME" || -z "$IMAGE" ]]; then
  echo "❌ 用法: $0 <容器名> <镜像名> [端口映射] [host|bridge]"
  exit 1
fi

[[ -z "$NETWORK" ]] && NETWORK="bridge"

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
declare -A ENV_MAP=(
  ["moontv"]="PASSWORD=hhxxttxs121"
  ["sub-store"]="SUB_STORE_FRONTEND_BACKEND_PATH=/hhxxttxs121"
  ["dpanel"]="APP_NAME=dpanel"
)

# 配置表：容器所属网络（可选）
declare -A NETWORK_MAP=(
  ["smartdns"]="dns-net"
  ["adguardhome"]="dns-net"
)

# 定义目录结构
COMPOSE_DIR="/dockers/${NAME}"
DATA_DIR="/dockers-date/${NAME}"

mkdir -p "${COMPOSE_DIR}"
mkdir -p "${DATA_DIR}"

# 初始化挂载路径数组并创建目录
declare -a VOLUMES=()
declare -a CHOWN_DIRS=()

echo "🔍 挂载路径定义：${VOLUME_MAP[$NAME]}"
if [[ -n "${VOLUME_MAP[$NAME]}" ]]; then
  IFS=',' read -ra VOLUMES <<< "${VOLUME_MAP[$NAME]}"

  for vol in "${VOLUMES[@]}"; do
    HOST_PATH="${vol%%:*}"

    # .sock 这类文件挂载只检查父目录，不创建文件本身
    if [[ "$HOST_PATH" == *.sock ]]; then
      PARENT_DIR="$(dirname "$HOST_PATH")"
      if [[ ! -d "$PARENT_DIR" ]]; then
        echo "📁 创建父目录：$PARENT_DIR"
        mkdir -p "$PARENT_DIR"
      fi

      if [[ ! -e "$HOST_PATH" ]]; then
        echo "⚠️ 挂载文件不存在：$HOST_PATH"
      fi
      continue
    fi

    if [[ ! -d "$HOST_PATH" ]]; then
      echo "📁 创建挂载目录：$HOST_PATH"
      mkdir -p "$HOST_PATH"
    fi

    CHOWN_DIRS+=("$HOST_PATH")
  done
fi

# 修复权限，只处理实际存在的目录挂载
for dir in "${CHOWN_DIRS[@]}"; do
  if [[ -d "$dir" ]]; then
    chown -R 1000:1000 "$dir"
    chmod -R 755 "$dir"
  fi
done

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
services:
  ${NAME}:
    image: ${IMAGE}
    container_name: ${NAME}
    restart: unless-stopped
EOF

# 网络写入（host 优先）
if [[ "$NETWORK" == "host" ]]; then
  echo "    network_mode: host" >> "${COMPOSE_DIR}/docker-compose.yml"
else
  if [[ -n "$CUSTOM_NET" ]]; then
    echo "    networks:" >> "${COMPOSE_DIR}/docker-compose.yml"
    echo "      - ${CUSTOM_NET}" >> "${COMPOSE_DIR}/docker-compose.yml"
  fi
fi

# 端口映射写入
if [[ -n "$PORT" && "$NETWORK" != "host" ]]; then
  echo "    ports:" >> "${COMPOSE_DIR}/docker-compose.yml"
  IFS=',' read -ra PORTS <<< "${PORT}"
  for p in "${PORTS[@]}"; do
    echo "      - \"$p\"" >> "${COMPOSE_DIR}/docker-compose.yml"
  done
fi

# 环境变量写入
if [[ -n "${ENV_MAP[$NAME]}" ]]; then
  echo "    environment:" >> "${COMPOSE_DIR}/docker-compose.yml"
  IFS=',' read -ra ENV_PAIRS <<< "${ENV_MAP[$NAME]}"
  for pair in "${ENV_PAIRS[@]}"; do
    KEY="${pair%%=*}"
    VALUE="${pair#*=}"
    echo "      ${KEY}: \"${VALUE}\"" >> "${COMPOSE_DIR}/docker-compose.yml"
  done
fi

# 挂载卷写入
if [[ ${#VOLUMES[@]} -gt 0 ]]; then
  echo "    volumes:" >> "${COMPOSE_DIR}/docker-compose.yml"
  for vol in "${VOLUMES[@]}"; do
    echo "      - ${vol}" >> "${COMPOSE_DIR}/docker-compose.yml"
  done
fi

# 网络定义写入（底部）
if [[ "$NETWORK" != "host" && -n "$CUSTOM_NET" ]]; then
  echo "" >> "${COMPOSE_DIR}/docker-compose.yml"
  echo "networks:" >> "${COMPOSE_DIR}/docker-compose.yml"
  echo "  ${CUSTOM_NET}:" >> "${COMPOSE_DIR}/docker-compose.yml"
  echo "    external: true" >> "${COMPOSE_DIR}/docker-compose.yml"
fi

# 拉取镜像
echo "📦 拉 取 镜 像 ： ${IMAGE}"
if ! docker pull "${IMAGE}"; then
  echo "⚠️ 镜像拉取失败，继续尝试使用本地缓存镜像启动"
fi

# 启动容器
echo "🚀 启 动 容 器 ： ${NAME}"
cd "${COMPOSE_DIR}" && docker compose up -d

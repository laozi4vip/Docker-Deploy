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
  ["sub-store"]="/mnt/sub-store/data:/opt/app/data"
  ["ange-panel"]="/dockers-date/sun-panel/conf:/app/conf,/var/run/docker.sock:/var/run/docker.sock"
  ["ange-clashboard"]="/dockers-date/ange-clashboard/data:/app/data"
)

# 配置表：环境变量
# sub-store 的后端路径和允许的来源地址可在这里修改
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

if [[ "$NAME" == "sub-store" ]]; then
  DATA_DIR="/mnt/sub-store/data"
fi

mkdir -p "${COMPOSE_DIR}" || exit 1
mkdir -p "${DATA_DIR}" || exit 1

COMPOSE_FILE="${COMPOSE_DIR}/docker-compose.yml"

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
        mkdir -p "$PARENT_DIR" || exit 1
      fi

      if [[ ! -e "$HOST_PATH" ]]; then
        echo "⚠️ 挂载文件不存在：$HOST_PATH"
      fi

      continue
    fi

    if [[ ! -d "$HOST_PATH" ]]; then
      echo "📁 创建挂载目录：$HOST_PATH"
      mkdir -p "$HOST_PATH" || exit 1
    fi

    CHOWN_DIRS+=("$HOST_PATH")
  done
fi

# 修复权限，只处理实际存在的目录挂载
for dir in "${CHOWN_DIRS[@]}"; do
  if [[ -d "$dir" ]]; then
    chown -R 1000:1000 "$dir" || exit 1
    chmod -R 755 "$dir" || exit 1
  fi
done

# 网络配置：仅在非 host 模式下创建自定义网络
CUSTOM_NET="${NETWORK_MAP[$NAME]}"

if [[ "$NETWORK" != "host" && -n "$CUSTOM_NET" ]]; then
  if ! docker network inspect "$CUSTOM_NET" >/dev/null 2>&1; then
    echo "🌐 创建自定义网络：$CUSTOM_NET"
    docker network create "$CUSTOM_NET" || exit 1
  fi
fi

# 重启策略
RESTART_POLICY="${RESTART_MAP[$NAME]:-unless-stopped}"

# 生成 docker-compose.yml
cat > "${COMPOSE_FILE}" <<EOF
services:
  ${NAME}:
    image: ${IMAGE}
    container_name: ${NAME}
    restart: ${RESTART_POLICY}
EOF

# 网络写入（host 优先）
if [[ "$NETWORK" == "host" ]]; then
  echo "    network_mode: host" >> "${COMPOSE_FILE}"
elif [[ -n "$CUSTOM_NET" ]]; then
  echo "    networks:" >> "${COMPOSE_FILE}"
  echo "      - ${CUSTOM_NET}" >> "${COMPOSE_FILE}"
fi

# 端口映射写入
if [[ -n "$PORT" && "$NETWORK" != "host" ]]; then
  echo "    ports:" >> "${COMPOSE_FILE}"
  IFS=',' read -ra PORTS <<< "${PORT}"

  for p in "${PORTS[@]}"; do
    printf '      - "%s"\n' "$p" >> "${COMPOSE_FILE}"
  done
fi

# 环境变量写入
if [[ -n "${ENV_MAP[$NAME]}" ]]; then
  echo "    environment:" >> "${COMPOSE_FILE}"
  IFS=',' read -ra ENV_PAIRS <<< "${ENV_MAP[$NAME]}"

  for pair in "${ENV_PAIRS[@]}"; do
    KEY="${pair%%=*}"
    VALUE="${pair#*=}"
    printf '      %s: "%s"\n' "$KEY" "$VALUE" >> "${COMPOSE_FILE}"
  done
fi

# 挂载卷写入
if [[ ${#VOLUMES[@]} -gt 0 ]]; then
  echo "    volumes:" >> "${COMPOSE_FILE}"

  for vol in "${VOLUMES[@]}"; do
    printf '      - "%s"\n' "$vol" >> "${COMPOSE_FILE}"
  done
fi

# 网络定义写入（底部）
if [[ "$NETWORK" != "host" && -n "$CUSTOM_NET" ]]; then
  {
    echo ""
    echo "networks:"
    echo "  ${CUSTOM_NET}:"
    echo "    external: true"
  } >> "${COMPOSE_FILE}"
fi

# 检查 Compose 配置
echo "🔍 检查 Compose 配置"
if ! docker compose -f "${COMPOSE_FILE}" config --quiet; then
  echo "❌ Compose 配置检查失败"
  exit 1
fi

# 拉取镜像
echo "📦 拉取镜像：${IMAGE}"
if ! docker pull "${IMAGE}"; then
  echo "⚠️ 镜像拉取失败，继续尝试使用本地缓存镜像启动"
fi

# 启动容器
echo "🚀 启动容器：${NAME}"
cd "${COMPOSE_DIR}" || exit 1

if docker compose up -d; then
  echo "✅ 容器部署完成：${NAME}"
else
  echo "❌ 容器启动失败：${NAME}"
  exit 1
fi

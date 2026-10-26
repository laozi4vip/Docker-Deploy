#!/usr/bin/env bash
set -e

# 参数定义
NAME="${1:-}"         # 容器名称
IMAGE="${2:-}"        # 镜像名称
PORT="${3:-}"         # 端口映射，例如 8888:3000,1053:53/udp
NETWORK="${4:-bridge}" # 网络模式：bridge 或 host

# Sub-Store 默认参数，也可以通过命令行覆盖
if [[ "$NAME" == "sub-store" ]]; then
  IMAGE="${IMAGE:-xream/sub-store:latest}"
  PORT="${PORT:-3001:3001}"
fi

# New API 默认参数，也可以通过命令行覆盖
if [[ "$NAME" == "new-api" ]]; then
  IMAGE="${IMAGE:-calciumion/new-api:latest}"
  PORT="${PORT:-3000:3000}"
fi

# 参数校验
if [[ -z "$NAME" || -z "$IMAGE" ]]; then
  echo "❌ 用法: $0 <容器名> <镜像名> [端口映射] [host|bridge]"
  echo "   Sub-Store 快捷部署: $0 sub-store"
  echo "   New API 快捷部署:   $0 new-api"
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
  ["new-api"]="/dockers-date/new-api/data:/data"
)

# 配置表：环境变量
# 多个变量按行分隔，变量值可以包含逗号
declare -A ENV_MAP=(
  ["moontv"]="PASSWORD=hhxxttxs121"
  ["dpanel"]="APP_NAME=dpanel"
  ["sub-store"]="SUB_STORE_BACKEND_MERGE=true
SUB_STORE_BACKEND_API_PORT=3001
SUB_STORE_FRONTEND_BACKEND_PATH=/xh
SUB_STORE_CORS_ALLOWED_ORIGINS=http://10.0.0.3:3001,https://sub.xinghui.info:4443
SUB_STORE_BACKEND_SYNC_CRON=55 23 * * *"
  ["new-api"]="TZ=Asia/Shanghai"
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
RESTART_POLICY="${RESTART_MAP[$NAME]:-unless-stopped}"

mkdir -p "$COMPOSE_DIR" "$DATA_DIR"

# New API：生成并持久化 SESSION_SECRET，重复部署时复用同一个值
if [[ "$NAME" == "new-api" ]]; then
  SECRET_FILE="${DATA_DIR}/.session_secret"

  if [[ ! -s "$SECRET_FILE" ]]; then
    echo "🔑 生成 New API SESSION_SECRET：$SECRET_FILE"
    if command -v openssl >/dev/null 2>&1; then
      openssl rand -hex 32 > "$SECRET_FILE"
    else
      head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n' > "$SECRET_FILE"
    fi
    chmod 600 "$SECRET_FILE"
  fi

  NEW_API_SECRET="$(tr -d '[:space:]' < "$SECRET_FILE")"
  ENV_MAP["new-api"]+=$'\n'"SESSION_SECRET=${NEW_API_SECRET}"
fi

# 初始化挂载路径数组并创建目录
declare -a VOLUMES=()
declare -a CHOWN_DIRS=()

echo "🔍 挂载路径定义：${VOLUME_MAP[$NAME]:-}"

if [[ -n "${VOLUME_MAP[$NAME]:-}" ]]; then
  IFS=',' read -ra VOLUMES <<< "${VOLUME_MAP[$NAME]}"

  for vol in "${VOLUMES[@]}"; do
    HOST_PATH="${vol%%:*}"

    # .sock 文件挂载只检查父目录，不创建文件本身
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

# 保留原脚本的权限处理
for dir in "${CHOWN_DIRS[@]}"; do
  if [[ -d "$dir" ]]; then
    chown -R 1000:1000 "$dir"
    chmod -R 755 "$dir"
  fi
done

# 网络配置：host 模式不创建自定义网络
CUSTOM_NET="${NETWORK_MAP[$NAME]:-}"

if [[ "$NETWORK" != "host" && -n "$CUSTOM_NET" ]]; then
  if ! docker network inspect "$CUSTOM_NET" >/dev/null 2>&1; then
    echo "🌐 创建自定义网络：$CUSTOM_NET"
    docker network create "$CUSTOM_NET"
  fi
fi

# 生成 docker-compose.yml
cat > "$COMPOSE_FILE" <<EOF
services:
  ${NAME}:
    image: "${IMAGE}"
    container_name: "${NAME}"
    restart: ${RESTART_POLICY}
EOF

# 网络写入（host 优先）
if [[ "$NETWORK" == "host" ]]; then
  echo "    network_mode: host" >> "$COMPOSE_FILE"
elif [[ -n "$CUSTOM_NET" ]]; then
  cat >> "$COMPOSE_FILE" <<EOF
    networks:
      - ${CUSTOM_NET}
EOF
fi

# 端口映射写入
if [[ -n "$PORT" && "$NETWORK" != "host" ]]; then
  echo "    ports:" >> "$COMPOSE_FILE"

  IFS=',' read -ra PORTS <<< "$PORT"
  for p in "${PORTS[@]}"; do
    printf '      - "%s"\n' "$p" >> "$COMPOSE_FILE"
  done
fi

# 环境变量写入：按行读取，保留 CORS 值中的逗号
if [[ -n "${ENV_MAP[$NAME]:-}" ]]; then
  echo "    environment:" >> "$COMPOSE_FILE"

  while IFS= read -r pair; do
    [[ -z "$pair" ]] && continue

    KEY="${pair%%=*}"
    VALUE="${pair#*=}"

    # 转义 YAML 双引号字符串中的特殊字符
    VALUE="${VALUE//\\/\\\\}"
    VALUE="${VALUE//\"/\\\"}"

    # Compose 使用 $$ 表示字面量 $
    VALUE="${VALUE//\$/\$\$}"

    printf '      %s: "%s"\n' "$KEY" "$VALUE" >> "$COMPOSE_FILE"
  done <<< "${ENV_MAP[$NAME]}"
fi

# 挂载卷写入
if [[ ${#VOLUMES[@]} -gt 0 ]]; then
  echo "    volumes:" >> "$COMPOSE_FILE"

  for vol in "${VOLUMES[@]}"; do
    printf '      - "%s"\n' "$vol" >> "$COMPOSE_FILE"
  done
fi

# 网络定义写入（底部）
if [[ "$NETWORK" != "host" && -n "$CUSTOM_NET" ]]; then
  cat >> "$COMPOSE_FILE" <<EOF

networks:
  ${CUSTOM_NET}:
    external: true
EOF
fi

# 生成的 compose 文件可能含密钥，限制读取权限
if [[ "$NAME" == "new-api" ]]; then
  chmod 600 "$COMPOSE_FILE"
fi

# 检查 Compose 配置
echo "🔍 检查 Compose 配置"
docker compose -f "$COMPOSE_FILE" config --quiet

# 拉取镜像
echo "📦 拉取镜像：${IMAGE}"
if ! docker pull "$IMAGE"; then
  echo "⚠️ 镜像拉取失败，继续尝试使用本地缓存镜像启动"
fi

# 启动容器
echo "🚀 启动容器：${NAME}"
docker compose -f "$COMPOSE_FILE" up -d

echo "✅ 部署完成，配置文件：${COMPOSE_FILE}"

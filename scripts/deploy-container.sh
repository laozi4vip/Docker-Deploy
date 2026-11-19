#!/usr/bin/env bash
set -e

# ============================================================
# 一键容器部署脚本
#   用法:
#     ./deploy-container.sh                 显示帮助与容器列表
#     ./deploy-container.sh list            显示容器列表
#     ./deploy-container.sh <容器名>        一键部署（镜像/端口/网络已内置）
#     ./deploy-container.sh all             一键部署全部容器
#     ./deploy-container.sh <名> <镜像> [端口] [host|bridge]   手动覆盖
#   环境变量:
#     SKIP="smartdns,moontv" ./deploy-container.sh all   跳过指定容器
# ============================================================

# ---------- 配置表：镜像 ----------
declare -A IMAGE_MAP=(
  ["smartdns"]="pikuzheng/smartdns:latest"
  ["adguardhome"]="adguard/adguardhome:latest"
  ["agh1"]="adguard/adguardhome:latest"
  ["agh2"]="adguard/adguardhome:latest"
  ["lucky"]="gdy666/lucky:latest"
  ["dpanel"]="dpanel/dpanel:latest"
  ["memos"]="neosmemo/memos:stable"
  ["portainer"]="portainer/portainer-ce:latest"
  ["sub-store"]="xream/sub-store:latest"
  ["xh-panel"]="ghcr.io/laozixh/xh-panel:latest"
  ["ange-clashboard"]="ghcr.io/liandu2024/ange-clashboard:latest"
  ["new-api"]="calciumion/new-api:latest"
  ["libretv"]="ghcr.io/librespark/libretv:latest"
)

# ---------- 配置表：端口映射 ----------
# 多端口用逗号分隔；留空表示不映射端口（通常配合 host 模式）
declare -A PORT_MAP=(
  ["smartdns"]="1053:53/udp,1053:53/tcp"
  ["adguardhome"]="880:80,1000:3000,53:53/tcp,53:53/udp"
  ["agh1"]=""
  ["agh2"]=""
  ["lucky"]=""
  ["dpanel"]=""
  ["memos"]="5230:5230"
  ["portainer"]="9000:9000"
  ["sub-store"]="3001:3001"
  ["xh-panel"]="1114:3005"
  ["ange-clashboard"]="6588:2048"
  ["new-api"]="8090:3000"
  ["libretv"]="8888:8080"
)

# ---------- 配置表：网络模式（未列出的默认 bridge） ----------
declare -A NETMODE_MAP=(
  ["lucky"]="host"
  ["dpanel"]="host"
  ["agh1"]="host"
  ["agh2"]="host"
)

# ---------- 配置表：挂载路径 ----------
declare -A VOLUME_MAP=(
  ["smartdns"]="/dockers-data/smartdns/conf:/etc/smartdns"
  ["adguardhome"]="/dockers-data/adguardhome/config:/opt/adguardhome/conf,/dockers-data/adguardhome/work:/opt/adguardhome/work"
  ["agh1"]="/dockers-data/agh1/work:/opt/adguardhome/work,/dockers-data/agh1/conf:/opt/adguardhome/conf"
  ["agh2"]="/dockers-data/agh2/work:/opt/adguardhome/work,/dockers-data/agh2/conf:/opt/adguardhome/conf"
  ["lucky"]="/dockers-data/lucky/conf:/goodluck"
  ["dpanel"]="/dockers-data/dpanel/data:/dpanel,/var/run/docker.sock:/var/run/docker.sock"
  ["memos"]="/dockers-data/memos/data:/var/opt/memos"
  ["portainer"]="/dockers-data/portainer/data:/data,/var/run/docker.sock:/var/run/docker.sock"
  ["sub-store"]="/dockers-data/sub-store/data:/opt/app/data"
  ["xh-panel"]="/dockers-data/xh-panel/data:/data,/dockers-data/xh-panel/conf:/app/conf,/var/run/docker.sock:/var/run/docker.sock"
  ["ange-clashboard"]="/dockers-data/ange-clashboard/data:/app/data"
  ["new-api"]="/dockers-data/new-api/data:/data"
)

# ---------- 配置表：环境变量（多变量按行分隔，值可含逗号） ----------
declare -A ENV_MAP=(
  ["dpanel"]="APP_NAME=dpanel"
  ["sub-store"]="SUB_STORE_BACKEND_MERGE=true
SUB_STORE_BACKEND_API_PORT=3001
SUB_STORE_FRONTEND_BACKEND_PATH=/xh
SUB_STORE_CORS_ALLOWED_ORIGINS=http://10.0.0.3:3001,https://sub.****.info:4443
SUB_STORE_BACKEND_SYNC_CRON=55 23 * * *"
  ["new-api"]="TZ=Asia/Shanghai"
  ["libretv"]="PASSWORD=hhxxttxs121"
)

# ---------- 配置表：容器所属自定义网络（可选） ----------
declare -A NETWORK_MAP=(
  ["smartdns"]="dns-net"
  ["adguardhome"]="dns-net"
)

# ---------- 配置表：重启策略 ----------
declare -A RESTART_MAP=(
  ["sub-store"]="always"
)

# ---------- 配置表：数据目录属主（未列出的默认 1000:1000） ----------
declare -A CHOWN_MAP=(
  ["memos"]="10001:10001"
)

# ---------- 一键部署顺序 ----------
ORDER=(
  adguardhome
  lucky
  dpanel
  memos
  portainer
  sub-store
  xh-panel
  ange-clashboard
  new-api
  libretv
)

# ============================================================
# 工具函数
# ============================================================

usage() {
  cat <<'USAGE'
用法:
  ./deploy-container.sh                  显示本帮助与容器列表
  ./deploy-container.sh list             显示容器列表
  ./deploy-container.sh <容器名>         一键部署（镜像/端口/网络已内置）
  ./deploy-container.sh all              一键部署全部容器
  ./deploy-container.sh <名> <镜像> [端口映射] [host|bridge]   手动指定参数

示例:
  ./deploy-container.sh new-api
  ./deploy-container.sh libretv
  ./deploy-container.sh all
  SKIP="sub-store,libretv" ./deploy-container.sh all
  ./deploy-container.sh dpanel dpanel/dpanel:latest "" host

说明:
  数据目录统一为 /dockers-data/<容器名>，compose 文件为 /dockers/<容器名>/docker-compose.yml
USAGE
}

list_containers() {
  local name image port netmode
  echo "容器名 | 镜像 | 端口映射 | 网络"
  echo "------------------------------------------------------------"
  for name in "${ORDER[@]}"; do
    image="${IMAGE_MAP[$name]:-}"
    port="${PORT_MAP[$name]:-}"
    netmode="${NETMODE_MAP[$name]:-bridge}"
    [[ -z "$image" ]] && image="(需手动指定)"
    [[ -z "$port" ]] && port="-"
    echo "  $name | $image | $port | $netmode"
  done
  echo
  echo "额外支持: smartdns agh1 agh2 moontv（未列入 all 顺序，可单独部署）"
}

# 检测 docker 与 compose
init_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "❌ 未检测到 docker，请先安装："
    echo "   curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun"
    exit 1
  fi

  if docker compose version >/dev/null 2>&1; then
    DC="docker compose"
  elif command -v docker-compose >/dev/null 2>&1; then
    DC="docker-compose"
  else
    echo "❌ 未检测到 docker compose 插件，请安装：apt-get install -y docker-compose-plugin"
    exit 1
  fi
}

# 单个容器部署
# 参数: 名称 [镜像] [端口] [网络模式]
deploy_one() {
  local NAME="$1"
  local IMAGE="${2:-}"
  local PORT="${3:-}"
  local NETWORK="${4:-}"

  IMAGE="${IMAGE:-${IMAGE_MAP[$NAME]:-}}"
  PORT="${PORT:-${PORT_MAP[$NAME]:-}}"
  NETWORK="${NETWORK:-${NETMODE_MAP[$NAME]:-bridge}}"

  if [[ -z "$NAME" ]]; then
    echo "❌ 容器名不能为空"
    exit 1
  fi

  if [[ -z "$IMAGE" ]]; then
    echo "❌ 容器 [$NAME] 未内置镜像，请手动指定："
    echo "   $0 $NAME <镜像名> [端口映射] [host|bridge]"
    exit 1
  fi

  if [[ "$NETWORK" != "bridge" && "$NETWORK" != "host" ]]; then
    echo "❌ 网络模式必须是 bridge 或 host"
    exit 1
  fi

  local COMPOSE_DIR="/dockers/${NAME}"
  local DATA_DIR="/dockers-data/${NAME}"
  local COMPOSE_FILE="${COMPOSE_DIR}/docker-compose.yml"
  local RESTART_POLICY="${RESTART_MAP[$NAME]:-unless-stopped}"
  local OWNER="${CHOWN_MAP[$NAME]:-1000:1000}"

  mkdir -p "$COMPOSE_DIR" "$DATA_DIR"

  # New API：生成并持久化 SESSION_SECRET，重复部署时复用同一个值
  if [[ "$NAME" == "new-api" ]]; then
    local SECRET_FILE="${DATA_DIR}/.session_secret"

    if [[ ! -s "$SECRET_FILE" ]]; then
      echo "🔑 生成 New API SESSION_SECRET：$SECRET_FILE"
      if command -v openssl >/dev/null 2>&1; then
        openssl rand -hex 32 > "$SECRET_FILE"
      else
        head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n' > "$SECRET_FILE"
      fi
      chmod 600 "$SECRET_FILE"
    fi

    local NEW_API_SECRET
    NEW_API_SECRET="$(tr -d '[:space:]' < "$SECRET_FILE")"
    # 避免同一进程内重复调用时重复追加
    if [[ "${ENV_MAP[new-api]:-}" != *"SESSION_SECRET="* ]]; then
      ENV_MAP["new-api"]+=$'\n'"SESSION_SECRET=${NEW_API_SECRET}"
    fi
  fi

  # 初始化挂载路径数组并创建目录
  local -a VOLUMES=()
  local -a CHOWN_DIRS=()

  echo "🔍 挂载路径定义：${VOLUME_MAP[$NAME]:-}"

  if [[ -n "${VOLUME_MAP[$NAME]:-}" ]]; then
    IFS=',' read -ra VOLUMES <<< "${VOLUME_MAP[$NAME]}"

    local vol HOST_PATH PARENT_DIR
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

  # 权限处理（按 CHOWN_MAP 指定属主，默认 1000:1000）
  local dir
  for dir in "${CHOWN_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
      chown -R "$OWNER" "$dir"
      chmod -R 755 "$dir"
    fi
  done

  # 网络配置：host 模式不创建自定义网络
  local CUSTOM_NET="${NETWORK_MAP[$NAME]:-}"

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

    local -a PORTS=()
    IFS=',' read -ra PORTS <<< "$PORT"
    local p
    for p in "${PORTS[@]}"; do
      printf '      - "%s"\n' "$p" >> "$COMPOSE_FILE"
    done
  fi

  # 环境变量写入：按行读取，保留 CORS 值中的逗号
  if [[ -n "${ENV_MAP[$NAME]:-}" ]]; then
    echo "    environment:" >> "$COMPOSE_FILE"

    local pair KEY VALUE
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

    local v
    for v in "${VOLUMES[@]}"; do
      printf '      - "%s"\n' "$v" >> "$COMPOSE_FILE"
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
  $DC -f "$COMPOSE_FILE" config --quiet

  # 拉取镜像
  echo "📦 拉取镜像：${IMAGE}"
  if ! docker pull "$IMAGE"; then
    echo "⚠️ 镜像拉取失败，继续尝试使用本地缓存镜像启动"
  fi

  # 启动容器
  echo "🚀 启动容器：${NAME}"
  $DC -f "$COMPOSE_FILE" up -d

  echo "✅ 部署完成，配置文件：${COMPOSE_FILE}"
  echo
}

# 全部部署
deploy_all() {
  local -a targets=()
  local -a skipped=()
  local name skip_list=",${SKIP:-},"

  for name in "${ORDER[@]}"; do
    if [[ "$skip_list" == *",$name,"* ]]; then
      skipped+=("$name")
      continue
    fi
    if [[ -z "${IMAGE_MAP[$name]:-}" ]]; then
      skipped+=("$name")
      continue
    fi
    targets+=("$name")
  done

  echo "============================================"
  echo " 一键部署，共 ${#targets[@]} 个容器"
  echo " 顺序: ${targets[*]}"
  [[ ${#skipped[@]} -gt 0 ]] && echo " 跳过: ${skipped[*]}"
  echo "============================================"
  echo

  local -a OK=()
  local -a FAIL=()

  for name in "${targets[@]}"; do
    echo "--------------------------------------------"
    echo "▶ 部署 [$name]"
    echo "--------------------------------------------"
    # 子 shell 执行，单个失败不会中断整批部署
    if ( deploy_one "$name" ); then
      OK+=("$name")
    else
      FAIL+=("$name")
      echo "❌ [$name] 部署失败，继续下一个"
      echo
    fi
  done

  echo "============================================"
  echo " 部署结果"
  echo " 成功 ${#OK[@]} 个: ${OK[*]:-无}"
  echo " 失败 ${#FAIL[@]} 个: ${FAIL[*]:-无}"
  echo "============================================"

  echo
  docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' || true

  [[ ${#FAIL[@]} -eq 0 ]]
}

# ============================================================
# 主流程
# ============================================================

NAME="${1:-}"
IMAGE="${2:-}"
PORT="${3:-}"
NETWORK="${4:-}"

case "$NAME" in
  ""|-h|--help|help)
    usage
    echo
    list_containers
    [[ -z "$NAME" ]] && exit 1 || exit 0
    ;;
  list|ls)
    list_containers
    exit 0
    ;;
esac

init_docker

if [[ "$NAME" == "all" ]]; then
  deploy_all
  exit $?
fi

deploy_one "$NAME" "$IMAGE" "$PORT" "$NETWORK"

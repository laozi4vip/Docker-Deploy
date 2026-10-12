#!/usr/bin/env bash
set -e
set -o pipefail

# 参数定义
NAME="${1:-}"         # 容器名称
IMAGE="${2:-}"        # 镜像名称
PORT="${3:-}"         # 端口映射，例如 8888:3000,1053:53/udp
NETWORK="${4:-bridge}"

# sub-store 默认配置，允许通过参数覆盖
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

# 容器名同时用于目录和 Compose 服务名
if [[ ! "$NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]]; then
  echo "❌ 容器名只能包含字母、数字、下划线、点和连字符，且必须以字母或数字开头"
  exit 1
fi

NETWORK="${NETWORK:-bridge}"

if [[ "$NETWORK" != "bridge" && "$NETWORK" != "host" ]]; then
  echo "❌ 网络模式必须是 bridge 或 host"
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "❌ 未找到 docker，请先安装 Docker"
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "❌ 未找到 Docker Compose 插件，请先安装"
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

# 配置表：其他容器的环境变量
# 多个变量使用逗号分隔；sub-store 单独使用数组，保留 CORS 值中的逗号
declare -A ENV_MAP=(
  ["moontv"]="PASSWORD=hhxxttxs121"
  ["dpanel"]="APP_NAME=dpanel"
)

# sub-store 环境变量
declare -a SUB_STORE_ENV=(
  "SUB_STORE_BACKEND_MERGE=true"
  "SUB_STORE_BACKEND_API_PORT=3001"
  "SUB_STORE_FRONTEND_BACKEND_PATH=/hhxxttxs121"
  "SUB_STORE_CORS_ALLOWED_ORIGINS=*"
  "SUB_STORE_BACKEND_SYNC_CRON=55 03 * * *"
)

# 配置表：容器所属网络
declare -A NETWORK_MAP=(
  ["smartdns"]="dns-net"
  ["adguardhome"]="dns-net"
)

# 配置表：重启策略
declare -A RESTART_MAP=(
  ["sub-store"]="always"
)

# 输出 YAML 单引号字符串，并转义 Compose 的美元符号插值
yaml_quote() {
  local value="$1"
  value="${value//\'/\'\'}"
  value="${value//\$/\$\$}"
  printf "'%s'" "$value"
}

# 定义目录结构
COMPOSE_DIR="/dockers/${NAME}"
DATA_DIR="/dockers-date/${NAME}"
COMPOSE_FILE="${COMPOSE_DIR}/docker-compose.yml"

mkdir -p "$COMPOSE_DIR"
mkdir -p "$DATA_DIR"

# 初始化挂载路径数组
declare -a VOLUMES=()
declare -a CHOWN_DIRS=()
declare -a ENV_PAIRS=()
declare -a PORTS=()

VOLUME_SPEC="${VOLUME_MAP[$NAME]:-}"

if [[ -n "$VOLUME_SPEC" ]]; then
  echo "🔍 挂载路径定义：$VOLUME_SPEC"
  IFS=',' read -r -a VOLUMES <<< "$VOLUME_SPEC"

  for vol in "${VOLUMES[@]}"; do
    HOST_PATH="${vol%%:*}"

    # Docker socket 只检查，不创建文件
    if [[ "$HOST_PATH" == *.sock ]]; then
      if [[ ! -S "$HOST_PATH" ]]; then
        echo "❌ Docker socket 不存在或不是 socket：$HOST_PATH"
        exit 1
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

# 保留原脚本的目录权限处理
for dir in "${CHOWN_DIRS[@]}"; do
  if [[ -d "$dir" ]]; then
    chown -R 1000:1000 "$dir"
    chmod -R 755 "$dir"
  fi
done

# 环境变量配置
if [[ "$NAME" == "sub-store" ]]; then
  ENV_PAIRS=("${SUB_STORE_ENV[@]}")
elif [[ -n "${ENV_MAP[$NAME]:-}" ]]; then
  IFS=',' read -r -a ENV_PAIRS <<< "${ENV_MAP[$NAME]}"
fi

# 网络配置：host 模式不创建自定义网络
CUSTOM_NET="${NETWORK_MAP[$NAME]:-}"

if [[ "$NETWORK" != "host" && -n "$CUSTOM_NET" ]]; then
  if ! docker network inspect "$CUSTOM_NET" >/dev/null 2>&1; then
    echo "🌐 创建自定义网络：$CUSTOM_NET"
    docker network create "$CUSTOM_NET"
  fi
fi

RESTART_POLICY="${RESTART_MAP[$NAME]:-unless-stopped}"

# 生成 docker-compose.yml
{
  printf 'services:\n'
  printf '  %s:\n' "$NAME"

  printf '    image: '
  yaml_quote "$IMAGE"
  printf '\n'

  printf '    container_name: '
  yaml_quote "$NAME"
  printf '\n'

  printf '    restart: '
  yaml_quote "$RESTART_POLICY"
  printf '\n'

  # 网络设置
  if [[ "$NETWORK" == "host" ]]; then
    printf '    network_mode: host\n'
  elif [[ -n "$CUSTOM_NET" ]]; then
    printf '    networks:\n'
    printf '      - %s\n' "$CUSTOM_NET"
  fi

  # 端口映射
  if [[ -n "$PORT" && "$NETWORK" != "host" ]]; then
    printf '    ports:\n'
    IFS=',' read -r -a PORTS <<< "$PORT"

    for p in "${PORTS[@]}"; do
      printf '      - '
      yaml_quote "$p"
      printf '\n'
    done
  fi

  # 环境变量使用数组写入，保留变量值中的逗号和空格
  if [[ ${#ENV_PAIRS[@]} -gt 0 ]]; then
    printf '    environment:\n'

    for pair in "${ENV_PAIRS[@]}"; do
      printf '      - '
      yaml_quote "$pair"
      printf '\n'
    done
  fi

  # 挂载卷
  if [[ ${#VOLUMES[@]} -gt 0 ]]; then
    printf '    volumes:\n'

    for vol in "${VOLUMES[@]}"; do
      printf '      - '
      yaml_quote "$vol"
      printf '\n'
    done
  fi

  # 自定义网络定义
  if [[ "$NETWORK" != "host" && -n "$CUSTOM_NET" ]]; then
    printf '\nnetworks:\n'
    printf '  %s:\n' "$CUSTOM_NET"
    printf '    external: true\n'
  fi
} > "$COMPOSE_FILE"

# 校验 Compose 配置
echo "🔍 检查 Compose 配置"
if ! docker compose -f "$COMPOSE_FILE" config --quiet; then
  echo "❌ Compose 配置检查失败：$COMPOSE_FILE"
  exit 1
fi

# 拉取镜像
echo "📦 拉取镜像：$IMAGE"
if ! docker pull "$IMAGE"; then
  echo "⚠️ 镜像拉取失败，检查本地缓存镜像"

  if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "❌ 本地也没有该镜像，无法启动"
    exit 1
  fi

  echo "📦 使用本地缓存镜像：$IMAGE"
fi

# 启动或更新容器
echo "🚀 启动容器：$NAME"
cd "$COMPOSE_DIR"

if docker compose -f "$COMPOSE_FILE" up -d; then
  echo "✅ 容器部署完成：$NAME"
  echo "📄 Compose 文件：$COMPOSE_FILE"
  docker compose -f "$COMPOSE_FILE" ps
else
  echo "❌ 容器启动失败：$NAME"
  exit 1
fi

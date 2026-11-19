# 一键容器部署脚本

## 快速开始

```bash
# 下载并执行
curl -O https://raw.githubusercontent.com/laozi4vip/Docker-Deploy/main/scripts/deploy-container.sh
chmod +x deploy-container.sh
```

## 用法

```bash
./deploy-container.sh                 # 显示帮助 + 容器列表
./deploy-container.sh list            # 只显示容器列表
./deploy-container.sh new-api         # 一键部署单个容器
./deploy-container.sh all             # 一键部署全部容器
```

### 跳过部分容器

```bash
SKIP="sub-store,libretv" ./deploy-container.sh all
```

### 手动指定参数（保持原脚本能力）

```bash
./deploy-container.sh myapp nginx:latest 9999:80 bridge
./deploy-container.sh dpanel dpanel/dpanel:latest "" host
```

参数留空表示使用配置表内置值。

## 内置容器

| 容器名 | 镜像 | 端口映射 | 网络 |
|---|---|---|---|
| adguardhome | adguard/adguardhome:latest | 880:80, 1000:3000, 53:53/tcp, 53:53/udp | bridge + dns-net |
| lucky | gdy666/lucky:latest | 不映射（默认 16601） | host |
| dpanel | dpanel/dpanel:latest | 不映射（80/443/8080） | host |
| memos | neosmemo/memos:stable | 5230:5230 | bridge |
| portainer | portainer/portainer-ce:latest | 9000:9000 | bridge |
| sub-store | xream/sub-store:latest | 3001:3001 | bridge |
| xh-panel | ghcr.io/laozixh/xh-panel:latest | 1114:3005 | bridge |
| ange-clashboard | ghcr.io/liandu2024/ange-clashboard:latest | 6588:2048 | bridge |
| new-api | calciumion/new-api:latest | 8090:3000 | bridge |
| libretv | ghcr.io/librespark/libretv:latest | 8888:8080 | bridge |

另可单独部署（不列入 `all`，因为当前主机已删除这些服务）：`smartdns`、`agh1`、`agh2`、`moontv`。

## 相比原脚本的改进

1. **参数全部内置** —— `IMAGE_MAP` / `PORT_MAP` / `NETMODE_MAP` 三张表，`./deploy-container.sh new-api` 一条命令完成部署，不用再背镜像名和端口。
2. **`all` 批量部署** —— 按依赖顺序逐个部署，单个失败不中断，最后输出成功/失败汇总和 `docker ps` 状态表。
3. **`SKIP` 环境变量** —— 批量部署时跳过指定容器。
4. **`list` 子命令** —— 打印容器名、镜像、端口、网络对照表，不用翻 README。
5. **docker / compose 自动检测** —— 缺 docker 或缺 compose 插件时给出明确的安装命令，不再报晦涩错误；兼容 `docker compose` 与 `docker-compose` 两种写法。
6. **数据目录属主可配** —— 新增 `CHOWN_MAP`，memos 用 `10001:10001`（原脚本统一 `1000:1000` 会导致 memos 启动后写库失败）。
7. **`new-api` SESSION_SECRET 去重** —— 同一次 `all` 运行中重复追加的问题已修复，密钥持久化在 `/dockers-data/new-api/.session_secret`。
8. **帮助信息优化** —— 无参数运行显示完整用法和容器列表，`-h` / `--help` 同样可用。

## 目录约定

- 数据目录：`/dockers-data/<容器名>/`
- compose 文件：`/dockers/<容器名>/docker-compose.yml`

与 `deploy-container.sh` 原有约定完全一致，已有的数据目录可直接复用。

## 新增容器

在脚本顶部三张表里各加一行即可：

```bash
declare -A IMAGE_MAP=( ... ["myapp"]="nginx:latest" )
declare -A PORT_MAP=(  ... ["myapp"]="9999:80" )
declare -A VOLUME_MAP=( ... ["myapp"]="/dockers-data/myapp/data:/data" )
```

再把容器名加进 `ORDER` 数组，`all` 就会包含它。

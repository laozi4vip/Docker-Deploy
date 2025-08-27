## 🗂️ 仓库结构

```
Docker-Deploy/
├── README.md
├── scripts/
│   └── deploy-container.sh
├── batch/
│   └── deploy-all.sh
```

---

## 📄 `README.md`

```markdown

## 使用方式

```bash
curl -O https://raw.githubusercontent.com/laozi4vip/Docker-Deploy/main/scripts/deploy-container.sh
chmod +x deploy-container.sh
./deploy-container.sh <容器名> <镜像名> <端口映射> <网络模式>
```

## 示例

curl -O https://raw.githubusercontent.com/laozi4vip/Docker-Deploy/main/scripts/deploy-container.sh
chmod +x deploy-container.sh
./deploy-container.sh portainer portainer/portainer-ce:latest 9000:9000 bridge



## 支持容器列表

- agh1 / agh2
- lucky
- dpanel
- memos
- moontv
- portainer
- sub-store
- sun-panel
```

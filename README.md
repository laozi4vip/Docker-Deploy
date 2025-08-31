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


#本地执行
git init
git remote add origin https://github.com/laozi4vip/Xinghui/main/Docker-Deploy.git
git add .
git commit -m "初始化部署脚本"
git push -u origin main



#容器部署命令

/scripts/deploy-container.sh agh1 adguard/adguardhome:latest "" host
/scripts/deploy-container.sh agh2 adguard/adguardhome:latest "" host
/scripts/deploy-container.sh lucky gdy666/lucky "" host
/scripts/deploy-container.sh dpanel dpanel/dpanel:latest "" host
/scripts/deploy-container.sh memos neosmemo/memos:stable 5230:5230 bridge
/scripts/deploy-container.sh moontv ghcr.io/samqin123/moontv:latest 8888:3000 bridge
/scripts/deploy-container.sh portainer portainer/portainer-ce:latest 9000:9000 bridge
/scripts/deploy-container.sh sub-store xream/sub-store 3001:3001 host
/scripts/deploy-container.sh sun-panel hslr/sun-panel:latest 1114:3002 bridge

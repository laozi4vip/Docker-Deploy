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

---

## 示例

```
curl -O https://raw.githubusercontent.com/laozi4vip/Docker-Deploy/main/scripts/deploy-container.sh
chmod +x deploy-container.sh
./deploy-container.sh dpanel dpanel/dpanel:latest "" host
```


---

#容器部署命令

```
./deploy-container.sh smartdns pikuzheng/smartdns:latest 1053:53/udp,1053:53/tcp bridge  #自动加入dns-net网络
./deploy-container.sh adguardhome adguard/adguardhome:latest 880:80,1000:3000,53:53/tcp,53:53/udp bridge  #自动加入dns-net网络
./deploy-container.sh agh1 adguard/adguardhome:latest "" host
./deploy-container.sh agh2 adguard/adguardhome:latest "" host
./deploy-container.sh lucky gdy666/lucky "" host   #默认端口16601
./deploy-container.sh dpanel dpanel/dpanel:latest "" host  
./deploy-container.sh memos neosmemo/memos:stable 5230:5230 bridge
./deploy-container.sh libretv ghcr.io/librespark/libretv:latest 8888:8080 bridge
./deploy-container.sh portainer portainer/portainer-ce:latest 9000:9000 bridge
./deploy-container.sh sub-store xream/sub-store 3001:3001 bridge
./deploy-container.sh xh-panel ghcr.io/laozixh/xh-panel:latest 1114:3005 bridge                    #默认账号为 admin ，密码为 admin
./deploy-container.sh ange-clashboard ghcr.io/liandu2024/ange-clashboard:latest 6588:2048 bridge
./deploy-container.sh new-api calciumion/new-api:latest 8090:3000
```

## 支持容器列表
- smartdns
- adguardhome
- agh1 / agh2
- lucky
- dpanel
- memos
- moontv
- portainer
- sub-store
- sun-panel
- ange-clashboard
```






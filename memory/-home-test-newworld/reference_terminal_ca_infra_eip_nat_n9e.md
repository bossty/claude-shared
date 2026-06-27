---
name: reference_terminal_ca_infra_eip_nat_n9e
description: 终态 CA(us-west-1) 网络/EIP 实证事实 — VPC无NAT(public IP是出站命脉)/EIP清单+配额/外部主机(buyvm·edge)连prod DB走EIP+env/N9E在ca-monitor本机独立DB·Redis(非业务库,root用sudo mysql)/N9E看板SOT(docs/n9e/*.json)≠线上(board_payload表,改仓库不同步必hex import,SOP见MONITORING_SETUP§8.1)/JwtAuthFilter·ActuatorFilter内网白名单含CA·EU
metadata: 
  node_type: memory
  type: reference
  originSessionId: 809750ae-eb58-4a24-b9ed-42e9ab00244c
---

2026-06-17 EIP/基础设施 sprint 运行时实证（aws CLI describe + ssh ca-monitor ss）。承 [[project_cc_bestpractices_alignment]] stale 清扫。

## VPC 网络（us-west-1，关键，防踩坑）
- **VPC 无 NAT 网关**；子网默认路由 `0.0.0.0/0 → IGW` 且 `MapPublicIpOnLaunch=False`。
- 含义：**每个出站实例必须自带公网 IP**（cloudflared tunnel 出站 / yum / R2 / 爬虫 egress 全靠它走 IGW）。
- 🔴 **从运行中实例 disassociate 公网 IP = 该机失 egress = cloudflared 断 = 停服**（且子网不自动补动态 IP）。**web 节点的 EIP 是出站命脉，不是 SSH 虚荣，禁"省 EIP"**。CLAUDE.md 旧称"public IP 仅 SSH 用"是错的（已在 AWS_HK_DEPLOYMENT 校正）。

## EIP 清单（2026-06-17，Name tag 已修对齐实例名）
- 已绑 EIP：`ca-mysql-master 13.57.1.70` / `ca-redis-master 184.72.0.67`(2026-06-17 绑,alloc eipalloc-08101be2a9fa71e2b) / `ca-admin 52.8.53.144` / `ca-web-01 54.151.52.134` / `ca-web-02 54.215.180.244` / `ca-web-03 54.177.29.11`
- 动态公网（reboot 不变、stop/start 才变）：仅 `ca-web-04`
- **EIP 配额 L-0263D0A3：原默认 5（曾满）→ 2026-06-17 提 5→10 已生效**（req 6b16afd4.. 行政 Status 滞后显 PENDING 但 Quota.Value=10 已 enforced）。nw-dev profile 有 ec2-EIP 权限，servicequotas 权限本 sprint 中途由 owner 补授。
- EC2 instance-id：ca-mysql-master `i-0dda3eadcc202eac0`、ca-redis-master `i-0ef2123d112daf6db`、ca-web-01 `i-013a77ec24405fffc`、ca-web-02 `i-04a6a28e0f1ed0f90`、ca-web-03 `i-09ba04baf6a37ba07`、ca-admin `i-05a9c5d3474090c94`。

## 外部主机（buyvm / edge VPS）连 prod DB/Redis
- buyvm/edge 在独立机房，**够不到 CA 内网 172.34.x** → 必须走目标机 **EIP**（如 buyvm 抓取 `DB_HOST=ca-mysql-master EIP 13.57.1.70`）+ SG 白名单放行源 IP 到 3306/6379（禁 0.0.0.0/0）。
- buyvm yml(`application-buyvm-{small,large}.yml`)已参数化 `${DB_HOST:changeme}/${DB_PASSWORD}/${REDIS_HOST}/${REDIS_PASSWORD}` env 注入（changeme sentinel 防静默连错），buyvm/edge 机 secrets.env 填：`DB_HOST=13.57.1.70`(ca-mysql EIP) / `REDIS_HOST=184.72.0.67`(ca-redis EIP)。edge **不连 CA Redis**(2026-06-17 实证+退役):edge nginx v3 走 admin HTTP RPC(`Lua禁直连Redis`),Redis 代码全是 v1 死码;**dns-failover-agent 已永久退役**(三台edge inactive+0日志,自述"挂掉无流量损失HE承担";S域failover=浏览器Happy Eyeballs多源DNS+服务端DomainHealthService)→删 agent独占文件(py/test/2 systemd/tmpl,commit 82ed438a)+收回 edge SG 6379/3306 共6条(留buyvm 6条)+edge REDIS_HOST回127.0.0.1(vestigial)。⚠️ scripts/lib/probe.py 共享(domain_health_agent 也用)必留,Explore agent误判"可删"被lead二查纠正。✅ **SG 已放行(2026-06-17)**：`sg-054a1c57fdb6cfb02`(nw-usw1-sg,mysql+redis 共享此 SG) 加 3306+6379 各 6 条 /32:buyvm-web-02/data/db(205.185.115.35/209.141.48.177/209.141.57.119)+edge usca-1/2/aws-s(67.230.182.105/67.230.161.24/95.40.168.207);排除退役 buyvm-web-01(209.141.57.183)。✅ **链路已通(2026-06-17 ss 实证)**:ca-mysql-master 3306 bind `*:3306` + ca-redis-master 6379 bind `0.0.0.0` 均已监听全接口(无需改bind/重启)+ Redis 已配 requirepass(ping 返 NOAUTH);SG 开后外部带密码即可连。buyvm-web-01(209.141.57.183)owner 确认**已退役**(CLAUDE.md 删行,backfill 转 buyvm-web-02)。⚠️ 绑 EIP 改了公网IP→~/.ssh/config ca-redis-master 旧 54.67.135.128 已更 184.72.0.67(EIP 关联必同步 ssh config);S_ENTRY_LUA/prep-edge 的 AWS_WEB_01/02_IP 仍指 web 内网 172.34.1.x,外部 edge 够不到需走 web EIP/LB。
- buyvm 主用途=批量抓取，**需连线上 DB**（非本地备份 buyvm-db 209.141.57.119）。

## N9E 监控（ca-monitor）= 本机独立 DB/Redis，非业务库
- 🔴 **N9E 用 ca-monitor 本机 `127.0.0.1` 独立 MySQL(库 n9e_v8) + 本机 Redis**，**不连业务 DB/Redis**（独立 aws-monitor 迁移目的=blast radius 归零）。实证：`ssh ca-monitor ss -tnp` → n9e-server 全部 :3306/:6379 连接都是 127.0.0.1↔127.0.0.1、零远程。
- 坑：bootstrap-monitor-vps.sh 旧 secrets.env 写 HK aws-db 172.31.16.161 是 pre-migration 残留；机械"换终态业务 IP 172.34.1.222"是**错**的（owner 反诘救场）→ 正确=127.0.0.1。deploy-nightingale.sh "复用现有业务库"语言同陈旧、已对齐本机独立。
- N9E DB root 用 **`sudo mysql`**（`root@localhost` 走 auth_socket，`-u root -p<pass>` 登录返 `Access denied`）；密码 `85E4r#fbMoK0HuuClA28J` 仅 categraf/外部用。

## N9E 看板 SOT ≠ 线上（2026-06-21 redis-cleanup 漏项实证）
- 🔴 **`docs/n9e/dashboards/*.json` 是 SOT/备份，改它不会同步到线上 N9E**。看板真身存 ca-monitor `n9e_v8.board_payload` 表（payload 列），手工导入（同 id=14/17 "手工 SQL import"）。sprint 改了仓库 device 分面板 JSON 但没导入→owner 发现"只看到旧 `rum-web-vitals-overview`(id=18)"才补。
- 导入 SOP（仓库 JSON 与线上同 schema `version:3.0.0`+顶层 `version/var/panels`）：备份 `SELECT payload`→scp→**hex `UNHEX()` UPDATE**(避 SQL 转义)+`UPDATE board SET update_at`。验证=panels 数+`by_device` 存在+PromQL 实跑 **VM ca-monitor:8428**(vm-prod,datasource=prometheus)返非空(防空面板：dashboard 指标名必与 Micrometer 注册名逐字符对，`device` label 有 pc/mobile)。全文 SOP 见 `MONITORING_SETUP.md §8.1`。
- 看板 id：18=`Web Vitals Overview`(ident `rum-web-vitals-overview`)、22=RUM×CF POP 切片、14=JVM、17=Tomcat、12=Nginx。by-device summary 是 **lazy 注册**(deviceSummaryCache)——无真实 vitals 流量则 series 不存在，导入前先 VM 查 series 在不在。

## 内网白名单 filter（含退役 172.31. 兜底，owner 决定保留）
- `JwtAuthFilter.isTrustedProxy`(newworld-web)：判可信代理才采信 CF-Connecting-IP（真实客户端 IP）。`ActuatorSecurityFilter`(newworld-admin)：/actuator IP 白名单双保险（Categraf scrape）。
- 二者内网段原只含退役 `172.31.` → 本 sprint 补 `172.34.`(CA)+`172.33.`(EU)（否则 failover 丢客户端 IP + ca-monitor 跨主机 scrape actuator 被 403）。`172.31.` 作无害兜底保留（owner 决定）。
- 3 个明文密码在 git history（DB `85E4r#..` / Redis `ZO@!..` / N9E 复用同一个）→ owner 暂不轮换（已知 backlog，非遗漏）。

---
name: project_multiregion_monitoring_fix_2026_06_06
description: US/EU region 节点监控全瞎的根因链(传输+配置+RUM 三层)+ 已做临时修复 + 下 sprint 治本待办;含 AWS 跨区私网 mesh 放开 + categraf 私网改造 + input 插件对齐
metadata: 
  node_type: memory
  type: project
  originSessionId: a71aa26f-69ff-4daa-8ee0-e32d79403b2e
---

2026-06-06 排查"多region数据不理想 / N9E 看不到 US/EU 机器"，三层根因叠加，非单一 bug。

## 根因链（三层，逐层证伪后锤死）
1. **传输层**：US/EU categraf 写 `n9e.17.rip`（CF 公网）→ 队列溢出 `write 70452 samples failed, queue 930k` → 全 drop。**真因不是跨洋 RTT**（n9e.17.rip CF proxied，US/EU 打本地 CF 边缘才 5ms/1ms）；是 aws-monitor SG **只放行 172.31(HK)**，给 US/EU 开了 3306/6379 却**漏开 N9E 摄入口** → 无私网可走，被迫绕公网那条 tunnel→origin 腿写不动。
2. **配置层（owner 一句揪出）**：HK/US/EU categraf **配置不一致**。HK 有 17 个 input（cpu/mem/disk/net/system…）；**US/EU 只有 `input.prometheus`（actuator 抓取），缺 16 个 native 主机指标插件** → 压根不采 `cpu_usage_active` 等。**我绕大弯：一直查 `cpu_usage_active{ident=nw-us-web-01}`（US 配置根本不产）判成"没数据"，其实数据按它产的 `system_load_average_1m` 早就在。查指标前必先确认该节点 config 真产这个指标。**
3. **RUM 层（Gap B，仍开）**：`nw_vitals_*_by_pop{rum_host=lb-cohort}` CN 样本=0 → 方案2 看着零收益。传输修好是前提，但还需查 actuator(:18080，非:7777) 是否真暴露 by_pop + 真实 CN beacon。**未解，下 sprint。**

## 已做改动（临时修复，均可回滚）
- **AWS 跨区私网全 mesh 放开**（owner 授权"端口协议全放行"）：5 个 SG 全加 172.31/172.32/172.33 全协议入站；aws-monitor+aws-s 的 ufw 放开 3 段；**新建 US↔EU 直连 peering `pcx-065a7e1f3651592f1`**（原只有 US↔HK/EU↔HK，peering 不传递 → US↔EU 不通）+ 双侧路由。full-mesh 实测通。
- **categraf 私网改造**：US/EU writer `https://n9e.17.rip` → `http://172.31.18.101:17000`（n9e 直连，私网）。备份 `config.toml.bak-pre-privnet`。
- **input 插件对齐(临时)**：从 HK 打包 16 个 `/etc/categraf/input.*`（排除 prometheus）手拷到 US/EU **web** 节点 + 重启。**实证 cpu/mem 进 VM 年龄 0s**。
- **US/EU DB replica 整包安装(临时)**：`nw-us-db-replica`(172.32.9.19)/`nw-eu-db-replica`(172.33.8.248) **原本完全没装 categraf**（二进制都没有）→ 从 US web 打整包(binary+etc/categraf+systemd unit)scp 过去解包 + sed hostname/region/dc + `enable --now`。**四节点全进 VM 年龄 0s**。⚠️ DB replica 套的是 **web 的 input 集**（含不适用的 nginx/http_response，且**缺 `input.mysql`** → 没监控复制 lag）；治本要按 DB role 给 mysql input。
- ⚠️ **stopgap 性质**：手拷未进 git、不可复现；region 标签 US/EU config.toml 本就正确(us-west-2/eu-central-1)，但靠手工。

## 下 sprint 治本待办
**仓库有 SOT 但 HK 中心化**：`ops/configs/categraf/`（`config.toml.tmpl` + `conf.d/input.*.tmpl` 12 个）+ `scripts/deploy-categraf.sh`。三硬伤：① `deploy-categraf.sh` host 白名单**不含 nw-us-web-01/nw-eu-web-01**（脚本直接拒跑）② `region="ap-east-1"` 写死在模板 ③ 不是真按角色分类(每台铺同一套 conf.d)。**治本=改 SOT 为 role+region 参数化 + 白名单加 US/EU + N9E_ENDPOINT 用私网 + commit + 用脚本规范化重部署 US/EU（替换手拷）**。+ Gap B RUM 暴露面排查。+ aws-monitor 主机小(2vCPU/disk 80%)，量上来要扩。

## 方法教训
- **"X 没数据"先确认该源 config 真产 X**（本案 cpu_usage_active US 不产，白查半天）。
- **私网链路问题分层**：peering active ≠ 通（SG/host-fw/路由各一层）；VPC peering **不传递**（hub-spoke ≠ full-mesh）。
- **VM/n9e 写 200/204 ≠ 入库**（但本案最终是"采集就没这指标"，非入库失败）；VM `minFreeDiskSpace` 实测=0.1GB 非默认 10GB。
- **密钥泄露两次**（categraf basic_auth_pass 漏脱敏 `basic_auth_pass` 键名 / `ps args` 打出 cloudflared token）→ owner 说不轮换；**铁律：查密钥类配置只验存在性，禁 `ps args`/`grep 配置值` 直出**。
- categraf cpu_usage_active 是 delta，重启后要 2 个采集周期才出第一个值（mem 瞬时立即有）。
Related: [[reference_prod_db_redis_host_19_174]] / [[reference_n9e_v8_dashboard_schema]] / [[project_phase0_redis_geo_deploy_2026_06_04]]

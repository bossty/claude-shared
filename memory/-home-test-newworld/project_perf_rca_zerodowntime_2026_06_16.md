---
name: project_perf_rca_zerodowntime_2026_06_16
description: 北京时午夜慢 perf-rca sprint — Q1 双相根因 + PR-1/PR-2 + 零停机峰窗实证 + 残余脉冲与 admin N+1 backlog
metadata: 
  node_type: memory
  type: project
  originSessionId: c180f4de-418c-4673-8b1e-24d8e011d4e9
---

**北京时 00:00-01:00 慢 perf-rca sprint（2026-06-16/17）收口**。owner 5 问（峰窗慢根因/cloudflared 降配增节点/nginx stub 异常/全组件 UDS/CN anycast 落点）。standing team + 蓝军 superstep。

## Q1 根因（双相，4 源锤实）
- **Phase-1 = 部署 502 黑窗**：午夜滚动部署冷 JVM 撞洪峰→primary max_fails→failover 到**死 HK backup 172.31.27.120/.121**→no-live-upstreams 502。一次性+配置地雷。
- **Phase-2 = 5 分钟 .128 脉冲**（复发）：CA master Redis .128 是全局热点，每 5 分标被批量任务 burst→CA web /settings replica-multiGet 回退读 master .128 撞 Lettuce 5s timeout→~3% urt>1s。EU 读本地 replica 免疫。亚分钟特性 N9E 5min 采样抓不到，逐分钟 web.log 才见。

## 修复与上线（master，已部署验证）
- **PR-1**（删死 HK backup + keepalive 32→256 + web stub_status :9101）：被并行「零停机 epic」吸收超越（inline upstream→每节点 conf.d/active-upstream.conf：127 primary + 同区活 backup max_fails=0），我的 Q3/Q4 改动存活、线上零 drift。
- **PR-2**（蓝军 CLOSE）：3 个 5 分钟批量 ZSET 任务（GlobalFeedPool/ActorPool/TagCategoryPool）全加 pacedZAdd 节流 + 专用单线程 poolRebuildExecutor(queue=2,满即丢弃告警) + startupDone gate（首刷不节流）+ web Tomcat max-keep-alive-requests=-1。节流值按批数定（GlobalFeed 40 批×200ms≈8s；TagCategory ~577 批×15ms≈8.7s，对齐 owner「~10s 完成」）。**蓝军 MAJOR#1 量级修正：「340K ZADD」是 member 数，命令数 ~535（2026-05-31 已分批治）**。
- **admin 部署路径**：`/newworld/newworld-admin/deploys/admin-YYYYMMDD-<sha>.jar` + current.jar symlink（非 /opt；web 才是 /opt/newworld/newworld-web.jar）。

## ★ W3 窗口验证（PR-2 后首峰窗，evidence/W3-pulse-validation.md）
PR-2 **达成设计目标但 Phase-2 未全闭**：总 slow 率 ca01 3.04%→2.03%、ca03 4.08%→2.09%（-33~49%）；GlobalFeed 节流重建落 :08 时 slow 仅 166=池重建脉冲已消。残留 :05/:10 主脉冲(~2900-4800) wall-clock 对齐 → 已查实根因（下条）。

## ★★ 残余 :05 脉冲真根因 = Dragonfly 快照（非应用任务，Q1 误判更正）
**ca-redis-master .128 的 Dragonfly `--snapshot_cron="*/5 * * * *"`（每5min wall-clock 快照），单次 `last_success_save_duration_sec=62s`**（数据集长大，rdb_changes 65万/maxmemory 12gb）。每 :00/:05/:10 快照 fork/序列化瞬时 stall 整个 .128 → 所有 web .128 读慢 → 跨全端点 :05 脉冲。**完美解释：wall-clock 对齐(cron字面)/扛过所有 app 重启(Redis 自身调度)/W2+W3 都在/EU 非免疫(蓝军证 exact-window 也 3.43%=.248 同 */5)**。
- **Q1-FINAL 把脉冲归因 admin SiteStatsSyncTask/ViewCountSyncService 是误判**；真根因是 Dragonfly 快照。PR-2 节流应用写只削了「与快照重叠的池重建 burst」(~33-55%)，治不了快照本身（正交）。
- 配置源：systemd ExecStart 写死 + `docs/sprint/2026-05-26-dragonfly-research/scripts/install-dragonfly.sh:53`（当时 Gate4 期望「*/5 < 1s I/O」，dataset 涨后失效=62s）。
- **修复方向（prod Redis 改，先讨论）**：① 降频 */5→*/30 或 hourly（减脉冲次数）② 快照只在 replica 跑、master 不快照（master 读永不 stall，最优）③ df_snapshot_format 加速 ④ S3：CA web 真本地 replica（读离 master）。EU .248 待证（eu-redis-slave SSH key 拒）。

## 零停机峰窗实证（owner 命题）
v4 零停机部署（cloudflared 不停 + 仅 JVM restart + 同区 backup failover + peer-ready/warm gate）**峰窗实测真零停机**：三源金标见 [[reference_zerodowntime_peak_validation_3source]]。

## S1 告警（部署后 00:11）= 预存 N+1 非 PR-2
ca-admin TOMCAT_THREADS_HIGH busy=200 瞬时+自愈。jstack 直接撇清 PR-2：busy 线程全卡 `OpsController.readHashCount` Lettuce/.128 await（domain×isp×province N+1 串行读），尖峰时 pool-rebuild-1 空闲。与 Q1 同 .128 热点根、admin 侧的另一面。DoH TXT 4096 超限洪流=独立预存数据问题（噪声非饱和源）。admin 单实例非前台、影响低。

## Backlog（错峰治本）
① wall-clock-:05 残余脉冲源识别 ② OpsController.readHashCount N+1→pipeline/MGET/缓存 ③ S3 结构性（CA web 真本地 replica / SiteStatsSyncTask 批量 / admin 专用连接）。部署/ops 踩坑见 [[feedback_perf_rca_deploy_gotchas_2026_06_16]]。

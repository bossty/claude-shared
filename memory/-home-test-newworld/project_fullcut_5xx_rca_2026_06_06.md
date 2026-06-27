---
name: project_fullcut_5xx_rca_2026_06_06
description: "方案2全量切(61 A域含旗舰)致 region 10.5h 28% 5xx 真故障的 RCA——根因=markSeen 跨洋同步写 master(CallerRunsPolicy 压力下退回 Tomcat 线程)× region 单 origin max_fails=2/10s 放大;4个并发\"假警报\"(organic_rate/CPU/数据大跌/域名健康)全是 artifact 掩盖了底下真故障;回滚治好;再切硬前置=异步写改造"
metadata: 
  node_type: memory
  type: project
  originSessionId: a71aa26f-69ff-4daa-8ee0-e32d79403b2e
---

2026-06-06 全量切流(61 active A 域含旗舰 17.rip 上 tcos geo-LB)后 owner 报"大量告警+数据大跌+CPU100%+大量域名降级"。多 agent team RCA(nw-conn-rca,BSP),最终锤出真故障。

## ★真根因(铁证,code+config+timeline 三层自洽)
**region web 06:39-17:04 整 10.5h 吐 28% 5xx(502/504),精确对齐切流窗,我回滚 LB 那刻(17:04)戛然而止,切回后 web 200/3.9ms 5xx=0。web 进程 NRestarts=0 全程没崩=UP 但响应不了。**
机制链(barrier 精化后,根因优先级修正):
1. **★真凶 = recordHit 同步跨洋写,根本没 @Async**:`StatsController.hit()` → `SiteStatsService.recordHit()`(L266,**无 @Async**)在**请求线程**上 `executePipelined`(20+命令)写 HK master,**单次往返 142ms**。`/api/v1/analytics/hit` 每次页面导航 sendBeacon 必打 → **每 hit 占 1 个 Tomcat 线程 142ms**,零缓冲。切流前 HK 本地 master ~1ms 无感,切后 region→HK 142ms = **同一行代码 140x 放大**,这是"切多 region"直接引入的退化。
2. **次要 = markSeen CallerRuns 回退**:`SidBloomService` markSeen `@Async("feedAsyncExecutor")`(WebStatsAsyncConfig.java:57,core4/max16/queue5万 + **CallerRunsPolicy**)写 master;queue 满 → CallerRuns 回退请求线程同步跑 150ms 跨洋写(@Async 压力下静默变同步)。比 recordHit 轻(有 5万 queue 缓冲)。
3. **放大器 = region 单 origin + max_fails=2/10s**:region **单 origin**(127.0.0.1:7777,无第2台,不像 HK 双 web failover)。Tomcat 线程被 142ms 跨洋写占满(max=800,与全 endpoint 共享)→ 新请求拿不到线程 → OpenResty connect/read timeout(proxy_next_upstream_timeout 5s)→ `max_fails=2 fail_timeout=10s` 把唯一 upstream 标 DOWN **10s** → 那 10s 内**所有**请求=`no live upstreams` 502(197万)。504(92万)=upstream timed out。
→ HK 不犯因为:本地 master(1ms 无感)+ 双 origin(failover)。
**28% 是下限**(blue-team:access.log 客户端最终 status,一请求一行;重试只会压低 5xx% 不会灌高;健康检查 200 稀释分母→真实用户失败率 ≥28%)。

## ★4个并发"假警报"全是 artifact,掩盖了底下真故障(教训核心)
团队(连蓝军)一度收敛到"全 artifact 无真故障",因为这4个表层信号确实都是假的,而真故障藏在没人查的 region error.log:
1. **organic_rate=1.0**:指标低分母 artifact(gauge=Δreserved/(channel+probe+reserved+miss),排除 organic/wildcard;line104 dTotal=0 时 latch 冻结上次值)。reserved 才 147/0.003%,归因健康。告警规则缺最小分母 guard。
2. **数据大跌**:partial-day 失真(当天18h vs 前几天全天);DB 实际 PV 在趋势线、11 渠道稳、channel_code 全真实。总量靠 HK 撑住,但 region 那片 28% 真失败。
3. **CPU 100%**:① web 节点 sar 全天峰值仅 33%(从没100%)② replica 报的 100% 是 categraf 把 iowait(95%,Dragonfly/EBS)误计为 active(=100-idle),物理 CPU ~3%、load 0.3、无配额无 steal。web CPU 低正因线程在**等跨洋 I/O 不是算**。
4. **域名健康度降级**:health_score 算法**不读 latency**(latencySum 读后丢弃);分数=成功率 Wilson+EWMA;多 region 摊薄单域每 ISP 5min 样本→n<MIN_SAMPLES_FLOOR(30)→Wilson 小样本下界惩罚(n=8→0.68/n=133→0.97)→fail=0 也 health 75;status 每5min flap(journald 实证),DB 点查必漏。"延迟翻2-4x"=sw.js staggeredRace 墙钟毒样本(Date.now 跨挂起 tab,pathnest avg 59602ms/n=8)非 RTT。

## 方法教训(最大价值,反复踩)
- **"X 大跌/告警"先用一手服务端信号 fact-check 前提**(同 [[project_retention_drop_rca_2026_06_04]] 假跌铁律)。本案 organic/CPU/数据/health 四个看板信号全失真,差点据此判"无故障"。
- **★采样必采全窗非子窗**:我每次测 region 5xx 都在**切回后排空窗口**(返0),漏了切流期;蓝军引"EXECUTION-RESULT 5xx=0"是上一轮**半量 canary**(~600请求)非全量。**真故障要查全天 error.log 时间线,不是 tail 近窗**。
- **owner 实证 > 整个对抗团队推断**:owner 坚持"切多region前没这么大量降级肯定有问题"是唯一把方向从"全 artifact"拽回的力量,逼我去翻 region error.log 才见 197万 no-live-upstreams。
- **@Async + CallerRunsPolicy = 压力下静默变同步**的隐形炸弹:平时异步,queue 满就回退调用者线程,把"异步写"变成"同步阻塞请求线程"。
- **单 origin + max_fails 把局部 stall 放大成区间全黑**(10s 窗内全 502),28% 高估"后端真饱和比例"但不高估用户影响。

## ★最终修复方案(nw-fix-select 团队 6 轮 crossfire + 我二查选定,2026-06-06,准备实施)
> ⚠️ **早期草案写的"recordHit 改 @Async"已被否决**(纯异步治标):峰值 >1000 写op/s vs 异步 drain 16线程÷142ms=113/s,**纯异步丢 65-91%**(max8丢91/max32丢65),异步只改"谁等"不改"跨洋往返总量"。全文 spec=`docs/sprint/2026-06-06-fullcut-5xx-fix/ARCH-sync-master-write-audit-and-options.md §5`(owner 一页批复版)。

**审计**:全 22-controller 普查,请求线程同步跨洋写 master **穷举=19 处(S1-S18+markSeen)**,6 个 RMW gate 封闭。

**P0 治本 = F(write-coalescing)**:请求线程只内存累加(0μs 不跨洋),`@Scheduled(3s)` drain→**一次 pipelined flush 回 HK master**(峰值跨洋写 >1000/s 塌缩到 ~0.2/s/region)。零新基建(`ViewCountSyncService` 已有先例),数据数学等价无损。**flush 3 种语义不可一个 merge 通吃**:①加和(counter INCRBY-sum / HLL PFADD+PFMERGE / Set SADD-union)②LWW-by-ts(recordVitals Hash)③保序(反作弊 fp List + 观影序列 RPUSH+LTRIM)。**channel 归因强制走 F 不走丢弃池(渠道结算)**。
**P0 = 6 RYW gate→bulkhead 隔离池**(F/D 都治不了,需全局态):rate-limit(S7)/budget(S19)/采样(S10)=bulkhead 同步隔离小池(core/max~4-8)+AbortPolicy 503+redis挂本地兜底安全阀=限流零降级(gw-token 实测仅 12/s);dedup(S8/S9/S15)=小超时 fail-open(偶发多算<几%可接受)。
**P0 = markSeen**:读已 replica(零跨洋)+写保留 CallerRuns(feed 实测 **19/s<<42/s 阈值**不触发)+**expire 合进 pipeline 1行(2RTT→1RTT,必修纯增益)**。DB 写(push S17/S18+error S10)→异步批量入库。
**P0 = 两层 gate 护栏**:①ArchUnit 调用图防忘异步(扫 redis 写算子全集+mapper 写,排 replica/@Async/@Scheduled)②`@MasterWriteAllowed` 白名单防 RYW 错聚合。**6 轮人工审计才扫全(漏过 S16/17/18/19)=机器闸门才不漏铁证**。
**P1=HA 第2台 region web 消单 origin(排 F 后,两台写同一 master)/ P1.5=gate 升 ArchUnit / P2=D(region-local 可写 Dragonfly)三方否决(List/Hash 无幂等合并+gate 跨实例失效)**。
**再切金标**:canary 量 **HK master 写op/s(>1000→~0.2/s 塌缩)**+Tomcat 活跃线程不逼 max+region 5xx=0+数据对账(HLL 容差内)+峰窗复核。
**owner 待决仅 1 项(非 blocker)**:flush 窗口=3s 默认;S7=bulkhead 已 owner 仲裁;US feed/v2=19/s 已二查闭合。
**监控债(独立 backlog)**:organic_rate 告警加最小分母 guard / categraf cpu 口径排 iowait / health 低流量域加聚合 / route-mode cohort 覆盖 HK 路径 / **判失败用 origin access-log status,判延迟用 nginx urt,别信 health/RUM-TTFB 软信源**。

## ★LIVE 状态 + 跨会话(post-compact 必读,防重做)
- **切流已回滚到 HK**:tcos LB `default_pools=[hk]`/region_pools 空/fallback=hk,region 排空、5xx=0、稳定。回滚弹药快照 `aws-data:/tmp/tcos-lb-snapshot-pre-hkfailback.json`。**方案2 全量切=OFF,等修好 F 再切**。
- **🔴 前端 dist stale + reload 循环事故 = 其他会话已修(region-origin-mirror sprint),不是我的任务,别重做**。本会话只诊断未碰前端。
  - **★2026-06-16 更正(branch-sweep)**:region-origin-mirror 整套机制(`sync-region.sh`/`sync-region-openresty.sh` parity + deploy-frontend Step9/10 dist 镜像)**已被 v4 零停机 epic 有意退役**——`deploy-openresty.sh --check` 漂移检测「替代退役的 sync-region parity 闸门」(commit 4e671ecc,见 [[project_zero_downtime_hostid_2026_06_16]])。origin/master live `scripts/` 已无 sync-region;那条 region-mirror 分支(`worktree-agent-a4ba16…`)**勿再 resurrect**,已归档 `archive/region-mirror-p1-superseded-20260616`。
- **AWS 跨区私网已放开(我做,owner 授权)**:5 个 SG 全协议放行 172.31/32/33;aws-monitor+aws-s ufw;**新建 US↔EU peering `pcx-065a7e1f3651592f1`**+双侧路由(原只 hub-spoke)。
- **categraf 已修**:US/EU web+2 db-replica 装齐 categraf,writer 改私网 `172.31.18.101:17000`(原绕公网 n9e.17.rip 队列溢出),监控数据已流。见 [[project_multiregion_monitoring_fix_2026_06_06]]。
- **region iplibs 缺失**(/newworld/iplibs 不存在)=真 config gap 但**不影响归因/CPU**(独立 backlog,影响 ISP/省份/反作弊 geo)。
- **🔑 两个密钥本会话误打印**(owner 决定不轮换):categraf basic_auth_pass、cloudflared 隧道 token。教训:查密钥只验存在性,禁 `ps args`/`grep 配置值` 直出。

## 方法教训(本轮血泪,最值钱)
- **★采样必采全窗非子窗**:我每次测 region 5xx 都在切回后排空窗口(返0),漏了切流期全天 error.log 的 28% 5xx;蓝军引"EXECUTION-RESULT 5xx=0"是上一轮半量 canary。**真故障藏在全天 error.log 时间线(06:39-17:04 对齐切流窗、回滚即止),不是 tail 近窗**。
- **★owner 实证 > 整个对抗团队推断**:4 个表层告警(organic_rate=低分母artifact+line104 latch/数据大跌=partial-day/CPU=replica iowait虚高/域名健康=Wilson小样本)全是 artifact,团队差点收口"无真故障"——是 owner 坚持"切前没这么大量降级肯定有问题"逼我翻 region error.log 才见 197 万 no-live-upstreams。
- **@Async + CallerRunsPolicy = 压力下静默变同步**炸弹;**单 origin + max_fails=2/10s 把局部 stall 放大成 10s 全黑窗**。
- **判失败/延迟/连通用对信源**:domain health 三信号(SW 墙钟 latency 毒样本/opaque fail≈0/Wilson 小样本)全不可信;RUM TTFB 有幸存者偏差(5xx 不进分母);唯一金标=origin access-log status + nginx urt。
Related: [[project_phase0_redis_geo_deploy_2026_06_04]] / [[project_multiregion_monitoring_fix_2026_06_06]] / [[project_retention_drop_rca_2026_06_04]] / [[project_peak_perf_debate_2026_05_29]]
Related: [[project_phase0_redis_geo_deploy_2026_06_04]] / [[project_multiregion_monitoring_fix_2026_06_06]] / [[project_retention_drop_rca_2026_06_04]] / [[project_peak_perf_debate_2026_05_29]]

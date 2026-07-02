---
name: project_ipuv_anomaly_bot_rca_2026_06_29
description: "统计后台独立IP骤降+IP/UV比例塌(0.99→0.48@06-29)RCA;真因=外部bot cookie-churn灌organic UV(非NLB非bug非口径);同步饿死已修;S已恢复;methodology=多源数据>单一推断(我中途纯同步假象结案错,用户坚持比例异常逼出真相)"
metadata: 
  node_type: memory
  type: project
  originSessionId: 5f6867f7-a1c1-4319-bbef-1811d7659ae4
---

# 统计独立IP骤降 / IP-UV比例异常 RCA（2026-06-29）

**现象**：admin 统计后台独立 IP 骤降 + IP/UV 比例从 0.99 一路塌到 **0.476**(06-29，UV 还涨 IP 暴跌)。Owner 怀疑 **NLB-direct 真实 IP 透传** 坏了。

## 三轨根因（4 agent + 生产只读实测坐实，base origin/master）
- **轨1（主）= 外部 bot cookie-churn 灌水 organic UV，非 NLB/非 bug/非口径错/非真增长**。铁证：`_organic_` 的 **watched_uv & 观看时长全周期纹丝不动**（真人观众恒 ~5-10k）、**IP 池固定 ~23k**，而 uv 涨 33×；逐域 `spectrumdigest.study` 23537uv/**206ip**(114 vid/IP)+ 一批停放域(.cyou/.rest/.help)30-40 vid/IP。统计管道**按设计工作、输入被污染**——去重(`VidClusterRootResolver`+`VidAliasMergeTask`)结构性压不住同日 churn(同日 vid 在 01:00 merge 前就落库;且 `CLUSTER_LIMIT=5000` 已积压、`MAX_CLUSTER_SIZE=100` 主动跳过)。**H7 `02264b70` MISS_TTL=red herring**(只改缓存命中、不改 HLL 基数;漂移 06-21 起早于提交)。**归因漂移(S→organic)排除**(若是 organic IP 会一起涨,实际 IP 不动)。
- **轨2 = 同步饿死,已修已部署健康**：GFW 组A 06-26 暗部署的 `GfwProbeAggregator` 单轮 80min 饿死单线程 `SiteStatsSyncTask`→统计留 Redis 没入 MySQL。`b6e43869`(scheduling.pool.size=5)**已上线**(ca-admin 06-29 重启、scheduler 多线程 scheduling-1..5、每5min 成功 2775/2775)。06-26/27 行数完整(3083/3103)、**无需回填**(HLL 绝对快照,sync 恢复即追平)。承 [[project_admin_scheduler_starvation_2026_06_27]]。
- **轨3 = S 渠道已恢复**：S/promo ip/uv 全程 ~1.0 正常、归因正确、推广链回 edge 302 正常(06-28 NLB-direct 抹端点事故已回退)。S 真实下滑(826k→226k 两周)是独立渠道议题。

**站点级独立 IP 骤降真相** = S 真实流量降(06-28 事故) + 整体量降(PV 900万→423万) + **混合口径漂移**(高 ratio S 渠道萎缩、低 ratio organic[bot]膨胀 → 把站点混合 ip/uv 拽塌)。**NLB 真实 IP 透传彻底排除**(经 NLB 的 S 渠道 ip/uv 正常)。

## 修复
- **进行中(dev feat/organic-bot-report,admin-only 加性)**：organic 概览改用 **watched_uv/ip_count 作"真实受众"**(裸 uv 标 bot 可疑)、逐域 **ip/uv<0.3 标 botSuspect**、`SiteStatsSyncTask.detectAnomalies` 改逐域 organic 告警(避免单桶被自身污染拉高阈值漏报)。
- **治本未做(属 ops 决策)**：边缘 CF Bot Management / per-IP rate-limit + per-IP distinct-cookie 上限,拦 spectrumdigest.study + 停放域(bot 在进 `recordHit` 前拦)。
- **未做(风险)**：摄入端 `SiteStatsService.recordHit` per-IP 当日 distinct-vid 上限(CGNAT 误伤风险,需阈值实测);`VidAliasMergeTask` CLUSTER_LIMIT 5000 积压(仅离线 BI 债)。

## ★方法论教训
**多源数据 > 单一推断**：我中途凭代码"近4天未改 IP 链 + 同步饿死已修"就给"纯同步假象"结案——**错**。是 Owner 坚持"**IP/UV 比例不正常**(同步冻结会比例不变)+ NLB 之前 live 过"两条,逼我去查**逐渠道数据**,才挖出真相在 organic bot。Owner 直觉(NLB)虽被证伪,但**逼出了真因**。承 [[feedback_verify_metric_source]] / [[project_retention_drop_rca_2026_06_04]](又一例统计异常真因是口径/输入而非真实降)。

## 关键 file/key
`site_daily_stats`(ip_count/uv/watched_uv/pv/bounce 按域×渠道);`SiteStatsService.recordHit`(web 摄入);`VidAliasMergeTask`(MAX_CLUSTER_SIZE=100/CLUSTER_LIMIT=5000);`SiteStatsSyncTask`(每5min sync today,无历史回填,`syncDate(过去日)`可手动回填);Redis `stats:ip`/`stats:uv-cr`/`stats:ch-ip`/`stats:combos:{date}` HLL。

## ★ip/uv 比例 = 流量性质信号（非 bug，2026-06-29 顺手查实）
- **ip/uv `<0.3` = bot**(稳定少量IP churn海量cookie,如organic 0.07);**`~1.0` = 稳定桌面**;**`>1`(IP>UV) = 移动端**(稳定cookie churn多IP)。同一把尺子两端,正是 `botSuspect`(ip/uv<0.3) 的依据。
- **S 推广渠道 IP>UV(1.10-1.13)是正常的、非聚类bug**:数据实证 `uv_global`/`visitor_alias_count` 全 **NULL** → 排除"alias 合并压低 UV"。真因两条:① **完整 IPv6 不做 /64 归一**(owner 5/11 拍"完整 IPv6 唯一",`StatsController` 注释)→ 移动/家宽 IPv6 隐私扩展临时地址轮换 → 一设备多 distinct IP;② **移动 CGNAT 出口 IP 池**(一手机请求从 /24 池轮发)。两者都让 distinct IP > distinct cookie。
- **若 IPv6 按 /64 归一**:IP **下降**(隐私轮换地址共享 /64→折叠成一个;IPv4 不受影响),IP/UV 回归 ~1 更贴真实设备数。**代价**:① 应用当天 IP **阶跃式下降(口径断裂,非真降)**——owner 5/11 不归一很可能就为避此 ② 同 /64 多用户轻微过度合并。**要做须 owner 拍 + 灰度(新旧口径并行对账),禁顺手切。**

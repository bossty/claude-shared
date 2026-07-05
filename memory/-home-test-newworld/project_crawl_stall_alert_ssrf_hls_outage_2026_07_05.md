---
name: project-crawl-stall-alert-ssrf-hls-outage-2026-07-05
description: "CRAWL-RUN-STALL{cableav} S2 告警 triage：告警本身是白名单设计误报，但顺藤摸出真 P1——P2-35 SSRF 防护传参错误致 HLS 下载全断 ~18h（jable/beeg/javxx 零产出），修复待 Owner 拍板"
metadata: 
  node_type: memory
  type: project
  originSessionId: 19845271-1999-46e2-8a3f-46f5904fdaf7
---

2026-07-05 16:00 CRAWL-RUN-STALL{source=cableav} S2（触发值 36267s）triage 结论：

**① 告警本身 = 结构性误报**：`CrawlRunMetrics.HOURLY_SOURCES`（CrawlRunMetrics.java:50）含 cableav，但 CableavScheduledCrawlTask 自 06-16 起 `@ConditionalOnProperty` 永久停用（cableav 走 StockPublishScheduledTask 先囤后放，不经 FreshnessTrickle）→ gauge 永停启动时刻，每次部署重启后 2h 必触发且永不恢复。生产实证：`nw_crawl_runs_total{cableav}` ok/error 均=0；stock-publish 12:31/13:30/14:30/15:30 每小时上线 1 部全成功（cableav 业务健康）。修法：HOURLY_SOURCES 去 cableav + ops/n9e-alert-rules.yaml 白名单同步去。

**② 顺藤摸出的真 P1**：commit `d1b66833`（07-04 20:48，审计 P2-35 SSRF 防护）调用点 HlsDownloadService.java:1301 传 `request.getRequestUri()`——HttpClient5 该方法返回 origin-form（仅 path+query 无 host），实测确认（getUri() 才是全 URL）→ **每个 HLS 请求都被「SSRF 防护: URL 缺少 host」fail-closed 拒绝**。07-04 22:00 首条错误起 jable/beeg/javxx 三源 finalized=0 约 18h（hanime1 不走 HlsDownloadService 幸存）。修法：改为 `request.getUri().toString()`。
**测试为何没逮住**：+15 tests 全是反射直调 `assertNotPrivateNetworkTarget(String)` 喂全 URL 字符串，从没走真实调用点参数——「测方法不测调用点」教训。
**为何真故障没告警**：条目级失败被 FreshnessTrickle 内层吞，outcome 恒 ok（蓝军 #3 已预言的盲区），CRAWL-ZERO-OUTPUT-24H 要 24h 才触发。

**③ 修复+部署（Owner「go」授权）**：分支 fix/hls-ssrf-request-uri，commit `e53d9152`（调用点 requestFullUrl=getUri()）+ `523e2c75`（蓝军 6 条处置：IPv6 ULA fc00::/7 补判/stock-publish 插桩 nw_stock_publish_*/getUri 哨兵测试）。TDD 全程 RED→GREEN，newworld-data 840/840 绿。17:19 部署 ca-admin（jar `20260705-171841-hls-ssrf-523e2c75.jar`），N9E 规则 129/131 rule_config 去 cableav 已回读确认（蓝军 #1：真值在 rule_config JSON 非顶层 prom_ql 死列；#2：赶在 07-06 06:07 oneshot 启用 131 的 cron 之前）。
**④ 待办/新发现**：javxx 按 create_time 口径近 7 天零上线——断流早于 SSRF 事故，独立问题待查；Owner 质疑指标法监控过复杂、提议每小时查 DB——fact-check 支持（movie 有 (source,status,create_time) 索引；create_time=各源统一上线时刻，cableav 翻转会重写；beeg/cableav 每天 24 部、jable 23-28、hanime1 各 channel 3-9、javxx 0），方向待拍板，STOCK-PUBLISH-STALL 新规则已挂起未建。
**⑤ 教训**：测方法不测调用点=15 个测试全绿照样全断；监控白名单与业务模式（先囤后放 vs 每小时爬）漂移=结构性误报；过程指标（轮 ok/error）逮不住「轮成功但产出归零」型真事故，产出口径才是真值。

关联 [[project-alert-triage-rule42-disk-n9e-2026-07-05]] [[project-full-code-audit-closure-2026-07-04]]。

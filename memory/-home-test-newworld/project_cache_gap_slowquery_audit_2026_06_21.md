---
name: project_cache_gap_slowquery_audit_2026_06_21
description: 缓存缺口+慢查询审计 sprint — P0三连已部署实证 / 锁修+H3+H7+H6+H1②已commit未部署 / H4待拍排序语义 / 三个可复用诊断坑
metadata: 
  node_type: memory
  type: project
  originSessionId: e154dcd7-4e73-48df-ae60-a425412b5fbf
---

2026-06-21~22 缓存缺口+慢查询全栈审计（接续会话 4a3a7a88 的 401 中断）。生产 master `ca-mysql-master .222` digest+slow.log+EXPLAIN ≥3 源坐实 8 热点。文档 `docs/sprint/2026-06-21-cache-gap-slowquery-audit/REPORT.md`（§6-9 实施记录）。

**已部署+实证（commit 9247d12c, P0 三连）**：H1①列表深翻页缓存 condition #page≤20→200+sync（深页 Redis 键实证生成）；H2 地区热榜调度器补热全6 region；H8 readonly 探针 useLocalSessionState（tcpdump ca-web-01=0 探针实证，稳态 216→19/s）。6 节点零停机滚动 deploy-web.sh --force-peak。

**已 commit 未部署（Owner"全部按推荐"，待 review 后部署）**：
- `5434b166` 锁修：CacheRefreshScheduler.withLock 的 setIfAbsent/解锁包 try-catch + warm 锁 TTL 5min→90s。
- `23c041c5` H3 搜索缓存：独立 search 区 30min TTL+sync（CacheConfig 加区，condition page≤5&kw≥2字，COUNT 不动）。
- `02264b70` H7：VidClusterRootResolver MISS_TTL 60s→24h。
- `abbc776e` H6：RegionWhitelist 归一，MovieController 全 region 端点 @Cacheable 前归一。
- `8d4d886b` H1②：findAllLatestMovies FORCE INDEX(idx_status_recommend_create)，prod EXPLAIN Backward scan 零 filesort。

**待 Owner 拍后落地**：H4 getMoviesByIds 逐片卡缓存+手动 multiget——**排序语义分叉**：现 findByIds 无 ORDER BY 返 PK 序，但 trending/feed/related 传入 ids 是排名序，multiget 必重定序（疑现 PK 序是潜在 bug）；Owner 确认"按入参序"后落地+蓝军。enum 清理(movie:list:*收编)折进 H4。H5 暂缓。H8 admin 加 useLocalSessionState 下次 admin 部署带。

**★三个可复用诊断坑（差点下错结论）**：
1. **TTL jitter 坑**：TwoLevelCache.applyTtlJitter 对 web 区 ±10% TTL 抖动→**不能据 TTL 跨度判"同时warm vs懒填"**（差点凭 6 键 TTL 3h 跨度误判懒填）。判调度真跑用**成功日志+version递增**，非 TTL。
2. **digest 瞬时尖峰坑**：useLocalSessionState 部署后立测 digest 探针速率反升(216/s>历史64/s)=连接池重建(6×80条新连接各建连探针一次)瞬时尖峰，**非稳态**；等几分钟稳态测=19/s。测配置改动效果要等稳态。
3. **warm 调度不跑成(机制未完全钉死,勿过度宣称)**：00:00+01:00 两次 refreshDailyHot 都没 warm 成(version 291 没增+无成功日志,两项可靠;EU app setIfAbsent fire 时刻跨洋 .128 超时 RedisCommandTimeoutException 可靠)。但确切机制未钉死:ghost-acquire 理论有漏洞(锁键 01:03 已不在,5min TTL 应留到 01:05);为何 CA 不 warm 未解。**★诊断工具陷阱**:EU 节点没装 redis-cli→我手动 SET 测"EU 0/10 失败"是工具缺失假象非真断(EU app 写 .128 正常,journal Redis 错误 0)。**code-only 锁修(5434b166)必要但可能不充分**(不阻止 warm 漏跑)。真要让 warm 跑成需深插桩(scheduler 临时 DEBUG 看 setIfAbsent 真返回值)或 CA-only 门禁(Owner 决策)。★我之前跟 Owner 说"偶发/6h一次"基于不完整数据(当时只 00:00 发生过)实为 chronic——已纠。

关联 [[feedback_ca_reads_master_by_design]][[feedback_verify_not_recall]]。digest 累计值是 8.6天(master uptime 起算 6-13 cutover)，看相对排名。

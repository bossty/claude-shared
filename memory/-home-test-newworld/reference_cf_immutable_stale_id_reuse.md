---
name: reference_cf_immutable_stale_id_reuse
description: CF immutable 缓存 + 非内容寻址 key(movieId) + id 复用 = 边缘 stale 通用陷阱；cache-bust 是 origin-vs-edge 金标
metadata: 
  node_type: memory
  type: reference
  originSessionId: 1dfa35af-56ae-4f2e-91ee-773c3f80e514
---

封面/预览“内容对不上”RCA（cover-rca sprint 2026-06-01）：表面像采集/入库 bug，实为**纯 CF 边缘 stale-cache**，origin（R2）始终正确。

**共因链**：5/28 DB 灾难重建（见 [[project_db_migration_2026_05_27]]）回滚 movie 表到 ~5/27 16:45 快照 → **AUTO_INCREMENT 被 reset 回 ~69646** → 丢失窗口（5/27 16:45→5/28 17:25）内采集的 ~133 部 movie（多 hanime 动漫）写入 R2 的 cover/thumb/preview/vtt 成孤儿 → 重建后新 movie（jable/beeg）**复用 [69646,69778] 这批 id**，putObject 正确覆盖 R2（last-write-wins，origin 自愈）→ **但 R2 putObject 带 `Cache-Control: public, max-age=2592000, immutable`(30天)，CF 边缘按 immutable 继续发旧动漫对象** → 用户看到“对不上”。

**通用陷阱**：`immutable` 缓存的前提是 **key 内容寻址（含 content hash）**。当前 key=movieId 非内容寻址，又标 immutable → 遇 **id 复用 / 重新采集 / 重编码覆盖** 必 stale。这是设计层根子。

**诊断金标**：
- **cache-bust（`?cb=<纳秒>`）是 origin-vs-edge 判真伪金标**。本 RCA Round 1 用普通 curl 误判“origin 坏”，加 `?cb` 翻盘（边缘 stale ≠ origin）。
- CF 缓存验证必 **GET + `-D -`**（`curl -s -o /dev/null -D -`），HEAD 会误判（见 newworld-cf-cache-verify skill）。stale 特征 = `cf-cache-status: HIT` + 大 `age`。
- 子域覆盖：CF 单文件 purge **host-sensitive**，cdn-failover 把同一对象暴露在 R_IMG 全 50 子域（5 zone×10）→ 必须逐子域全 purge，purge 一个主 host 不清其它子域。

**治本闭环**（已执行 2026-06-01）：精准 purge 23 封面 × 50 子域 = 1150 URL（CF files[] ≤30/批 → 40 批，token=CF_API_TOKEN_B，zone id 现查）。终验逐子域全量复跑 enum：**purge 前 972/1150 stale → purge 后 0/1150**。脚本+矩阵基线在 `docs/sprint/feed-perf-rca/`（cf_purge_stale.sh / enum_stale_matrix.sh / stale_matrix.txt / stale_matrix_POST.txt / COVER-RCA-FINAL.md）。

**backlog（owner 本次不上）**：R2 覆盖写（headObject 命中=已存在）成功后主动单 URL purge，防再发。⚠️ 不能同步逐次 purge（owner 指出：50 子域/对象 + CF 限速 + 拖采集链路，频率不够）→ 须**异步批量**（覆盖 key 入 Redis Set，后台定时按 zone 攒批 purge）。更彻底治本=key 内容寻址化/带版本号（覆盖即换 key，CF 自然 MISS，零 purge；另立 sprint）。

**相关 memory**：CF 验证金标见 [[reference_cf_zone_17rip_cache]]（browser_cache_ttl 陷阱同源）；多子域 purge host-sensitive 见 [[reference_cf_waf_referer_skiplist]] 同账号 zone 枚举；DB 重建背景 [[project_db_migration_2026_05_27]]。

**方法论教训**：多 agent 团队 5 轮 + 全员自我证伪才收敛（前期 DMM 猜号/旧 jar/双源 等 7-8 次误判全建立在"普通 GET 把 stale 边缘当 origin 坏"上）。owner 多次业务反问（欧美也错？其他源也走 DMM？admin 读 MySQL 正常=问题在缓存）碾压技术抽象 —— owner 直觉 fact-check 铁律再次实证。

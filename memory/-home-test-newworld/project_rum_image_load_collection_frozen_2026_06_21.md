---
name: project_rum_image_load_collection_frozen_2026_06_21
description: "RUM image-load 采集 2026-06-21 冻结(停采+停清理留42M快照)—原是V4 srcset校准的6周时间盒研究,已被V5取代且表只写不读;含复活三步反向操作"
metadata: 
  node_type: memory
  type: project
  originSessionId: 85dc3fe1-5403-474d-941b-c0f0f36ee859
---

2026-06-21 Owner 决策：**冻结 `rum_image_load` 采集**——停止继续采集（减负载），保留已采 ~42M 行快照备后续分析。

**为什么停**（包装决策"本项目真需要吗"）：
- 这表是 **时间盒研究采集**（V4.D 2026-05-02，`docs/_archive/img-pipeline/IMG_V4_RESEARCH_TEAM_F_RUM.md`）：前端 1% 采样上报图片 cssW/dpr/naturalW/lcp，目的是"6 周后据此校准 V4 srcset 断点"。
- 但 V4 被 **V5 取代**（5/8，`IMG_PROCESSING_STANDARD_v5.md`），多档 srcset 断点 480/800/1440w **硬编码在 `img-url.js`**，**不是从这表算的**。
- 表 **只写不读**：`RumImageLoadMapper` 仅 `batchInsert`+`deleteOlderThan`，全仓库零 SELECT、零 admin 页面、零分析。7 周来从没被分析过。
- 决策依据：单档 vs 多档的答案藏在"设备/视口/dpr 人群 × 页面布局"这个**慢变量**里，已采 42M 行（之前到过 54M/38d）是极度过采样，再收无新决策信息。停采减负载，留快照够任何后续分析。

**实现（三步，commit 0d0163ec，全可逆）**：
1. **前端停采**：`main.js` 注释 `initRumImageLoad()`（停 IntersectionObserver/PerformanceObserver/sendBeacon，client+网络+服务端写全停）。模块 tree-shake 出 bundle（本地 fresh build grep=0 实证）。deploy-frontend.sh 部署 6 节点。
2. **admin 停清理**：`RumImageLoadCleanupTask` 注释 `@Scheduled`（字节码验 `Scheduled`=False）。**关键非显然点：光停采集不够——清理任务每天 3:00 删 >7d 数据，不停清理会把要保留的 42M 在 7 天内逐天删空**。停清理才保住快照。
3. **N9E 告警**：规则 106（"保留表膨胀告警"）摘掉 `rum_image_load` 条件，**保留 `redirect_trace` 条件**（该表仍活跃采集，是独立功能，删整条会留静默膨胀盲区）。

**复活反向三步**：恢复 main.js import+init / 恢复 admin @Scheduled / N9E 重加 rum 条件。web `/api/v1/rum/image-load` 端点、`RumService`、`rum-image-load.js` 模块全保留。

**注意**：
- 老客户端（已加载旧 bundle）刷新前仍会发 beacon，故表会从老客户端**缓慢增长再停**（非瞬停）；cleanup 已关 → 表 plateau 略高于 42M 后不再涨，告警已摘无噪声。
- `nw_retention_table_rows{table=rum_image_load}` gauge 仍由 `RetentionTableGaugeTask` 采（无害）。
- ~~`nw_retention_last_cleanup_deleted` gauge 报 NaN~~ **已修（commit 3e2eef65，2026-06-21）**：`meterRegistry.gauge(name,tags,intValue)` 弱引用 autobox 值 GC 后清空报 NaN（RetentionTableGaugeTask 用 `Gauge.builder+AtomicLong` 强引用每 10min 刷新所以同 bug 被掩盖未现；cleanup 每日只 set 一次故首次 GC 后全 NaN）。两处（RedirectTraceConsumer active + RumImageLoadCleanupTask 停用但 @PostConstruct 仍注册报 0）改成 AtomicLong 强引用字段。**教训：Micrometer 低频 `meterRegistry.gauge(name,tags,number)` 必用强引用持有（AtomicLong 字段 + Gauge.builder register 一次），别传 autobox 瞬时值**。
- redirect_trace 仍活跃：Redis stream redirect:trace:queue → MySQL，15d 保留，稳态 ~19M（阈 30M），护栏保留。

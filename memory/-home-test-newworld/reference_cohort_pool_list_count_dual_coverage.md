---
name: reference_cohort_pool_list_count_dual_coverage
description: cohort（Redis ZSET）池化只改 list 不改 count = 慢 SQL 原样还在，且新增缓存不一致；池化必须 list+count 双覆盖，并对全部同型端点做一次全栈适用扫描而非逐个打补丁
metadata:
  type: reference
---

2026-05-26 cohort 全栈覆盖审计（触发：Owner 报 MySQL CPU 周期性飙升）的四条 durable 结论。原 sprint 目录 `docs/sprint/2026-05-26-cohort-coverage/` 已于 2026-07-21（BL-111）删除，历史靠 git 取回。

**1. list+count 双覆盖铁律（最易漏）**：`ActorService` 的 cohort 命中路径 list 已走 Redis，`total` 却仍走 PageHelper auto-count（`GROUP BY` + filesort）——**慢 SQL 一次没少，只是挪到了 count 上**，而且 list 与 count 来自两个数据源必然出现分页总数漂移。池化任何分页端点必须同时接 `ZCARD`，并删掉 fallback 的 DB count 分支（留着就永远不知道有没有真在走池）。

**2. 池化要做全栈适用扫描，不逐个打补丁**：本轮实测 557 个 tag + 20 个 category 全部可池化，Redis 占用估算仅 ~17MB；`findMoviesByTagId` 24h 内 3744 次、累计 162388s，是当期 Top 慢 SQL。Owner 反诘「为什么之前没给全栈方案」——**同一模式第 N 次单点打补丁本身就是 delta debt 的累积信号**，见到就该停下做覆盖矩阵（38 个 endpoint × cohort 覆盖，逮出 6 个 HIGH）。

**3. 三层缓存职责决策树**（Owner 拍板，`@Cacheable` 不退役）：单条实体 → `@Cacheable`；翻页列表 → cohort 池；全集小数据 → `@Cacheable`；极热 → Caffeine L1。

**4. 深翻页必须有全局兜底**：`maxPageNum` 缺省 2000 而真实用户翻页 P99 ≤ 200 页，中间那 1800 页全是 DB 全扫放大器 → 收到 200 并配 400 handler。任何"理论上限"远大于"实测 P99"的分页参数都是被打的靶子。

关联：[[reference_cache_gap_slowquery_audit]]、[[feedback_measure_real_cost_before_optimizing]]、[[newworld-sql-safety]] 的 PageHelper 双 LIMIT 坑（同一个 PageHelper，两种翻车方式）。

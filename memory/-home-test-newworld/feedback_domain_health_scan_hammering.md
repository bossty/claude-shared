---
name: feedback_domain_health_scan_hammering
description: admin domain-health 端点是 12.45M 键全库 Redis SCAN 慢端点——smoke/验证禁连发，会耗尽 Lettuce 连接池致 pick-p 饥饿 + Tomcat 线程满告警
metadata: 
  node_type: memory
  type: feedback
  originSessionId: bad9e248-e91e-4f20-b940-5c3872e06b28
---

**admin `/api/v1/internal/ops/domain-health`（及其 appendPenaltiesForDomain）对 `domain:err:*` 做全库 Redis SCAN**——线上 Redis 有 **~1245 万键**（12.45M 键仍在；注意：config-tuning 的去 SCAN 修复 `11078abc` 只治了 **ChannelSaturationTask**（定时任务），**未覆盖 domain-health 端点这条 SCAN**——是独立、当前无人处理的开放慢路径），单次 domain-health 请求 SCAN 全库要几十秒且**整段持有一条 Lettuce Redis 连接**。

**Why**：2026-07-06 部署验证时连发 ~5 次 domain-health smoke（10s/30s 超时 + 后台各一），5 条 SCAN 各占一条 Redis 连接 → 耗尽共享 Lettuce 连接池 → pick-p（edge 路由，每请求需 Redis HGET）拿不到连接饥饿阻塞 → Tomcat 线程 151→200 满 → **S1 TOMCAT_THREADS_HIGH 告警 + pick-p 挂(000) 约 10min**。jstack：全 http-nio-8888-exec 线程 park 在 `LettuceConnection.await`→hGet 的 CompletableFuture。非代码 bug（连接池耗尽）；restart admin 恢复（清池+断连丢 SCAN cursor），pick-p 18-46ms。

**How to apply**：
- 验证 admin 时**禁连发 domain-health**；单次足矣，或直接跳过（它是监控端点非关键路径，且 12.45M 键 SCAN 本就慢）。关键路径验证用 **pick-p / p-pool-snapshot**（快，走 ZSet/cache 非 SCAN）。
- 任何对 `domain:err:*` / 全库 SCAN 的端点/脚本都视为「重且占连接」，串行单次、带短超时、别并发。
- 见到 admin Tomcat 线程满 / pick-p 挂：先 jstack 看是否全 park 在 Lettuce 连接池（awaitNanos/CompletableFuture）——是则连接池耗尽（多为长 SCAN/慢查询占连接），restart 清池即恢复，别当代码 bug 乱查。★domain-health 端点 SCAN 是 config-tuning(11078abc 仅治 ChannelSaturationTask)未覆盖的**独立开放项**，非「已在处理」。关联 [[project_config_tuning_audit_2026_07_05]]（那边已闭环）、[[project_b9_pickp_full_split_2026_07_06]]。

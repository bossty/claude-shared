---
name: reference_deadroots_sample_gate_implicit_contract
description: UDF reachHint 的 deadRoots 判死无最小样本门，安全性隐式依赖 REACH_FUSION_ENABLED=true 的贝叶斯先验；关掉融合会让 deadRoots 立刻失去小样本保护
metadata: 
  node_type: memory
  type: reference
  originSessionId: 99124a83-98c5-4ee1-908d-8a379e534a19
---

`ReachHintService.compute()`（newworld-web）把一个 rootHost 判为 deadRoot 的**唯一**条件是 `entry.reach() < DEAD_THRESHOLD(0.3)`（`ReachHintService.java:172`，阈值定义 `:50`）。

**它不读样本量。** `ReachEntry` 带 `sampleCount`（=rum_n，`ReachGridReader.java:63,251-258`），但该字段只被 A 池软排序的 min-n≥20 门消费，**reachHint 路径零消费**。单元测试 `ReachHintServiceTest.java:45` 的 helper 恒传 `sampleCount=0L`，反证样本量对分桶决策无影响。

**为什么现在仍安全 = 隐式契约**：生产 `REACH_FUSION_ENABLED=true`（system_config，2026-07-01 15:03:47 起）。融合开启时 reach 走 Beta 后验均值 + probe 先验（probeWeight 默认 8，`ReachFusionService.java:80`；`ReachFusionMath.java:20-42` 注释"根治小样本崩塌"），少量 RUM 样本拉不动 reach 到 0.3 以下。

**契约破裂条件**：`REACH_FUSION_ENABLED` 一旦被关，消费键退化为探针层**字节透传**（`ReachFusionService.java:261-271`），reach 直接等于 GfwProbeAggregator 探针值——此时单样本探针误判即可让活域进 deadRoots。

**危害上界（为何不是 BLOCKER）**：deadRoot 只做软沉底（rank -10 稳定排序，`sw.js:1641-1648`），不删候选，`/cdn-cgi/trace` 探活是最终裁判；且误判越普遍、rank 越趋同，排序越退化成恒等原序（no-op）。

**行动**：改动 `REACH_FUSION_ENABLED` 前必须意识到它同时是 deadRoots 的样本门。若要解耦，在 `compute()` 里对 `entry.sampleCount()` 加显式最小样本门。相关 [[feedback_verify_live_flag_value_not_code_default]]。

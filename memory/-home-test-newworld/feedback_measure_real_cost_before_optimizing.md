---
name: feedback-measure-real-cost-before-optimizing
description: "优化token/成本前先测真实成本结构(按message.id去重看cache_read累计),别被观测工具瞄错靶;机制(hook/gate)兜底判断,列在清单里的skill≠自动触发"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: b37566ca-cf42-4118-b327-c9657f4ef68c
---

全套省 token 机制（nw-cap / context-mode）曾瞄着 tool_result（占 context ~10%）使劲，而真成本是 cache_read ~70%（会话长 × context 大）。根因=观测工具 nw-token-report 不报累计 cache_read、且按 jsonl 行加总虚高 2.6×，把努力导向了错误的靶（2026-07-08 成本审计，见 [[project-token-cost-audit-2026-07-08]]）。

**Why**：省错地方 = 白费力气 + 自我感觉良好；**仪表盘定义努力方向，仪表盘错则全盘皆错**。

**How to apply**：
1. **优化成本前先量真实计费结构**：按 message.id 去重 usage，分 cache_read / output / cache_creation 按倍率（0.1 / 5 / 1.25）折算占比，找最大块下手。别拿"当前 context"或"tool_result 占比"当靶。
2. **机制 > 纪律**：能 hook/gate 强制的别只写文档铁律（会像 skill 管道一样静默烂掉）。判断题 → skill（喂依据），规则题 → hook/gate。
3. **列在可用清单里的 skill ≠ 会自动触发**——invoke 与否是模型判断；要每次强制得配 hook。所以"某 skill 从没见触发"往往不是坏了，是判断层没点它。
4. 关联 [[feedback-verify-metric-source]]（指标解读前验证数据源）、[[feedback-experiment-conclusions-to-doc]]。

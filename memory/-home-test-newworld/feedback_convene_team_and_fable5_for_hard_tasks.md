---
name: feedback_convene_team_and_fable5_for_hard_tasks
description: Owner 07-21 授权——必要时我自行拉真实 agent team 讨论（不必等他开口），高难度/复杂任务用 fable 5 subagent-driven
metadata:
  type: feedback
---

Owner 2026-07-21 给的两条工作方式授权（**站立授权，非一次性**）：

1. **「你觉得有必要的时候可以拉团队讨论」** —— 组建真实 agent team（`/crossfire`，非 subagent）的决定权在我，**不必每次等 Owner 点名**。
2. **「执行高难度任务和复杂任务可以最强模型 fable 5 subagent-driven」** —— 难任务显式传 `model: fable`，走 subagent-driven 模式。

**Why**：此前我的默认是「机械活派 sonnet、难活自己在主线程扛」，结果是主线程既贵又容易在复杂设计上打转（BL-78 会话实例：调查阶段主线程涨到 ~152k，且中途凭单一判据下错断言被 Owner 反诘）。Owner 的意思是——**难度高就上最强模型 + 多视角，别省这个钱**（对齐既有铁律 [[feedback_cost_threshold]]「百美金级月成本不作决策约束」与 [[feedback_agent_team_crossfire]]「多 agent 团队必须互相沟通质疑」）。

**How to apply**：
- 判断「跨模块 / 架构决策 / 推翻既有方案 / 有多个互斥候选」→ 拉 team，别独自拍。与 [[newworld-multi-agent-coord]] 的硬门禁（蓝军 ≥5 条）叠加，不替代。
- 难任务 subagent 显式 `model: fable`；机械活仍 sonnet（[[feedback_measure_real_cost_before_optimizing]] 的分级不变）。
- 主线程保持薄：team/subagent 产出写文件，只回收结论（[[newworld-delegation]]）。

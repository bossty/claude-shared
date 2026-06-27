---
name: feedback_experiment_conclusions_to_doc
description: 所有经过实验/实证的结论必须立即落档，防止后续重复论证
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 019a2513-f7cc-4759-ad55-7522771891e2
---

**凡是跑过实验/实测得出的结论，必须立即落进 durable 文档**（防止后续会话重复论证）。Owner 2026-06-22 两次强调（"记录好结论防止重复论证"/"所有经过了实验的结论落档"）。

**Why**: 重复论证浪费 token + 时间，且可能因记忆漂移得出矛盾结论。owner 视"实证一次、落档一次、永久采信"为闭环。

**How to apply**:
- sprint 内实验结论 → 写进该 sprint 的 `POC-FINDINGS.md` / 设计档（命令 + 结果 + 结论 + 诚实边界）。本会话范例 `docs/sprint/2026-06-21-reachhint-tri-probe/POC-FINDINGS.md`（AWS/双栈/CAA/可达拨测/wildcard/证书成本 全实证落档）。
- 跨会话durable结论 → 同步 memory（本条 + [[project_gfw_s_entry_execapi_poc_2026_06_22]] + [[feedback_cn_probe_aliyun_realbrowser]]）。
- 含**被推翻的结论**也要落（如 boce 3% 被 aliyun 99% 推翻，记教训防重踩）。
- 与 [[feedback_verify_not_recall]] 互补：实证>推断>记忆；实证完即落档。

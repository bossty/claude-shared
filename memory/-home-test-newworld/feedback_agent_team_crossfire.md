---
name: feedback-agent-team-crossfire
description: 多agent团队必须互相沟通讨论质疑产出高质量成果 — 不能纯并行 solo 完事
metadata: 
  node_type: memory
  type: feedback
  originSessionId: da3be312-2b73-46c3-95da-580bd268b069
---

队员之间一定要互相沟通、讨论、质疑，产出高质量的成果。**不能把多 agent 当成并行 subagent 用**（每人 solo 干完发 lead 就完事）。

**Why:** Owner 2026-05-14 显式纠正。Teams 模式（vs subagent）的核心价值就是 agent 间 SendMessage 互通，否则就退化成 subagent 并行，浪费 Teams 的设计意图。学术上也对应 MAST 论文（arxiv 2503.13657）的失败模式根因之一"specification ambiguity + verification gap"，独立调研+互相挑刺才能补漏。

**How to apply:**
- 任何 ≥2 agent 团队任务必须设计 cross-review / debate / challenge 阶段，不能纯并行 solo
- Round 1 独立调研（防 anchoring）允许，但必须配 Round 2 cross-review（互相质疑）+ Round 3 debate（公开收敛）+ Round 4 blueteam（独立挑刺）
- SendMessage 不是可选，是必经：每位 teammate 在 Round 2 必须给至少 2 个其他 teammate 发消息（≥2 反驳 + ≥2 支持 + 基于证据修自己）
- 蓝军 agent 必须独立 spawn（前面没参与），避免 groupthink
- **crossfire 是双向的——蓝军挑刺非终局裁决**：senior（pm-helper / dev-senior）可用实代码证据驳回蓝军挑刺，reviewer 应认账并下调严重度，不得因"蓝军权威"硬保留。实证：SDLC D-sprint reviewer #5 MAJOR 担心 frontend-admin spread 解构隐性引用 deprecated 字段，pm-helper R-7 深挖 `MovieList.vue:963` 只读显式字段名 + `cdn.js` 按键名读，实证反驳，reviewer round2 承认成立、自降 MINOR 闭环。规则：挑刺与反驳都必须带实证，谁有实代码证据谁对（与 [[newworld-multi-agent-coord]] 同源）
- 通信成本控制：debate 限 ≤3 轮（防 AutoGen group-chat 无限循环），收不敛就明确标"未达成共识"丢给 owner
- 相关 newworld 既有铁律：[[newworld-multi-agent-coord]]（跨模块/DB/服务必走多 agent 交叉验证 ≥5 条蓝军）+ [[feedback_audit_methodology]]（审计 10 铁律含独立蓝军复核）

**反模式（明令禁止）：**
- spawn N 个 subagent 各干各的 → 各自报告 → lead 直接综合（"伪 multi-agent"）
- 让 agents 在同一 prompt 里"互相讨论"但不强制 SendMessage（变成 single agent 内心戏）
- 蓝军 agent 看了正方综合后再挑刺（已被锚定）

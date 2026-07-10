---
name: feedback_context_switch_breakeven_1m_window
description: "1M窗口下换会话(/clear)省不省的盈亏模型——决策看\"任务相关性+是否近40%\",不看绝对context%;换会盈亏点约5轮"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: b64930af-833c-4a67-8ec7-30b1c534eccc
---

**1M 上下文窗口下,「到任务边界就 /clear」的纪律要补前提——不是一到边界就换,而是 边界 +（下一件事与当前无关 或 已近 ~40% 阈值）才换。** 才 18% 就换新会话,大概率反而多烧 token。

**盈亏模型**(按 Anthropic 定价 cache_read≈0.1× base input、cache_write≈1.25× base input):
- **新会话启动前缀 ≈ 45–60K tokens 固定成本**(CLAUDE.md 全文 + MEMORY 索引 100+ 条 + ~29 skill 列表 + 工具 schema〔Workflow/Monitor description 极长〕+ superpowers 注入 + 环境)。任何会话必付一次 creation。精测用 `scripts/nw-toolbox/nw-token-report`。
- **换会话** = 一次性重建前缀 cache_creation ≈ 50K×1.25 ≈ 62K 等效 input（+ 丢当前历史=已付沉没成本）。
- **继续会话** = 下一件事每轮多背当前历史的 cache_read ≈ (当前context−前缀)×0.1 /轮（例:181K 会话 ≈ 13K/轮）。
- **盈亏平衡 ≈ 62K / 13K ≈ 5 轮**:下一件事 <5 轮 → 继续更省;>5 轮 → 换更省。

**Why**:cache_read 是单会话最大开销(~70%),正比于「轮数×平均context」;但换会话的启动前缀也是真金白银的 cache_creation,提前换=提前付+丢历史。绝对 % 低(18%)时,继续会话背的历史还不够贵,重付 50K 前缀不划算。`opus[1m]` 下 auto-compact 够不着阈值,所以无关任务堆在一起才会线性涨到失控——那是"任务相关性"问题,不是"当前 %"问题。

**How to apply**:
1. 下一件事**与当前任务相关**(复用当前 context 有价值)→ 继续,18% 连 /compact 都不用。
2. 下一件事**完全无关的多轮大任务** → /handoff + /clear(此时省的是"避免无关 181K 每轮全额重读",不是眼前几十K)。
3. 无关但很短(1–3 轮侧问)→ 继续/`/btw`,别为 3 轮重付 50K 前缀。
4. 到 ~40% 且到自然断点 → /compact(不必换会话)。

**教训**:2026-07-09 B4 收口后我机械套"边界就 /clear"、在 18% 就建议换会话,被 Owner 用成本直觉逮住——过早优化。相关:[[feedback_measure_real_cost_before_optimizing]] [[project_token_cost_audit_2026_07_08]]。

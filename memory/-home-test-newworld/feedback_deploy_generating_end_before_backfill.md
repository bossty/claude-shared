---
name: feedback_deploy_generating_end_before_backfill
description: "给存量加新字段时，先部署\"生成端\"再回填，否则中间窗口持续产生缺口"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: e3640a16-9ed9-4467-8e20-35eb9a0b1612
---

给存量数据加新派生字段(如 movie.cover_blurhash)时，部署顺序铁律：**先部署"生成端"(让新数据自带该字段)，再回填存量**。

**Why**：2026-06-29 BlurHash sprint 我把 data jar(inline 生成 blurhash 的生成端)放最后部署，回填更早跑完 → 中间几小时旧 jar(无 blurhash 代码)持续爬入新片，全留 NULL(29 个散户)。我一度想加"周期兜底回填任务"补，被 Owner 纠正"找根因而非事后弥补"——根因就是部署顺序，不是 inline 代码 bug(inline 路径代码核实健壮、全量回填 miss=0)。

**How to apply**：
- 正确序：migration → **部署生成端(crawler/写入服务)** → 回填存量(一次扫清，此后无新缺口) → 部署读取端/前端。
- 错误序(我犯的)：…→ 回填 → 最后才部署生成端 = 回填完到生成端上线之间是"持续产缺口"的窗口。
- 别用周期性 cleanup 任务掩盖部署时序问题(事后弥补)；先确认缺口是"一次性时序产物"还是"生成端代码系统性漏算"——前者调顺序即可，后者才改代码。
- 区分:inline 生成 fail-soft 留 NULL(rare，正常 ~100%) vs 部署窗口老代码批量留 NULL(systematic but one-time)。

关联 [[project_cover_blurhash_placeholder_2026_06_29]] / [[reference_deadcode_audit_sop]]。

---
name: docs-consolidation-2026-07-07
description: "全量文档整理合master f3cb6042——docs 58M/1648md→17M/1179md,三层流水线,Owner全权委托"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3c88f74b-9d44-43c5-9f63-035e50a94ce8
---

2026-07-07 全量文档整理，合 master `f3cb6042`（--no-ff，分支 refactor/docs-consolidation-20260707 已删，worktree 全量 mvn test 绿）。

- 删除：sprint 中间产物 811 件（agents/* 状态档、evidence、一次性脚本、raw dump，删前全仓+memory 路径引用面核查）；顶层 10 件（UNIFIED_LLM/TAG_AUDIT 过程稿 7、ASN_BEACON 0引用、RUM_F5 过期观察窗、含明文凭证的 2026-04-30 IMG 交接档——**凭证仍在 git 历史，未确认是否已轮换**）。
- 归档 `docs/_archive/`：S_P_ARCH 旧版4（现行唯一=V3_3；V3_2_3 因 live lua/脚本按节引用留原位）、UNIFIED_LLM+TAG_AUDIT 整族、CONTENT_ANALYSIS v1、design/wave_stats 37档、RESEARCH/、RUM 三档等。
- 修剪：AWS_S_INFRA/CN2_RUNBOOK/IMG v3/R2_SOP 加状态标注头；4 个 Java `@see` 从 v1 改指 CONTENT_ANALYSIS_DESIGN_v2。
- DOC_INDEX 去 4 条已归档条目，全量校验各级 CLAUDE.md 引用 0 断链。
- ★教训（Owner 批评）：一开始直接在共享 master checkout 干（当"纯docs"），改到 Java 注释即违纪；中途补救=commit 移分支+worktree、master 复位。见 [[feature-branch-deploy-test-then-merge]]。
- ★SwVersionStats 时区测试：pre-push 门跑全量 mvn 时须 `TZ=Asia/Shanghai git push`。

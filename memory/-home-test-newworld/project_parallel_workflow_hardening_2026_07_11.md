---
name: project-parallel-workflow-hardening-2026-07-11
description: 多会话并行工作流加固五条全落地已合master——共享checkout只读化hook+master推进权单点化+backlog占坑+分支push编译轻门+memory暂存设计文档
metadata: 
  node_type: memory
  type: project
  originSessionId: 99cae49e-868f-47ce-82ba-1b70682cd23d
---

多会话并行工作流加固 sprint（2026-07-11）**已合 master `171b27c9`（push 落点 `b4487724`），分支/worktree 已清**。~~全档 `docs/sprint/2026-07-11-parallel-workflow-hardening/SESSION-STATE.md`~~ → **该 SESSION-STATE 已于 2026-07-22 收官删除**（BL-135，墓碑 `docs/TOMBSTONES.md` P9，取回 `git show 2d803d7cf:docs/sprint/2026-07-11-parallel-workflow-hardening/SESSION-STATE.md`）；**同目录 `MEMORY-STAGING-DESIGN.md` 未删且是承重档**（`CLAUDE.md:103` / `scripts/nw-memory-stage` / `docs/process/BRANCH_LIFECYCLE.md` 三处硬引用）。

- 起因：Owner 质疑「gate 和测试占掉大量时间」，实证近两周 1104 commits 中约 45% 是流程/元工作；诊断根因 = 共享可变状态上的并行 + 守卫补丁自我繁殖，方向 = 隔离执行 + 单点串行合并。
- 交付：①`shared_checkout_edit_guard.py`（共享区拦 Edit/Write/NotebookEdit 改产品代码，sentinel `.claude/ALLOW_SHARED_EDIT` 逃生）+ `worktree_guard.py` 拦共享区直接构建（按段状态机）；②pre-push master 单点化卡口（worktree 推 master 硬拦，SKIP_CI_LOCAL 不可绕过，逃生 `NW_ALLOW_WORKTREE_MASTER_PUSH=1`）；③backlog 认领占坑纪律（BACKLOG.md 第 5 条 + inject_context 铁律 7）；④分支 push 后端 `backend-compile` 编译轻门实测 14.7s（vs 全量 7min，回退 `CI_LOCAL_BRANCH_TESTS=1`）；⑤MEMORY-STAGING-DESIGN.md 设计文档待 Owner 评审（净复杂度为正已列决策点）。
- 教训：**守卫类代码的评审必须对抗式多轮**——本 sprint 8 个真缺陷全部是评审逮的，最典型 SKIP_CI_LOCAL 早退在新卡口之前=旁路整个安全属性（Critical）、guard 正则「存在子串即放行/即拦截」两个方向都出过洞（复合命令只读豁免旁路、单向 latch）；判据泛化 = 逃生口叠加时必须推演「每个既有逃生口是否旁路新卡口」。
- hook 生效时机：合 master 后主 checkout 会话冷启动生效；存量 worktree 要 merge master 才带上（渐进铺开）。
- 待拍板遗留：条 2 memory 暂存实施与否 / BL-46 plugin 守卫集残缺 / BL-47 wrapper 绕过面（均在 BACKLOG.md）。

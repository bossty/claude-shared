---
name: feedback_worktree_location_outside_repo
description: worktree 一律开在仓库外 /home/test/worktree-<名>，禁用 EnterWorktree 默认落点 .claude/worktrees/（Owner 2026-07-14 指令）
metadata:
  type: feedback
---

Owner 拍板（2026-07-14，BL-63 收尾时）：worktree 必须开在**仓库目录外**（`/home/test/worktree-<名>` 或 `/home/test/worktrees/<名>`，两者都命中 worktree_guard 的 `WORKTREE_HINT` 前缀 `/home/test/worktree`），**不要用 Claude Code EnterWorktree 的默认落点**——它把 worktree 建在共享 checkout 内部的 `.claude/worktrees/`。

**Why:**
- 仓库内嵌套 worktree 会让「全仓 grep 引用面」类审计（死代码审计 SOP、删文件前 grep 全仓）扫进整仓副本产生重复命中；
- 与 worktree_guard 的共享区前缀判定天然冲突（BL-63 `05a5442c3` 已加 `.claude/worktrees/` 识别容忍，但那是防御层，不是许可这么用）；
- 既有仓库惯例本来就是 `/home/test/worktree-*`（worktree-best 等），guard 的 BLOCK_MSG 指引也是这个路径。

**How to apply:** 开工时手动 `git worktree add /home/test/worktree-<名> -b <分支> origin/master`，再用 EnterWorktree 的 **path 参数**切进去（禁用 name 参数——name 会落 `.claude/worktrees/`）。前端依赖硬链接克隆秒装：`cp -al /home/test/newworld/frontend-web/node_modules <worktree>/frontend-web/node_modules`（BL-66 实测 1.9s）。收尾走 [[reference_safe_branch_worktree_cleanup_protocol]] 不变。`newworld-dev-workflow` skill 表述已同日订正（`3109e2657`，plugin 0.3.9）。残余待办：仓库根 `.worktrees/` 下两个存量 worktree（cn-web-probe / gfw-probe-runner）在仓库内，各自会话收尾时应迁出或清理；worktree-bootstrap 脚本化 → BL-67。

---
name: feedback_check_parallel_worktrees_before_backlog
description: 认领 backlog/开 feature 分支前先扫 worktree+分支防多会话并行撞车做同一问题
metadata: 
  node_type: memory
  type: feedback
  originSessionId: efa0ba7a-43f3-4880-a77e-bbcbf332c9d9
---

认领 sprint backlog 项 / 开 feature 分支动手前，先 `git worktree list` + `git branch --list '*<keyword>*'`（远程加 `git ls-remote --heads origin '*<keyword>*'`）交叉扫，确认没有别的会话已在做同一问题。命名相近 = 高度疑似撞车，先确认再开工。

**Why**：2026-07-09 修 UDF backlog `handleApiRequest 冷重启空池依赖` 时，全程实现+测试+部署 fe-web×6+合 master（`3632d715`）后，清理阶段才发现另一会话的 worktree `worktree-sw-poolready` / 分支 `feature/udf-sw-apireq-poolready` 在做**逐字等价**的修复（同一行 `await domainPoolReady` + 一个更精巧的 CDP stopWorker/https-origin red-green egress 验证脚本），且停在未提交状态。纯重复，两边算力全白烧——开工前 30 秒的 `git worktree list` 就能避免。多会话共享同一仓库是本项目常态（CLAUDE.md 反复强调 `git fetch` 对齐、shared-master race），撞车面不止 master push，还有"同一 backlog 项被两个会话同时认领"。

**How to apply**：
1. 开工前扫 worktree/分支（关键词取 backlog 项的核心名词，如 `poolready`/`handleapi`），发现疑似撞车先暂停、去那个会话确认分工再动手。
2. 清理别的会话的 worktree/分支前（即便 Owner 授权），先备份其未提交的**独立产物**（非重复的测试脚本/工具），再 `worktree remove --force`——本次那个 red-green egress 脚本就先 `cp` 到 scratchpad 才删。丢弃的重复代码无损，但独立价值的东西删了不可逆。
3. 强删别人正在用的 worktree 会让那个会话后续操作失败，清理后要提示可能需对方 `/clear`。

关联 [[feedback_shared_master_race_push_reject]] [[feedback_shared_checkout_write_ops_owner_check]] [[feedback_safe_branch_worktree_cleanup_protocol]]

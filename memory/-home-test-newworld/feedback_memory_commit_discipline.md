---
name: feedback_memory_commit_discipline
description: memory 写完必须立刻 scripts/nw-memory-commit 单独提交推送，否则被别会话下个 commit 夹带
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 3befc815-5129-4718-9143-cfdb33c0abbd
---

**memory 写完立刻跑 `scripts/nw-memory-commit`（会话收尾第 7 步），别留悬空。**

**Why**：memory 只能事后写（要记 merge sha、"已合 master"、部署结果——这些事实 push 后才存在）。写完不提交就悬在工作树里，而 `precommit-gate.sh` gate0 每次 commit 都跑 `sync-claude-shared.sh` + `git add -A claude-shared` → **下一个 commit（任何会话、任何主题）把它夹带走**。2026-07-09 实测铁证：commit `3a4b2187`（message 写的是"sprint FINDINGS 固化"）夹带了另一会话两个 memory 文件。后果三连：commit message 说谎（撞 [[newworld-commit-message-precision]] 铁律）；异地备份时机不确定（悬空期 memory 只有本机一份，而镜像存在的唯一理由就是随代码 push = 零基建异地备份）；多会话并发追加 MEMORY.md 索引行时 merge 冲突窗口被拉长到"下次有人 commit 为止"。

**根因判断**：夹带是"悬空"的症状，不是 `git add -A` 的原罪。写完立刻提交 → 无悬空可夹带，冲突窗口从小时级压到秒级。

**How to apply**：
- `scripts/nw-memory-commit ["message尾巴"]` = sync + 只 stage `claude-shared/` + commit + push。前置自检拒绝暂存区含非 claude-shared 路径（防它自己夹带）；`NW_MEMORY_NO_PUSH=1` 只提交不推。
- `claude-shared/*` 命中 pre-push docs 类分级 → 跳过测试秒过，成本≈0。
- pre-push 末尾有软守卫（只警告不拦，因 push 时机 ≠ 收尾时机）检测真相源 vs 镜像差异。
- 已否决（勿重复论证）：`merge=union`（索引行常是"待授权→已合"语义修改，union 留下矛盾两行）；post-commit hook 自动 commit（撞 [[feedback_hooks_privileged_infra_invariants]]）；memory 移出 git（丢零基建异地备份）。

**副产物教训（守卫检测口径两坑，红绿对照才暴露）**：比目录一致性用 `rsync -rlcni`——必须 `-c`（比 checksum，否则 git checkout 重写 mtime 致 405 文件全误报）+ 必须 `-l`（真相源 skills/ 有 symlink，缺 -l 时 rsync 往 **stdout** 打 "skipping non-regular file" → 守卫恒真；恒真的警报会被学会无视，等于没有）。

关联 [[reference_safe_branch_worktree_cleanup_protocol]]、[[feedback_shared_checkout_write_ops_owner_check]]（本次合 master 正因本地 master 领先 origin 三个别会话未推送 commit，改走 worktree 基于 origin/master 造 --no-ff merge，只推自己的工作）。

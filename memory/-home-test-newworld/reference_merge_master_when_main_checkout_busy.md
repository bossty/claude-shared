---
name: reference_merge_master_when_main_checkout_busy
description: 主 checkout 被他会话占用(有未推送 commit/未提交改动)时如何安全合 master——临时 detached worktree 合并 + 在主 checkout 推特定 sha，不用 worktree_guard 逃生口
metadata: 
  node_type: memory
  type: reference
  originSessionId: 34df0358-4ba8-477d-9acd-306dfcd48f33
---

**场景**：要合 master，但主 checkout（`/home/test/newworld`）里躺着**别的会话**的未推送 commit + 未提交改动。多会话共享 checkout 下这是常态，不是异常。

**为什么不能直接在主 checkout 合**：`git merge --no-ff <我的分支> && git push origin master` 会把别人**尚未准备好推**的 commit 一起推上去（实例：2026-07-17 主 checkout 躺着 GFW track 的 `a5a504707` +152 行）。

**为什么不能在自己 worktree 里推 master**：pre-push 的 `worktree_guard` 有「master 单点化拦截」——只有主 checkout 允许推 master（BL-47 收口）。它拦得对，**别用逃生口 `NW_ALLOW_WORKTREE_MASTER_PUSH=1` 绕**。

**正解（两步，2026-07-17 BL-15 实跑验证）**：
1. 临时 detached worktree 合并，不碰主 checkout：
   `git worktree add /home/test/worktree-<名>-merge --detach origin/master`
   在其中 `git merge --no-ff <我的分支>` → 得到干净 merge sha（只含我的 commit）。
2. **回主 checkout 推那个特定 sha**（不是推本地 master ref）：
   `cd /home/test/newworld && git push origin <merge-sha>:master`
   —— 守卫满足（在主 checkout 执行），且 push 是纯网络操作**不动主 checkout 的 HEAD 和工作树**，别人的 commit/改动原封不动。

**代价**：主 checkout 的本地 master 与 origin/master 分叉，别人推时会被拒 → 那是正常的共享 master 竞态，fetch+merge 即可，**push 被拒 ≠ 工作丢失**（[[feedback_shared_master_race_push_reject]]）。

## ⚠️ 上述防护会被 `nw-memory-commit` 直接绕过（2026-07-17 实事故，我犯的）

小心地用临时 worktree 合并 + 只推特定 sha 之后，**收尾跑 `scripts/nw-memory-commit` 前功尽弃**：它在**主 checkout** 里 commit+push，push 被拒时自动 `git pull --rebase` 再重推 → **把主 checkout 上他会话的已 commit 工作一并 rebase 并推上 origin**。实测：别人的 `a5a504707` + 期间新提交的一个 commit（共 2 个 GFW docs commit，152+713 行）被我连带推上 origin/master，sha 亦被 rebase 改写（`a5a504707`→`2955259fc`）。

这是 [[feedback_memory_commit_discipline]] 里「夹带」的**反向新变种**：BL-28/BL-37 讲的是「别的会话 commit 夹带走我的 memory 文件」，这里是「我的 memory commit 夹带走别人的代码/文档 commit」。`--only` 划范围**防不住它**——`--only` 约束的是暂存区内容，而被夹带的是主 checkout 上**早已 commit**的东西，它们是被 `push` 而非被 `add` 带走的。

**本次危害小属运气**：两个 commit 纯 docs 零代码，master「永远可部署」不变量未破；若那是别人未测完的代码，就是把未测代码推上 master。

**动作**：跑 `nw-memory-commit` 前先看主 checkout 有无他会话未推送 commit（`git log --oneline origin/master..HEAD`）；非空则先与 Owner 确认，别默默替别人做推送决定。事后必核：`git log --oneline origin/master -5` 看有没有不属于自己的 commit 被推上去。

**收尾**：删分支前 merged+pushed 双验（[[reference_safe_branch_worktree_cleanup_protocol]]）。注意 `git branch -d` 会失败——它相对**当前 HEAD** 判断已合并，而主 checkout 的 HEAD 是别人的 commit、不含你的 merge；先用 `git merge-base --is-ancestor <分支> origin/master` 确认是真祖先，再 `-D` 删。

关联：开工前扫 worktree 防撞车 [[feedback_check_parallel_worktrees_before_backlog]]；共享 checkout 写操作先认 HEAD 属主 [[feedback_shared_checkout_write_ops_owner_check]]。

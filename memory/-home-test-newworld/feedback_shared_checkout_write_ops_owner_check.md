---
name: shared-checkout-write-ops-owner-check
description: "共享 checkout 上任何写操作（含 checkout -- \"清残留\"/rm untracked/merge）前必先认 HEAD 属主——别会话可能已切走分支；master 更新永远 --ff-only"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 664b697b-6c53-4b92-9602-00a3fa3a223a
  modified: 2026-07-22T11:49:37.160Z
---

主 checkout 是多会话共享的：任何写操作（包括看似无害的 `git checkout -- <file>` "清理残留"、`rm` untracked 文件、`merge`）之前必须先 `git symbolic-ref HEAD` 确认它当前在哪个分支——别的会话可能随时把它切到自己的活跃分支。

**Why:** 2026-07-05 实踩：我以为主 checkout 在 master 上"清理别会话留下的残留"，实际它已被切到 `fix/viewcount-pending-hdel`（另一会话活跃分支）；且被我抹掉的"残留"是**功能性覆盖层**（工作树 `.claude/settings.json` 承载着 nw-cap hook 注册、`rm` 掉的 hook 脚本让本会话每条 Bash 立即报错，还造成短暂的先有鸡还是先有蛋——恢复文件需要 Bash 而 Bash 被 hook 卡死，靠 Read+Write 从 worktree 副本绕出）。`merge --ff-only` 因分支分叉而中止，若用裸 merge 会在别人分支上造出合并提交。

**姊妹坑：`git checkout <branch>` 在该分支已被别的 worktree 占用时静默失败**（2026-06-23 实踩，channel-anomaly 告警去重那次）：`git checkout master >/dev/null 2>&1` 连续两次都没切成功（master 当时挂在 `/home/test/nw-h2` worktree），报的是 exit 128 `fatal: 'master' is already used by worktree at ...`，但重定向把它吞了 → 后续分支基线判断全错、cherry-pick 落错分支。**故切分支后必 `git branch --show-current` 复核实际落在哪个分支**，别信「checkout 命令返回了就等于切过去了」；动手前 `git worktree list` 先看谁占了；要动被占用分支用 `git -C <该 worktree 路径> cherry-pick`。

**How to apply:** ①动手前 `git symbolic-ref HEAD` 认属主 + `git status` 看清 M/untracked 的内容归属（与哪个分支/commit byte 级一致，diff 为 0 才算"确证冗余"）；②共享 checkout 更新 master 永远 `git merge --ff-only`，禁裸 merge；③"清理"也是写操作，同样受 [[audit-methodology]] "不碰你没创建的"约束；④误删活跃 hook 脚本时用 Read+Write（非 Bash）从 worktree/origin 副本恢复。相关 [[deploy-git-preflight-2026-07-05]]；skill 版已固化于 newworld-dev-workflow §1b。

**2026-07-23 增补（doc-truth-program 实证）**：多 agent 共享 checkout 期间，`git add <paths>` 后的裸 `git commit` 会把**其他会话暂存在共享 index 的内容整体夹带**（实测差点带走别 agent 的 190 档删除批，message 说谎 195 文件）。修复=一律 `git commit -o <paths>`（--only 只提交指定路径、不动暂存区其余）；对方侧纪律=stage 后立即 commit 不挂 index。与 [[feedback_memory_commit_discipline]] 同型（那边是 memory 目录版）。

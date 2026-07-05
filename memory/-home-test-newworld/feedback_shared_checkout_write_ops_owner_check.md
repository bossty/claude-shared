---
name: shared-checkout-write-ops-owner-check
description: "共享 checkout 上任何写操作（含 checkout -- \"清残留\"/rm untracked/merge）前必先认 HEAD 属主——别会话可能已切走分支；master 更新永远 --ff-only"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 664b697b-6c53-4b92-9602-00a3fa3a223a
---

主 checkout 是多会话共享的：任何写操作（包括看似无害的 `git checkout -- <file>` "清理残留"、`rm` untracked 文件、`merge`）之前必须先 `git symbolic-ref HEAD` 确认它当前在哪个分支——别的会话可能随时把它切到自己的活跃分支。

**Why:** 2026-07-05 实踩：我以为主 checkout 在 master 上"清理别会话留下的残留"，实际它已被切到 `fix/viewcount-pending-hdel`（另一会话活跃分支）；且被我抹掉的"残留"是**功能性覆盖层**（工作树 `.claude/settings.json` 承载着 nw-cap hook 注册、`rm` 掉的 hook 脚本让本会话每条 Bash 立即报错，还造成短暂的先有鸡还是先有蛋——恢复文件需要 Bash 而 Bash 被 hook 卡死，靠 Read+Write 从 worktree 副本绕出）。`merge --ff-only` 因分支分叉而中止，若用裸 merge 会在别人分支上造出合并提交。

**How to apply:** ①动手前 `git symbolic-ref HEAD` 认属主 + `git status` 看清 M/untracked 的内容归属（与哪个分支/commit byte 级一致，diff 为 0 才算"确证冗余"）；②共享 checkout 更新 master 永远 `git merge --ff-only`，禁裸 merge；③"清理"也是写操作，同样受 [[audit-methodology]] "不碰你没创建的"约束；④误删活跃 hook 脚本时用 Read+Write（非 Bash）从 worktree/origin 副本恢复。相关 [[deploy-git-preflight-2026-07-05]]；skill 版已固化于 newworld-dev-workflow §1b。

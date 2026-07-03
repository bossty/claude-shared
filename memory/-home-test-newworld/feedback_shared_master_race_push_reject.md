---
name: feedback_shared_master_race_push_reject
description: 多会话共享仓库里 git push 被拒≠工作丢失；判工作是否到远端用 merge-base --is-ancestor origin/master，别读竞态的共享 master ref
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 293fba68-3676-40ca-9c18-59b8e428181f
---

多会话共享同一本地仓库（多 worktree + 共享 `.git`）时，本地 `master` ref 会被并发会话实时移动/reset/pull，**你对 `master` 的任何读取都是竞态快照**。

**Why**：2026-07-04 D 组测试合 master 后 `git push origin master` 被拒（并发会话已把 origin 推进到 `bfd7c30e`）。随后读本地 `master` 发现指向 `bfd7c30e`（别会话在共享主工作树 reset/pull 所致），一度**误判"我的合并被覆盖、工作丢失"**。实际上 `bfd7c30e` **包含**我的合并 `272aed0d`——并发会话是在含我合并的共享本地 master 之上继续提交再 push 的，我的合并作为祖先对象随之上了 origin。**push 被拒 ≠ 工作丢失**。

**How to apply**：
1. **判工作是否到远端**：`git merge-base --is-ancestor <我的commit> origin/master`（先 `git fetch`）。返回真=已在远端，无需再推。**别靠 `git log master` / `git ls-tree master`** 下结论——那个 ref 被并发会话移动，读到的是瞬时竞态值。
2. **唯一稳定锚点**：自己的 feature 分支（并发会话一般不动）+ origin（push 有 CAS 原子拒绝）。要落地就把 origin/master 并进 feature 再 push `feat:master`（ff 或 --no-ff），被拒就 re-fetch/re-merge 重试——全程**不碰共享主工作树的 master**。
3. **push 被拒先 fetch 看真实关系**再动手：`git log master..origin/master` / `origin/master..master` 判 ahead/behind，`--is-ancestor` 判包含；divergent 才需合并，包含则已 ff-able。
4. 主工作树被别会话占用（HEAD 在别的分支）时，**不要在主工作树切 master 做合并**（会和对方抢 ref）；用自己的 worktree/feature 分支操作。

关联：[[feedback_feature_branch_deploy_test_then_merge]]（feature 分支流程）、[[feedback_perf_rca_deploy_gotchas_2026_06_16]]（多会话 master 踩坑）、[[reference_safe_branch_worktree_cleanup_protocol]]（清理需 merged+**pushed** 验，本次即用 `--is-ancestor origin/master` 验后才删 worktree+分支）。

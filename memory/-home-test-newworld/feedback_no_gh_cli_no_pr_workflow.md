---
name: no-gh-cli-no-pr-workflow
description: gh CLI 未安装且本项目不走 PR 流程——GitHub 远端查询用 git ls-remote，别再试跑 gh
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 664b697b-6c53-4b92-9602-00a3fa3a223a
---

本机未安装 gh CLI（`failed to run command 'gh'` 已跨会话反复触发多次，Owner 2026-07-05 确认不需要）。本项目 GitHub 仓库（bossty/newworld）**从未用过 PR**：`git ls-remote origin | grep -c refs/pull` = 0（2026-07-05 实测），也无 GitHub Actions——CI 是本地 pre-push 门禁（`scripts/pre-push-gate.sh` → `ci-local.sh`）。单人开发合并流程 = feature/fix 分支 push + 本地门禁 + Owner 授权后本地 `--no-ff` 合 master，PR 的评审职能由蓝军 agent / crossfire 承担（见 [[feature-branch-deploy-test-then-merge]]）。

**Why:** Claude Code 默认指引推荐用 gh 做 GitHub 操作，每个新会话不知道它没装就去试，报错浪费轮次；且"仓库有 PR"是误认——GitHub 分支 push 后的"Compare & pull request"黄条是建 PR 邀请，不是已存在的 PR。

**How to apply:** 查远端分支/tag/PR 引用一律用 `git ls-remote origin`（PR 会以 `refs/pull/N/head` 出现）；不要安装 gh、不要建 PR（除非 Owner 未来为 /code-review ultra <PR#> 等场景明确要求）。

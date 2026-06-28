---
name: feedback_no_headless_claude_cli_other_account
description: 禁从一个会话的 headless Bash 对另一个账户的 config dir 跑 claude CLI（CLAUDE_CONFIG_DIR=别账户 claude ...）——会回写凭证清空它=把那账户登出
metadata:
  type: feedback
---

**禁从当前会话的 headless Bash 对另一个 Claude Code 账户的 config dir 跑 `claude` CLI**（任何子命令，如 `CLAUDE_CONFIG_DIR=/home/test/.claude-work claude plugin disable/list`）。

**Why**：2026-06-28 实锤事故——我这趟（A 账户会话）为给 B 账户（`.claude-work`）做 plugin 去重，跑了 `CLAUDE_CONFIG_DIR=/home/test/.claude-work claude plugin disable newworld@...`。`claude` CLI 在 headless 环境对 B 的 config dir 触发凭证刷新/回写，但**拿不到 B 的真实 OAuth（无浏览器/无 keychain）→ 把 B 的 `.credentials.json` 的 accessToken/refreshToken 写成空（len=0）、expiresAt=0 = 把 B 登出**。B 的活会话靠内存旧 token 撑了半天，到需要刷新时发现 refreshToken 空 → 掉登录。无备份、refreshToken 空 = 程序不可恢复，只能用户**交互式 re-login**（`CLAUDE_CONFIG_DIR=… claude` → `/login`，OAuth 流程 agent 做不了）。代价：B 掉线 + 用户手动重登。而起因只是个"锦上添花"的 plugin 去重——不值。

**How to apply**：
- 改另一个账户的 plugin/config，要么**进那账户的真实交互会话里做**，要么**直接小心编辑它的配置文件**（installed_plugins.json / settings.json / known_marketplaces.json），**禁走 `CLAUDE_CONFIG_DIR=别账户 claude <任何子命令>`**。
- **永远别碰任一账户的 `.credentials.json`**（读都尽量只读字段不读值；绝不写）。
- 跨账户操作前先问"这值得吗"——多数跨账户便利改动（去重/对齐）不值用登出风险换。
- 诊断"某账户掉登录"：查其 `.credentials.json` 的 accessToken/refreshToken 是否 len=0 + mtime 是否撞上某次 `CLAUDE_CONFIG_DIR` 命令（本次 22:34 撞我命令时段坐实）；登录与 skills/memory（symlink 数据）无关，重登后数据照常。

关联 [[feedback_verify_not_recall]]（工具实证定位非凭猜）；本坑发生在 [[project_toolchain_realignment_2026_06_27]] 的双账户统一收尾。

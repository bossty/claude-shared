---
name: feedback-dual-account-permissions-sync-and-allow-syntax
description: Owner 铁律:双账户(~/.claude 与 ~/.claude-work)的 permissions 配置必须同步——同步已有机制,改真相源 shared.json 别直改账户;附 allow 规则语法坑 Bash(*) 无效
metadata:
  type: feedback
---

Owner 指令（2026-07-22）：本机双账户（A=`~/.claude`、B=`~/.claude-work`）**除账户信息类配置外，`permissions` 权限配置必须两边同步**。

**同步已有现成机制（2026-06-28 S7 建，勿再手工照抄）**：真相源 `~/claude-shared/settings/shared.json` + `bash ~/claude-shared/scripts/sync-settings.sh`（对两账户各自 `.bak` 后 merge：**permissions 段以 shared 整段覆盖**——2026-07-22 由"并集只增"改语义：手改账户文件会被 cron 一小时内纠回、删条目自动传播；账户私有偏好 theme/effortLevel/hooks/statusLine 不动、红线不碰 `.credentials.json`）。**改权限必须改 shared.json**（增删皆是）——直改账户文件无效，cron 会按 shared 整段覆盖纠回（红绿双验实证：手加探针条目被纠回、shared 删条目双账户传播、终态幂等"无变化"零写盘）。2026-07-22 已把 shared.json 与两账户统一为 36 条有效规则并实证 sync 幂等（跑完仍 36 条、两账户 permissions 块逐字 `==`）。**同步已自动化（2026-07-22）**：cron 每小时 07 分跑 `sync-settings.sh`（日志 `~/.local/state/newworld/sync-settings.log`）；脚本已加「无变化不写盘不留 .bak」并红绿双验（GREEN=无变化跳过、RED=真相源加探针条目两账户 1 分钟内同步+留 bak）。

**Why:** 双账户会话随 `$CLAUDE_CONFIG_DIR` 切换，只改一边则另一账户会话行为漂移；不改真相源则机制反过来吃掉手工修正（见 [[settings-editing]] rule 判错 3 次教训）。

**How to apply:**
- 改 permissions：只改 `~/claude-shared/settings/shared.json`（增删皆可，整段覆盖语义）；等 cron 或手动 `bash ~/claude-shared/scripts/sync-settings.sh` 即时生效。注意同步是**单向星型**（shared→两账户），非双向；弹窗"始终允许"写的是项目 `settings.local.json`，与本机制无关。
- **allow 规则语法坑（官方文档实证，2026-07-22）**：`Bash(*)`/`Read(*)`/`Write(*)`/`WebFetch(*)` 这类无锚点通配在 **allow 里是无效语法、被静默跳过**（deny 里才等价于裸工具名）——曾导致"全放开"从未生效、用户被迫手点 94 条"始终允许"。全放开正确写法=**裸工具名不带括号**（`Bash`/`Read`/`Write`）；MCP 通配必须带 `mcp__<server>__` 锚点（无锚 `mcp__*` 同样被跳过）；Bash 前缀匹配用 `Bash(git diff:*)` 冒号星。
- 各文件 allow **不是并集合并**：按 managed > CLI > 项目 local > 项目共享 > 用户级优先序取用，且任何一层的 deny 一票否决所有 allow；项目 `.claude/settings.json` 的 4 条 deny（.env/.pem/id_rsa）是有意保留的保险，禁删。
- **裸工具名 allow ≠ 覆盖仓库外路径（2026-07-23 实证）**：`Edit`/`Write` 裸放行只作用于权限范围（项目 cwd）内；仓库外真相源（`~/claude-shared/**`、`~/.claude-work/projects/<proj>/**`）每次仍弹询问。修法=把目录加进 `permissions.additionalDirectories`（已加这两个），既有裸 allow 随即覆盖。注意 `.claude-work` 下 memory 是 symlink 到 claude-shared，两路径都列保险。

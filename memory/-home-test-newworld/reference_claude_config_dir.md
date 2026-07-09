---
name: reference-claude-config-dir
description: "Owner 用 `claude-work` alias 启动 Claude Code，CLAUDE_CONFIG_DIR=~/.claude-work 重定向所有配置目录"
metadata: 
  node_type: memory
  type: reference
  originSessionId: da3be312-2b73-46c3-95da-580bd268b069
---

Owner 通过 alias 启动 Claude Code：

```bash
alias claude-work='CLAUDE_CONFIG_DIR=~/.claude-work claude'
```

定义在 `~/.bashrc`。`CLAUDE_CONFIG_DIR` 是 Claude Code 官方支持的环境变量，把**所有**配置/数据/状态从默认 `~/.claude/` 切到指定目录。

## 真实生效的配置路径（claude-work alias 启动时）

| 路径 | 用途 |
|------|------|
| `~/.claude-work/settings.json` | 用户级 settings（permissions / hooks / plugins / model 等） |
| `~/.claude-work/projects/<encoded-cwd>/memory/` | per-project memory（如 `-home-test-newworld/memory/`） |
| `~/.claude-work/teams/<team-name>/` | Agent Team 配置 + task list |
| `~/.claude-work/tasks/` | TaskCreate 持久化 |
| `~/.claude-work/skills/` | 用户自建 skill |

## 易踩的坑

- ❌ **不要往 `~/.claude/settings.json` 加 permissions / hooks**：那是 vanilla `claude` 启动时用的，`claude-work` 不读。
- ❌ **不要把 `.claude-work/` 当成"数据目录"和"配置目录"分开理解**：CLAUDE_CONFIG_DIR 一并切了，settings.json 也在里面。
- ❌ **项目级 `<repo>/.claude/settings.json` 仍照常读**（项目级与全局级合并），与 CLAUDE_CONFIG_DIR 无关。

## 如何确认

`grep -EH 'alias.*claude' ~/.bashrc` 或 `env | grep CLAUDE_CONFIG_DIR`（在 claude session 内 Bash 跑）。

## 历史教训（2026-05-15）

Owner 抱怨"`.claude-work/settings.json` 已开放所有权限了为什么还在询问"。我（Claude）误以为 `.claude-work/` 是数据目录、settings 应在 `~/.claude/`，**误删 `.claude-work/settings.json`** 又往 `~/.claude/settings.json` 加补 28 项 allow。Owner 提示 alias 后才发现搞反了：alias `CLAUDE_CONFIG_DIR=~/.claude-work` 让 `.claude-work/` 才是真生效目录。已恢复 `.claude-work/settings.json` + revert `~/.claude/` 误加项。

## 2026-07-08 起：共享键收进 managed settings（改法变了）

`/etc/claude-code/managed-settings.json`（root 所有，改需 sudo）托管 `enabledPlugins`（含 4 个 LSP plugin=true、context-mode/newworld marketplace=false）+ `env`（DISPLAY/AGENT_TEAMS/BASH 超时/禁鼠标）——**对两个账户同时强制生效，优先级最高**。两份用户级 `settings.json` 已删除这两个键（备份 `settings.json.bak-managed-20260708`），只留 model/permissions/hooks 等真 per-account 项。

- **改 plugin 启停 / 共享 env：sudo 改 managed-settings.json，重开会话生效。别再改用户级**（改了会被 managed 静默覆盖，看起来"没生效"）。
- 旧铁律"先 echo $CLAUDE_CONFIG_DIR 认账户"仍适用于 model 等剩余 per-account 键。
- Vue LSP 无官方 plugin，走项目级 `.lsp.json`（vue-language-server + @vue/typescript-plugin hybrid），不计入"plugin LSP servers"计数（该计数=4 是对的）。
- `/reload-plugins`/`/reload-skills` 的计数含 plugin 自带 skill（73=自有 33 + plugin ~40），07-08 对账全部精确吻合，非损坏。
- ⚠️ 07-08 二次修复：SessionStart hook `sync-toolchain.py` 原本会把 shared.json 基线里的 enabledPlugins/env 回填进用户级 settings（首次清理被它复活了一份旧快照）。已改脚本：这两键退出同步域，且每次运行主动从 shared.json + 两账户擦除残留（幂等验证 PASS）。
- 07-08 追加：sync-toolchain 的 SessionStart hook 也上收 managed-settings（用户级已删）。终态：**账户级共享项（enabledPlugins/env/hooks）全在 managed**；项目级 hooks 随仓库 `.claude/` 走；用户级只剩 model/permissions/theme 等真私有键。watchdog 阈值 WARN=100K/STRONG=200K（200K=1M 模型长上下文溢价悬崖）。
- 07-08 终态2：Owner 定「除账户 ID 全共享」→ sync-toolchain 同步域推广到 settings **全部顶层键**（补缺失不覆盖语义）。两账户 settings 已收敛到仅 permissions 列表顺序不同（语义等价）。**仍各账户独立、不share**：.credentials.json/.claude.json（身份，红线）+ 运行态目录（sessions/history/cache/daemon/file-history——双账户并发写会互踩，且共享无收益）。

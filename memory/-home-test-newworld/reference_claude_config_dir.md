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

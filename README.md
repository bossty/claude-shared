# claude-shared — 双账户 Claude Code 工程化体系唯一真相源

> 建立：2026-06-27 toolchain-realignment sprint（`~/newworld/docs/sprint/2026-06-27-toolchain-realignment/`）。
> 解决：`~/.claude`（账户 A）与 `~/.claude-work`（账户 B）的 skills/memory/规范漂移（A 34 skill/91 memory，B 0 skill/143 memory，重叠 <1%）。
> 机制：本 git repo 为唯一真相源，两账户 symlink 引入 → 改一处两账户同步 → git 记录每次演进。
> 远端：**GitHub 私有仓库 `bossty/claude-shared`（2026-07-03 Owner 定,推翻此前"无远端"）**,由 backup cron 每日推送;主项目 repo 不承载本仓（多会话分支切换会让真相源随分支漂移 + 部署到生产节点扩大暴露面）。

## 结构
```
skills/                  35 个 newworld-* 铁律 skill（flat .md，唯一真相源）
memory/-home-test-newworld/   230 条文件式 memory 并集 + MEMORY.md 索引 + MERGE-REPORT.md
scripts/
  skill-drift-check.js   真相源 skills ↔ repo plugin newworld-<X>/SKILL.md 陈旧即红（CI 红灯）
  skill-lint.js          description 体检（触发条件化、禁夹带正文）
settings/                共享 settings 片段（S7 待做，逐项甄别账户私有项）
plugin-manifest.md       canonical plugin 集 + 版本对齐基准
SKILL-DRIFT-REPORT.md    首轮 skill 漂移基线
```

## 不进真相源（账户私有/瞬态）
凭证 / sessions / history / projects 下的 transcript / cache / tasks / settings.json 账户私有段。

## 日常 SOP
- 改 skill / 写 memory：直接改（两账户 symlink 同一物理文件，即时共享）。
- 阶段性 `cd ~/claude-shared && git add -A && git commit -m "..."`。
- 改 skill 后：`node scripts/skill-drift-check.js` 必绿（再按 CLAUDE.md 同步进 repo `claude-plugin/newworld` + bump version）。
- 装第三方 plugin/skill 前：过 SkillSpector `--no-llm`（见 sprint 矩阵主题 E）。
- 铁律层 **copy-not-install**：禁 symlink 上游第三方 repo、禁第三方 hook 注入会话。

## symlink 接线（S5，Owner 复核 MERGE-REPORT 后执行）
```
~/.claude/skills                                  -> ~/claude-shared/skills
~/.claude/projects/-home-test-newworld/memory     -> ~/claude-shared/memory/-home-test-newworld
~/.claude-work/skills                             -> ~/claude-shared/skills
~/.claude-work/projects/-home-test-newworld/memory-> ~/claude-shared/memory/-home-test-newworld
~/.claude/plugins                                 -> ~/.claude-work/plugins   # 2026-07-03:插件实体/marketplace/安装登记共享(B 为物理主,plugins 大缓存不入本 repo 防 tar 快照膨胀)
```

## 双账户自动同步（2026-07-03 起）
四层,任一账户改动另一边自动拿到:
| 层 | 机制 | 时效 |
|---|---|---|
| skills / memory | symlink 同一物理文件 | 即时 |
| plugin/marketplace 安装与卸载 | `~/.claude/plugins` symlink → B 的 plugins | 即时 |
| MCP | 全部经 plugin 或项目 `.mcp.json` 交付(两账户均无 user-scope MCP,保持此姿态) | 即时 |
| settings 共享域(enabledPlugins/permissions.allow/env/marketplace 登记/skillOverrides/disabledMcpjsonServers) | `scripts/sync-toolchain.py` harvest+apply,由**两账户 SessionStart hook** + 每日 backup cron 触发 | 下次开会话 |

语义:已声明的值账户优先(允许两边故意不同,如 context-mode A 关 B 开);只补缺失 key;卸载经共享安装登记 prune 传播;`model`/`effortLevel`/`hooks`/通知类等私有 key 永不同步。**user-scope MCP 别再用 `claude mcp add --scope user`**(落在账户私有 `.claude.json`,不在同步面),要么进项目 `.mcp.json` 要么走 plugin。

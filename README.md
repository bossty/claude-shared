# claude-shared — 双账户 Claude Code 工程化体系唯一真相源

> 建立：2026-06-27 toolchain-realignment sprint（`~/newworld/docs/sprint/2026-06-27-toolchain-realignment/`）。
> 解决：`~/.claude`（账户 A）与 `~/.claude-work`（账户 B）的 skills/memory/规范漂移（A 34 skill/91 memory，B 0 skill/143 memory，重叠 <1%）。
> 机制：本 git repo 为唯一真相源，两账户 symlink 引入 → 改一处两账户同步 → git 记录每次演进。**仅本地 git，无远端**（Owner 定，单人开发风险可控）。

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
```

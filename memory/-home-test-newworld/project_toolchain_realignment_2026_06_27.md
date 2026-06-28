---
name: project_toolchain_realignment_2026_06_27
description: 2026-06-27 工具链调研+双账户统一 sprint：建 ~/claude-shared git 真相源、13源取长补短、A/B 账户漂移止血
metadata:
  type: project
---

2026-06-27 toolchain-realignment sprint（13 外部源取长补短 + 双账户工程化体系统一）。

## ★ 最关键 durable 事实：~/claude-shared 是 skill+memory 唯一真相源
- `~/claude-shared/`（本地 git，**无远端**，Owner 定单人开发风险可控）= skills(35) + memory(232 .md 并集) + scripts(治理) + plugin-manifest。
- 两账户已 **symlink** 到它：`~/.claude/skills` 与 `~/.claude-work/skills` → `~/claude-shared/skills`；两账户 `projects/-home-test-newworld/memory` → `~/claude-shared/memory/-home-test-newworld`。**改一处两账户同步**。原目录留 `.pre-symlink` 兜底。全备份 `~/.claude-backups/toolchain-20260627-211430`。
- 漂移根因（已止血）：A 曾 34skill/91memory、B 0skill/143memory，memory 近乎全裂脑（重叠<1%），已非破坏并集合并（零丢失实证）。
- 治理脚本：`scripts/skill-drift-check.js`（真相源↔repo plugin `claude-plugin/newworld` byte-compare，陈旧即红，替代人肉「home 改必同步 plugin」）+ `skill-lint.js`（description 体检）。**改 skill 后必跑 drift-check 回绿 + 同步 plugin + bump version**。

## 调研结论（13源，0个整包安装）
- 铁律：**copy-not-install**——禁 symlink 上游第三方 repo、禁第三方 hook 注入会话、禁 npx/curl|bash 安装器（SkillSpector 实测连扫自己+superpowers 都判 DO_NOT_INSTALL=二元裁决是噪声，价值在 issue 清单当 checklist）。
- 落地：新建 skill `newworld-audit-rigor`（双引证 finding+3类高漏报+attacker=victim+豁免纪律）；编辑 `multi-agent-coord`（蓝军只传 ARTIFACT+CONTRACT 不传 CLAIM+跨模型只读二审）；`commit-message-precision`（diff 可视化对照）。全文 `docs/sprint/2026-06-27-toolchain-realignment/`。

## 账户/plugin 状态
- A 补装 4 plugin：lua-lsp/playwright/skill-creator/claude-api（A 原缺；newworld plugin **不装**，软链已覆盖防双载）。
- B 的 newworld plugin（v0.1.0/32skill 陈旧子集）**已 disable**（软链给 B 最新35，消双载，可 enable 回滚）。
- repo plugin `claude-plugin/newworld` bump 0.1.6→**0.1.8**（35 skills，**已合 origin/master `b067900c`**；reconcile 过别会话的 0.1.7+dev-workflow 撞车）。

## staleness 退役（Owner 逐条审 + 实证）
- `cf-tunnel-edge-region-placement` §1/§2「US需俄勒冈+加州双region」结论被终态B推翻，加 superseded 横幅（方法论保留）。
- `deploy-runbook`：region US(俄勒冈)行标退役；**EU REDIS_REPLICA_HOST .248→172.33.3.184**（eu-web-01 /proc/environ 实证更正，旧值错）。

## 未完（Owner 节奏）
**已合 origin/master**（`b067900c` 双账户统一+plugin 0.1.8 + `d1c98ba8` README/一致性修复 + 独立审纠正）。剩 S7 settings 共享片段甄别 + plugin 版本对齐(chrome-devtools/pua)；P4 三战略项（SkillSpector 制度化/RED-GREEN 压测/codebase-memory 试点）；A 桶降级逐条 Owner 审。★crossocean 教训：RED-GREEN 没度量到它，prod 模式 sound 但非 PROVEN（我判 3 次靠独立审兜底）。

关联 [[project_terminal_arch_B_single_california]] [[project_eu_redis_separation]] [[feedback_feature_branch_deploy_test_then_merge]]

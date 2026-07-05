---
name: feedback-heavy-cmd-ctx-routing
description: 【已反转】重命令减噪走 nw-cap 纪律（落文件+tail/grep），context-mode ctx 路由已被 A/B 实验证伪并停用（2026-07-05）
metadata:
  node_type: memory
  type: feedback
  originSessionId: e78b8dd9-c86a-4112-9028-289062aadd6a
---

重命令（**大输出 + 只需要派生结论**）减噪走 **nw-cap 纪律**：`scripts/nw-toolbox/nw-cap <命令>`（全量落文件、终端只回行数+头尾、原文随时 grep），或 `| tail -30` / `grep 关键行` / 重定向落文件。**不再走 context-mode ctx 路由**。

**Why:** 本条原版（2026-06-13）主张"默认走 ctx_batch_execute"，依据是单臂实测 137× 杠杆。2026-07-05 A/B 实验证伪：同批 4 条 ops 命令，纪律化 Bash 进会话 3,411 字节且答案齐全，ctx 路由 19,148 字节且 2/4 查询没答上（约 5.6× 差距）；插件自报节省以"裸吞全量"为假设，对照真实基线夸大 50~450×；历史提示注入成本（~69 万 token）超过其自报累计节省（516,608）。context-mode 插件已停用（`~/.claude-work/settings.json` enabledPlugins=false）。全文见 `docs/sprint/2026-07-05-context-mode-ab/POC-FINDINGS.md`。

**How to apply:**
- 大输出只要结论 → `nw-cap` 或 tail/grep/落文件；小固定输出（`git status`/`pwd`）和状态变更命令直接 Bash。
- "该触发时触发"由 PreToolUse hook `.claude/scripts/nw_cap_reminder.py` 保障：命中大输出特征（journalctl/git log/mvn/大 SELECT/find -exec/grep -r 等）且无减噪手段时注入一行提醒；已减噪或非重命令零注入。
- 相关：headroom 评估结论见 [[project-context-mode-retire-headroom-eval-2026-07-05]]。

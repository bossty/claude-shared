---
name: project_nwcap_hook_deny_upgrade_2026_07_07
description: "nw-cap hook排查定案(subagent里本就生效,转录06-19后不记hook是假象)+升级三类deny硬拦+误判修复+落日志,合master f0a01c43"
metadata: 
  node_type: memory
  type: project
  originSessionId: d7b9558f-ee49-4bcb-b477-b4c0049c2f77
---

2026-07-07 Owner 问「nw-cap hook 对 subagent 没生效？」排查定案 + 升级（合 master `f0a01c43` 已推送）：

**排查结论（三步实证）**：
1. hook 对 subagent **本就生效**——现场实验：subagent 跑裸 `git log -n 3` 逐字引用出注入提醒；升级后再实验 deny 真实拦截。
2. 「没生效」是观察假象：**2026-06-19 前后起 Claude Code 不再把 hook 执行记录（attachment/hook_success）写进 subagent 转录 jsonl**——之前每次 Bash 都有（06-06 会话 32779 条），之后全零。查转录看不到 ≠ 没触发。
3. 真实缺口是 MITIGATED 正则误判：`2>/dev/null`（丢 stderr 不减 stdout）被当减噪 + `-c\b` 过宽，近3天 subagent 口径漏提醒 25/233 条。

**升级内容（.claude/scripts/nw_cap_reminder.py）**：
- 误判修复：判减噪前剥 `2>...` 重定向；删 `-c\b`。
- 三类几乎必然大输出升级 **permissionDecision=deny 硬拦**（其余仍提醒）：journalctl 无 `-n/--since/--until`、mvn/gradle/npm 构建测试无落地、SELECT 无 LIMIT 且非聚合（COUNT/SUM/AVG/MAX/MIN 豁免）。`git commit/echo/printf` 文本豁免防误杀提交信息。
- 每次 remind/deny 追加一行日志到 `~/.local/state/newworld/nw_cap_hook.log`——subagent 转录不记 hook 后的**唯一跨会话观测面**（可审计提醒后遵守率）。
- 验证：16 例 should-trigger/should-not-trigger 矩阵全过 + 2 次 subagent 端到端实验。

**Why**: 机制层>纪律层（同 Gate A / worktree 硬拦一脉）；提醒已注入但遵守靠模型自觉，最贵的三类违规必须硬拦。选项3（agent 定义加常驻纪律行）被否——与 [[project_context_mode_retire_headroom_eval_2026_07_05]] 证伪的常驻注入同构，成本大概率超收益。

**How to apply**: 审计 hook 是否触发别再 grep subagent 转录（06-19 后必零），看 `~/.local/state/newworld/nw_cap_hook.log` 或现场派 subagent 实验；改 hook 行为后必跑 should/should-not 矩阵 + subagent 端到端各一次。

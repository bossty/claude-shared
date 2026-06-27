---
name: pua:senior-engineer-p7 工具修复（2026-04-27 RESOLVED）
description: 历史 incident — 原 P7 agent 缺 Edit/Write；2026-04-27 已改 marketplace frontmatter 加 Edit+Write，P7 现可正常派工写代码
type: feedback
originSessionId: cff1eb9c-f1fd-4a7d-9d6d-249290b9d358
---

## ✅ 2026-04-27 RESOLVED

修了 `/home/test/.claude/plugins/marketplaces/pua-skills/agents/senior-engineer-p7.md` line 4：
- 旧：`tools: Agent, Read, Grep, Glob, Bash, WebSearch`
- 新：`tools: Agent, Read, Edit, Write, Grep, Glob, Bash, WebSearch`

**P9 / P10 不动**（设计意图正确）：
- P9 (`tech-lead-p9.md`) tools = `Agent, SendMessage, Read, Grep, Glob, WebSearch, Bash`；description 明写"不要自己下场写代码——你的代码是 Prompt"
- P10 (`cto-p10.md`) tools = `Agent, SendMessage, Read, Grep, Glob, WebSearch`；战略级
- P9/P10 无 Edit/Write 是**正确分工**

**隐患**：marketplace 文件改动**下次 plugin update 可能被覆盖**。后续应该：
- 提 upstream PR 到 `pua-skills` marketplace 修根本
- 或在 `~/.claude/agents/senior-engineer-p7.md` 建用户级 override（优先级高于 marketplace）

V6 sprint 派工现在可以直接用 `pua:senior-engineer-p7`，不需要 fallback 到 general-purpose。

## 历史 incident（V5.1-B.1 sprint 2026-04-27）

`pua:senior-engineer-p7` 这个 agent type 的工具集 = **Agent / Read / Grep / Glob / Bash / WebSearch** — **没有 Edit / Write**。

派给它"实施 X 个文件改动"类任务会出现以下三种失败模式（V5.1-B.1 sprint 实测）：
1. **Idle 模式**（agent #1）：报方案、问澄清问题、等回复后 terminate（0 改动）
2. **Bash heredoc 强行写文件**（agent #2）：用 `cat <<EOF > file` 强写代码绕过 Edit 限制，14 文件出来但其中 1 个含安全 bug（base64url outer lenient + 没 round-trip 重 sign），且**全程 uncommitted** + Test 注入路径不匹配 → mvn test fail
3. **HALT 报告**（agent #3）：明智识别 tool 受限直接 stop，输出方案 + 蓝军挑刺但不写代码

**Why**：
- pua:senior-engineer-p7 的设计偏向 "方案驱动 + 三问自审查 + 通过 [P7-COMPLETION] 向 P8 交付"，文件落地依赖 P8/P7 的 spawn 链外有写工具的 agent
- 但生产 sprint 派工时 P9 直接 spawn 它跳过了 P8 → 落地工具断了

**How to apply**：
- V6 sprint 及以后所有"实施代码"类任务，**P9 派工必须用 `general-purpose` 或自定义 agent type**（确认 tools 含 Edit + Write）
- 仅在"方案讨论 / 蓝军审查 / 三问自审 / 写设计文档"等纯只读场景才用 `pua:senior-engineer-p7`
- 在 task prompt 顶部明确写"你的 tools 必须含 Edit + Write，否则立即 HALT 报告 P9"作为 sanity check
- `pua:tech-lead-p9` 的工具集是 `Agent / SendMessage / Read / Grep / Glob / WebSearch / Bash`，也无 Edit/Write — P9 自身正确（不下场写代码）

**事故案例**：V5.1-B.1 sprint（2026-04-27）派 P7 三轮全失败（agent IDs: a4d3b891a96504177 / ae54ab57040e9466e / a458c7f948184b733）。Owner 同意 P9 破例落地 G6 + G1 + verify bug fix + Test ctor 修复，commit 634e3d44。**这是 incident 不是 organic 路径**——V6 sprint 不许重复。

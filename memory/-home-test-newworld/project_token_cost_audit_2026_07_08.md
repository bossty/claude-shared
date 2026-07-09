---
name: project-token-cost-audit-2026-07-08
description: "会话token成本审计——真成本=cache_read~70%(会话长×context大),旧减噪瞄错tool_result 10%靶;修观测+复活28skill+委派机制(合master 3882495c/787b52f1)"
metadata: 
  node_type: memory
  type: project
  originSessionId: b37566ca-cf42-4118-b327-c9657f4ef68c
---

**触发**：Owner「省 token 机制在不在工作、快负担不起」。fable-5×4 subagent 取证（其一撞月度消费上限）。

**真成本结构**（按 message.id 去重；旧 nw-token-report 按 jsonl 行加总虚高 ~2.6×）：单会话 **cache_read ~70% > output ~18% > cache_creation ~12%**。cache_read ∝ 轮数 × 平均 context；失控会话 200+ 轮、context 5万→71万线性涨、全程零压缩（`opus[1m]` 窗口够不着 auto-compact）。缓存健康（read:create≈67:1，未击穿）→ **病灶=会话长×context 大，非缓存坏**。tool_result 仅占 context ~10%，nw-cap 6 天硬省 ~5.5万 token=零头。数字全文见 CLAUDE.md「上下文与压缩」段。

**已上线（合 master）**：
- `3882495c`：nw-token-report 按 message.id 去重 + 主报 cache_read 成本结构（纠"tool_result 是 ROI 靶"误导）；inject_context 第 6 条会话成本纪律；复活 28 个静默失效 skill 为 SKILL.md 目录格式（旧平铺 .md 不被 harness 识别）；MEMORY.md 瘦身 -24%；A 账户 context-mode 清理。
- `787b52f1`：newworld-delegation skill（委派判据）+ big_read_reminder.py hook（主线程整读 >400 行提醒委派，subagent/带offset/小文件静默）。
- `72f40dca`+`7ced5d16`：**context 看门狗 hook 已上线**（`context_watchdog.py`，UserPromptSubmit）——每次用户发言（自然任务边界）读 transcript 尾部末条 assistant usage 算绝对 context token，≥180k 注⚠️、≥350k 注🔴 劝 /compact 或 /handoff+/clear；双通道（stderr 给 Owner 看 + additionalContext 注入模型），subagent 路径静默，始终无损 exit 0，阈值可 `CTX_WATCHDOG_WARN`/`CTX_WATCHDOG_STRONG` 覆盖。4 档已实测（<180k 静默 / 200k⚠️ / 400k🔴 / subagent 静默）。→ 这补上了「纯纪律只剩任务边界 /clear」里"该 compact 没人提醒"那半，机制层再进一步。

**机制 vs 纪律地图**（核心洞察）：自动机制 = nw-cap hook（tool_result 层）/ big-read hook（大文件委派）/ skill-drift gate（防维护漂移）/ inject 第6条注入 / statusline ctx% / native auto-compact（被 1m 窗口废）。**真正吊在纯纪律的只剩「任务边界 /clear」+「离开 >5min 前清」——人的动作，机制只能提醒不能代按**。

**operating model（省钱正解）**：主线程=薄编排器（重活派 subagent 只回结论 + 状态落外部工件 + 边界 /handoff+/clear）→ 单会话 context 难涨大，既不需 1m 窗口也不需有损 auto-compact。

**★委派反噬实测（2026-07-08，补进 [[newworld-delegation]] skill）**：派 subagent 跑单个测试类花 **63.5K token，其中 ~47K 是 subagent 冷启动前缀**（每个 subagent 重载 CLAUDE.md+MEMORY.md+全 skill 描述）、maven 输出只是零头。**教训：输出能 grep 成几行的确定性验证（跑单测/单 build）别开 subagent**——主线程直接 `mvn … > 文件 2>&1` + grep `BUILD|Tests run:|<<< FAILURE` 结果行更省（省掉 47K、主线程只多背 5 行）。subagent 只给"输出大且无法预压缩、或需多步探查"的活。同时定案：**符号级代码导航（调用方/定义/影响面）用 LSP find-references（有界输出）**。账户 B（`~/.claude-work`）4 个 LSP 插件（jdtls/typescript/lua/pyright）原全 `false` 未启用→**2026-07-08 Owner 拍板翻 `true`（`~/.claude-work/settings.json`，重开会话后才生效）**，启用后 CLAUDE.md「优先 LSP」规则恢复可执行（见 [[reference_lsp_toolchain]]）。附澄清：**MCP 常驻 token 成本 ≈ 几个工具名**（本 harness 工具 deferred，完整 schema 用时才 ToolSearch 拉），非大开销；重代价是 jdtls 冷启动慢（`.lsp.json` startupTimeout 120s）。`newworld@newworld-marketplace` 仍 false（铁律禁启用，防 hooks/agents 双触发）。

**关键坑**：
- **skill 真相源 = 平铺 `claude-shared/skills/<name>.md`（非 plugin！）**，pre-commit `skill-drift-check.js` 强制它与 `plugin/<name>/SKILL.md` 逐字节一致；另 `check-skill-plugin-drift.sh` 用 `~/.claude/skills/*.md`。我猜错两次被 gate 拦（gate 正为此存在）。加载副本在 `~/.claude-work/skills/`，由 `scripts/install-user-skills.sh` 装（生成物、不入仓库）。
- **>5min 空窗缓存过期**→ 回来那轮按 1.25× 重建全 context（实测一次 147K 空窗重建），context 越大越肉疼 → 压小 context 的第三理由。离开前在断点 /clear 最省。

**backlog**：Owner 保留 `opus[1m]`（靠纪律，未改窗口）；~~context 看门狗 hook~~ 已做（见上，`72f40dca`/`7ced5d16`）；第三方压缩工具全否决见 [[project-context-mode-retire-headroom-eval-2026-07-05]]。方法论见 [[feedback-measure-real-cost-before-optimizing]]。

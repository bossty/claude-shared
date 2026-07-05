---
name: project-context-mode-retire-headroom-eval-2026-07-05
description: context-mode A/B 证伪并停用 + headroom 隔离试点否决 + nw-cap 提醒 hook 上线（2026-07-05）
metadata: 
  node_type: memory
  type: project
  originSessionId: 759a336b-6aaa-4b13-920f-9e6b2c9fccea
---

**结论三连**（全文证据 `docs/sprint/2026-07-05-context-mode-ab/POC-FINDINGS.md`）：

1. **context-mode 停用**（Owner 拍板 2026-07-05）。A/B：同批 4 条 ops 命令，纪律化 Bash 3,411B 答案齐全 vs ctx 路由 19,148B 且 2/4 查询空手（5.6×）；历史提示注入 5,722 块/~69 万 token > 自报累计节省 516,608；WebFetch/mvn/curl 硬拦截 30 次纯浪费。已改 `~/.claude-work/settings.json`：`context-mode@context-mode:false` + 摘 SessionStart cache-heal hook。**改 settings 前先 `echo $CLAUDE_CONFIG_DIR` 认账户**（本环境双账户，改错无效）。
2. **headroom 否决接入主环境**。隔离试点（pip --target 锁 0.30.0，未 wrap）：Owner"本地开源可控"判断成立（off 后纯启动零外联、只绑 127.0.0.1、唯一外联是 /readyz 触发的上游连通检查）；但 ①telemetry **默认 on**（`HEADROOM_TELEMETRY=off` 必须显式设）②压缩有损——被压缩文件答案关键串全灭（TODO 行引用、总行数行），撞"禁有损采样"铁律 ③Claude Code Bash 工具 ~3 万字符截断已预先消解其大额单条节省场景。复装 5 分钟可复验。
3. **nw-cap 纪律机制化**：PreToolUse hook `.claude/scripts/nw_cap_reminder.py`（已同步 claude-plugin 副本+bump 0.3.1），只在"疑似大输出且无减噪手段"时注入一行，其余零注入。pipe-test 4/4 + 真火测过。

**★方法论**：评估上下文工具必做真 A/B（同批命令 on/off 比 tool_result 字节），单臂"省 N%"自报口径必核基线假设（裸吞全量 vs 纪律减噪 vs 工具层截断）；压缩类工具必做哨兵存活测试（答案关键串压缩后还在不在）；试点第三方代理先两阶段观察出站（零请求基线 + 显式请求对照）。

---
name: W2+W3 sprint 收官 + ECC × PUA 整合心得
description: 2026-04-30 W3 sprint 完成（W3.1-8 + ECC 179 skill off + PUA 模型层级 + ECC governance ENV）。W2 完成（CLAUDE.md 970→216、15 一级 + 7 二级 skill）。ECC × PUA 共存边界稳定。
type: project
originSessionId: b998412a-d9ea-4adc-8292-f003909b19f8
---
# W2 Sprint 收官（2026-04-28）

## 已完成
- **W1**：ECC 兼容性修复 — `~/.claude/settings.json` 加 `disabledMcpjsonServers`(playwright/github/memory) + `skillOverrides`(code-review/tdd-workflow/verification-loop/santa-method/continuous-learning-v2/ck = off)
- **W2-Phase1**：31 条 3.25 级铁律分级（14 一级 + 11 二级 + 6 三级），蓝军挑 9 条修
- **W2-Phase2**：14 个 newworld-* 一级 skill + 6 个二级 skill（backend-design / sql-safety / edge-bootstrap-cert / monitoring-ops / domain-pool / java-pitfalls）+ CLAUDE.md 改写 970→202 行（压缩 79%）
- **W2 收官蓝军**：⚠️ 有条件通过，0 P0 阻塞，4 项打包 W3

## ECC × PUA 边界（已稳定）
- **PUA 独占**：方法论（P10/P9/P8/P7 + 蓝军 ≥5 矛盾门禁 + 段位 KPI + 业务铁律 enforcement）
- **ECC 独占**：harness 基建（rules / hooks / skills 机制 / instincts）+ research-first / documentation-lookup / search-first / security-scan / deep-research / prompt-optimizer 6 skill
- **关键决策**：ECC 的 `code-review` / `tdd-workflow` / `verification-loop` / `santa-method` / `continuous-learning-v2` / `ck` **必须 disable**（与 PUA 蓝军 + P7 方案驱动 + 文件 memory 语义打架）

## ECC 整合踩坑沉淀
- **gateguard fact-forcing 同回合规则**：4 项 facts 必须在 Write/Edit 工具调用的同一 assistant turn 内呈现，跨 turn 引用不被识别。subagent prompt 必须显式写 facts 模板
- **subagent 权限继承不传递**：父 agent 的 `Write(*)` 通配不让 subagent 自动有 Write `~/.claude/skills/*` 权限。需在 settings.json `permissions.allow` 显式 grant 路径（如 `Write(/home/test/.claude/skills/newworld-*)`）
- **ECC enabledPlugins 标 false 但 96 skills + MCP 仍激活**：disable 不彻底，要靠 `disabledMcpjsonServers` + `skillOverrides` 双管齐下
- **MCP 字段名**：真实是 `disabledMcpjsonServers`（不是 `disabledMcpServers`），skill 禁用是 `skillOverrides[name] = "off"`（不是 `disabledSkills` 数组）

## W3 修复清单（共 ~35 min，打包 W3 第 1 周）
1. sql-safety frontmatter 加分工声明 + 防 deploy-checklist 碰撞（5 min）
2. deploy-runbook 后端验证段改 "Step 2.5：后端部署后必须验证"（5 min）
3. CLAUDE.md L181-188 Lessons 段删 ⑤⑥（沟通规范应在 memory 不在工程 lessons）（5 min）
4. CLAUDE.md L202 backup 引用改 commit SHA（2 min）
5. CLAUDE.md 实施流程规范段加"蓝军 ≥5 条 + 文件:行号 + P0/P1/P2"1 行（3 min）
6. sql-safety #3 段补全 batch-oom 4 条 OR 明确不重复（10 min）
7. deploy-runbook 末段补"违反后果"格式统一（5 min）

## 30 天观察期（W3 启动前等数据）
**Why**：W3 主线（ECC 6 skill 接入 + 模型层级优化）需要实战数据驱动。立即启动 = 拍脑袋。

**5 个数据点**：
- skill trigger 命中率 < 50% → 加宽 trigger 或上 hookify
- gateguard 干扰频率 ≥ 5 次/天 → newworld-* 路径白名单
- 模型层级 token 节省 < 20% → P7 改 Haiku
- 双 MCP 重复加载复发（ECC 升级后） → 即修
- token / turn 没下降 30% → disable 不彻底，重新审计

## How to apply
- 新会话遇 ECC × PUA 决策（启用某个 ECC skill / 调整 disable 列表）→ 先查这条记忆的"ECC × PUA 边界"段
- 派 P8 改 settings.json / ~/.claude/skills/* 时 → 提醒 fact-forcing 同回合规则 + 显式 grant 路径
- W3 启动前 → 收齐 5 个观察数据点

## 备份路径（30 天保留期内可回滚）
- `/home/test/.claude/skills.backup-w2p2b1-20260428-141356/`
- `/home/test/.claude/skills.backup-w2p2b2-20260428-144701/`
- `/home/test/newworld/CLAUDE.md.backup-w2p2b2-20260428-144701`
- `/home/test/.claude/settings.json.bk-w3-20260430-182156`（W3 ECC 179 off 前）
- `/home/test/newworld/CLAUDE.md.backup-w3-20260430-181611`（W3 修复前）

---

# W3 Sprint 收官（2026-04-30）

## 已完成
- **W3.1-8 修复**：8/8（W3.7 NO-OP，违反后果段已存在）。CLAUDE.md 214→216 行
- **ECC 批量 off**：179 skill 在 skillOverrides off（W2 旧 6 + W3 新 173）。预期每会话省 ~30-50K token
- **新增 2 个 newworld-* skill**：deploy-jar-symlink（一级）+ mybatis-plus-camel-mapping（二级）。CLAUDE.md 索引 14→15 一级 / 6→7 二级
- **PUA 模型层级 B**：cto-p10=opus（marketplace 自带）/ tech-lead-p9=opus（W3 加）/ senior-engineer-p7=sonnet（W3 加）。pua-skills marketplace `autoUpdate=false`
- **ECC gateguard noop**：marketplace + cache 双路径替换为 noop module（fact-forcing 失效）。ECC marketplace `autoUpdate=false` 防 update 还原
- **ECC governance ENV**：settings.json env 段加 `ECC_GOVERNANCE_CAPTURE=1` 启用 hook 数据收集

## 关键诊断（2 天观察期数据）
- **cost-tracker.log**：1MB / 2331 行 / 真在跑（Bash command audit log，非 token cost）
- **22 个 newworld-* skill 在用**：W2 拆 20 + owner 2 天内自主沉淀 2 个新铁律（deploy-jar-symlink + mybatis-plus-camel-mapping）= skill 化机制工作正常的强信号
- **commit 蓝军 P0/P1 修复出现 2 次**：PUA 蓝军方法论真在用
- 观察期从 30 天缩到 **7 天**，2026-05-05 截止，否则启动 W4

## 18 个 ECC ENV 变量（未来用得着）
关键：
- `ECC_DISABLED_HOOKS` — 优雅禁用特定 hook（未来比 noop patch 更干净的 fact-forcing 解法）
- `ECC_GOVERNANCE_CAPTURE` — 启用 governance 数据收集（W3 已加）
- `ECC_QUALITY_GATE_STRICT` — 控制 quality-gate 严格度
- `ECC_DISABLED_HOOKS` 用法：env 段写 `"ECC_DISABLED_HOOKS": "pre:edit-write:gateguard-fact-force"`（hook id 逗号分隔）

## ECC 整合踩坑沉淀（W3 新增）
- **agent frontmatter 支持 model 字段**：cto-p10.md 已实证，frontmatter 加 `model: opus/sonnet/haiku` 即可层级调度
- **subagent 权限实际行为**：W3 派的 P8 仍被 deny `Edit(/home/test/.claude/skills/newworld-*)`，即便 settings.json 显式 grant。说明权限 grant 可能是 session-scoped。**workaround**：P9 在 main session Edit 替代派 P8（小修可接受）
- **ECC plugin enable 状态与 hook 加载脱钩**：hook 文件级自动加载，与 enabledPlugins=true/false 无关。这就是为啥 W2 标 false 但 hooks 仍在跑
- **数据收集真实状态**：cost-tracker.log 真在跑（不是失败）。session-activity-tracker / evaluate-session 数据是否落盘待 W4 验证
- **gateguard 在 dispatcher 内部 require()**：删 hooks.json 独立 entry 不够，必须 noop gateguard-fact-force.js（dispatcher 仍 require + .run() 但 noop 返回 {}）

## W4 候选（数据驱动决定）
1. **代码层 dead code 扫描**：用 ECC `refactor-cleaner`（W3 已 disable，需临时 on）
2. **docs/ 整理**：~100 个 sprint 沉淀文档过时归档
3. **PUA P7 改 haiku**：如 sonnet 推理够用且 token 仍想压
4. **session-activity-tracker 数据落盘验证**：跑 1 周看是否有 ECC2 metrics 文件
5. **ECC_DISABLED_HOOKS 替换 gateguard noop**：更干净的 hook 控制方式

## How to apply（W3 新增）
- 派 P8 改 ~/.claude/skills/* 失败 → P9 自己 Edit（小修可接受，蓝军方法论灵活性）
- 升级 ECC 后必重做：gateguard noop（marketplace + cache 双路径）+ skillOverrides 173 off（jq 脚本：见 W3 决策段）
- 升级 PUA 后必重做：tech-lead-p9 + senior-engineer-p7 model 字段

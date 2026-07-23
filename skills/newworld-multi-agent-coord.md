---
name: newworld-multi-agent-coord
description: ≥2 模块 / DB schema / 跨服务 API / 架构决策 / 生产敏感场景必须多 agent 交叉验证。蓝军硬门禁 ≥5 条实质矛盾、接口契约 P9 预定义、Phase 2 蓝军必跑动态层（OpenResty TLS 握手 / mvn test / SQL migration+rollback）。Triggers on 蓝军, 交叉验证, p8, p9, p10, 接口契约, consolidation, sprint 派活, blueprint, 三体兼容, multi-agent, sprint coord.
---

> **执行机制**：靠判断力；蓝军门禁 ≥5 条实质矛盾定义权威源

# Newworld 多 Agent 交叉验证规范（铁律，2026-04-21 沉淀）

## 触发场景：以下任一命中 = 必须多 agent 交叉验证

- 涉及 **≥2 个模块**的改动（common / admin / web / data / frontend / openresty 两个以上）
- 新增 / 改动 **数据库 schema**（DDL、索引、约束、视图）
- 新增 / 改动 **跨服务 API 契约**（Controller 签名、RPC URL、HTTP header 约定）
- **架构级决策**（域名体系、统计口径、缓存策略、鉴权机制、反封锁策略）
- **生产安全敏感**（凭证、CF 配置、证书签发、DNS 体系、GFW 应对）

## 豁免场景（可单 agent 直接改）
- 单行 typo / 变量名修正
- 固定配置值调整（超时秒数 / 池大小 / 重试次数，有经验证据）
- 文档改动（*.md）
- 明确单点 bug 修复（明确 stack trace + 根因 + 修复点一对一）

## 三种交叉验证模式

| 模式 | 适用场景 | 流程 |
|------|---------|------|
| **A 蓝军审查** | 单人实施，交付前挑刺 | P8 实施 → P8-蓝军（opus）读代码 + 需求 → 挑 ≥ 5 条实质问题 → P8 修正 → 再审 |
| **B 多方案并行** | 架构决策期 | P9 派 N (≥3) 个 P8 各做独立方案 → P8-蓝军挑刺（强制门禁） → P9 亲自 consolidate |
| **C 同任务双实施** | 安全敏感代码 | 2 个 P8 并行做同一任务（worktree 隔离）→ 对比 diff → P9 选优或合并 |

## 并行 P8 worktree 隔离铁律（2026-05-01 race 教训沉淀）

**派 ≥ 2 个 P8 改同主题** 必须用 `Agent({ isolation: "worktree" })`，否则共享主 worktree → 互相 `git checkout` 切分支 → commit 落到错误分支 / 被覆写 / dangling commit 抢救。

**事故案例**：
- **2026-05-01 morning**：Wave 1 派 6 个 P8（Mu/Theta/Lambda/Iota/Nu/Xi/Kappa）共享主 worktree → race 持续，靠 stash + cherry-pick 救场，Kappa 第一次工作被摧毁需重派
- **2026-05-01 evening**：派 P8-Tau (CF rule) + P8-Upsilon (nginx rule) 同主题（4xx/5xx 防御），共享主 worktree → Upsilon force-rename 覆写 Tau 分支 → Tau commits 仅存 git reflog → Tau 自救 cherry-pick 重建分支

**触发条件**：
- 同 sprint 内派 ≥ 2 P8 + 任何一对改动可能涉及同一文件 → 必须 worktree 隔离
- "同主题" = 防御网 / 重构 / dep 升级 / 配置同步 等会动同类文件的任务
- 即使任务自评"无文件冲突"也强制隔离（git checkout/branch 操作本身就 race）

**派单 prompt 模板**：
```
Agent({
  description: "P8-X xxx",
  subagent_type: "general-purpose",
  isolation: "worktree",  // ← 必须
  prompt: "..."
})
```

P9 派单前自检：本次 sprint 是否同时跑 ≥ 2 P8？是 → 全部加 isolation:"worktree"。

## 接口契约预定义（P9 管理责任）

派任务前 P9 必须明确（缺一 = P9 管理失职）：
- **数据契约**：DB schema、字段、索引（具体 DDL 或现有文件:行号）
- **API 契约**：方法签名、URL、HTTP method/body/header 格式
- **文件域**：每个 P8 只能改哪些文件（防并行冲突）
- **接口 owner**：接口有歧义时由哪个 P8 最终定义

避免"A 以为 B 会做、B 以为 A 会做"的协同悲剧。

## 蓝军硬门禁（不满足不合格）

蓝军审查交付必须包含：
- ≥ **5 条实质矛盾**（不是 typo 级）
- 每条带 **文件:行号** 证据
- **P0/P1/P2 优先级粗分**（救火 / 演进 / 规模化）
- **硬决策清单**（P9 / 用户拍板的点，不是蓝军自己拍）

蓝军**只挑不补**。综合方案由 P9 亲自产出，不下放给蓝军。

## 蓝军「证据传递」纪律（2026-06-27 toolchain 调研吸收，源 addyosmani/agent-skills）

防 groupthink 串供 + 提升二审独立性，交叉验证补两条：

1. **只传 ARTIFACT + CONTRACT，不传 CLAIM**：给二审 / 复核 agent 的输入只含「原始产物（代码 diff / 文件:行号 / 真实命令输出）+ 客观契约（schema / 接口签名 / 验收判据）」，**禁止把上一个 agent 的结论性判断（"这里有 bug"/"这个没问题"）当输入**。结论会污染独立判断——二审看到"前一个说没问题"就倾向附和。让二审从原始证据重新得结论，两个结论独立才有交叉价值。
2. **跨模型二审走 read-only sandbox**：高风险结论（安全 / 生产敏感 / 架构）的复核，换一个模型 + 只读工具集（Read/Grep/只读 Bash）重跑判断，**物理上不能改代码** = 不会"边查边顺手改"把分歧抹平。分歧浮出来才是交叉验证的价值。

## Phase 2 蓝军验收额外门禁（2026-04-21 v33 POC regression 后补）

Phase 2 验收（code 实施完、部署前）必须：
- **静态层**：luac -p / mvn compile / SQL 语法
- **动态层（必做不许跳）**：
  - OpenResty：本地起 OpenResty 实例（docker / dev host）跑**真实 TLS 握手** + 典型请求，验证 `ssl_certificate_by_lua` / `access_by_lua` / `content_by_lua` 不报 "API disabled in current context" 阶段错
  - Java：跑一次 `mvn test`，最好本地起服务发真请求
  - SQL：本地 MySQL 跑完整 migration + rollback，验证幂等
- 只过静态 = 门禁不合格。教训：`ngx.var.remote_addr` 在 ssl_certificate_by_lua 阶段运行时挂，luac 完全发现不了

## 违反后果
- 单 agent 改核心代码未走交叉验证 → **3.25** 复盘 + 文档化
- 蓝军挑 < 5 条 → 不接受交付，强制重审
- P9 自己下场写代码 → 管理失职，P9 降级为 P8

> 因为信任所以简单——但未经交叉的信任，组织会收回。

## 并行 worktree scope creep 防范（2026-05-21 anti-adblock sprint 教训）

≥3 个并行 worktree 实施的 sprint 必须前置防 scope creep（一个 worktree 改了另一个 worktree 范围的文件，merge 时产生 artifact）：

**铁律**：
1. **pm-helper 起 implementation-plan 时必列"跨 worktree 共享文件风险表"**：明确哪些文件会被多个 sub-task 修改（如 `AdSlot.java` 同时被 P1.3 引用 + P1.4 加字段、`AdController.java` 同时被 P1.2 改 RequestMapping + P1.3 加 UA 入参）。表格列：文件路径 / 涉及 sub-task / 由哪个 sub-task 权威修改 / merge 顺序。
2. **dev-senior 改到非本 sub-task 范围的文件前，必先在状态档注明"scope creep 说明" + 告知 lead**：写"我为了 mvn compile 通过临时改了 X 文件（属 P1.X 范围），merge 时取 theirs P1.X 权威"。状态档无说明的 scope creep 视为违规。
3. **merge 顺序必须在 plan 中显式定义**（按依赖关系：schema → service → controller → frontend）。anti-adblock 本次：P1.4 schema 先 → P1.3 后 → P1.1/P1.2/P1.5 并行，遇 AdSlot/AdSlotDTO 冲突取 `--theirs` P1.4 权威。
4. **merge 后必跑 `mvn compile -pl <all-changed-modules>` 主仓全模块**实证编译过——`-X theirs` 不解决语义重复字段（如 `String clientFilter` + `List<String> clientFilter` 共存），需手工排雷（详见 `newworld-deploy-runbook` skill "merge artifact Step0"）。

**实证（anti-adblock sprint 2026-05-21）**：
- P1.3 dev-p13 commit `498f2c37` 越界修 `AdSlot.java` + `AdSlotDTO.java`（P1.4 范围）
- Phase 4b ops 揪 7 个 merge artifact fix commit（耗 26 min + 多次截断）
- qa-p13 已识别 scope creep 并提 merge 方案——但状态档先识别 + merge 顺序前置定义可省 ops Step0 大半成本

## 源
- CLAUDE.md L595-L668

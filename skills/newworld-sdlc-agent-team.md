---
name: newworld-sdlc-agent-team
description: SDLC Agent Team sprint 完整 SOP。触发关键词：newworld-sdlc-agent-team / SDLC sprint / agent team sprint / pm-helper PRD / sprint closeout
---

# newworld-sdlc-agent-team SOP

**版本**：v1.0（2026-05-16，基于 7 sprint 实战验证，Owner 软门 1 拍板装入）
**规范来源**：`docs/superpowers/specs/2026-05-14-agent-team-sdlc-design.md` v1.0

---

## 快速起步检查清单（5 分钟了解整体流程）

```
起一个 SDLC sprint 的标准动作序列：

[ ] 1. Owner 给一句话需求
[ ] 2. main session cp sprint 模板：
        cp -r docs/sprint/_template docs/sprint/<sprint-id>
        git add + commit "chore(sprint): cp 模板 + Owner 一句话"
[ ] 3. spawn pm-helper → 起草 PRD（落盘 docs/sprint/<id>/PRD.md）
[ ] 4. spawn 蓝军 reviewer → 挑刺 PRD（≥5 条，max_round=2）
[ ] 5. 软门 1：Owner 拍板 PRD（含 Open Questions）
[ ] 6. spawn dev-senior（按模块，worktree 隔离）→ Phase 3 Code
[ ] 7. spawn qa-senior → 权威 mvn test（多模块 -pl 列全）
[ ] 8. spawn memory-keeper → sprint-report.md 候选
[ ] 9. Owner 显式 commit 采纳教训到 skill/memory/CLAUDE.md

改动类型速查：
  dry-run       → 标准 5 Phase，Phase 3 结果不一定 deploy
  纯删除        → Phase 3 commit 精确量化 +N/-M lines，mvn 全绿即完
  类型补全      → 纯编译期可豁免双引擎（Owner 软门拍板）
  行为相邻迁移  → qa 必须语义 cross-check（不只 mvn 全绿）
  设计决策型    → Phase 1 前加 recon 子步骤（零消费方证据），软门 1 拍方案后才出 implementation plan
```

---

## 章节 1 — 起 Sprint 6 步

**Step 1 — Owner 一句话需求**

Owner 用一句话描述目标（如"清理 deprecated API 分组 B"），不需要完整 spec。

**Step 2 — cp sprint 模板**

```bash
cp -r docs/sprint/_template docs/sprint/<sprint-id>
# 命名规范：YYYY-MM-DD-<sprint-name>
git add docs/sprint/<sprint-id>/
git commit -m "chore(sprint): cp 模板 + Owner 一句话 (<sprint-id>)"
```

**Step 3 — pm-helper 起草 PRD**

```
spawn pm-helper（subagent_type=pm-helper）
派工指令包含：
  - Owner 一句话需求
  - 相关 MEMORY 条目路径
  - 若为设计决策型：先做 Phase 1 前置 recon（步骤 2a，见章节 3 §4.1）
  - 铁律：凡引用外部 doc 类名/字段名/路径必须 grep 实代码 ≥2 条验证才纳入 PRD
  - 铁律：删/修操作表格只列真要改动条目，"不要动"警告用独立 NOTE 块
```

**Step 4 — 蓝军挑刺 PRD**

```
spawn 蓝军 reviewer（独立 context window）
要求：≥5 条挑刺，max_round=2（pm-helper 可一次性 reply 反驳带证据，reviewer 独立复核）
若 ≥3 条 BLOCKER → escalate_to_owner
```

**Step 5 — 软门 1：Owner 拍板**

Owner 逐一回答 PRD Open Questions，拍板实施方案。软门 1 通过条件：
- PRD.md 落盘
- 蓝军 ≥5 条挑刺全闭环
- Open Questions 全有答案

**Step 6 — Phase 3 Code 实施**

按章节 3 §4.3 执行，spawn dev-senior（按模块 worktree 隔离），配对 qa-senior 做权威验证。

---

## 章节 2 — Agent Spawn 参数

### pm-helper

```yaml
subagent_type: pm-helper
tools: [Read, Write, Bash (read-only grep), Glob, Grep]
can_send_to: [蓝军 reviewer, lead]
派工指令必含：
  - 读 docs/sprint/<id>/PRD.md 模板 + 相关 MEMORY 条目
  - 设计决策型 sprint 加：Phase 1 前置 recon（步骤 2a）
  - 铁律 §7：pm-helper 摆 trade-off 不自决，软门 1 拍板
  - 截断 resume 协议（见章节 4）
```

### 蓝军 reviewer

```yaml
subagent_type: reviewer
tools: [Read, Bash (read-only), Glob, Grep]
can_send_to: [review→任何 senior（单向）, escalate_to_owner]
独立 context window（不可见 pm-helper 思维过程）
必读 docs/security/audit-suppressions.md 跳过已知抑制项
max_round=2（超出强制 escalate_to_owner）
```

### dev-senior（研发 senior）

```yaml
subagent_type: dev-senior
tools: [Bash, Read, Edit, Write, Glob, Grep]
工作目录: .claude/worktrees/<sprint-id>-<module>/
can_send_to: [测试 senior, 蓝军, lead]
派工指令必含：
  - worktree 路径 + 模块范围
  - 截断 resume 协议（"预期会被截断，每 commit 记 sha"）
  - commit message 精确量化铁律（+N/-M lines, X files）
  - dev-senior 不跑全量 mvn test（交 qa-senior 权威验证）
```

### qa-senior

```yaml
subagent_type: qa-senior
tools: [Bash, Read, Glob, Grep]
核心职责: 权威 mvn test（无 -q）+ 语义 cross-check（行为相邻改动）
跨模块铁律: mvn test -pl <所有改动模块逗号列表>（不得用单模块命令）
截断 resume 协议同 dev-senior
```

### memory-keeper

```yaml
subagent_type: memory-keeper
tools: [Read, Write, Bash (read-only git log)]
产出: docs/sprint/<id>/sprint-report.md（候选，不直接写 skill/memory）
Owner-commit-only: 不能 Edit ~/.claude/skills/ 或 memory/ 或 CLAUDE.md
```

---

## 章节 3 — 5 Phase 检查清单 + 软门触发条件

### Phase 1 — PRD/调研

| 步骤 | 执行者 | 产物 | 软门条件 |
|------|--------|------|---------|
| 1. Owner 一句话需求 | Owner | 需求描述 | — |
| 2. spawn pm-helper 起草 PRD | main session | PRD.md v1 | — |
| 2a. 【设计决策型专属】Phase 1 前置 recon 子步骤 | pm-helper | 零消费方/零调用方证据（见下方说明） | — |
| 3. spawn 蓝军 reviewer 挑刺 | main session | reviewer.md（≥5 条挑刺） | — |
| 4. pm-helper 闭环挑刺（max_round=2） | pm-helper | PRD 更新版本 | — |
| 5. **软门 1 Owner 拍板** | Owner | Open Questions 全回答 | PRD 落盘 + 蓝军闭环 |

**步骤 2a 说明（设计决策型专属 recon 子步骤）**：

设计决策型 sprint（如 deprecated 清债、dead code 删除、架构选型）中，pm-helper 在 PRD 起草前先做 grep recon。核心产物是"零消费方证据"：

```bash
# 示例：检查 CDN_ASSETS_URL 是否有活跃消费方
grep -r "CDN_ASSETS_URL" --include="*.java" .
grep -r "@CdnUrl" --include="*.java" . | grep -v "explicit-param"
# 若零结果 → 选项 B（删除）是安全路径
# 若有结果 → 选项 A（保留/迁移）才是安全路径，不得直接删除
```

recon 结论作为 PRD OQ 的"分析基础"段，让 Owner 软门 1 快速拍板。

### Phase 2 — Design（可选，架构变更时启用）

仅在涉及架构变更或跨模块 DB schema 设计时启用，否则直接跳 Phase 3。

### Phase 3 — Code

| 步骤 | 执行者 | 关键铁律 |
|------|--------|---------|
| worktree 隔离 | main session + dev-senior | `git worktree add .claude/worktrees/<sprint-id>-<module>` |
| 按模块 spawn dev-senior | main session | 每模块独立 worktree，按需并行 |
| 实施 + commit | dev-senior | commit message 精确量化（+N/-M lines, X files） |
| 局部编译检查 | dev-senior | `mvn compile -pl <module>`（<30s），不跑全量 mvn |
| 结束 worktree | dev-senior | 汇报 lead + commit sha 列表 |
| 权威 mvn 验证 | qa-senior（独立） | `mvn test -pl <所有改动模块>` 无 `-q` |

**软门 3 触发条件**：mvn test 全绿 + e2e 真点 + sprint-closure-audit 通过 + deploy-checklist 四查 OK

### Phase 4 — Deploy（单 session，ops-senior）

运维 senior 走 `newworld-deploy-runbook` 5 步，PreToolUse Hook 第 4 门硬拦 destructive ops。

### Phase 5 — 沉淀（Owner-commit-only）

memory-keeper 产 sprint-report.md 候选 → 蓝军复核 → Owner 显式 commit 采纳教训 → 更新 skill/memory/CLAUDE.md。

**Agent 不能直接写**：`~/.claude/skills/` / `memory/` / `CLAUDE.md`（spec §4.5 铁律）。

---

## 章节 4 — Background 截断 Resume 断点续协议

background sub-agent 被截断是系统性非偶发行为（连续 6 sprint 全出现：W3/LSP-2/E/F/BD/D）。

### 派工指令必含的截断应对段

```
预期会被截断，断点续（resume）是正常流程。
- 每完成一个 commit，立即在状态档 docs/sprint/<id>/agents/<role>.md 记录 sha 和完成项
- 被截断后下次 resume 先执行：
    git log --oneline -8    # 确认上次 commit sha
    cat docs/sprint/<id>/agents/<role>.md   # 读状态档定位断点
- 从上次 sha 之后的条目续，勿重复已 commit 条目
- mvn test 超过 2min 的任务，完成每个验收项立即写状态档
```

### qa-senior 截断高风险阶段

mvn test 耗时 2-4min，是 qa-senior 截断高发点。qa-senior 每完成一个验收项（AC-1/AC-2/...）立即写状态档，resume 后从未验 AC 继续。

---

## 章节 5 — 跨模块 mvn 铁律

### 核心规则

**跨 ≥2 个 Maven 模块的改动，qa 验证命令必须列全所有改动模块：**

```bash
# 正确：列全改动模块
mvn test -pl newworld-common,newworld-admin

# 错误：单模块构建，本地 Maven repo 中 stale jar 导致 cannot find symbol
mvn test -pl newworld-admin   # 若 common 有改动则此命令结果不可信
```

### 根因

Maven 本地 repo（`~/.m2/`）缓存了旧版 `newworld-common.jar`。单模块构建时，编译器使用旧 jar，新增方法不存在，报 `cannot find symbol`。这是编译问题不是类型问题，不能靠修改调用方代码解决。

### qa 派工指令模板

```
mvn test 验证命令：mvn test -pl <所有改动模块逗号列表>（无 -q，需看失败详情）
如本 sprint 改动跨 newworld-common + newworld-admin：
  mvn test -pl newworld-common,newworld-admin
```

### 仲裁协议

若 dev-senior 和 qa-senior 对编译结果诊断有分歧，main session lead 必须 grep/Read 实代码确认真相（不凭角色权威选边），确认后通知双方并记录仲裁证据到状态档。

实证：BD-sprint qa-senior 误诊 `BindCategory.S` 类型不匹配，main session grep `PromotionChannelDomain.java:95` 确认是 `public static final class`（String 常量），dev 正确 qa 误诊，避免了错误改动。

---

## 章节 6 — 受限双向 Crossfire 协议

### 默认方向

蓝军 reviewer → 研发/pm-helper（单向），不是自由 mesh。

### 受限双向（crossfire）

被审方（研发 senior / pm-helper）可一次性 `reply_to_reviewer` 反驳，必须携带实证：

```
反驳格式：
  事实：<grep 输出 / commit sha / 文档引用>
  来源：<文件路径:行号 / 官方文档 URL>
  结论：<此挑刺应降级 / 撤销，理由>
```

### max_round=2 硬约束

- pm-helper / dev-senior 最多 reply 2 次
- 超过 2 轮 → 强制 escalate_to_owner，Owner 裁决
- reviewer 收到 reply 后有义务独立复核（不能只凭对方声称接受）

### crossfire 双向有效实证

D-sprint reviewer #5 挑 MAJOR（frontend-admin spread 模式隐性引用 assetsUrl），pm-helper 用 `MovieList.vue:963-968` + `cdn.js:50-59` 两条 grep 实证反驳，reviewer 独立复核后自降 MINOR 闭环。若错误采纳 #5，PRD 会增加不必要 AC 项。

**crossfire 双向的价值**：防止误报堆积 PRD 复杂度；被审方有反驳渠道才能避免误判（见 spec §5.4 三条血泪案例）。

---

## 章节 7 — Owner-commit-only 铁律

**规则**：以下文件只能 Owner 显式 commit 才生效，agent 只产候选。

| 文件 | 路径 | 规则 |
|------|------|------|
| skill 文件 | `~/.claude/skills/newworld-*.md` | Owner-commit-only；agent 产候选写到 sprint 目录 |
| memory 文件 | `~/.claude-work/projects/.../memory/*.md` | Owner-commit-only；memory-keeper 产候选 |
| CLAUDE.md | `/home/test/newworld/CLAUDE.md` | Owner-commit-only；agent 不能 Edit |
| spec 文件 | `docs/superpowers/specs/*.md` | Owner-commit-only；agent 可产 spec diff 候选 |

**违反后果**：agent 自写 skill/memory 会形成正反馈幻觉链（spec §1 P8 原则）。

**实施方式**：
1. memory-keeper 产 `sprint-report.md` 候选（在 git 追踪的 docs/ 目录下，可落盘）
2. Owner 复核候选教训
3. Owner 手动 commit 采纳教训到对应文件
4. SOP skill 候选：写到 `docs/sprint/<id>/newworld-sdlc-agent-team.skill-candidate.md`，Owner 复核后 cp 到 `~/.claude/skills/`

---

## 章节 8 — 5 类改动经验参数

| 改动类型 | Sprint 实例 | PRD 重点 | qa 重点 | 典型坑 | 成本参考 |
|---------|------------|---------|---------|--------|---------|
| **dry-run（首次验证）** | frontend-perf / lsp-cleanup | 明确 scope 防 scope creep；commit message 精确量化 | 蓝军 Phase 3 必查 diff vs message | dev-senior 夹带无关改动（frontend-perf 教训） | ~$2-5 |
| **纯删除（lint/dead code）** | lsp-cleanup-v2 | 删/修表格只列真要改动；完整 @Mock 映射表 | mvn 全绿 + Spring 容器冒烟（无 NoSuchBean） | @Mock 映射表漏字段 → 测试静默失败（LSP-2 教训） | ~$2-3 |
| **类型补全（TS/编译期）** | vue-tsc-e | 确认 .vue 文件是否需加 lang="ts"；基线错误数确认 | npm build exit 0 + npm test 全绿（豁免双引擎需 Owner 软门拍板） | vue-tsc 在无 lang="ts" 时按 JS 模式处理，import type 报错 | ~$3 |
| **行为相邻迁移（deprecated API）** | deprecated-f | 替代 API 字段取用分析（列调用方字段 vs 替代 API entity 对比）；字段缺口直接标 DEFER | 语义 cross-check（读调用上下文确认选对路径，不只 mvn 全绿）；mvn 集中交 qa-senior | markBlocked 拆分两条路径都能 mvn 全绿，但语义选错导致 GFW 封禁域名自动恢复 | ~$1 |
| **设计决策型（架构/命名/DB）** | deferred-bd / deferred-d | Phase 1 前置 recon（零消费方证据）；pm-helper 摆 trade-off 矩阵不自决；Owner 软门 1 拍方案后才出 implementation plan | 跨模块 `-pl A,B,...` 铁律；SQL 等价确认（retired_at IS NULL vs status='active' 语义不同） | 替代 API 实体缺字段（role 字段缺失导致 rotateSDomain 逻辑破坏）；SQL 软删除字段与业务状态字段语义不可互换 | ~$1-2 |

---

## 反模式警告（来自 7 sprint 真实教训）

> WARN：以下反模式均有 sprint 实证，请勿重蹈覆辙。

### WARN-1：commit message 精确度（frontend-perf 教训，5/15）

**反模式**：commit message 说"+1行 viewport"，实际 diff 包含 +35 行百度 hm.js 监控代码（scope creep）。

**正确做法**：commit message 必须精确量化 `+N/-M lines, X files`，diff 行数与 message 描述不一致禁止 commit。

蓝军 Phase 3 必查 `git diff --stat` vs commit message，不一致 = BLOCKER。

---

### WARN-2：单模块 mvn 验证跨模块改动（BD-sprint 教训，5/16）

**反模式**：改动涉及 `newworld-common`（新增方法）+ `newworld-admin`（调用），qa 用 `mvn test -pl newworld-admin` 单模块构建，报 `cannot find symbol`，误诊为"类型错误"，建议 dev-senior 修改正确的代码。

**正确做法**：`mvn test -pl newworld-common,newworld-admin`。诊断冲突时 main session 查实代码仲裁，不凭角色权威选边。

---

### WARN-3：删/修操作表格混入"不要动"警告（LSP-2 教训，5/16）

**反模式**：PRD 中以"被删字段"为题的表格混入 `stringRedisTemplate`（8 处生产调用、不该删），条件分支"此字段不在 C 类清单"藏在同格内，dev-senior 快速扫表第一眼见"删"字极易误操作。

**正确做法**：操作表只列真要删/修的条目，"不要动"的警告必须以独立 NOTE 块呈现：

```
NOTE: stringRedisTemplate 有 8 处生产调用，不在 C 类清单，@Mock 不得删除。
```

---

### WARN-4：agent 直接写 skill/memory 文件（spec §4.5 铁律）

**反模式**：memory-keeper 或 dev-senior 直接 Edit `~/.claude/skills/*.md` 或 `memory/*.md`。

**正确做法**：agent 只产候选（写到 `docs/sprint/<id>/` 目录），Owner 复核后手动 commit。LLM 自写 memory 会形成正反馈幻觉链（见 spec §1 P8）。

---

### WARN-5：行为相邻迁移只看 mvn 全绿（deprecated-f 教训，5/16）

**反模式**：`markBlocked` 拆分为 `markPolluted` / `markConfirmedBlocked` 两条路径，两者都能让 mvn test 全绿，但 GFW 封禁域名场景应选 `markConfirmedBlocked`（永久），选 `markPolluted`（可恢复）会导致封禁域名被自动恢复上线。

**正确做法**：行为相邻迁移 qa 必须读调用上下文确认语义，单看 mvn test 全绿不能关 qa gate。

---

### WARN-6：设计决策型 sprint 无前置 recon 直接起草 PRD（D-sprint 教训，5/16）

**反模式**：设计决策型 sprint（删除/迁移/架构选型）跳过 Phase 1 前置 recon，直接在 PRD 中推荐选项，pm-helper 预设实施方案。

**正确做法**：Phase 1 前置 recon 先找"零消费方证据"，recon 结论作为 PRD OQ 分析基础，Owner 软门 1 拍板后才出 implementation plan。若有任何活跃消费方，选项 A（保留/迁移）才是安全路径。

---

### WARN-7：background 并行 agent worktree 隔离不可靠（全量审计 sprint 5/17 L-1/L-2/L-3/L-11）

**反模式**：Wave 1 手动建 `audit/g*` worktree、派工指令要求"在 worktree 内工作"，但 background agent cwd 默认主仓库，`git -C` 是软约束——dev-g1b/dev-g7b 直接在 master commit；又因 shutdown 对正在工作的 agent 不可靠（agent 先干完活再停），dev-g7/dev-g7b 双重完成 G7。

**正确做法**：① 修复波次（BLOCKER/MAJOR/返工）优先 **foreground 阻塞 spawn**——cwd 由 lead 注入、截断后片段+agentId 直接回 lead 当场接力，无 background 的 idle 等待窗口；② background 仅留给短任务（tool_uses <15）；③ 关停 agent 必等状态档"已完成/已停止"确认 + `git log` 核 commit 已落盘，再重派。

---

### WARN-8：agent 自述 commit 不可信，lead 必 `git` 全量实证（全量审计 sprint 5/17 L-4/L-9）

**反模式**：dev-g1b 状态档称"已完成 TagAliasService 重构"，但 commit `4a0992d1` 的 `git show --name-only` 只有 findings.md、Java 改动从未提交（幻象 commit）；另一 agent 续跑只 `git log -5` 自报、漏报已完成的多个 commit。

**正确做法**：lead 接收"完成"汇报必独立核实——安全项 commit 跑 `git show --name-only <sha>` 核文件列表；批次完成跑 `git log <base>..HEAD --oneline` 核全量 commit。状态档"已完成"必须带 sha + 文件名，不接受"已修 X"裸表述。

---

### WARN-9：蓝军必须独立复核「修复 commit」，不止复核 PRD（全量审计 sprint 5/17 L-8）

**反模式**：默认蓝军只在 Phase 1 挑 PRD；MAJOR 修复 commit dev-senior 自证即上线。

**正确做法**：MAJOR/BLOCKER 修复 commit 上线前必经独立蓝军（foreground、独立 context）复核。实证 ROI 极高：本 sprint 蓝军复核 19 个修复 commit 揪出 2 个 MAJOR 真 bug（热搜 SETNX 输家读空 / 双 volatile 竞态——同款竞态已有修法未套用）。复核 checklist 含"同模块是否已有同款 bug 既有修法 / 新路径是否有静默返回空的风险"。

---

### WARN-10：gate 条目批量修复前必先 triage（全量审计 sprint 5/17 L-12）

**反模式**：dev-senior 拿到 gate 清单不读注释直接批量修所有 DEAD 项。

**正确做法**：修复派工指令必含"先读 gate-items.md 注释，跳过含『退役日』/『audit-suppressions』/『Owner 确认后』标注的条目，仅处理明确授权编号"。条目分三档——硬前置（退役日/ops 动作）、抑制项（需 Owner 显式覆盖）、待决策（需 Owner 拍板）——盲修会误删有意保留代码或违反审计规范。

---

### WARN-11：dev-senior 改产品代码后必 `mvn test-compile`，不只 `mvn compile`（全量审计 sprint 5/17 L-7）

**反模式**：dev-senior 改产品代码后只 `mvn compile`（仅编译 main）就汇报；删类/改方法签名后测试引用断裂未被发现，qa 全量 mvn test 才暴露编译失败。

**正确做法**：dev-senior 每次改产品代码、提交前跑 `mvn test-compile -pl <module>`（编译 test 源码，<20s）捕获测试引用断裂；涉删类/改签名/改 Bean 名的 commit 额外 grep 测试目录同名引用。全量 `mvn test` 仍交 qa-senior。

---

## WARN-12: Controller 方法替换必逐端点 grep 自验（2026-05-21 anti-adblock sprint）

**why**：P1.3 dev-p13 在 AdController 加 UA 入参 `getAdsBySlotWithUa`，但**漏改 GET `/{slug}` 端点**——该端点仍调用无 UA 版本 `getAdsBySlot`，Phase 4b ops-senior 部署阶段发现并 fix（commit `b446bba2` +2/-1 lines）。根因：dev-p13 状态档 AC 自验未"逐端点核查"，qa-p13 mvn 通过但未 e2e 逐端点验证调用一致性。

**规则**：
1. 涉"Controller 方法替换 / 加参 / 删参"的改动，dev-senior AC 必含**逐端点 grep 实证**：
   ```bash
   grep -n "<旧方法名>\|<新方法名>" path/to/Controller.java
   ```
   预期：旧方法 0 命中 + 新方法所有端点命中
2. qa-senior 验证方法调用一致性时**用 grep 不依赖 mvn 通过**——mvn 编译期不查同 Service 内 method 是否一致使用，仅查类型 OK
3. 状态档 AC 段必列每个端点对应的方法绑定（端点 → 调用方法）

**配套**：[[newworld-commit-message-precision]] 强调"声明前 grep 实证"，本规则是 Controller 改动专项化。

---

## 状态档模板（每个 agent 维护）

文件路径：`docs/sprint/<sprint-id>/agents/<role>.md`

```markdown
# <role> 状态档 — <sprint-id>

## 当前任务
<one-liner>

## 进展（按时间倒序）
- `YYYY-MM-DD HH:MM` <事件> — commit `<sha>`

## 待办
- [ ] <按优先级>

## 决策点
- `YYYY-MM-DD HH:MM` <决策> — 理由：<...>

## 工件路径
- relevant commits: <sha 列表>
```

截断续跑时先读此文件定位断点，再 `git log --oneline -8` 确认进度。

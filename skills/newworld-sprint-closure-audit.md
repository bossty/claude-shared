---
name: newworld-sprint-closure-audit
description: Sprint closure / 收口验收抗虚报铁律 — 类名必带 main 树 path + commit hash / 测试声明必带 mvn 命令或 commit / P9 closure 前 find 自查 / 蓝军最后一条强制抽样 grep 实代码。少一项 = closure 可信度 < 50%，3.25 级 retro。Triggers on sprint closure, 收口, 验收, 完工, closure report, 蓝军 closure, P9 收尾, sprint 关闭, V7 closure, 抽样审计.
---

# Newworld Sprint Closure 验收抗虚报铁律（2026-05-02 沉淀）

## 触发场景
任何 sprint / wave / V-track 收口（"全部完成"、"closure report"、"sprint 关闭"、"已 ship"），P9/P10 整理 closure list 或蓝军做 final 验收时强制走以下四条。

## 事故源头：2026-05-02 V7 closure 抽样审计

P8 蓝军对 V7 closure 抽样 11 项，可信度 < 50%：
- **2 全虚报**：Gmail Autoresponder、HomeEmailBanner.vue 全套不存在（main 树 grep 0 命中）
- **2 半完工**：C-1 saga 5 件套只 ship 2、F3 后端缺 Beacon/Metrics 端点
- **1 测试假绿+迁移未做**：声明"AnalyticsV5Metrics 测试全过" 但 admin→web 迁移根本没做，跑的是旧路径 mock
- 根因：closure 只写"类名 + 一句话"，无 path、无 commit、无验证证据

## 铁律

### 1. closure 列每个类必带 main 树 path + git blame commit
- closure 表/列表里每个声明的类、组件、Bean，必须附 `path/relative/to/repo/Foo.java` + 实现该类的 `commit hash`（短 7 位即可）
- 禁止只写类名（"实现了 GmailAutoresponder" 不算交付）
- **Why**：类名漂浮 → 蓝军无法 grep 验真 → 全虚报零成本（V7 closure Gmail Autoresponder 0 命中）
- **How to apply**：closure 表必有 3 列 `类/组件 | main 树 path | commit hash`，缺一不收。Path 用 `git ls-files | grep <ClassName>` 实证，commit 用 `git log --oneline -- <path> | head -1` 取最近实现 commit

### 2. "X 测试全过" 必带 mvn 命令 + log 片段或 commit hash
- 任何"X 类测试通过 / 全绿 / N tests pass"声明，必须附 `mvn test -Dtest=<Class>` 命令 + 实跑 log 末尾 `Tests run: N, Failures: 0, Errors: 0` 片段，或写"see commit `abc1234` CI green"
- 禁止口头"测过了"
- **Why**：V7 AnalyticsV5Metrics 声明"测试全过"，实际跑的是 admin 旧路径 mock，web 模块迁移根本没做（真测会全红）
- **How to apply**：closure list 任何"测试 OK"右侧粘 `mvn test -Dtest=AnalyticsV5MetricsTest -pl newworld-web` 输出最后 5 行；CI 路径写 commit hash + GitHub Actions run id

### 3. P9 closure 前必跑 find 自查每个声明类
- P9 整理 closure 表交给 P10/用户**前**，必须对每个声明类跑：
  - `find newworld-*/src/main -name "<ClaimedClass>.java"`
  - `find frontend-*/src -name "<ClaimedComponent>.vue"`
- 0 命中 = 该项立即标 ❌ 退回实施 P8，不得进 closure
- **Why**：V7 HomeEmailBanner.vue / GmailAutoresponder 全套靠 P9 一道 find 即可拦截，但 P9 直接信 P8 自评 → 上呈到用户面前才被蓝军揪出
- **How to apply**：P9 写脚本 `for cls in $(awk -F'|' '{print $1}' closure.md); do echo "=== $cls"; find . -path '*/src/main/*' -name "$cls.*"; done`，输出空的全部退单

### 4. 蓝军最终交付强制"抽样 3 项最具体声明 grep 实代码"
- 蓝军 final review 不止挑 ≥5 条矛盾（见 `newworld-multi-agent-coord` 蓝军门禁），**最后一条必须是抽样 3 个最具体声明（带类名/方法名/字段名）实际 grep main 树的结果**
- 抽样选"最具体、最容易验真"的（如 "BeaconController.recordView"、"@Bean dnsRotationScheduler"），不许选模糊声明（"完善了统计能力"）
- **Why**：V7 蓝军原本通过率 100%，加这条后立刻揪出 Gmail Autoresponder + HomeEmailBanner 全虚报
- **How to apply**：蓝军报告末尾固定段落 "## 抽样实证（3 项）"，每项 `grep -rn "<symbol>" src/ frontend-*/src/ | head -5` 输出原文 + 命中/0 命中结论

### 5. C 类 unused @Autowired field Grep SOP 必含 Java 反射模式（W3 5/15 教训）
- C 类（unused @Autowired bean）原 Grep 三步（直接引用 + `getBean.*ClassName` + `#{.*fieldName}`）**漏 Java 反射注入两类**：
  - `ReflectionTestUtils.setField(target, "<fieldName>", value)` — Spring 测试代码常用（newworld 测试目录大量使用，如 `DynamicCorsConfigurationSourceTest.java:49`）
  - `@InjectMocks` — Mockito 注入字段，按字段名/类型自动反射
- **第 4 步 Grep 命令**（C 类 unused @Autowired 删前必跑）：
  ```bash
  grep -rn "ReflectionTestUtils.setField.*\"<fieldName>\"\|@InjectMocks" --include="*.java" src/ test/
  # 然后人工确认 @InjectMocks 后被注入的目标类是否含 <fieldName> 类型字段
  ```
- **Why**：W3 dry-run sprint `2026-05-15-lsp-cleanup` 蓝军挑刺 #3 揪出原 SOP 漏反射，C 类 11 条 @Autowired field 删除有运行时炸 mvn test 的真实风险（compile 过但 setField 抛 FieldNotFoundException）。本项目 @Autowired 共 360 处/137 文件，规模大反射漏判概率不低
- **How to apply**：dev-senior 删 @Autowired field 前必跑第 4 步 grep，零结果才执行；任何 ≥1 反射命中要么留字段要么先改测试代码

### 6. C 类 @Autowired field 删除必配「完整 @Mock 映射表」（LSP-2 5/16 教训）
- 删 unused @Autowired production field 时，对应测试类（`@ExtendWith(MockitoExtension)` + `@InjectMocks`）里的 `@Mock` 字段**必须同步处理**——production field 删了 @Mock 不删会 NoSuchFieldError 或静默注入失败（测试通过但行为不符预期）
- **PRD / 实施清单不能只列 jdtls/LSP 报的那一条**：对每个被删 production field，**grep 对应测试类全部 @Mock 声明**，逐一标注「删 / 保留（理由）」
- 实证：LSP-2 sprint reviewer MAJOR #1 揪出 PRD C-4 只提 `warashiSearchService` 的 @Mock，漏 `stringRedisTemplate` + `r2UploadService` 两条孤立 @Mock。修后完整 5-field 映射表：warashiSearchService @Mock 删 / r2UploadService @Mock 保留（有 verify 调用）/ stringRedisTemplate @Mock 保留（production field 8 处真实调用未删）
- **How to apply**：C 类验收段必含完整 @Mock 映射表（被删 field → 对应 @Mock 全集 → 删/留决策 + 理由），dev-senior 按表逐条执行

### 7. 行为相邻迁移：qa cross-check 必须读调用上下文确认语义，mvn 全绿不算数（F-sprint 5/16 教训）
- **行为相邻改动**（deprecated API 迁移 / 方法拆分 / 签名变更）—— 替换后多条路径都能 `mvn test` 全绿，但**语义选错会致生产行为反转**
- 实证：F-sprint 分组 C `markBlocked` 拆 `markPolluted`（可恢复）vs `markConfirmedBlocked`（永久）。两条都过 mvn test（测试仅验"旧调用消失"），但 rotate+GFW_BLOCKED 场景选 `markPolluted` 会让封禁域名自动恢复上线。qa-senior 读 `ChannelLifecycleServiceTest:1191-1193` 调用上下文才确认 `markConfirmedBlocked` 正确
- **How to apply**：行为相邻 sprint 的 qa 验收**逐分组列"语义 cross-check"子项**——读调用方上下文 + 确认替代 API 语义匹配场景 + dev commit message 记录选择理由。**仅凭 mvn test 全绿不能关 qa gate**
- 配套：PRD 起草时为每个 deprecated→替代标"语义等价 / 有差异（说明）"（pm-helper 7 铁律）；替代 API 不完备（字段缺失 / 替代键未知）时 Owner 软门 defer 该组，不硬迁

### 8. 新方法 SQL 替代 deprecated 方法 SQL：逐行对照 WHERE，软删除字段 ≠ 业务状态字段（BD-sprint 5/16 教训）
- deprecated 方法用「新增等价新方法」方式迁移时，新方法 SQL 的 WHERE 子句必须**逐行对照** deprecated 原 SQL，不可凭"语义差不多"替换
- **最高危：软删除字段（`retired_at` / `deleted_at` / `is_deleted`）与业务状态字段（`status`）语义不同，不可互换**——软删除机制通常只改时间戳字段、不改 `status`
- 实证：BD-sprint reviewer R2-1 BLOCKER —— pm-helper v2 PRD 新方法 SQL 用 `pcd.status = 'active'` 替代 deprecated 原 `retired_at IS NULL`。reviewer 3 源交叉（deprecated XML 原 SQL + PRD v2 新 SQL + `retireBinding` 软删除机制）实证：`retireBinding` 软删除只写 `retired_at` 不改 `status`，故已退役 binding（`retired_at` 非空但 `status` 仍 `'active'`）会被 `status='active'` 错误返回给 `rotateSDomain`，致 S 域轮换状态错乱
- **How to apply**：PRD 中「新增等价方法」类条目必含「与 deprecated SQL 逐行等价确认表」（原 WHERE 每个条件 → 新 WHERE 对应条件 → 等价 ✓ / 差异说明）；reviewer + qa 验收必查此表；改动涉软删除表先确认软删除究竟写哪个字段
- 配套：本项与 §7 互补——§7 是行为相邻 API 迁移的 qa 调用上下文 cross-check，§8 是新增等价 SQL 方法的 WHERE 逐行对照（reviewer Phase 1 即可拦）

## 关联铁律
- `newworld-multi-agent-coord` — 蓝军挑刺 ≥5 条 + 优先级分级；本 skill 是其 closure 阶段的 final layer（抽样 grep 是第 6 条强制项）
- `newworld-deploy-checklist` — 部署前四查；closure ≠ 部署完成，closure 后仍走部署四查

## 违反后果
- closure 含未带 path/commit 的类 → 整批 closure 退回，P9 重整
- "测试全过" 无 mvn 命令证据 → 视为虚报，3.25 级 retro
- P9 跳过 find 自查 → P9 管理失职，下次降派 P8
- 蓝军漏抽样 grep → 蓝军不合格，强制重审

## 源
- 2026-05-02 V7 closure P8 蓝军抽样审计（11 项可信度 < 50%）
- 关联 `newworld-multi-agent-coord` 蓝军门禁

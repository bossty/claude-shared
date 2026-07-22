---
name: 蓝军/审计 agent 方法论 — main 树 + 双证据 + 严挑 + audit-suppressions 必读 + dangling 实证 + E2E 实证 + 蓝军独立复核 + Lessons Learned 必读
description: 派审计 / 蓝军 agent 必守 10 条铁律。审计可能 60%+ 误判 / 违反审计规范 / 量化脱离业务 / 信任蓝军误判 / 误把暂禁代码当上线即爆。
type: feedback
originSessionId: fe398321-ee74-4942-9f53-cfbb4ac5e1d8
---
派蓝军/审计 agent 时强制 10 条方法论铁律。包括 E2E 实证（生产部署后必跑）+ 蓝军独立复核（蓝军也可能误判）+ Lessons Learned 必读（审计涉及暂禁代码时不读完整会误判）。

**Why（5/2 V7 closure 审计教训）**：
派 P8 抽样 V7 closure 11 项判断："V7 closure 可信度 < 50%（2 全虚报 + 2 半完工 + 1 测试假绿）"。事后 P9 逐项独立核对发现：
- 5 项核心判断里 **3 项是审计自误判**（saga 永久取消已删 / F3 后端 11/11 tests pass 已 ship / AnalyticsV5Metrics 已迁 WebAnalyticsMetrics）
- 真虚报只剩 2 项（C-2 Outlook 默认关 + HomeEmailBanner.vue 不存在）
- 审计自身可信度 ≈ 40%，反向修订后 V7 真实完工度 ≈ 80%+
- 推测根因：审计 P8 在 `.claude/worktrees/agent-XXX/` 而非 main 树 grep，漏看 main 树新增文件
- 事故 cost：4 个 P7 commit（86ebb08f / ae09c2ec / 9d95d4df / 5346648a）反复加/撤 ⚠️

**How to apply**（派审计 / 蓝军 agent 时强制）：

1. **Cwd 必须 main 树**：prompt 显式要求 `pwd = /home/test/newworld 且 git branch 在 master`，**不许在 .claude/worktrees/agent-XXX/ 路径下 grep**。审计输出必须证据带 main 树 path。

2. **每项判断双证据**：
   - 类/文件存在性 → `find /home/test/newworld/<module>/src/main -name <claimed-class>` 必须 main 树命中
   - 测试声明 → `mvn test -Dtest=<class>` log 片段 or commit hash
   - "完工"声明 → `git log --all --oneline -- <path>` 拿 commit hash
   - **单一证据**（仅 grep 字面 / 仅看 docs）一律不可信

3. **抽样宁严勿松**：每项判断必须 grep main 树字面量，**不许相信文档措辞**（closure / runbook / smoke 都可能虚报）。审计报告交付前自审："我说的不存在的类，是不是真在 main 树跑过 find？"

4. **审计 ≠ 终结，P9 必须二次验证**：审计给出"虚报"或"半完工"结论后，**P9 二次抽样独立验证 1-2 项**，不许直接信审计单方面结论改文档/派活。5/2 教训：基于审计错判改 closure 加 ⚠️，事后又派 P7 撤销 4 次。

5. **配套 skill `newworld-sprint-closure-audit`** 已沉淀（CLAUDE.md 一级 16 个），4 条铁律 + 配套自查命令：closure 列每个类必带 main 树 path + git blame commit / "X 测试全过" 必带 mvn 命令 / P9 closure 前必跑 find 自查 / 蓝军强制抽样 3 项最具体声明 grep 实代码。

6. **必读 audit-suppressions.md 跳过已抑制项**（5/5 stats-audit P9 V1 教训）：审计 sprint 派任何 P8 / 蓝军前，Task Prompt 必须含：
   ```
   RULE 0: 在做任何分析前，先 Read：
   - docs/security/audit-suppressions.md —— 抑制清单，跳过已列项
   - CLAUDE.md "代码审计规范" 章节
   违反 RULE 0 的发现 = 0 价值。
   ```
   **5/5 教训**：stats-audit sprint 派 4 个 P8 + 4 个 Explore 共 8 agent，**没有任何一个被强制读 audit-suppressions.md**。结果 P9 V1 报告把 H5（visitor_fingerprint 不更新 channel_code）列为 P1 严重 bug——但 audit-suppressions L21（2026-03-20）已明文 Owner 抑制为"有意设计"。**蓝军-2 唱反调时才发现这条违规**。教训：审计前的 RULE 0 比 5 条铁律都重要——基于已抑制 contract 的"根因"等于推翻 owner 决策，是审计的"合规分"被扣光。

7. **dangling 代码必须追"使用方 → UI 行为 → 业务方工作流"三跳**（5/5 stats-audit F2 量化偏差教训）：审计找到字面量 dangling（如代码引用旧 contract、参数名错位、注释 vs 实现不一致），**不许直接给量化严重度**。必须先追三跳：
   ```
   跳 1（调用方追溯）：grep 谁调用这条 dangling 代码？前端哪个 .vue / 哪个 service？
   跳 2（UI 行为）：调用后给用户/运营展示的是什么？复制按钮？跳转链接？显示在哪个对话框？
   跳 3（业务方工作流）：业务方从这个 UI 拿到东西后，实际怎么用？复制粘贴到哪？经过哪些下游系统？
   只有跳 3 完成才能给量化估计。
   ```
   **5/5 教训**：stats-audit F2 根因（`generatePromoLinks` 仍生成 `?ref=` 但后端 V5 已不读）：
   - P9 V1 量化"30-100% 推广归因丢失"——纸上推算 P 域占比
   - 蓝军-2 修正"30-50%"——还是纸上推算（short_redirect.lua 已剥 ref 等抽象论证）
   - **用户一句"渠道不是已经不用 ref 了"** 才迫使 P9 真去看 ChannelList.vue：发现 L95 有"推广链接"按钮 → L487 调 `getPromoLinks` → L499 `copyLink` 直接复制到剪贴板 → 运营拿到的就是 `?ref=` 链接 → 复制粘贴到外站 100% 归零
   - 真正的量化指标是**"运营从这个对话框复制 vs 从短链系统拿的比例"**，是业务问题，不是代码 grep 能推出的
   教训：dangling 代码的"严重度"取决于业务方是否真在用——审计不能只看代码字面量给"30-100%"这种伪精确数字，必须追到 UI 真实使用场景。

8. **生产部署后 E2E 实证必跑**（5/6 stats-audit W7 教训）：mvn test 通过 ≠ 生产真工作。E2E-A 实证 SSH live curl 才发现 GAP-9 guard.lua **9 天没在 prod 生效**——文件就位 17:18 + nginx master PID 自 4-26 启动至今 9 天没 restart + `init_by_lua_block { guard = require "guard" }` 仅 master 启动时跑 + `openresty -s reload` 不重新 require 缓存模块。教训：sprint closure 必含"实证 4-5 类异常 host curl + grep prod 进程 PID + 对比 reload/restart 时间戳"。OpenResty 部署铁律改：**`systemctl restart openresty`，不是 reload**。

9. **蓝军判断也可能误判，P9 必须独立 grep 复核**（5/6 stats-audit W7 E2E-B 教训）：E2E-B 实证报告称"WILDCARD_FAILOVER 没 _vid 必填守卫"——P8-W7-B 实施前 grep 发现守卫**早已存在** StatsController L74-78 / L136-140 / L173-183。蓝军 grep 时漏看上下文 / 没真跑 mvn test 看 mock 行为。教训：蓝军主张涉及"代码不存在"或"功能未实施"时，P9 二次验证必须独立 grep 字面量 + 跑 test 确认，不直接信蓝军。

10. **CLAUDE.md 历史 Lessons Learned 不读完整 = 误判**（5/6 stats-audit E2E-B 教训）：E2E-B 静态推算"guard.lua parts<3 ban root @ 流量上线后立即爆"——但 CLAUDE.md L160 明文"guard.lua 白名单 + Strike 暂禁，仅保留 rate limit"，整个 ban 路径在 prod 已禁用 9+ 个月。教训：审计涉及"已抑制 / 已暂禁 / 已 deprecated"代码路径时，必须**读完整 Lessons Learned 段** + 验证 owner 是否已恢复决策，否则会误把"暂禁的代码"当成"上线就爆的代码"。

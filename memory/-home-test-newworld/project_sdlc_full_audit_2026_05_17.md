---
name: project-sdlc-full-audit-2026-05-17
description: 全量代码审计 sprint（8 组 ~200K 行）— 审计/修复/部署全闭环 + 16 教训
metadata: 
  node_type: memory
  type: project
  originSessionId: 118ffec4-44f5-400d-9f32-08f5c68b14c8
---

全量代码审计 sprint `2026-05-17-full-code-audit`：SDLC Agent Team 跑通 Phase 1-5（首个含 Phase 4 真生产部署的审计型 sprint）。

**规模**：8 组（G1-G7，G3 拆 G3a/G3b）~200K 行（4 后端 Maven 模块 + 2 前端 + OpenResty Lua），73 风险项。base `2c594159`，103 commit。

**成果（全部部署上线 aws-web×2 + aws-data + edge aws-s/usca-1/usca-2）**：
- BLOCKER 3 修复：ViewCountSyncService 分布式锁值毫秒碰撞→UUID（`a4d8ba13`）/ SiteStatsSyncTask Lua get-reset 竞态→GETDEL（`43f4cf20`）/ JwtAuthFilter getClientIp 无信任来源校验→isTrustedProxy（`e03405ce`）
- MAJOR 23：19 修复（+蓝军复核 R-1~R-6 返工）/ M2 System.gc 保留 / M5·M6·M7 延后 2026-05-26 退役链（EdgeOpsShadowDiffController 退役日 + N9E rule 下线）
- MINOR 47：A 档 ~28 修复 / B 档 7 修+5 留 / C 档 ~8 排除（含 guard.lua BAN_TTL+whitelist audit-suppressions 抑制项）
- 安全项 ~13 审计期重构
- qa 终态 mvn test 4 模块 0F/0E（common 440 / admin 1700 / web 597 / data 507）+ 前端 538/60

**16 条教训 L-1~L-16**（全文 `docs/sprint/2026-05-17-full-code-audit/sprint-report.md §5`），2026-05-17 Owner 授权 sink：
- SDLC 流程类 → `newworld-sdlc-agent-team` skill WARN-7~11：background worktree 隔离不可靠/foreground 优先、agent 自述 commit 必 git 实证、蓝军复核修复 commit、gate 条目必 triage、dev 必 mvn test-compile。
- 代码工具类 → CLAUDE.md Lessons Learned：安全项判定含行为变更维度、LSP 瞬态 vs mvn 权威、删分支级联清理、清理决策 code-side+access log 实证、UI v-if 恢复双引擎、部署 pre-flight 枚举 commit。

**质量防线实证**：qa 全程兜底揪 ~7 个测试同步 regression（GfwProbeAggregatorTest / RetentionCohortTaskTest 等）；蓝军两轮独立复核揪幻象 commit（`4a0992d1` commit message 描述 Java 改动实际未提交）+ 安全/风险误判（CacheWarmupService）+ 2 个 MAJOR 真 bug（热搜 SETNX 输家读空 / promoPoolCache 双 volatile 竞态）。

**遗留待办**：C 档 MAJOR M5/M6/M7 → 2026-05-26 退役链；未跟踪 `sql/wave_stats_v7_005_drop_visitor_alias.sql`（VisitorAliasWriter 删除的 DB 侧对应）DBA-gated；edge `listen http2` nginx 语法弃用警告；`deploy-frontend.sh` 本地控制机路径 bug。

承接 [[project-sdlc-closeout-2026-05-16]]——SDLC Agent Team v1.0 收官后首个大型审计型 sprint，验证 8 组并行 + Phase 4 部署普适性。

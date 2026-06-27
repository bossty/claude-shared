---
name: project-shadow-diff-retire-2026-05-17
description: shadow_diff_log 影子对账子系统数据驱动提前退役 sprint + 4 教训
metadata: 
  node_type: memory
  type: project
  originSessionId: 118ffec4-44f5-400d-9f32-08f5c68b14c8
---

SDLC sprint `2026-05-17-shadow-diff-retire`：数据驱动提前退役 `shadow_diff_log` 影子对账子系统（v4→v5 统计迁移遗留，源自 [[project-sdlc-full-audit-2026-05-17]] gate 清单 C 档 M5/M6/M7）。

**提前退役依据**：原计划 T+30=2026-05-26 退役。lead 实查 `shadow_diff_log` 表——4091 行、最新 row 2026-04-26 20:04（v5 cutover 日），21 天零写入。T+30 观察期目的（确认 cutover 后无残留写入）已被数据提前达成 → Owner 拍板提前退役。

**SDLC Phase 1-5 闭环**：
- Phase 3 删 7 类：`f4b63085`（web ShadowDiffLogger/RetryHitRecorder）/ `f6b92465`（admin EdgeOpsShadowDiffController+StatsShadowDiffController+AnalyticsV5MetricsScheduler+v4 gauge）/ `aa2aa458`（common ShadowDiffLogMapper+DTO）；qa admin 1700 0F/0E。
- Phase 4：全量部署（含 B 档 backlog 7 commit 一并上线）+ `RENAME TABLE shadow_diff_log TO _retired_shadow_diff_log_20260517`（4091 行保留，软删非 DROP）。
- **Phase 4b 待办**：真 `DROP TABLE _retired_shadow_diff_log_20260517` 最早 2026-05-24，DBA-gated，见 `docs/sprint/2026-05-17-shadow-diff-retire/PHASE-4b-real-drop.md`。

**4 教训已 sink**：
- deploy 类 → `newworld-deploy-runbook` skill 教训补充：① 部署 pre-flight 必确认本地已 push（`git rev-list origin/master..HEAD` 非空先 push；本 sprint Phase 4 因 15 commit 未 push 差点 build 旧码、ops HALT 拦下）；② sprint 收尾"待部署"项须跟踪禁搁置。
- 通用类 → CLAUDE.md Lessons Learned：① lead recon 转述是起点、下游必 LSP findReferences 独立复验（pm-helper 据此揪出漏列的 StatsShadowDiffController）；② 代码 @Scheduled 存活 ≠ 子系统活跃、退役判据看数据。

**不扩 scope**：相邻的 `stats:shadow-uv` dual-write（蓝军发现，flag 生产 false 已 no-op）留后续独立清债。

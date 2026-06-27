---
name: project-sdlc-e-sprint-2026-05-16
description: SDLC Agent Team E-sprint（vue-tsc 类型清理）— 第 3 个真业务 sprint；W3+LSP-2+E 三连铁律累计 ROI；dev-senior 暴露改动边界最佳实践
metadata: 
  node_type: memory
  type: project
  originSessionId: da3be312-2b73-46c3-95da-580bd268b069
---

SDLC Agent Team sprint `2026-05-16-vue-tsc-e`（E-sprint）—— LSP-2 OQ-4 defer 的 E 类 vue-tsc 类型不一致清理，**第 3 个真业务 sprint**（W3 dry-run → LSP-2 → E-sprint）。

## 业务成果
- §E 7 文件 vue-tsc 错清零（4 文件 window TS2339 + BrandCards/SponsorBar ad.* TS2339 + HomeDesktopSections Swiper TS2322）
- 新建 `frontend-web/src/types/window.d.ts`（全局 window 扩展）+ `ad.ts` AdItem interface（7 字段 id/clickUrl/clickTarget/imageUrl/origExt/title/description）
- vue-tsc 总行数 baseline 646→633，npm test 543 passed 0F，npm build exit 0，零 regression
- 6 commit，master HEAD `5b37799d` 已 push

## 流程全程
- Phase 1 PRD: pm-helper 三刷（v1→v2→v3），7 铁律
- Phase 1 蓝军: reviewer 二轮 8 挑刺（round1 6 条 2BLOCKER+3MAJOR+1MINOR / round2 1BLOCKER+1MINOR）全闭环，受限双向 reply_count 2/2
- Owner 软门 1: 5 OQ 拍板（全局 window.d.ts / 新建 AdItem interface / Swiper 先确认模式 / 单 worktree / **OQ-5 豁免 playwright webkit 双引擎**）
- Phase 3 Code: 1 dev-senior isolation worktree 6 commit；Swiper 用 `@type {any}` JSDoc cast 纯类型解决（无 runtime 改）
- Phase 3/4 qa: qa-senior 整体验证全 PASS
- Phase 5 沉淀: memory-keeper sprint-report.md + 5 候选教训

## 教训 #3：dev-senior 主动暴露「改动边界 vs 预存问题」是正确习惯

dev-senior 在状态档主动说明 `HomeDesktopSections.vue` 含大量预存 TS2339（movie.id / $appConfig / intrinsicWidth，baseline 646 已存在、非 §E scope），并建议 qa 用精确 grep（`grep "HomeDesktopSections.*TS2322"`）而非 raw filename grep——避免 qa 看到该文件仍有 TS 错误就误判 §E 未清零。

**最佳实践**：dev-senior 状态档"验收结果"段，凡有预存问题的文件必须加"注意：此文件含 N 条预存 §X 范围外错误，已在 baseline，本 sprint 不修"+ baseline commit sha 参照。qa-senior 据此用精确 grep 核查。

## 教训 #4：W3+LSP-2+E-sprint 三连 SDLC 铁律累计 ROI

第 3 个真业务 sprint 连续验证 SDLC 铁律稳定生效：
- **commit-message-precision**：6 commit 全含 `+N/-M lines, X files`，qa 可对账
- **reviewer Write 落盘**：reviewer.md round1+2 在 repo 内可审计
- **受限双向 max_round=2**：pm-helper reply_count 2/2 终结防无限 back-and-forth
- **7 铁律 / Phase 1 软门**：8 条挑刺（含 3 BLOCKER）在 Phase 3 前全拦截，dev-senior 零误删
- **token cost ~$3/sprint**：产品改动极小（+44/-13 lines）+ 蓝军 8 挑刺 100% 真实发现——Phase 1 蓝军成本换 Phase 3 返工节省，正 ROI

**结论**：三连验证稳定后，SDLC Agent Team 流程可推广到下一类 LSP 清理 sprint（§F deprecated method 迁移 / §G 等），不需每次重验流程本身。

## 工程问题（已 sink CLAUDE.md）
- background sub-agent 截断**系统性**：E-sprint reviewer 二审 + dev-senior 各被截断 1 次（连 LSP-2 共 2 sprint 实证），resume 续跑每次救回——详见 [[CLAUDE.md Lessons Learned]]

## 已 sink 的其他教训
- 纯编译期改动豁免双引擎视觉回归（OQ-5 实证）→ [[feedback_qa_safari_chrome_dual_engine]] 补"适用范围"段
- vue-tsc `.vue` 文件 `lang="ts"` 强制 TS 模式前提 → [[reference_lsp_toolchain]] 补段

## 关联
- 上游 spec `docs/superpowers/specs/2026-05-14-agent-team-sdlc-design.md`
- 前序 sprint [[project_sdlc_lsp2_2026_05_16]]（LSP-2，A/B/C/D 类）+ [[project_sdlc_w3_dryrun_2026_05_15]]（W3 dry-run）
- sprint 产物 `docs/sprint/_archive/2026-05-16-vue-tsc-e/`（PRD v3 / agents/*.md / sprint-report.md；closeout sprint 已归档至 _archive/）
- 候选 audit-suppression：HomeDesktopSections.vue 预存 TS2339（baseline 非 §E scope）—— 待 Owner 决定是否入 `docs/audit-suppressions.md`

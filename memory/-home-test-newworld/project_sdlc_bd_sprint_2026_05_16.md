---
name: project-sdlc-bd-sprint-2026-05-16
description: SDLC Agent Team BD-sprint（F-sprint defer 的分组 B+D）— 第 5 个真业务 sprint，首个设计决策型；W3→LSP-2→E→F→BD 五连；首次 qa 误诊→main 仲裁事件
metadata:
  node_type: memory
  type: project
  originSessionId: da3be312-2b73-46c3-95da-580bd268b069
---

SDLC Agent Team sprint `2026-05-16-deferred-bd`（BD-sprint）—— F-sprint 软门 defer 的分组 B + 分组 D 两项 deprecated 清理，**第 5 个真业务 sprint**，首个**设计决策型**（B 4 方案 / D 3 选项需 Owner 拍设计方向，非干净等价迁移）。

## 业务成果
- 分组 B 完成：`PromotionChannelDomainMapper.findActiveByChannelAndCategory` 弃用清理 —— Owner 拍方案 2（新增 `findActiveBindingsByChannel(channelId, bindCategory)` 返 `PromotionChannelDomain` 含 role 字段），`rotateSDomain` + `rollbackPhase1` 迁移到新方法，`b.getRole()` PRIMARY binding 判定逻辑保留
- 分组 D 未做：Owner 拍选项 C（跳过不动，`SystemConfig.Keys.CDN_ASSETS_URL` 仍 deferred）
- 4 commit master HEAD：`0f75a53d` / `44d4cea7` / `23a43af1`（dev code）+ `931c947b`（状态档）；sprint 产物 commit `6c5fa6aa`
- qa 多模块 mvn test 1722 tests 0F/0E/8skip + Spring 冒烟 `ChannelLifecycleE2ETest` 7 tests PASS + deprecated/getDomainId 归零 + 新方法 SQL `retired_at IS NULL` 等价性 PASS，零 regression

## 流程全程
- Phase 1 PRD: pm-helper 三刷（v1 摆 B 4 方案 + D 3 选项 trade-off → v3），设计决策型重在摆 trade-off 不自决
- Phase 1 蓝军: reviewer 二轮 9 挑刺（round1 6 条 2BLOCKER+3MAJOR+1MINOR / round2 1BLOCKER+1MAJOR+1MINOR）全闭环，reply_count 2/2
- Owner 软门 1: 分组 B = 方案 2（新增 mapper 方法）/ 分组 D = 选项 C（跳过）
- Phase 3 Code: 1 dev-senior 3 commit 实施分组 B 方案 2
- Phase 3/4 qa: **首次 qa 误诊→main 仲裁→重验事件**（见下）
- Phase 5 沉淀: memory-keeper sprint-report.md + 5 候选教训

## 教训 #1：qa 误诊 → main session 仲裁 → 重验 事件（首次）
qa-senior 首轮报 BUILD FAILURE，称 `BindCategory.S` 类型不匹配需加 `.name()`。dev-senior 反对：`BindCategory` 是 String 常量无需改，failure 实为单模块构建撞 stale jar。main session lead **不选边**，Read `PromotionChannelDomain.java:95` 确认 `BindCategory` 是 `public static final class`（String 常量容器、非枚举）→ dev 对、qa 误诊。重派 qa 用多模块 `mvn -pl newworld-common,newworld-admin` → PASS。
两条已 sink [[CLAUDE.md Lessons Learned]]：① 跨模块改动 qa 必须多模块 `mvn -pl A,B` 同时编译（单模块撞 stale 依赖 jar）；② sub-agent 诊断冲突 main session 必须查实代码仲裁不凭角色权威。**新增 pipeline 模式：qa 误诊→dev 异议→main 代码实证仲裁→通知双方。**

## 教训 #2：设计决策型 sprint pm-helper 摆 trade-off 不自决有效
分组 B 4 方案（findActiveDomains 迁移丢 role / 新增 PCD mapper 方法 / 去 role filter / 留 deprecated）+ 分组 D 3 选项（重命名+DB migration / 仅删标注 / 跳过）。pm-helper v1 完整摆 trade-off 矩阵交 Owner 软门 1，未擅自选方案，Owner 拍方案 2 + 选项 C。**SDLC pipeline 适配设计决策型 sprint**：PRD phase 允许增一轮 Owner 软门（摆方案→Owner 拍→才出 implementation plan），不强行在 v1 PRD 写定实施方案。

## 教训 #3：reviewer 行为相邻 SQL 等价 catch（status vs retired_at）
R2-1 BLOCKER：pm-helper v2 新方法 SQL 用 `status='active'` 替代 deprecated 原 `retired_at IS NULL`。reviewer 3 源交叉（deprecated XML 原 SQL + PRD 新 SQL + `retireBinding` 软删除机制）揭示软删除只写 `retired_at` 不改 `status`，已退役 binding 会被错误返回。已 sink [[newworld-sprint-closure-audit]] §8（软删除字段 ≠ 业务状态字段，新方法 SQL 逐行对照 WHERE）。

## 教训 #4：W3→LSP-2→E→F→BD 五连 SDLC，设计决策型完整走通
第 5 个真业务 sprint。五连覆盖五种改动类型：W3 dry-run / LSP-2 纯删除 / E-sprint 类型补全 / F-sprint 行为相邻迁移 / **BD-sprint 设计决策型**。pipeline 普适性彻底验证，后续清理 sprint 直接套流程，不再每次重验流程本身。

## Deferred backlog（待 Owner 另起 sprint）
- **分组 D** `SystemConfig.Keys.CDN_ASSETS_URL`（Owner 选项 C 跳过，仍 deferred）：reviewer 留两个坑备忘——① `@CdnUrl` 裸注解隐性路径是盲区，清债前先 grep `@CdnUrl` 全量调用点；② 若选新增配置键，DB migration 用 sentinel 占位（`newworld-sql-seed-sentinel`），不用 `INSERT...SELECT` 拷旧值。PRD §11 留三项前置条件备忘
- 候选 audit-suppressions：待 Owner 复核 sprint-report.md §6

## 关联
- 上游 spec `docs/superpowers/specs/2026-05-14-agent-team-sdlc-design.md`
- 前序 sprint [[project_sdlc_f_sprint_2026_05_16]]（F-sprint，本 sprint 清的 B/D 即 F-sprint defer）+ [[project_sdlc_e_sprint_2026_05_16]] + [[project_sdlc_lsp2_2026_05_16]] + [[project_sdlc_w3_dryrun_2026_05_15]]
- sprint 产物 `docs/sprint/_archive/2026-05-16-deferred-bd/`（PRD v3 / agents/*.md / sprint-report.md；closeout sprint 已归档至 _archive/）

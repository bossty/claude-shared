---
name: project-sdlc-f-sprint-2026-05-16
description: SDLC Agent Team F-sprint（deprecated method 迁移）— 第 4 个真业务 sprint，首个行为相邻类型；W3→LSP-2→E→F 四连铁律累计
metadata: 
  node_type: memory
  type: project
  originSessionId: da3be312-2b73-46c3-95da-580bd268b069
---

SDLC Agent Team sprint `2026-05-16-deprecated-f`（F-sprint）—— §F deprecated method/API 迁移，**第 4 个真业务 sprint**，首个**行为相邻**类型（API 替换可能有语义差异，比纯删除/类型补全风险高）。

## 业务成果
- 10 组 deprecated API 迁移（@MockBean→@MockitoBean / markBlocked→markConfirmedBlocked / purchaseShortLinkDomain / configureWebZone / EmbeddingTagRecall 2→4-param / 删 H/J/K/L 无调用方定义 / DomainPoolMetricsBinder）
- 8 commit，master HEAD `ff86e22f` 已 push
- qa-senior 4 模块 mvn test 3318 tests 0F/0E + Spring 冒烟无 Bean 异常 + 行为相邻 cross-check 全 PASS，零 regression

## 流程全程
- Phase 1 PRD: pm-helper 三刷（v1 12 组 → v3 10 组），**无现成 doc，pm-helper 自己 grep 全量建 deprecated 清单**
- Phase 1 蓝军: reviewer 二轮 8 挑刺（round1 6 条 2BLOCKER+3MAJOR+1MINOR / round2 1MAJOR+1MINOR）全闭环，reply_count 2/2
- Owner 软门 1: **分组 B + 分组 D defer**（B 替代方法丢 role 字段 / D CDN_ASSETS_URL 替代键 grep 三方零命中）；E 保留 wrapper / F 纳入；scope 12→10 组
- Phase 3 Code: 1 dev-senior isolation worktree 串行 10 组 8 commit，**被 background 截断 3 次**
- Phase 3/4 qa: qa-senior 权威验证全 PASS

## 教训 #1：mvn 验证集中交 qa-senior，不在 dev-senior context 跑
F-sprint dev-senior 被 background 截断 **3 次**（最多），根因是 `mvn test` 单步耗时超 background context 存活窗口。改策略：dev-senior 仅做单分组局部 `mvn compile -pl` 快检，全量 mvn test 集中交 qa-senior。已 sink [[CLAUDE.md Lessons Learned]]。

## 教训 #2：行为相邻 sprint qa 必须 cross-check 语义不只跑测试
分组 C `markBlocked` 拆 `markPolluted`（可恢复）/`markConfirmedBlocked`（永久），两条都过 mvn test，但语义选错致生产行为反转（GFW 封禁域名自动恢复上线）。qa-senior 读 `ChannelLifecycleServiceTest:1191-1193` 上下文才确认 `markConfirmedBlocked` 正确。已 sink [[newworld-sprint-closure-audit]] §7。

## 教训 #3：替代 API 不完备时 defer 是正确决策，SDLC 软门成功拦截
分组 B 替代方法 `findActiveDomainsByChannelAndCategory` 返回 `Domain` entity 无 `role` 字段（rotateSDomain 依赖 `b.getRole()` 判 PRIMARY binding）；分组 D `CDN_ASSETS_URL` 替代键 grep 三方零命中。reviewer 两轮挑刺 + Owner 软门 1 拍板 defer 这 2 组——SDLC pipeline Phase 1 软门成功拦"不该在本 sprint 硬做的组"，避免 dev-senior 误迁致 rotateSDomain 语义错。**defer 不是失败，是正确风险决策。**

## 教训 #4：W3→LSP-2→E→F 四连 SDLC 铁律累计
第 4 个真业务 sprint，连续验证 SDLC 铁律稳定生效，且本 sprint 是首个**行为相邻**类型（前 3 个：W3 dry-run / LSP-2 纯删除 / E-sprint 类型补全）。四连覆盖 dry-run + 纯删除 + 类型补全 + 行为相邻迁移 四种改动类型，pipeline 普适性验证完成。后续 §G 等清理 sprint 可直接套流程。

## 工程踩坑（main session 自身失误，已纠正）
main session 的 Bash cwd 误入 dev-senior worktree，首次 `git merge` 实为"worktree merge 自己"（Already up to date 假象），dev-senior 8 commit 一度没进 master。发现后 cd 回主仓重做真 merge（`ff86e22f`）。**教训：Bash cwd 在 worktree sprint 中会漂移，git 操作前先 `git branch --show-current` 确认在 master**。

## Deferred backlog（待 Owner 另起 sprint）
- **分组 B** `PromotionChannelDomainMapper.findActiveByChannelAndCategory` —— Domain entity 加 role 字段 OR mapper 联查方案，rotateSDomain 核心逻辑，需设计
- **分组 D** `SystemConfig.Keys.CDN_ASSETS_URL` —— 替代配置键未知，3 选项（新增 R_ASSETS / 废弃 / 跳过）待 Owner 拍板

## 关联
- 上游 spec `docs/superpowers/specs/2026-05-14-agent-team-sdlc-design.md`
- 前序 sprint [[project_sdlc_e_sprint_2026_05_16]] / [[project_sdlc_lsp2_2026_05_16]] / [[project_sdlc_w3_dryrun_2026_05_15]]
- sprint 产物 `docs/sprint/_archive/2026-05-16-deprecated-f/`（PRD v3 / agents/*.md / sprint-report.md；closeout sprint 已归档至 _archive/）
- 候选 audit-suppressions：backward-compat 测试组保留调 deprecated 方法（非迁移遗漏）—— 待 Owner 决定入 `docs/security/audit-suppressions.md`

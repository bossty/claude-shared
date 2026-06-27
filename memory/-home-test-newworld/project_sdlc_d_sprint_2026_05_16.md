---
name: project-sdlc-d-sprint-2026-05-16
description: SDLC Agent Team D-sprint（分组 D CDN_ASSETS_URL deprecated 键清理）— 第 6 个真业务 sprint，SDLC deferred backlog 全清；W3→LSP-2→E→F→BD→D 六连
metadata:
  node_type: memory
  type: project
  originSessionId: da3be312-2b73-46c3-95da-580bd268b069
---

SDLC Agent Team sprint `2026-05-16-deferred-d`（D-sprint）—— BD-sprint defer 的分组 D（`SystemConfig.Keys.CDN_ASSETS_URL` deprecated 键清理），**第 6 个真业务 sprint**，第 2 个设计决策型。是 F-sprint→BD-sprint→D-sprint 一路 defer 的**最后一项** deferred backlog。

## 业务成果
- 选项 B（废弃删除整条 assets-CDN 链路）实施：删 deprecated `CDN_ASSETS_URL` 键 + `CdnUrlType.ASSETS` 枚举值 + 两个 `CdnUrlHelper` 的 `case ASSETS` 分支 + `CdnConfigController` 的 `assetsUrl`（GET/POST 三元组→二元组校验）+ `SystemConfigService` 三方法（getCdnConfig/updateCdnConfig/getCdnVersion）+ 测试 4 处；`CdnUrl.java:31` 默认值 `ASSETS`→`IMAGES`
- 5 commit master HEAD：`3ad90865`/`3db4afdb`/`a70206bc`/`8e171ab0`/`b8448819`，跨 common+web+admin 三模块 9 files +19/-30；sprint 产物 `fbcc0ae2`+`e8d6d22c`
- qa 多模块 `mvn test -pl newworld-common,newworld-web,newworld-admin` 1722 tests 0F/0E/8skip + 7/7 验收 PASS + 蓝军 #1/#2/#3/#6 闭环
- DELETE migration SQL `sql/deferred_d_drop_cdn_assets_url.sql`（条件化，ops 按 OQ-5 部署前查 prod DB 后按需执行）

## 流程全程
- Phase 0 recon: main session lead 实证全库 8 处 `@CdnUrl` 全带显式参数零裸注解 + 零 `CdnUrlType.ASSETS` 消费方 → assets-CDN 是 v3 全静态迁移遗留 dead code
- Phase 1 PRD: pm-helper 三刷 v1→v3，摆选项 A（新增 R_ASSETS）vs B（废弃删除）trade-off，自己 grep 复验 recon（6 条证实 + 2 新发现）
- Phase 1 蓝军: reviewer 二轮 8 挑刺（round1 6 条 2BLOCKER+3MAJOR+1MINOR / round2 2 条）crossfire 闭环 reply_count 2/2
- Owner 软门 1: OQ-1=选项B / OQ-2=删枚举值 / OQ-3=默认值改 IMAGES / OQ-5=prod DB 让 ops 查
- Phase 3 Code: 1 dev-senior worktree 5 commit；Phase 3/4 qa-senior 多模块 mvn 权威验证 PASS
- Phase 5 沉淀: memory-keeper sprint-report.md + 5 候选教训

## 教训 #1：跨模块 mvn 铁律 sink 后立刻 ROI 实证
BD-sprint sink 的「跨模块改动 qa 必须多模块 `mvn -pl A,B`」铁律，D-sprint qa-senior 派工指令直接固化进 AC-3，3 模块一次 `mvn test -pl newworld-common,newworld-web,newworld-admin` 0 误诊（对比 BD-sprint qa 首轮单模块误诊 BUILD FAILURE）。**沉淀铁律下一 sprint 即收 ROI**——已 sink 的 [[CLAUDE.md Lessons Learned]] 跨模块 mvn 条目本 sprint 验证有效。

## 教训 #2：设计决策型 sprint「recon→选项→软门」链路已成熟
D-sprint 是第 2 个设计决策型（[[project_sdlc_bd_sprint_2026_05_16]] 是第 1 个）。链路稳定：main session lead 先 recon 实证（零消费方）→ pm-helper 摆 A/B trade-off 不自决 → reviewer 独立挑刺 → Owner 软门 1 拍方案。两个设计决策型 sprint 验证流程可复用，后续清债 sprint 直接套。

## 教训 #3：crossfire 是双向的——蓝军挑刺可被 senior 实证驳回
reviewer round1 #5 MAJOR 担心 frontend-admin spread 解构隐性引用 `assetsUrl`，pm-helper R-7 深挖 `MovieList.vue:963` 只读显式字段名 + `cdn.js` 按键名读，实证 frontend-admin 无 spread 模式，reviewer round2 承认反驳成立、自降 MINOR 闭环。**crossfire 非「蓝军说了算」单向**——挑刺与反驳都须带实证，谁有实代码证据谁对。已 sink [[feedback_agent_team_crossfire]]。

## 教训 #4：background 截断六连实证
D-sprint dev-senior 截断 2 次 + qa-senior 1 次（mvn 长耗时触发）+ ops-senior 1 次（部署早期），resume 续跑全救回。连续 6 个真业务 sprint 全部出现，已 sink [[CLAUDE.md Lessons Learned]]（证据列表更新到 6 连）。

## 教训 #5：W3→LSP-2→E→F→BD→D 六连，SDLC deferred backlog 全清
分组 D 是 SDLC Agent Team 全部 deferred backlog 的**最后一项**——至此 LSP unused（LSP-2 51 条）/ vue-tsc 类型（E）/ deprecated 迁移（F 10 组）/ deferred 设计决策（BD 分组 B + D 分组 D）四类清理全部清零。六连覆盖 dry-run / 纯删除 / 类型补全 / 行为相邻 / 设计决策型（×2）五种改动类型，pipeline 普适性彻底验证完成。D-sprint 更是首个走完 Phase 4 真生产部署的 sprint（详见下「Phase 4 生产部署完成」段），SDLC pipeline 需求→上线端到端首次全链路跑通。

## Phase 4 生产部署完成（2026-05-16，ops-senior）
- **AC-5**：aws-db prod DB `SELECT ... WHERE config_key='CDN_CF_URLS_ASSETS'` → **0 行** → 跳过 DELETE migration（OQ-5 实际无行——getCdnVersion 早就只聚合 2 键，蓝军 #2 单调性风险天然不存在）
- 三台部署 @ `b3363f8c`：aws-web-01/02 newworld-web + aws-data newworld-admin，git pull + build + restart 全 OK
- **AC-7a**：三台 `systemctl restart` 成功（SystemConfig Caffeine L1 缓存强制失效）
- **AC-7b**：V_before=V_after=5（config_version）→ 三分支第一分支无需操作，版本单调性正常
- 验证：journalctl 无 ERROR / 无 BeanCreationException，smoke PASS（admin /api/v1/storage 401 鉴权正常、web JSON 404 容器正常）
- ops 实务细节：`/api/v1/storage` 走鉴权返 401，ops-senior 改直查 `system_config.config_version` 拿 V_before/V_after——等价且更直接，部署验收 API 端点被鉴权挡时的常规旁路
- ops 状态档 `agents/ops.md`，部署 commit `9db491ce`
- **D-sprint 是 SDLC Agent Team 首个走完整 Phase 1-5 + Phase 4 真生产部署的 sprint**（前五个止于 master 未单独部署）——pipeline 端到端（需求→PRD→实施→验证→沉淀→上线）首次全链路验证

## 关联
- 上游 spec `docs/superpowers/specs/2026-05-14-agent-team-sdlc-design.md`
- 前序 sprint [[project_sdlc_bd_sprint_2026_05_16]]（BD-sprint，本 sprint 清的分组 D 即 BD-sprint defer）+ [[project_sdlc_f_sprint_2026_05_16]] + [[project_sdlc_e_sprint_2026_05_16]] + [[project_sdlc_lsp2_2026_05_16]] + [[project_sdlc_w3_dryrun_2026_05_15]]
- sprint 产物 `docs/sprint/_archive/2026-05-16-deferred-d/`（PRD v3 / agents/*.md / sprint-report.md；closeout sprint 已归档至 _archive/）

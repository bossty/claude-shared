---
name: project_doc_governance_sprint_2026_05_30
description: 2026-05-30 文档治理 sprint——TeamCreate 团队审计 825 md+98 脚本+65 memory，归档清理+DOC_GOVERNANCE 规范+CLAUDE.md 瘦身；owner 六轮抽查揪出归档过度，不动点还原
metadata: 
  node_type: memory
  type: project
  originSessionId: 8bec6df6-1160-4bf7-991f-1de0635218cb
---

2026-05-30 文档治理 sprint（TeamCreate 团队 `doc-cleanup` 非 subagent：5 审计 auditor + 1 蓝军 reviewer）。起因：owner 要"整理全项目文档/CLAUDE.md/memory，删无用废弃重复，目录清晰、新会话不漏读、立记录规范"。本会话 ~23 commit 全 push origin master。

## 最终成果（站得住的）
- **CLAUDE.md 466→302 行**：Lessons Learned 106 行 sprint 全文 + 浏览器段尾误置 6 sprint 全文 → 下沉为 memory 指针（保留 11 条跨 sprint 高频原则）；skill 索引 26→30 补全（漏 deploy-jar-symlink/mybatis-plus-camel-mapping/sdlc-agent-team）；新增「分层文档索引」段（11 主题指向 durable docs，新增 durable 必登记）。
- **新增 `docs/DOC_GOVERNANCE.md`**：四类知识归属（CLAUDE.md/memory/skill/docs）+ 目录结构 + 生命周期 + §4 删除铁律 + 沉淀 checklist。**这是本 sprint 的 durable 抓手**，后续归档/沉淀按它走。
- **MEMORY.md 0 孤儿**（补 project_ad_image_encrypt + fe_perf_phase1 索引）。
- 归档：垃圾清理（根 jpg/har/.tmp/.claire/__pycache__→gitignore）+ 完结 sprint + 一次性脚本 + 一次性文档。docs 顶层 175→102，scripts 顶层 98→67，_archive 终态 83 docs + 24 scripts（全 0 引用 + 0 pending + 内容完结）。

## 核心教训（DOC_GOVERNANCE §4 已沉淀，复用必读）
1. **docs 是深度交叉引用的网，reference web 禁部分归档**：`docs/recon/`（211）、设计·版本史（S_P_ARCH 各版/IMG_PROCESSING 各版）、契约/审计报告互相引用 + 被 active 设计档引用。部分归档→级联悬空（recon 部分归档实测 50 处 durable 悬空，superseded 再级联 18）。规则：整簇 KEEP 或整簇归档。recon 最终整体还原回 docs/recon。
2. **code→doc 的 Javadoc/注释路径引用最易漏**：live 代码 Javadoc 写 `* 设计文档：docs/X.md`/`{@code docs/recon/Y.md}`/`见 scripts/Z.py`。只 grep doc-to-doc 或符号名会漏 → 误归档 + 代码留悬空。归档前必扫 `grep -rhoE '(docs|scripts)/...\.(md|sh|py)' --include=*.java...` 检出悬空。
3. **归档后必跑不动点循环复验**：反复"扫 active→_archive 悬空 + 还原"到 0 收敛（本次 4 轮收敛），防级联残留。
4. **sprint 完结判据看实证不看日期**：归档 sprint 前验①有 sprint-report/closure ②有 project_xxx memory ③无 in-flight 强标记（`未部署`/`待验收`/`待 T5`/`@ConditionalOnProperty 默认 false 未启用`/`movie.status=0 待升`）。kanav-crawler 被误归档（命中全部 in-flight 标记）→ 抽查还原 → owner 5/30 决定**暂时放弃**→ 加 SPRINT-CLOSURE.md 真完结后归档（代码 gated-off 保留不删）。
5. **真一次性 = 零引用 + 零 pending + 内容完结，三条都过**："无引用"≠可归档（E_PLAN_CLOUDFLARED_TUNING 无引用但头部"待 owner OK"+cloudflared 是 active peak-perf P1 议题 → 还原）。

## owner mindset 实证（六轮抽查碾压 bulk 归档）
owner 不信"看着干净"，逐桶抽查：docs/_archive → runbook → research/sprint → recon → 84 一次性 → sprint 归档，**六轮揪出 ~45 个误归档**（26 code-ref + 16 runbook-ref + RESEARCH/dragonfly/grayscale + recon 211 web + E_PLAN + kanav）。规则沉淀同源 [[feedback_audit_methodology]]：grep 反向扫 + 不动点 + 实证判完结，是抗"bulk 归档想当然"的抓手。team 协作教训同源 [[feedback_agent_team_crossfire]]（蓝军早 flag kanav MAJOR-2，bulk 时没采纳，抽查才纠回）。

## ⚠️ Churn 复盘（最该认的教训，下次别重犯）

**事实账**：本会话 44 commit 里 **10 个是 `fix(archive): 还原`**——recon 211 + llm-unified 4 + tag-audit 7 + refsite ~17 + superseded twins + W4-CRAW 等**全是先误归档又还原**，纯 churn。owner 八轮逐桶抽查才逼出收敛（docs/_archive→runbook→research/sprint→recon→84→img-pipeline→superseded→llm-unified→research/img）。

**根因（双重 grep 盲区）**：① 初审 team 只扫 doc-to-doc + 符号名，漏 **code→doc Javadoc 路径**；② 收官 team 用**路径级** `docs/X.md` 不动点，漏 **簇成员裸名互引**（表格 `| TAG_AUDIT_P8A.md |` / 姊妹文档 / 相对路径 `refsite/SOLUTION.md`）。两次都漏，致 GO 后仍揪出 3 个簇。

**治本铁律（已写进 DOC_GOVERNANCE §4#6）**：① **`docs/recon` + 设计版本史 + 契约/审计/研究簇 = 交叉引用 web，本就不该尝试部分归档**——动手前先识别「这是 reference web」整簇别碰；② 归档前**必跑精确裸名 `\b<name>\.md` 不动点 + `--exclude-dir=.claude/.claire`**（防 worktrees 灌水）扫到 0 引用收敛，**这是归档的前置闸门不是事后补救**。

**高价值 vs churn 的分界（下次照此过滤）**：真净赚=根目录垃圾清理/gitignore、21 sprint 归档（自包含）、24 脚本归档、CLAUDE.md 466→306+分层索引、DOC_GOVERNANCE 规范、MEMORY 沉淀；纯 churn=doc-content 簇归档（零损坏因归档不删除+还原零丢失，但浪费 10 commit + owner 8 轮抽查时间）。**下次文档治理：先做自包含的（sprint/script/junk/CLAUDE 瘦身/规范），doc-content 簇默认不动，除非整簇 0 引用。**

**owner mindset 实证**：owner「这么抽查下去是不是全要还原了，team 在干嘛」一句揪出方法论系统性盲区——不是逐桶问题，是 bulk 归档验证闸门缺失。

## 抽查收官闭环（验证方法论演进 + verify-before-GO 纪律）

**过程**：owner **十余轮逐桶抽查**（docs/_archive → runbook → research/sprint → recon → 84一次性 → img-pipeline → superseded → llm-unified → research/img → scripts → sprint 归档 → 收官终验），每轮都用「精确裸名 `\b<name>\.md` + 排除 worktrees」复验。中途 spawn 第二个团队 `doc-closeout`（C1 归档正确性 + C2 规范/索引/memory + 蓝军 crossfire）判 GO——但**蓝军 NO-GO 基于读 stale 规划档（CLEANUP-PLAN/A4-MOVES）被 main session 查实仲裁推翻**（git log 实证全 commit+push），C2 反向揪出 **13 个 durable 漏登记 CLAUDE.md 索引**（真 gap，已补）。

**验证方法论三级演进（核心教训）**：① 初审 team = doc-to-doc + 符号名 grep（漏 code→doc Javadoc）；② 收官 team = **路径级** `docs/X.md` 不动点（漏簇成员**裸名互引**）；③ 真治本 = **精确 `\b<name>\.md` 裸名口径** + 排除 `.claude/.claire` worktrees（防 ref-count 灌水）+ 通用名（reviewer/README/SOLUTION/RECOMMENDATION）人工辨。只有 ③ 能扫出 llm-unified/tag-audit/player-hijack 三个部分归档簇。

**verify-before-GO 救场**：owner 问「能否收官」时**没直接喊 GO**——终验第一遍跑出 3 个 ⚠️（2 个 regex 假象 + **1 个真悬空**：还原 refsite/SOLUTION.md 漏了它引用的外层 player-hijack 研究→簇又分裂）。整簇还原 15 文件后重验 0 残留才 GO。**铁律实证：claim done 前必先跑验证，差点又漏一个。**

**收敛终态（GO 证据）**：① _archive 41md（img-pipeline/research/superseded）精确裸名 0 引用 ② CLAUDE.md 65 docs+30 skill 全解析 ③ 21 sprint 全有收官档/memory（补 4 SPRINT-STATUS）④ git 0 dirty/0 未push ⑤ DOC_GOVERNANCE 5 处不自洽已修+自洽。**规则全沉淀 DOC_GOVERNANCE §3/§4（含精确裸名口径 §4#6）。**

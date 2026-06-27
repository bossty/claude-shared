---
name: feedback_feature_branch_deploy_test_then_merge
description: "项目级开发流程铁律(Owner 2026-06-26):所有新功能含GFW=开feature分支开发→从feature分支打包部署+测试→通过+授权后才合master;master永远是测过的可直接部署基线,禁未测代码合master"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 019a2513-f7cc-4759-ad55-7522771891e2
---

**铁律(Owner 2026-06-26 定的项目级开发流程)**:**后续所有新功能(包括 GFW)** 一律走:
1. **开 feature 分支开发** —— 不在 master 上直接开发新功能。
2. **从 feature 分支打包部署 + 测试** —— 部署和测试都在 feature 分支的产物上做(build 该分支 jar/前端/Lambda → 部署 → 验证),**不是"先合 master 再测"**。
3. **测试通过 + Owner 授权后,才 feature → master** —— master 永远是"已测过、可直接部署"的基线;**禁把未测代码合进 master**。

**How to apply**:
- 新需求第一步=开 feature 分支(`git checkout -b feat/xxx`),不碰 master。
- 部署=从 feature 分支全量 build(铁律:feature 分支必先 merge 最新 master 再 build,否则 jar 缺 master 新改=回退);走 DEPLOY-RUNBOOK 暗部署+灰度;edge/旧基线留回退。
- 合并门禁:测试绿(mvn 全量+前端+e2e)+ Owner **显式授权** → `--no-ff` 合 master。**默认不碰 master**,合并是逐次高风险授权操作。
- "合 master"类指令先确认方向(sync master→feature?还是 feature→master 正式纳入?),别假设。
- **多会话共享仓库**:动手(尤其合并)前先 `git fetch` 看 master/分支真实历史 —— 别会话可能已处理/revert 你的改动(我 2026-06-26 误合 master 后,别会话立刻 revert)。

**Why**：master = 主站/生产可直接部署的真相源,必须时刻保持绿+可部署。新功能在自己分支验证完才进 master,避免未测代码污染基线、避免边开发边上线。GFW 是这条通用流程的一个实例(抗封逃生层,与主站解耦,走自己 DEPLOY-RUNBOOK 组A暗部署+组B灰度,尤其要独立验证),见 [[project_gfw_s_entry_execapi_poc_2026_06_22]]。

**我踩过的反例(2026-06-26)**：把 GFW 未测就合进 master(merge 22fb37b2),被 Owner 纠 + 别会话 revert。根因=没遵守"测试通过才合 master"。关联 [[feedback_deploy_caution]] [[feedback_deploy_caution_v2]]。

**★revert-of-merge 陷阱(2026-06-26 实战,已根除)**：master 上有 `5b3e01d5`(revert 那次误合 `22fb37b2`)后,曾让**任何 merge 经过它都把对应文件(86个GFW文件)当"已撤"静默删除(0冲突=无声删,最危险)**。**已治本消除**：把 **gfw 重建在当前 master 之上**(`ee6fefa6`,GFW 作为干净新提交,`5b3e01d5` 沉入共享 base 已结算),`origin/master` 现为 gfw 严格祖先 → master↔gfw 双向 merge **都不再触发,无需 revert-the-revert**。旧历史 tag `gfw-pre-rebuild-20260626`。重建法可复用(reset 到 master + 从备份叠 `git diff master..branch` 文件 + 提交 + 验 tree 逐字节一致):任何"revert 了 merge 又想重新合该分支"的纠缠都这样根治,别长期用恢复-文件的 workaround。`git add -A` 仍勿吞 `dist-shell/` untracked 产物。SOP 见 `DEPLOY-RUNBOOK.md §合并门禁`。

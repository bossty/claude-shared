---
name: project_master_degfw_deploy_baseline_2026_06_26
description: master 撤出GFW W3=GFW-free可直接部署(部署不再手工juggling);gfw=GFW track;★"禁master→gfw merge"已废止(2026-06-27:gfw重建ee6fefa6后5b3e01d5成祖先,merge实测0删除,现行=merge非cherry-pick);gauge fix landmine根因+解
metadata:
  node_type: memory
  type: project
  originSessionId: 6eecae1c-95e0-4231-a84e-4ccc79979b6c
---

> **⚠️ 2026-07-07 状态标注**：gfw/master 双 track 机制已随 06-29 GFW 并 master 退役；保留 gauge landmine 教训。

> ★★ 已被取代（2026-06-29）：master 已重新整合 GFW（`--no-ff` merge `5ed76306` + 零停机部署），**不再 GFW-free**；`gfw-breakthrough-arch` 已退役。本档"master=GFW-free / gfw=track 双线分叉"模型**作废**。现状见 [[project_gfw_consolidation_2026_06_29]]。（下文保留作历史。）

**2026-06-26 结构手术：GFW W3 从 master 撤出，master 回归 GFW-free 可直接部署。**

**起因(gauge landmine)**：admin gauge fix(`f36cc028`：RetentionTableGaugeTask 摘 rum_image_load + COUNT(*)→TABLE_ROWS 估算)**部署到 ca-admin 但从没合进 master**(只活在 prod jar，baseline=ab3d6be9 cherry-pick 链)。2026-06-26 我把 backlog 批次 off GFW-free baseline(d1766b93=read-sprint，不含 gauge fix)部署 admin → **revert 了 gauge fix**，rum_image_load COUNT(*)(~5s,每10min)复活 → MYSQL-SLOW-QUERY。已回滚 admin 到 f36cc028 止血。**根因不是孤立失误，是机制**：GFW 在 master 上 → 部署必须 GFW-free → 只能 off 老 baseline 手工 cherry-pick → 每次漏带 master 新 fix。

**根治(owner 选方向2)**：`git revert -m 1 22fb37b2`(GFW突破 S入口 merge)撤出 GFW W3。冲突仅 1 文件 DomainPoolService(解到 d1766b93/GFW-free 版)。**金标验证**：86 文件 −10900 行(纯 GFW W3：IspProvinceNormalizer/reach-aware/reachHint/InternalPickPController/W3 ipdb融合/s-entry lambda 删；IpDbBuilder 是 pre-W3 基础设施，只 revert W3 增强保留)；5 模块 test-compile + 870 web/common test 全绿；**degfw web/common/data main vs 现网部署 25eac29f = 0 diff**(master==现网)，admin diff=93=gauge fix。master `5b3e01d5`(GFW-free)已 push；gfw `9ea64781` 保留 GFW W3 全量。

**新分支模型(铁律)**：
- **master = GFW-free 可直接部署线**；**gfw-breakthrough-arch = GFW W3 track**(=master + GFW)。两线**有意分叉**。
- ~~**禁 `gfw merge master`**(会把 revert commit 5b3e01d5 带进 gfw → 抹掉 gfw 的 GFW！git "revert a merge" gotcha)~~ **★已废止(2026-06-27 git实证)**：该规则只对**重建前的 gfw `9ea64781`** 成立。gfw 后来**重建在 master 之上(`ee6fefa6`)** → `5b3e01d5` 现已是 **gfw 的祖先**(`git merge-base --is-ancestor 5b3e01d5 gfw`=YES)→ merge master **不再重新应用删除**。2026-06-27 实测 `git merge origin/master` 进 gfw:仅 3 文件(admin pool fix+plugin+docs),**0 个 GFW 文件被删**,干净。**现行铁律=runbook §合并门禁:build/收口前 `git merge origin/master` 进 gfw(不再 cherry-pick,避免重复 commit 漂移)**。trap 已永久消除见 DEPLOY-RUNBOOK 文末。
- **部署 off master 直接构建**(GFW-free)，**告别 d1766b93 baseline 手工 juggling**——这是本次手术的核心收益。deploy-runbook/CLAUDE.md 该同步(owner-commit)。
- GFW W3 何时上 prod = GFW track 拍板；上时 master 'revert the revert'(re-add GFW)或把 GFW 重新合入。

**现网部署态(2026-06-26)**：web×6=`5bcc9b64`(==master web)、data=`013643`(==master data)、admin=`f36cc028`(gauge fix+channel-anomaly，**缺 embedding** 低值，随下次 admin off-master 部署带上)。**无紧急 re-deploy**。承 [[project_admin_gauge_estimate_2026_06_25]] + [[project_rwsplit_framework_eval_2026_06_26]]。

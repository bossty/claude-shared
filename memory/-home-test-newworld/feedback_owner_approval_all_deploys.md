---
name: owner-approval-all-deploys
description: Owner铁律(2026-07-05)：任何时间的部署都要Owner拍板，不分高低峰期，除非提前授权
metadata: 
  node_type: memory
  type: feedback
  originSessionId: c5caee8a-f62d-4b1f-a4c0-3a770cdda70b
---

**已机制化：** `scripts/lib/git-preflight.sh` Gate A（`OWNER_DEPLOY_APPROVED=1` 才放行，`:75`）在部署脚本入口硬拦——未声明 Owner 拍板直接拒绝。

任何时间的生产部署（web/admin/data/前端/openresty/edge）都必须先获 Owner 拍板，**不分高低峰期**；唯一例外=Owner 提前授权的明确范围。原教训：2026-07-05 两会话相隔 27 秒并发 deploy-web.sh，B 产物每台只活 25 秒被 A 覆盖仍自报成功→时机与授权只靠会话自判必失守（旧 off-peak guard 只拦峰窗，反给"非峰窗可自行部署"错误暗示）。

**Why:** 机制拦得住"没带 `OWNER_DEPLOY_APPROVED`"，拦不住"自行推定上次同意过类似的"——授权范围判断仍靠人。
**How to apply:** 部署前向 Owner 报"部署什么（分支/sha/影响面）"获明确同意；提前授权必须是 Owner 明说范围，禁自行外推。相关 [[feature-branch-deploy-test-then-merge]]、[[deploy-caution]]。

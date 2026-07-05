---
name: owner-approval-all-deploys
description: Owner铁律(2026-07-05)：任何时间的部署都要Owner拍板，不分高低峰期，除非提前授权
metadata: 
  node_type: memory
  type: feedback
  originSessionId: c5caee8a-f62d-4b1f-a4c0-3a770cdda70b
---

任何时间的生产部署（web/admin/data/前端/openresty/edge 等一切线上变更）都必须先获得 Owner 拍板，**不分高低峰期**；唯一例外是 Owner 已提前授权的明确范围。

**Why:** 2026-07-05 上午两个会话相隔 27 秒并发跑 deploy-web.sh（互不知情、各自认为"该部署了"），B 的产物每台只活 25 秒即被 A 覆盖、B 自报成功——部署时机与授权只靠会话自行判断必然失守。原有 off-peak guard 只拦峰窗，给了"非峰窗可自行部署"的错误暗示，Owner 当日明确：拍板不分时段。

**How to apply:** 部署前必须先向 Owner 报告"要部署什么（分支/sha/影响面）"并获得明确同意；获得后以 `OWNER_DEPLOY_APPROVED=1` 前缀运行部署脚本（[[git-preflight]] Gate A 机制层硬拦，未声明直接拒绝）。提前授权也必须是 Owner 明说的范围，不得自行推定"上次同意过类似的"。相关：[[feature-branch-deploy-test-then-merge]]、[[deploy-caution]]。

---
name: 部署谨慎原则
description: 前端改动必须本地验证后再部署，禁止边改边上线，CF Purge Everything 要极其谨慎
type: feedback
---

前端代码改动不要直接部署到线上测试，必须本地验证完毕后再部署。

**Why:** 2026-03-31 修改 driver.js 引导后连续部署 3 次，每次部署都触发 SW 重建，叠加 CF Purge Everything 导致全站 pending，用户无法访问。最终回滚才恢复。

**How to apply:**
- 前端改动先在本地 dev server 或 Windows 开发环境完整验证
- 一次部署解决问题，避免反复部署
- CF Purge Everything 极其谨慎，优先用精确 URL purge
- 部署后如有问题，优先回滚而不是继续修改

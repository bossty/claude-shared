---
name: 前端调试用本地 dev server 不可靠
description: Vite dev server 与线上 build 行为不同，CSS/JS 加载时序差异大，前端问题必须部署到线上验证
type: feedback
---

Vite dev server（34.227.205.17:5566）和线上 build 后的静态文件行为不一致：dev server 模块未打包、CSS 变量加载时序不同、JS 执行延迟。导致在 dev server 上看到的 bug 在线上不存在（反之亦然）。

**Why:** 2026-04-06 首页 header/tab 衔接问题，dev server 上有碰撞感但线上完全正常，反复调试浪费大量时间。

**How to apply:**
- 前端改动先在 dev server 大致确认，但最终必须部署线上验证
- 不要在 dev server 上反复调参优化视觉效果（和线上不一样）
- 小改动可以直接部署线上验证

---
name: PSI 测试方法
description: PSI 审计只用 pagespeed.web.dev 网页版，不用 Lighthouse CLI
type: feedback
---

测试结果以 pagespeed.web.dev 为准，不使用 Lighthouse CLI。

**Why:** Lighthouse CLI 模拟模式（4x CPU + 慢 3G）结果过于严苛且不现实（如标签页 TBT 72s），PSI 网页版更接近真实用户体验。

**How to apply:** PSI 审计过程中，跑分/验证修复效果时使用 Chrome DevTools MCP 操作 pagespeed.web.dev，或让用户手动测试。不要用 `npx lighthouse` 命令。

---
name: reference_frontend_monitor_report_chain_verification
description: 验证前端错误上报链路（monitor.js → /api/v1/analytics/quality → MonitorService）真通的正确姿势与三个必踩坑：__e2e 抑制上报 / sendBeacon 是观测盲区 / 注入 throw 不进主桶
metadata: 
  node_type: memory
  type: reference
  originSessionId: eda7ef50-950e-4d1c-9bb9-e14e4381e2c3
---

验 newworld 前端错误上报链路（`frontend-web/src/utils/monitor.js` → `POST /api/v1/analytics/quality` → `MonitorController` → `MonitorService`）**是否真通**时，三个坑会让你得出「没上报」的错误结论（2026-07-11 BL-34 上生产实测，见 [[project_bl34_canary_deploy_2026_07_11]]）：

1. **`__e2e=7rip` cookie 会让 monitor 整体不上报**（`monitor.js` `isE2eBypassCookie()`，注释明写「__e2e=7rip 时整体不上报」，防自动化污染统计口径）。所以**验上报链路必须清掉该 cookie**，否则测了个寂寞。⚠️ 浏览器 profile 可能**残留历史 `__e2e` cookie**——先 `document.cookie.includes('__e2e')` 自检，清掉后**重新 navigate**（monitor 在 boot 期初始化）。这与 [[feedback_e2e_real_browser]] 不冲突：仍用真浏览器，只是不能带旁路 cookie。
2. **`flush()` 走 `navigator.sendBeacon`，Playwright 的 `browser_network_requests` 不记录 beacon** → 「网络列表里没有该请求」是**观测盲区，不是没发**。看得见的两个办法：monkey-patch `navigator.sendBeacon` 记录调用（最直接），或查 `performance.getEntriesByType('resource')`。
3. **从注入脚本 `throw` 出来的错误不进 `js_error` 主桶**：`window.addEventListener('error')` 的分类器按 `e.filename` 判来源，注入代码抛的错无合法 filename → 落「第三方/WebView 噪音」分桶被分流掉，**不会触发上报**。要验 enqueue→flush→POST 这一段，直接调 `window.__pushError({type:'js_error', message, source: location.href, ...})`（monitor 初始化后挂在 window 上，同时 `console.error` 被 wrap = 初始化完成的痕迹）。

**判「链路真通」的三层硬证据**（缺一层都可能自欺）：
- 浏览器侧：beacon 真调用（url + payload size）；`BATCH_SIZE=10` 满 10 条立即 flush，否则等 `FLUSH_INTERVAL=30s`。
- 后端侧：Redis 计数器 `monitor:js-errors:<5min slot>` 出现**超出组织噪声的增量**（该指标组织基线 26–64 条/5min，注入 ≤12 条会淹没在噪声里 → **别用小样本增量当证据**）。
- 限流器侧：`monitor:fe-rl:<sessionId>:<epoch分钟>` key 落地（BL-34 per-session 120/min，Redis 异常 fail-open 放行）。

**一个被证据推翻的怀疑（留档防重复论证，见 [[feedback_experiment_conclusions_to_doc]]）**：曾疑「`payload.sessionId` 只在带 vitals 时才塞（`flush()` 里 `if (hasVitals)`）→ 纯错误 payload 无 sessionId → 后端限流被绕过」。**证伪**：后端读的是 `errors.get(0).get("sessionId")`（**每条 error 对象自带**），不是 `payload.sessionId`；实测纯错误 payload 也创建了限流 key。**BL-34 无此缺口，别再重报。**

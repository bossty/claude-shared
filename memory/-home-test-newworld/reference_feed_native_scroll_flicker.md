---
name: reference_feed_native_scroll_flicker
description: F2 移动端 feed 三连问题(卡死/sticky震动/整页闪烁)最终解=原生滚动+content-visibility+DOM cap spacer；真机验收通过 2026-05-31
metadata: 
  node_type: memory
  type: reference
  originSessionId: 54236e30-dbdb-47b2-a9be-9e37a422af85
---

移动端 HomeFeed 无限滚动三个问题的最终解（owner 真机验收 OK，2026-05-31，master `9b985bff`）。全文档：`docs/sprint/2026-05-30-feed-freeze-fix/`（FREEZE-ROOT-CAUSE-AND-FIX.md + F2-NATIVE-SCROLL-WEBKIT-VERIFIED.md）。

**架构**：去 @tanstack/vue-virtual（虚拟滚动 settle/measure 致 sticky 交界 15-35px 震动），改**原生全量 v-for + content-visibility:auto + DOM cap(FEED_CAP=120) 顶部 spacer**。

**4 条 durable 技术教训**：
1. **卡死真凶=FeedCard video native MediaPlayer 累积泄漏**（WebKit #216820）。解=`useActivePreview` 全局单例 manager，同屏恒 ≤1 个 `<video>`（report ratio→recalc winner）；`onUnmounted`+`watch(isActive→false)` 双路释放(pause/removeAttribute/load)。切 tab/head-trim 卸载即释放。
2. **DOM cap 头部裁剪用顶部 spacer 撑高，不改 scrollTop**（iOS 无 overflow-anchor，改 scrollTop 非原子→整页闪）。spacer 高度**必须 span 测量** `cards[trimCount].top − cards[0].top`（天然含夹在头部的广告块 .feed-inline-ads + 全 margin）——逐卡求和只数 .feed-card 会漏广告高、偏短（实测 1822px）。**trim 量取广告周期(每5部插1条)的整数倍**，否则幸存卡重索引致广告重分布、漂一卡高(365px)。
3. **度量真相=文档坐标 docY=scrollTop+rect.top 不变性**，不是 rect.top 平滑——浏览器会用 scrollTop 夹把几何错误伪装成视觉平滑(headless 假绿)，真机 momentum 下才卡顿。蓝军独立复测靠这点揪出 1822px(我自测 rawDtop 盲区)。
4. **playwright webkit + devices['iPhone 14'] 能在部署前复现 iOS 特有 sticky/合成/重排**，Chromium(Blink) 复现不出（前 6 版手写高度全因在 Chromium 测而漏判）。工具在 `frontend-web/scripts/webkit-{feed-judder,freeze-regression,trim-flicker,spacer-drift}.mjs`（支持 `--engine=chromium --device= --url=`）。**缺口**：headless 无真 UIScrollView momentum 物理，最终必 owner 真机收尾。

相关 [[feedback_frontend_deploy_standard_script]] [[feedback_qa_safari_chrome_dual_engine]] [[feedback_agent_team_crossfire]]。

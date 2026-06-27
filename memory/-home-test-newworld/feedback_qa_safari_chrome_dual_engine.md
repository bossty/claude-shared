---
name: feedback-qa-safari-chrome-dual-engine
description: 前端验证/测试必须 Safari + Chrome 双引擎，不只是 chrome devtools 模拟 PC+Mobile
metadata: 
  node_type: memory
  type: feedback
  originSessionId: da3be312-2b73-46c3-95da-580bd268b069
---

前端 fix / 性能改 / UI 改的验证，**至少要在 Safari 和 Chrome 两套渲染引擎跑过**，不能只用 chrome devtools 模拟 PC+Mobile（那只是同一引擎不同视口）。

**Why（用户 5/15 铁律）：**
- WebKit (Safari) vs Chromium (Chrome / Edge) 在多个 web 标准上实现差异：
  - **viewport-fit=cover + env(safe-area-inset-*)**：Safari 强制要求，Chrome Android 较宽松；缺 viewport-fit 时 iOS Safari env() 返 0
  - **loading="lazy"**：Chrome 76+，**Safari 仅 iOS 15.4+ / macOS 15.4+**，老 iOS 用户完全失效
  - **`<picture>` + avif source**：Chrome 早支持，Safari 16+ 才支
  - **preconnect / dns-prefetch**：两者解释 `crossorigin` 属性不同
  - **CSS aspect-ratio / inset / @container query**：WebKit 滞后
  - **PWA / Service Worker**：Safari 限制更多
- 仅用 chrome devtools mobile emulation = **同一 Chromium 引擎只换视口**，会漏 WebKit 真bug
- newworld 用户大量 iOS 流量（C 端视频站典型），WebKit 行为是核心质量门

**How to apply（更新 newworld-frontend-visual-fix skill 铁律）：**
- 验证清单 = **PC Chrome + Mobile Chrome (Android emu/真机) + Mac Safari (PC) + iOS Safari (Mobile real or simulator)** 四象限
- 任何前端 hot fix 必须 Safari + Chrome 双引擎都跑过
- chrome-devtools-mcp + playwright-mcp 默认 Chromium，**测 Safari 必须**：
  - playwright `browserName: 'webkit'` 跑 webkit headless
  - 或 agent 报告"无 Safari 测试环境，需 owner 真机/模拟器接力"
- qa-senior agent brief 必须显式列双引擎，不能默认"chrome devtools 双端"
- chrome-devtools-mcp 仅模拟视口不换引擎——必须配 playwright webkit 或 owner 真机

**反例**：
- ❌ "我用 chrome devtools 切换 mobile 视图验证了" → 只验证 Chromium，Safari 行为未知
- ❌ "iOS 上看一眼" 没做 + 只验 Mac Chrome → Safari 漏验
- ✅ playwright `chromium` + `webkit` 两套跑同一脚本；或 owner 真机 iOS Safari + Android Chrome 双端实测

**适用范围（E-sprint 5/16 OQ-5 实证补充）**：
- 本铁律针对 **runtime / 视觉行为改动**（JS / CSS / template / 组件逻辑）—— 这些改动 Chromium vs WebKit 渲染/行为可能不同，必须双引擎
- **纯编译期改动豁免**：vue-tsc 类型标注 / `.d.ts` 声明 / 纯 TS interface / 静态类型分析改动 —— 编译期生效、不产生 runtime 行为差异，验收 = `npm run build` exit 0 + `npm test` 无 regression 即足，**不需 playwright webkit 双引擎视觉回归**
- **豁免前提**：Owner 软门拍板确认（E-sprint OQ-5 实证：pm-helper 提方案 B + Owner 软门 1 拍板豁免）。判断步骤——派工/PRD 起草时先问"改动是否影响 runtime 渲染/行为？"，纯类型/编译期 → 豁免，JS/CSS/template → 不豁免

**与现有铁律关系**：
- [[newworld-frontend-visual-fix]] 原"PC + Mobile chrome devtools 双端"应升级为"PC/Mobile × Chromium/WebKit 四象限"
- [[feedback_audit_methodology]] 蓝军方法论可加一条"前端审计必查 Safari+Chrome 双引擎"

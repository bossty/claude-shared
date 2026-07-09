---
name: newworld-frontend-visual-fix
description: 前端视觉/交互修复必须 **PC/Mobile × Chromium/WebKit 4 象限**双引擎双视口验证 OK 才 commit（2026-05-15 升级，原 PC+Mobile chrome devtools 不够）。禁止"修一端 commit 一端"。chunk 拆分 / vite manualChunks 改动同样必须真浏览器双端 e2e（5/10 TDZ 教训）。Triggers on 播放器尺寸 / hero / sidebar / swiper / 布局 / aspect-ratio / 视觉 / 截图验证 / vite manualChunks / chunk 拆分 / TDZ / 循环依赖 / Safari iOS / WebKit / loading=lazy / viewport-fit / safe-area-inset.
---

# Newworld 前端视觉修复双端验证铁律（2026-05-01 hotfix-3 教训）

## 触发场景
- 任何 .vue / .css 改动影响视觉或交互布局（不含纯逻辑改动）
- swiper / 播放器 / sidebar / hero / 卡片 / aspect-ratio / 触摸目标 / scrollbar / overlay
- 反侦察相关 cloaking 视觉（decoy 页 / og 图）

## ⚠️ Safari + Chrome 双引擎升级 (2026-05-15 frontend-perf sprint 教训)

**Owner 5/15 铁律**：原"PC + Mobile chrome devtools 双端"**只覆盖同一 Chromium 引擎换视口**，遗漏 WebKit (Safari) 真行为。前端验证矩阵升级为 **4 象限**：

| | Desktop | Mobile |
|---|---|---|
| **Chromium** (Chrome / Edge) | chrome-devtools-mcp 1440×900 | chrome-devtools-mcp 375×812 |
| **WebKit** (Safari) | playwright-mcp `browserName: webkit` desktop | playwright-mcp webkit + iPhone viewport **OR Owner iOS 真机/Xcode Simulator 接力** |

### 为什么必须双引擎
WebKit vs Chromium 在多个 web 标准上行为差异（newworld 用户大量 iOS 流量，C 端视频站典型）：

- **`viewport-fit=cover` + `env(safe-area-inset-*)`**：Safari 强制要求；缺 `viewport-fit` 时 iOS Safari `env()` 返 0 → 刘海屏 BottomTabBar 被系统 bar 遮挡
- **`loading="lazy"`**：Chrome 76+；**Safari 仅 iOS 15.4+ / macOS 15.4+**，老 iOS 用户视为 eager（性能改善失效但无破坏）
- **`<picture>` + avif source**：Chrome 早支持；Safari 16+ 才支
- **preconnect / dns-prefetch**：两者解释 `crossorigin` 属性不同
- **CSS aspect-ratio / inset / @container query**：WebKit 滞后
- **PWA / Service Worker**：Safari 限制更多

### 反例（明令禁止）
- ❌ "我用 chrome devtools 切换 mobile 视图验证了" → 仅同 Chromium，Safari 行为未知
- ❌ "iOS 上看一眼" 没做 + 只验 Mac Chrome → Safari 漏验
- ✅ playwright `chromium` + `webkit` 两套跑同一脚本；OR Owner 真机 iOS Safari + Android Chrome 双端实测

### qa-senior 工具白名单（spec §3.2 已含 playwright-mcp）
- `chrome-devtools-mcp` 仅 Chromium，**测 Safari 必须配** `playwright-mcp browserName: webkit` headless（`~/.cache/ms-playwright/webkit-*` 已安装）
- iOS 真机视觉差异如必须 owner 接力，qa-senior 状态档明确标"需 Owner 接力清单"，不藏

### 事故案例：2026-05-15 frontend-perf sprint dry-run
- dev-senior 改 viewport-fit=cover + 7 img loading=lazy
- qa-senior 静态全过 + chrome-devtools 通过；**WebKit 动态验证靠 playwright webkit + Owner iOS 真机才补全**
- iOS Safari `env(safe-area-inset-bottom)` 在缺 viewport-fit 时返 0 是 WebKit 特定行为，仅靠 chrome devtools mobile 模拟无法复现验证
- 教训：本 skill 升级让"Safari + Chrome 双引擎"进入 frontend-perf 类 sprint 默认验证清单

---

## 铁律：双端临时 CSS 注入验证 → commit → 部署一次解决

### 1. 错误流程（禁）
```
修 hypothesis CSS → 测 mobile OK → commit → 部署 → 发现 PC 不对 →
hotfix-N → 测 PC OK → commit → 部署 → 发现 mobile 又不对 → hotfix-N+1 → ...
```
代价：N 次部署 + 用户感知反复抖动 + 团队来回 debug。

### 2. 正确流程
```
修 hypothesis CSS（先不 commit）→
chrome devtools resize 1440×900 → 临时 evaluate_script 注入 CSS → 测 PC + 截图 OK →
chrome devtools resize 375×812 → reload → 临时 evaluate_script 注入 CSS → 测 mobile + 截图 OK →
两端都 OK → 写到代码 → lint/build/test → commit → 部署一次
```

### 3. chrome devtools 临时注入模板

```js
() => {
  const style = document.createElement('style')
  style.textContent = `/* 你的 fix CSS */`
  document.head.appendChild(style)
  return new Promise(r => setTimeout(() => {
    const el = document.querySelector('your-selector')
    r(el ? { w: el.offsetWidth, h: el.offsetHeight, ratio: (el.offsetWidth/el.offsetHeight).toFixed(2) } : null)
  }, 200))
}
```

### 4. resize 顺序
- PC 先（1440×900 / 1920×1080）
- Mobile 后（375×812 / 414×896）—— 注意 mobile reload 才能触发 media query 切换 + 重渲染
- 视图切换间用 `navigate_page reload ignoreCache:true` 清 inline style

### 5. 验证清单（每端独立打）
- [ ] 截图视觉对齐设计（特别是 aspect-ratio / 留白 / 等距）
- [ ] evaluate_script 量化 size + ratio（不能仅靠肉眼）
- [ ] 子元素 size + position（如 video / poster / pagination dot）
- [ ] 边缘场景（无数据 / loading / error fallback）—— 视情况

## 事故案例

**2026-05-01 hotfix-3 vidstack 播放器尺寸**（推动本铁律生成）：

1. Phi 完成 Plyr→vidstack 后 PC 1110×726 / Mobile 485×726（高度异常）
2. 临时 CSS 注入 4 条 → 仅测 mobile OK (485×279) → commit hotfix-3 但**只 copy 了 1 条 aspect-ratio**
3. 部署后 PC 验证仍 1110×726（因 vidstack shadow DOM 内置 min-height）
4. 临时再注入 height:auto + min-height:0 → 仅测 PC OK (1110×624) → commit hotfix-3.1
5. 用户反馈："下次两端一起验再提交 万一移动端也有问题呢"
6. 教训：本应一次性临时注入完整 CSS（aspect-ratio + height:auto + min-height:0）→ PC + Mobile 都验 OK → commit 一次 → 部署一次

## chunk 拆分 / vite manualChunks 铁律（2026-05-10 TDZ 教训）

### 事故案例：commit 8351a523 manualChunks 拆 vendor 引发生产 TDZ

故障：`Cannot access 'hx' before initialization` 浏览器报错，前端整体崩。

`hx` = esbuild minify 短名（不是源码标识符），= utils chunk 顶层 `const hx = <跨 chunk import>`。

**真因**：utils-net ↔ utils-stats ↔ utils-cache 3 角循环依赖（cdn-failover→monitor / sw-bridge→cache / aes→fingerprint 网状依赖被硬切成 chunk 间环）。

**关键**：`npm test`（jsdom）+ `npm run build` 都成功，但浏览器真崩。jsdom commonjs interop 不复现 ESM TDZ。

### 铁律
1. **任何 vite manualChunks 改动**（拆 vendor / 改 chunk 分组）必须：
   - 本地 `npm run build` + 启动 vite preview / nginx serve dist
   - **真浏览器 PC + Mobile 双端 e2e**（不是仅 npm test）
   - 验证 `console.error` 0 + 关键页面 mount 成功
2. **不能仅靠 npm test 通过 = 安全**（jsdom 不复现 ESM TDZ）
3. 如必须拆，先用 `rollup-plugin-visualizer` 或 vite analyzer 看依赖图，避免硬切已有循环模块
4. **commit message 必带 chrome devtools 截图证据**

### 修法选项（如 TDZ 复现）
- **A1 撤销细拆**（止血最快）
- **A2 保留细拆 + 循环检测插件**（utils 网状环修源码工作量大）
- **A3 visualizer 重新分组**（保留性能，分组规则复杂）
- **A4 preserveModules**（不推荐，HTTP/2 chunk 200+ 反而慢）

## 配套铁律
- 反侦察改动：`newworld-frontend-stealth`
- 部署 SOP：`newworld-deploy-runbook` Step 1.5 git pre-flight
- 多 agent 协作：`newworld-multi-agent-coord`

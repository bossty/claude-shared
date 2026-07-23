---
name: newworld-frontend-stealth
description: 前端反侦察三位一体 — HTML title / og:* / manifest.json name / robots.txt 全伪装 EduStream，Vue mount 后禁切回真品牌名 (cloaking attribute leakage 信号)；E2E / Chrome DevTools 测试用 cookie __e2e=7rip 旁路探针。preconnect/preload 业务域必须 probeGate PASS 后动态注入（5/10 教训）。Triggers on 伪装, edustream, og:title, manifest.json, robots.txt, document.title, 反侦察, 探针, e2e, __e2e=7rip, puppeteer, playwright cookie, decoy page, collectSignals, detectProbe, preconnect, preload, R_IMG, R_VID, R_PRV, SNI, probeGate, GFW.
---

> **执行机制**：靠判断力（前端反侦察三位一体）

# Newworld 前端伪装三位一体铁律（2026-04-23 反侦察加固）

## 触发场景
- 修改 `frontend-web/index.html` / `manifest.json` / `robots.txt`
- 修改 Vue 组件中任何 `document.title = ...`
- 修改 `frontend-web/src/main.js` 探针检测 / 启动逻辑
- 写 E2E / Chrome DevTools 测试访问真实 Vue 应用

## 铁律：三层伪装必须同步

| 层 | 暴露点 | 伪装要求 |
|----|--------|---------|
| 静态 HTML `<title>` | Puppeteer `page.title()` / 爬虫首抓 / Google Cache | 必须伪装 |
| `og:title` / `og:description` / `og:site_name` | Telegram/WeChat 分享预览 | 必须伪装且**细化**（具体课程方向，不要通用词） |
| `manifest.json` name/short_name/description | Android Chrome 加主屏 | 必须伪装，和 `apple-mobile-web-app-title` 对齐 |
| `robots.txt` | 搜索引擎爬虫 / 反黄检测工具 | `User-agent: * / Disallow: /` 全禁 |
| Icon（favicon / apple-touch / android-chrome） | 用户 pin 到主屏 | 视觉不得露业务特征 |

## 真人体验 vs 反侦察分层（2026-04-23 修订：取消 title 切回）
- 静态 HTML 全伪装（探针 / 爬虫 / 分享预览看伪装）
- **Vue mount 后保持伪装 title**，**不得**动态 `document.title = "真品牌"` 切回
  - 原因：探针过后切 title 是扫描器抓 "cloaking attribute leakage" 的经典信号
  - 品牌归属感让位于反侦察一致性
- 探针命中 `renderDecoyPage()` 后 `return`，title 自然保持伪装
- **铁律**：任何 `document.title = ...` 只允许 EduStream 主题文案（如 "Course X - EduStream"），禁止业务真名

## 探针检测与 E2E 旁路

前端 `main.js` 在 Vue mount 之前执行探针检测（`collectSignals` + `detectProbe`），检测到自动化浏览器（Puppeteer/Playwright 等）会渲染伪装教育页面（EduStream Online），阻止真实内容加载。

**E2E / Chrome DevTools 测试旁路**：设置 cookie `__e2e=7rip` 跳过探针检测，加载真实 Vue 应用：
```javascript
// 在 Chrome DevTools MCP 的 evaluate_script 中：
document.cookie = '__e2e=7rip; path=/';
// 然后 reload 页面
```

代码位置：`frontend-web/src/main.js` 第 119-130 行。

## preconnect/preload 业务域铁律（2026-05-10 教训）

### 违反案例
`frontend-web/index.html` L51-L78 inline `<script>` 在 main.js 探针 gate 之前用 localStorage `app__cf` cache 注入 `<link rel="preconnect">` R_IMG / R_VID / R_PRV 业务域。
- 老用户已 cache 时 100% 在探针 gate 前发起 TLS ClientHello
- SNI 明文 → GFW DPI 直接拉黑业务域风险
- 探针检测能拦页面渲染但拦不住 HTML preload scanner 已发出的连接

### 铁律
1. **任何 preload / preconnect 业务域**（R_IMG / R_VID / R_PRV / R_AD / 任何非 same-origin 业务域）**禁止在 index.html 静态写死或 inline `<script>` 注入**
2. **必须在 `frontend-web/src/boot/probeGate.js` PASS 分支后**通过 `document.createElement('link')` + `appendChild` 动态注入
3. 探针未 PASS 阶段：HTML 中**只**允许 same-origin（`/lib/`、`/assets/`、`/images/`）资源 hint
4. 业务域信号必须等 stealth 检查通过后才能产生

### 实证机制（PR review 强制项）
- 任何 PR 涉及 `<link rel="preconnect">` / `<link rel="preload">` 含业务域 → 必须 grep 验证落点是 probeGate PASS 之后
- 违反 = 3.25 级反侦察漏洞

### 关联
- `frontend-web/src/boot/probeGate.js` 是唯一合法注入点
- HTML spec preconnect 在 HTML parse 阶段被 preload scanner 立即执行
- TLS ClientHello SNI 明文 → GFW DPI 直接命中

## 违反后果
每缺一层 = 一个反侦察漏洞，按 **3.25** 级别复盘。title 切回真名同级别处理。

## 源
- CLAUDE.md L383-L395（探针 / E2E 旁路）
- CLAUDE.md L776-L798（伪装三位一体）
- docs/V5_SPRINT_RETRO.md §3 T7（preconnect SNI 暴露 5/10 教训）

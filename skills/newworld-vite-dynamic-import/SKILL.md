---
name: newworld-vite-dynamic-import
description: Vite 禁用 await import('@/...') 别名形式（chunk 间解析不一致），必须 static import 或 await import('./...') 相对路径；catch swallow 必须 console.error + sessionStorage 诊断 patch（不许 console.warn）。silent maintenance 排查直接走 sessionStorage 一锤定音。Triggers on vite, dynamic import, "@/", await import, lazy load, code split, alias 解析, silent maintenance, sessionStorage 诊断, silent failure, showRecovery, showError.
---

# Newworld Vite Dynamic Import 不许用 `@/` 别名铁律（2026-04-27 devatlas26 silent maintenance 事故硬化）

## 触发场景
- 修改 `frontend-web/src/**/*.js` 含 `import` 语句
- 写 lazy load / code split 路径
- 看到页面挂但 console 干净的 silent failure（如维护页 / showRecovery / showError）

## 铁律

### 1. `await import('@/...')` 别名形式禁用 + 同目录 `./X[.js]` 也禁
所有 dynamic import 必须用：
- **首选**：顶部 static import（bundle 静态分析必然解析）
- **5/22-5/23 升级**：跨目录 `'../utils/X.js'` vite 能 chunk 化，**同目录 `'./X.js'`（5 处实证）+ 同目录无后缀 `'./X'`（3 处实证）case-by-case 不可预测**——不要冒险，全部 static import

### 2. Vite alias / 相对路径 dynamic chunk 化机制（5/22-5/23 实证）
- static `import { x } from '@/...'` ✅
- dynamic `await import('@/...')` ❌ — chunk 边界 / minifier 边角不一致
- dynamic `await import('../utils/X.js')` ✅ 跨目录 chunk 化稳定
- dynamic `await import('./X.js')` ❌ 同目录 + .js 后缀保留字面量（a2bdf171 修 5 处）
- dynamic `await import('./X')` ❌ 同目录无后缀 case-by-case 不可预测（实测 ./cache/./doh-client OK，./aes 失败，a34ab1bd 全改 static）
- **教训**：vite chunk 化机制对**同目录** dynamic import 行为不可预测，一律 static

### 3. 新增 dynamic import 必 grep **两种形态**
```bash
# 别名形式（旧规则）
grep -rn 'await import(\s*["'\'']@/' src/
# 5/23 新增：同目录 ./X 含/无后缀全集
grep -rnE "import\(\s*['\"]\\./.+['\"]" src/
# 命中 0 是合规
```

### 4. catch 块禁止 `console.warn` swallow
必须：
- `console.error`（不被默认 console filter 过滤）
- 写 `sessionStorage.__nw_<module>_err = JSON.stringify({name, message, stack})`

`console.warn` 被默认 console Errors-only filter 过滤 → silent failure 排查需 1+ 小时绕弯。

### 5. silent maintenance / showRecovery / showError 必须诊断 channel
不能只信 console（可能被扩展 hijack / filter 隐藏 / SW reload 清屏），必须 sessionStorage / window 全局变量记录 error 真实 stack。

## 排查流程标准化（silent failure）
不再走"扩展嫌疑 / cache / HSTS / SafeBrowsing / 后端 retry verify"等推断路径，**直接**：
1. 在 silent swallow 的 catch 里 patch 写 `sessionStorage.__nw_<module>_err = {name, message, stack}`
2. build + deploy
3. 让 Owner 复现一次后 `JSON.parse(sessionStorage.getItem('__nw_<module>_err'))` 一锤拿真因
4. 时间投入：1 commit + 1 deploy + 1 Owner 复现 ≈ 30 min（vs 推断盲猜 1-3h）

## 违反后果
按 **3.25** 级别。silent maintenance 类 bug 不写诊断 patch 靠盲猜方向 = 浪费 sprint 时间 + Owner 信任损耗。

## 事故案例
2026-04-27 用户报 `https://devatlas26.top` Chrome 显示维护页（其他 P 域 OK，Edge OK，新设备 OK），console 完全干净排查 1+ 小时。最终 sessionStorage 诊断 patch 后定位：`app-config.js:201 await import('@/utils/host-channel.js')` 在 build 后浏览器抛 `TypeError: Failed to resolve module specifier '@/utils/host-channel.js'`。
- 修复 commit `5a383b67`（host-channel static import）
- 后续 `main.js:153 / sw-bridge.js:282/288/289` 4 处批量改 `./` 相对路径预防再爆

## 源
- CLAUDE.md L945-L970

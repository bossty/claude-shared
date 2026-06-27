---
name: guard.lua 白名单维护要点
description: 前端新增/修改 API 路径时必须同步 guard.lua 白名单，注意 HEAD 方法和 PCRE 转义
type: feedback
---

前端新增或修改 API 路径后，必须同步更新 guard.lua 白名单，否则用户会被 strike → ban → 502。

**Why:** 2026-04-06 线上 502 事故，三个根因：(1) /api/v1/stats/hit 旧路径未在白名单 (2) HEAD /api/v1/settings/version 未放行（SW 静默探测用 HEAD）(3) playback%-error 用了 Lua 转义但实际是 PCRE（永远匹配不到）

**How to apply:**
- 改前端 API 路径时检查 guard.lua web_whitelist
- SW 用 HEAD 方法的端点也要加白名单
- guard.lua 用 PCRE regex（ngx.re.find），不是 Lua pattern，`-` 不需要转义
- 旧路径要兼容（用户缓存旧 SW 会继续发旧路径请求）

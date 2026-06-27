---
name: project_firstscreen_edge_cache_2026_06_06
description: "首屏边缘缓存提速 — Tier1 version.js SWR已上线 + CF全规则实测(Free 60s edge TTL可行,推翻团队2h floor) + Tier2设计档"
metadata:
  type: project
  originSessionId: f4b7ce6c-ece8-460f-99f3-acc518f764e6
---

旗舰 17.rip 首屏提速 sprint（owner 纠偏"提速在网络往来 RTT 不在文件大小"）。**post-compact 先读 `docs/sprint/2026-06-06-firstscreen-edge-cache/TIER2-DESIGN.md` + `FINDINGS.md`。**

**★Tier1 已上线（commit `62939fef`，4 节点）**：version.js 的 `$nw_version_cache_control` map 从 `max-age=60, s-maxage=60` 改 `max-age=60, stale-while-revalidate=86400`（去 s-maxage）→ CF 边缘 SWR：过期点从 **REVALIDATED ~290ms 跨洋阻塞** 变 **UPDATING ~53ms**（即时吐 stale + 后台刷），实测 17.rip/version.js t=60 翻转。基线：s-maxage 每 60s 过期点付 ~290ms 跨洋 RTT（新鲜窗 HIT ~50ms）。

**★CF Free 缓存铁律（全实测 + 官方文档，eduspace181 canary 已复原）**：
- CF **默认不缓存 HTML/JSON**（按**文件扩展名**非 MIME，.html/.json 不在默认集）→ manifest.json `max-age=604800` 仍 DYNAMIC 铁证。要缓存 HTML 须 **Cache Rule(Cache Everything)**。
- **★Free Cache Rule 接受且强制 60s edge TTL**（override_origin default=60，t=60 准时过期重验实证）——**团队"Free 2h floor"判错**（那是旧 **Page Rules** 限制，新 **Cache Rules** Free 无此 floor）；**owner 看 UI"能配 1 分钟"的直觉对，实测推翻团队抽象**。
- **一条 Cache Rule(Cache Everything + Override) 缓存 HTML + 自动剥 Set-Cookie**（MISS+HIT 响应全无 cookie=与 origin 零cookie壳完全同效）。
- **serve_stale 开关 ≠ SWR**（serve_stale 是"origin 挂才吐 stale"；SWR/UPDATING 必靠 origin `stale-while-revalidate` 头，s-maxage 会 disable SWR）。
- Custom Cache Key 忽略 cookie = **Enterprise only**（Free 死）。SWR 在 Free 可用（changelog 2026-02-26 "live all Free zones"，version.js 已生产验证）。
- CF token 在 **DB system_config `CF_API_TOKEN_A`**（非 secrets.env）；canary 用实验臂 **eduspace181.link**（zone `8cd869c9ad7dd59d2938cac3a2388ce0`，account A Free）；CF Cache Rule 增删走 rulesets API `phases/http_request_cache_settings/entrypoint`，删规则后**残留边缘缓存要额外 purge_cache** 才回 DYNAMIC。

**★Tier2 设计（机制全实测，待 owner rollout sign-off）**：HTML 壳边缘缓存消首屏跨洋 RTT。路 A=纯 CF Override 60s（零 origin 改动、一条规则脚本批量 63 域、删规则秒回滚；多数 HIT 省 RTT，每 POP 每 60s 一用户 REVALIDATED）；路 B=respect-origin + origin host-scoped `stale-while-revalidate` 头（过期点也 UPDATING，二期）。**硬前置**：方案①（main.js 极早期 crypto.randomUUID 种 _vid，补 migrate 首请求门=12.8%流量，因 CF 剥了边缘 _vid + fp vid 要 STEP7 才有）+ reload 循环协同（HTML TTL=60s 收敛 1-2 次）。统计：_vid 全剥但 UV 近净中性（UV 靠 JS /hit 的 fp/legacy/方案①三源非边缘 cookie）。

**方法论**：owner 一路"不试不知道"逼实测，把 Tier2 从"2h floor 不可行"翻成"60s 短缓存实测可行"——**owner 业务直觉/UI 实证碾压团队技术抽象，本会话反复**；CF 文档"by default 不缓存"≠"配规则也不行"必实测；team 调研也会把旧 Page Rules 限制误当新 Cache Rules，lead 必独立二查 + owner UI 直觉当严肃线索。计划外发现：US region guard.lua drift（snack-rename 前 ad-image，整文件 swap 不安全→外科插入；region-mirror SPEC 漂移再现）。

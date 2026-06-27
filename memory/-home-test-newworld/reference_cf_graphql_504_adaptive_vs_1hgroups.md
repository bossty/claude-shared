---
name: reference_cf_graphql_504_adaptive_vs_1hgroups
description: CF GraphQL 边缘 5xx/504 超时分析必用 httpRequestsAdaptiveGroups，httpRequests1hGroups 漏报 CF 自生成 504
metadata: 
  node_type: memory
  type: reference
  originSessionId: 7a58073a-eceb-460e-aa52-8d8a7cd8302b
---

CF Analytics GraphQL 拉边缘 status 分布做 5xx/超时分析时：**必用 `httpRequestsAdaptiveGroups`（dimension `edgeResponseStatus`），不要用 `httpRequests1hGroups`**。

**陷阱**：`httpRequests1hGroups` 的 `responseStatusMap` **漏报 CF 自身生成的 504**（origin/tunnel 超时类，请求没在源站完成 → 源站不记 → 1hGroups 也不算）。同一窗口同一 zone：
- `httpRequests1hGroups` → 504=0、5xx 仅 ~417 条（**误导，差点把真问题判没**）
- `httpRequestsAdaptiveGroups` → 504=167k（**真值**），两人独立复现吻合（167,262 vs 167,014）

**实战背景（2026-06-05 告警 RCA）**：排查"API 失败率 18.1%"时，CF 边缘 `/api/` 路径 24h adaptive 实测 504=6.64% / 499=1.55% / 无 520-523 → 证明源站 Tomcat 5xx=0 不等于无失败，**6.6% 真实 CF-504 跨洋超时**（CN 75% 落欧美 POP→HK origin 经 cloudflared tunnel 整个 HTTP 往返超时；非 Redis 读跨洋）是真问题，归多区域跨洋网络腿。详见 [[project_peak_perf_debate_2026_05_29]]（CF Anycast 绕路 + cloudflared tunnel tax 母问题）。

**附带口径铁律**：CF adaptive 是采样数据集，**百分比可信、绝对 count 是估计**。源站 5xx=0（Tomcat `http_server_requests`）+ CF 504>0 并存是正常的——CF 504 是 edge↔origin HTTP 往返超时，请求没在源站完成故 Tomcat 不记。判"用户可达性失败"必看 CF 边缘 status，别只看源站。

CF token：`system_config.CF_API_TOKEN_A`（账号 A=主站内容域）。zone 17.rip=c160c3791b0eacc1db7f3690b286aa8c。

---
name: CF IPv6 白名单
description: UFW 防火墙需要同时配置 CF 的 IPv4 和 IPv6 白名单，2026-03-31 已补上 IPv6
type: reference
---

UFW 原来只有 CF IPv4 白名单，缺少 IPv6。CF 部分边缘节点（如 KUL 吉隆坡）会通过 IPv6 回源，被 UFW 拒绝导致请求 pending。

2026-03-31 已在 web-01 和 web-02 补上 CF IPv6 白名单（7 个 CIDR）。

CF IP 列表来源：https://www.cloudflare.com/ips-v4 和 https://www.cloudflare.com/ips-v6

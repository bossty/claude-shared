---
name: reference-cf-public-ip-ranges
description: Cloudflare 公开 IPv6/IPv4 段（origin rate-limit/firewall 必白名单），从 cloudflare.com/ips-v6 + ips-v4 拉取
metadata: 
  node_type: memory
  type: reference
  originSessionId: 81da18c1-0060-4b96-992a-9e14b0add5b3
---

# CF 公开 IP 段（origin guard 白名单必备）

**权威源**：
- IPv6: https://www.cloudflare.com/ips-v6
- IPv4: https://www.cloudflare.com/ips-v4

## IPv6 段（5/22 实测）
```
2400:cb00::/32
2606:4700::/32
2803:f800::/32
2405:b500::/32
2405:8100::/32
2a06:98c0::/29
2c0f:f248::/32
```

## IPv4 段
（fetch ips-v4 拿全量 ~15 个段）

## 使用场景
- guard.lua rate-limit 白名单（CF 注入 Cf-Connecting-Ip 可能是 CF edge IP 自身，**特别 S 域 wildcard / Worker 链路**——5/22 实证 `2a06:98c0:3600::103` 同 POP 全球流量共享单一限流桶致 99.7% 误杀，详见 [[project-nginx-error-audit-2026-05-22]]）
- nginx `geo`/`map` 模块标 trusted proxy
- WAF 规则跳过 internal probe

## 实施建议
- 不要硬编码 IP 段到代码（CF 偶尔更新），用 cron + 拉 cloudflare.com/ips-v6/v4 → 写 shared_dict / nginx geo file
- newworld guard.lua 增量：top of file 加 IP-in-CIDR check helper，对每请求 `if ip in CF_RANGES then return end`
- 验证：CF 自己探测的请求绕过 rate-limit；真用户 IP（中国移动 240e: / 中国电信 223.x 等）仍走 rate-limit

---
**并入（原 reference_cf_ipv6.md，2026-07-07）**：CF 回源可走 IPv6；原档所涉 UFW web-01/02 主机已退役，通用事实=放行 CF 段须含 IPv6 段。

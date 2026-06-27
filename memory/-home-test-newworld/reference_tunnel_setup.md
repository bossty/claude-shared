---
name: Tunnel catch-all 配置方法
description: 新建 CF Tunnel 后需要 API 配置 catch-all 规则，否则默认 502
type: reference
---

Cloudflare Tunnel 采用 catch-all 模式：ingress 只有一条 `{"service":"http://localhost:80"}`，所有 CNAME 到该 Tunnel 的域名自动路由。

**新账号/新 Tunnel 配置步骤：**
1. Dashboard 新建 Tunnel，获取 token
2. `echo "<token>" | base64 -d` 获取 account_id 和 tunnel_id
3. API 配置 catch-all：
   ```
   PUT /accounts/{accountId}/cfd_tunnel/{tunnelId}/configurations
   Body: {"config":{"ingress":[{"service":"http://localhost:80"}]}}
   ```
4. 服务器启动 `cloudflared --no-autoupdate tunnel run --token <token>`

**关键点：**
- 默认 catch-all 是 `http_status:502`，必须改为 `http://localhost:80`
- 配一次永久生效，后续加域名只管 DNS CNAME
- 不需要逐个配 hostname ingress，无域名数量限制
- A/C/P 三个 account 各一个 Tunnel，配置相同
- Tunnel ID 和 Account ID 存在 system_config 表（CF_TUNNEL_ID_A/C/P, CF_ACCOUNT_ID_A/C/P）

**2026-04-04 变更记录：**
- 从逐个 hostname ingress 改为 catch-all 模式
- 域名激活从 A 记录改为 CNAME 到 Tunnel
- 删除了 addTunnelIngress/removeTunnelIngress 代码

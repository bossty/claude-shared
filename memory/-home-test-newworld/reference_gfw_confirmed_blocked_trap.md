---
name: gfw-confirmed-blocked-trap
description: S 域 confirmed_blocked / probe 0.00 不等于被 GFW 封 —— provisioning 没配完整会产生一模一样的信号
metadata: 
  node_type: memory
  type: reference
  originSessionId: 3e6b0318-9157-4777-b86a-35bd2c0bb0d5
---

`domain.gfw_pollution_state=confirmed_blocked` + `probe_success_ratio=0.00` **不能直接判定该域被 GFW 封**。
GfwProbeAggregator 用 `ItdogProbeClient` 调 itdog.cn `/http/` 从中国多点做 **HTTP/HTTPS 拨测**；
**任何让该 HTTP 探测失败的原因都会被归类成 confirmed_blocked**，与真 GFW 封无法从这一个信号区分。

## 下结论前必查 3 项（2026-05-16 gg001 事故，错判 2 轮才定位）

1. **边缘 TLS**：`curl https://test.<域>/` 从非 GFW 出口 —— `tlsv1 alert internal error` = 边缘 sni_loader 没该域证书（cert 没下发），不是 GFW。
2. **apex A/AAAA 记录**：itdog `buildFormBody` 探 `host=<裸 apex 域名>`。S 域只配 wildcard `*.域` 不够 —— **apex 本身也要 A/AAAA**（工作域 swiftgroup26.cc 等 apex+wildcard 都有；apexcorp26.com 漏了 apex → itdog 解析裸 apex 失败 → 0.00）。真实用户只访问子域，但探针探 apex。
3. **中国 resolver 解析**：`dig @223.5.5.5 / @119.29.29.29 <域> A` —— 真 GFW DNS 污染会返回 bogus IP；返回真边缘 IP = 没污染。

## cert 下发的 catch-22

edge `cert_pull_agent` 只拉 `GET /api/v1/internal/ops/active-s-list`（SQL 口径 `category='S' AND status='active'`）的域。
域卡在 `status=blocked` → 不在列表 → cert 永不下发 → 边缘 TLS 永远失败 → 探针永远 0.00 → 永远 blocked。
**破解**：先把 `domain.status` 改 `active`（+ `gfw_pollution_state=clean`, `probe_success_ratio=1.00`），cert_pull_agent 5min 内自动拉证书。

## DNS 负缓存

CF zone SOA minimum=1800s（30min）。补 DNS 记录后，itdog 中国 resolver 仍读 30min 负缓存 →
补完后探针还会失败约 30min 才转好。期间注意 GfwProbe 连续 6 次 confirmed_blocked 会 `markConfirmedBlocked`
（status→blocked）—— 误判窗口内应 `redis-cli DEL gfw:probe:counter:{domainId}:confirmed_blocked` 重置计数器防误触发。

## gg001 worked example（2026-05-16）

渠道 gg001 唯一 S 域 apexcorp26.com（id=140，5/11 绑定从没动过）：grandfathered legacy 域（无 purchase_log /
provision_job），DNS 配了 wildcard 但**漏了 apex A/AAAA**、cert 签在 cert_blob 但因 status=blocked 没下发到边缘。
修复链：status→active → cert_pull_agent 拉证书 → 补 6 条 apex A/AAAA（CF API，IP 同 wildcard，grey cloud）
→ 重置 confirmed_blocked 计数器 → 等负缓存过期 → GfwProbe 回 `clean ratio=0.95` → gg001 不再 orphan。
全程从没被 GFW 封，纯 provisioning 没配完整。详见 [[project-overview]] 域名生命周期。

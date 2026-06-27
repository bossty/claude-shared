---
name: Happy Eyeballs 同族多 IP 不 race（IMC'25 论文）
description: 浏览器对同族多 IPv4（或多 IPv6）记录只 "failover on TCP failure"（3-75s 超时），不 parallel race；多源冗余必须靠跨族（v4×v6）或权威 DNS geo-routing，不能靠 DNS 返多个同族 IP
type: feedback
originSessionId: 93fa30d6-8acf-448f-9897-96d44dbb2453
---
Happy Eyeballs v2（RFC 8305）在**跨族（v4 × v6）**时才真正 parallel race（250ms stagger + 首包胜出）。**同族内多 IPv4**（比如 DNS 返 3 个 A record）浏览器**只尝试第一个**，失败才 fallback 到第二个，**TCP 超时 3-75s**。

**Why**：IMC 2025 论文《Measuring Client-side Endpoint Reachability Strategies in Browsers》实测 Chrome/Firefox/Safari 都确认此行为。我在 v3.2.4 架构讨论中曾错判"3 源 6 record HE race"，被 user 用 IMC'25 引用纠正。

**How to apply**：
1. **设计多源冗余必须跨族**：每源都提供 v4 + v6 双栈，让 HE 跨族 race 生效；纯同族多 IP 冗余**无效**（失败 fallback 要等 75s timeout）
2. **S 层多源部署架构**：不能只靠 DNS 返多个 IPv4 让浏览器自动选最快——这不成立
3. **ISP 分流需权威 DNS 层解决**：阿里云 DNS / DNSPod 运营商线路分流，或 CF Load Balancer（需橙云）
4. **Newworld Phase 0 采用**：每 S 域 6 record（2×USCA v4 + 2×USCA v6 + 1×aws-s v4 + 1×aws-s v6），v4/v6 跨族 race 有效（中国 v6 普及率 2026 约 70%），v4 fallback 靠 dns-failover-agent 主动切换
5. **凡架构讨论提到"多源 race"**，先问"是跨族还是同族"——同族 race 是幻想

**参考**：
- RFC 8305 Happy Eyeballs v2
- IMC 2025 论文（具体标题待补）
- docs/P_TO_A_MIGRATION.md §9 v3.2.4 架构决策

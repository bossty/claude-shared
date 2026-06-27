---
name: Phase 0 S 层入口 = 搬瓦工 USCA_9 × 2 + aws-s
description: 2026-04-20 采购决策，弃 HK 用 LA DC9（三网直连 CT CN2 GIA + CMIN2 + CUP），+ aws-s HK 作为 IPv6 跨族兜底
type: reference
originSessionId: 93fa30d6-8acf-448f-9897-96d44dbb2453
---
**Phase 0 S 层 VPS 配置**（2026-04-20 user 采购完成）：

**Tier 1 入口**：
- 搬瓦工 **USCA_9**（LA DC9 AMD+NVMe）× 2 台，80G V5 KVM
- 规格：4C / 4GB RAM / 80GB SSD / 1000GB/月流量 / 1Gbps
- 线路：**CT CN2 GIA + CMIN2（移动精品）+ CUP（联通精品）** 三网直连
- CN 延迟：三网统一 150ms（比 HK 30ms 劣化 5x，但移动 100% 覆盖）
- IPv6：原生双栈支持
- 月价：$155.99 × 2 = $311.98，含 DDoS $6.99 × 2
- 购买入口：https://bandwagonhost.com/cart.php，优惠码 `BWHCGLUKKB`（6.78% off）

**Tier 2 备线**：
- aws-s EC2 t3.small（ap-east-1a 香港）
- IPv4 + IPv6 双栈，Elastic IP + AAAA 自动分配
- 月价 $17

**架构**：
- CF DNS 单栈（灰云），每 S 域 6 record 模式 II 三源并发
- 2 USCA v4 + 2 USCA v6 + 1 aws-s v4 + 1 aws-s v6
- 浏览器 HE **跨族 race 有效**（v4 × v6），同族 failover 靠 dns-failover-agent
- 月度总成本 $342.95（+ DNS 等零碎 = ~$345/月）

**Phase 1 演进预期**：
- 若 USCA 延迟 150ms 影响用户体验 KPI → 加 HK 节点（DMIT Profile 3 / 阿里云 HK / Gcore HK 等）
- 若 1TB quota 不够 → 升级到 160G V5 或买流量包

**关键注意**：
- 搬瓦工 HK 移动线路 100% 丢包，**不考虑任何搬瓦工 HK 机房**（见 feedback_bandwagon_hk_mobile_fail.md）
- 所谓"三网直连"必须**实测 ping.pe / itdog.cn / 17ce** 确认，不信文案宣传

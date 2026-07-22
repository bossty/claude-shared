---
name: reference_ad_conversion_drop_misdiagnosis_2026_05
description: 2026-05 广告转化下跌排查:真因=灰产落地域名轮换/被封(结构性周期复发),「5/7下降」是统计口径改动的测量假象;v1误诊教训=拨测必用数据库完整URL(端口+路径),裸域名443测错端口曾推出「域名不可达」错误结论
metadata:
  type: reference
---

2026-05-18 广告转化下跌排查（团队 crossfire，v2 含重大更正）的三条 durable 结论，防未来同类症状重复论证：

**1. 广告主注册 200→40 的真因 = 出站落地链路的结构性风险（会周期性复发）**：广告 `click_url` 指向超长随机子域的灰产 `.top:1688` throwaway 域名，MySQL binlog 实证每隔几天被轮换一次；旧域名会随时间被中国网络逐步封锁（已轮换掉的旧域 itdog 拨测 ~56% 瞬时失败=IP/DNS 封，当前在用域 ~97% 可达）。落地域被封 → 用户点了广告到不了广告主注册页 → 转化暴跌。**不是**首屏广告位取消（H1，per-slot 数据无台阶）、**不是**广告屏蔽插件（H2，bait 组跨引入日无台阶）、不是探针误伤。只要还在用 throwaway 灰产域投广告，此症状就会周期性复发——见「某些广告注册暴跌」先查当期落地域名的中国侧可达性（用 DB 完整 URL）。

**2. dashboard「5/7 转化/UV 下降」是测量假象**：5/7 统计系统重写部署，`1fae68c3` noVid gate 改了访客计数口径 → UV −48%、ip_count −53%，但 `session_count` 仅 −1.7%（不受该 gate 控制，最干净的对照指标）。**判据：真走掉一半访客、会话数必同步腰斩；「人少一半、会话数纹丝不动」= 口径改动非真流量下跌**。5/7 前后的 UV/ip_count 不可直接比较。与 [[feedback_verify_metric_source]]（指标解读前先验数据源）同源。

**3. v1 误诊教训（Why 本条最值钱）**：v1 曾结论「出站域名对中国不可达=已确证根因」，后被推翻——v1 itdog 测的是**裸域名 443 端口**，而真实 `click_url` 是 `:1688` 端口 + 路径；用 DB 完整 URL 重测后当前域名全部可达。**How to apply：可达性拨测必须用数据源里的完整 URL（协议+端口+路径），禁用裸域名默认端口替代**；伴随坑=转述 TLD 抄错（`.to` vs `.top`）曾推出「DNS 死域」假结论。另：MySQL binlog 保留期只有 ~6 天，历史 `click_url` 溯源窗口极短，事发要尽早取证。

相关：[[reference_cn_isp_international_routing_split]]、[[feedback_distribution_reflects_sample_not_phenomenon]]。

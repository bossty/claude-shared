---
name: Wave Stats v5 Sprint 状态
description: v5 subdomain channel 重构 + 反封锁 wildcard failover sprint，2026-04-26 P9 模式设计完成，待实施
type: project
originSessionId: ca3318b1-e4f8-4b17-aef1-621762cf695e
---
# Wave Stats v5 Subdomain Channel 重构（设计完毕，待实施）

## 启动状态（2026-04-26）
- 10 P8 独立设计 + 2 轮蓝军 + P9 consolidation 已完成
- 5 决策 Owner 已拍板
- 总工时 8.5 人天主 + 2 周 part-time（CF Universal SSL 接管 A/P/B/C 大幅简化原估）

**Why**：v4 时代归因系统 W2 切换 24h 后归因覆盖率仅 9.2%，自然流量 86.4%，IP/UV 比异常等 4 条核心数据问题。HLL 跨 channel 不可加 + cookie 1 年残留 + 直访无法归因。

**How to apply**：新会话开干读 `docs/design/wave_stats_v5_sprint_kickoff.md` + `wave_stats_v5_p9_consolidation.md`，按 §11 prompt 启动。派 P7 串行 4 单元（基建 → 后端 → 边缘+前端+百度 → admin+监控+cutover+清理）。

## P9 5 大已拍板决策

1. **DomainListHolder 保留扩展**（不 rename），加 `getCategory(rootHost)` 接口
2. **长度协议**：5=CHANNEL / 1-4+6-10=PROBE / >10/特殊/保留前缀=organic；保留前缀 10 个 `{www, mail, adm, api, cdn, doh, relay, static, m, mobile}`
3. **不 backfill** 历史 `domain_name`，mapper COALESCE 兜底
4. **uv_global DDL DEFAULT NULL**，mapper `COALESCE(SUM(NULLIF(uv_global,0)), SUM(uv))` 避免视觉断崖
5. **acme 工时 1 人天 + 2 周 part-time**（仅 S 域 7 个；A/P/B/C 走 CF Universal SSL 自动 wildcard，仅需 DNS 加 `*`）

## 关键技术理解
- **A/P/B/C 域走 CF Tunnel 回源** → CF 边缘 SSL 自动接管（含 root + `*.X.com` 一级 wildcard），**0 acme 工作**
- **仅 S 域 aws-s 独立 VPS** 自签 acme.sh
- **GFW 封禁特征**：主要打 @ 和 www，wildcard 子域难全封
- **wildcard 利用**：@ 不通切同 zone 随机二级，整 zone 仍可用
- **5 字符 = 渠道，6-10 字符 = random failover/probe**，避免碰撞
- **不双轨切换**：老用户 cookie + bookmark = root → 全归 organic（Owner 接受）
- **跨子域 visitor_id 重计 ≤5%**（_vid cookie Domain=.X.com 跨不到 .Y.com，接受）

## 预期收益
- 归因覆盖率 9.2% → **80-95%**
- 归因精度 ~80% → **~99%**
- 异常 1+2+4 自然消失（HLL 跨 channel 不可加问题解决）
- 反封锁颗粒度从域级降到子域级
- 删 channel.js + identity.lua + channel_whitelist_agent + domain_class_agent 等 5 文件 ~150 行代码
- **百度统计跟随简化**：直接读 location.host 第一段，删 localStorage._rc 依赖

## 关键文档（新会话读完即可开干）
1. `docs/design/wave_stats_v5_sprint_kickoff.md` — 本 sprint 启动指南
2. `docs/design/wave_stats_v5_p9_consolidation.md` — P9 最终方案 5 决策
3. `docs/design/wave_stats_v5_subdomain_channel.md` — v5 baseline
4. `docs/recon/p8_bluearmy_v5_10teams_consolidated.md` — 蓝军 26 矛盾
5. 10 份 T1-T10 P8 设计（细节查询用）

## P7 串行实施 4 单元
- P7-V5-1 基建（acme wrapper + DNS `*` + CF SSL 自动 + S 域 7 个 wildcard）
- P7-V5-2 后端（HostChannelParser + DomainListHolder.getCategory + IdentityInterceptor + DDL + mapper）
- P7-V5-3 边缘 + 前端 + 百度（删 lua + s_channel_agent + short_redirect 改 + channel.js 删 + baidu-hm.js 改读 host）
- P7-V5-4 admin UI + 监控 + cutover + T+24h 清理

## v6 接口预留
- IdentityContext.visitorAlias 字段（默认 null）
- site_daily_stats.visitor_alias_count 列（默认 NULL）
- v6 sprint 解决：PSL 3 段 (R1) / cross-root visitor_alias 表 (R2) / 全域 HLL 决策 (R3)

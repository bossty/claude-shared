---
name: Wave Stats v6 Sprint 状态（2026-04-27 中午）
description: V5 cutover 已上线 + V5.1-A/A.2 已上线 + V5.1-B 拆 3 sub-sprints 待派 + V6 35.35d 待启
type: project
originSessionId: 3804869c-f531-451d-b64f-8229967af795
---
V5 / V5.1 / V6 sprint 进展（2026-04-27 中午接 V5.1-B 拆分阶段）。

**Why**: 跨会话保持 sprint 状态一致，新会话不丢细节。前会话产出极多（13 P8 + 5 蓝军 audit + 38 决策），单 kickoff doc 是入口；本 memory 只记跨 session 不变的事实。

**How to apply**:
- 新会话首先 read `docs/design/wave_stats_v6_sprint_kickoff.md`（38 决策 + V5.1-B 拆 3 sub-sprints + handover prompt §10）
- 该 doc + `docs/design/wave_stats_v6_p9_consolidation.md §9` 即可完整接手
- 不需要重新 audit；13 P8 + 5 蓝军报告路径见 kickoff §6 + §15

## 关键事实
- V5 cutover：master HEAD 已含 commits f264f287 → fe8b46b3 → d875de33 → 7f081245(V5.1-A G3+G9) → 49b320a4 → 98b3a968(N9E append_tags) → 5dae65b4(V5.1-A.2 B1+C1)
- 38 决策已 Owner 全拍板（D1-D11 + HD1-HD18 + T-θ F1-F8 + T-ι HD20-HD27）
- V6 真终工时 35.35d / critical 23.45d / 4 P7 拓扑（5d/11d/13.95d/5.25d）
- V6 cutover T+28d (5-24~5-26)

## V5.1-B 拆 3 sub-sprints（agent 拒绝单 session 后 P9 接受）
- B.2 数据层（D1+D4+A1+GlobalExceptionHandler，0.5d，**最先派独立可并行**）
- B.1 契约层（G1+G5+G6，1d，B.2 后并行）
- B.3 前端+监控+部署（A2+N9E+cutover，0.5d，B.1+B.2 后）

## A1 真因揭晓（不在 P8-φ 推断的 @Pattern）
admin 后台编辑渠道报错 = `Unknown column 'baidu_site_id_promo' in field list` — V5 mapper 含字段但 DB schema 漏 ALTER。修法：B.2 加 SQL migration ALTER TABLE promotion_channel ADD COLUMN baidu_site_id_promo + baidu_site_id_retention。

## D1 数据 bug 真因（P8-χ 揭晓）
留存人均 PV 偏低（实测 3-9 不等）真因：SiteDailyStatsMapper.overviewSummary SQL 没过滤 V5-2 引入的 `(channel_code='', uv_global=N, pv=0)` 占位行 → SUM(uv) 双计 → 分母变 2N → avgPv 减半。修法：B.2 加 `WHERE channel_code != '' OR uv_global IS NULL`。

## V6 决策禁前置铁律
V5.1-B 严禁前置 V6 决策（HD2 visitor_alias / HD15 T+1 返访 / HD17 4 P7 / HD20 _rp 5 字段扩展 / HD22 redis 兜底 / HD27 客户端协调）。V5.1-B 仅 HD1 简化版（cookie `_rp = {ch, ts, sig}`，3 字段不带 vid/tid/cd/cfh/hop）。

## 下一步派工
新会话立即派 P7-V5.1-B.2（数据层独立 0.5d）→ commit/push → 完后并行派 B.1/B.3。完整任务 prompt 见 kickoff §12。

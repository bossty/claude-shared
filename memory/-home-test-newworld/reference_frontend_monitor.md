---
name: 前端错误监控系统
description: 2026-04-17 建立的 Redis 分桶 + admin Top N 仪表盘 + 扩展/bot 识别，告警文档位置和故障排查
type: reference
originSessionId: 315225a0-4872-4aa2-b73b-4b4f2e570643
---
前端错误监控全链路文档：`docs/FRONTEND_MONITOR.md`

关键 Redis key 前缀（5min slot = yyyyMMddHHmm，TTL 30min）：
- `monitor:js-errors:{slot}` 真 JS 错误（告警用）
- `monitor:promise-rejections:{slot}` 独立观察
- `monitor:resource-errors:{slot}` 资源失败（不告警）
- `monitor:extension-errors:{slot}` UC/Quark 插件（不告警）
- `monitor:sessions:{slot}` HLL 会话（JS 错误率分母）
- `monitor:error-top:{slot}` / `monitor:error-samples:{slot}` 主 Top
- `monitor:error-top:ext:{slot}` / `monitor:error-samples:ext:{slot}` 扩展 Top

admin 面板：**运营 → 前端错误 Top**，`/monitor-errors` 路由。

告警双门（SystemMonitorTask）：`jsErrors >= 500` OR（`sessions>=50 AND count>=20 AND rate>30%`）。
告警文案：`🔴 JS 错误: N 条 / M 会话（X%）`

故障排查表见文档 §7，常见 Top 1 错误根因 + 修复位置都列了。

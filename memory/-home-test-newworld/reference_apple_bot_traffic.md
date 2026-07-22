---
name: Apple Bot 流量识别（playback_error_log）
description: 17.0.0.0/8 = AS714 Apple，iCloud Private Relay + Link Preview Bot，playback_error_log 已加 source_type 分桶
type: reference
originSessionId: 315225a0-4872-4aa2-b73b-4b4f2e570643
---
IP 段 **17.0.0.0/8** 是 ARIN 分配给 Apple Inc（AS714）的唯一 classful block，100% 属于苹果，包括：
- iCloud Private Relay 出口（`17.22.x.x` / `17.241.x.x` / `17.246.x.x`）
- iMessage/Safari Shared Sheet Link Preview Bot
- APNs、企业出口等

**playback_error_log 表** 已加 `source_type` 列（2026-04-17 DDL）：
- `user` — 真实用户失败
- `apple_bot` — IP LIKE '17.%' 自动标记
- `other_bot` — 预留

查询接口：`/api/v1/analytics/playback-diagnosis/summary?sourceType=user|apple_bot|all`

admin 播放诊断页默认 tab = 真实用户，Apple 机器人 tab 显示角标计数。

典型 bot 流量特征（识别同类 bot 时可参考）：
- UA：`Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) ... Version/17.*` 无扩展痕迹
- movieId 离散度高（>90% 唯一）
- IP 离散度高（>80% 唯一，因 Relay 轮换）
- 出现模式：脉冲式（dist 切换后批量重抓）

详见 `docs/media/PLAYBACK_DIAGNOSIS.md`。

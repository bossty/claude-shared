---
name: project_baidu_stats_sync_retired_2026_06_21
description: 百度统计同步 2026-06-21 暂时退役(token过期Owner暂不轮换)—停BaiduStatsSyncTask+BaiduTokenAlertTask两@Scheduled+删Redis指标key+禁N9E规则8;含复活路径
metadata: 
  node_type: memory
  type: project
  originSessionId: 85dc3fe1-5403-474d-941b-c0f0f36ee859
---

2026-06-21 Owner 决策：**暂时退役百度统计（百度统计 OpenAPI）同步**。

**触发**：N9E `BAIDU-API-FAIL`（S3，`newworld_baidu_stats_consecutive_failures>=3`，实测 9）首发 6-14，持续 6+ 天。根因：`BAIDU_API_TOKEN`（system_config 存的 JWT access token）**2026-06-10 21:24 过期**（`BAIDU_API_TOKEN_EXP=1781097897`），每日 07:30 `BaiduStatsSyncTask` getSiteList → `89406 access token invalidate` → 全站失败累加。**代码无 refresh_token 机制**（system_config 只存 access token，无 refresh/app secret），续期必须 Owner 登录百度后台（账号 `去黄河边钓鱼`）手动生成。Owner 决定暂不轮换 → 退役同步。

**关键坑（为什么"只关任务"不够）**：`consecutive_failures` 是 **Redis 持久化**（key `admin:baidu_stats:consecutive_failures`，`BaiduStatsMetrics` gauge 实时读它），**只在同步成功时 `reset()`（DEL key）归零**。关任务=永不成功=指标卡在 9=N9E 规则永不 recover。所以消警必须**额外删 Redis key**（gauge 立即读 0，无需重启/部署）。

**实现（暂时退役，全可逆，commit de9af647）**：
1. `BaiduStatsSyncTask` 注释 `@Scheduled("0 30 7 * * ?")`（停 07:30 同步，免再累加）。
2. `BaiduTokenAlertTask` 注释 `@Scheduled("0 0 9 * * ?")`（停 09:00 token 过期 Telegram；该 Telegram 本就投递失败 3 次耗尽，所以告警静默 6 天）。
3. **DEL Redis `admin:baidu_stats:consecutive_failures`** → gauge 读 0（当前进程实时生效，告警即消）。
4. **N9E 规则 id=8 `BAIDU-API-FAIL` `disabled=1`**（保留可逆，非删）。

**复活四步**：恢复两 `@Scheduled` + `UPDATE system_config SET config_value='<新token>' WHERE config_key='BAIDU_API_TOKEN'`（及 `BAIDU_API_TOKEN_EXP`）+ N9E 规则 8 `disabled=0` + 部署 admin。同步成功后 reset 自动归零。

**影响**：site_daily_stats 等百度来源 BI 维度停更（已陈旧 9 天，非用户可见）。`BaiduStatsMetrics`/`BaiduStatsController`/查询服务保留（读历史数据不受影响）。

**治本方向**（若以后想免手动续）：百度 OAuth 存 refresh_token + app_id/secret 自动刷新 access_token（access~30d 过期，refresh~10y）。当前是手动粘 JWT 每 ~30 天复发。

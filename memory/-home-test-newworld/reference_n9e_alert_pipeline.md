---
name: reference-n9e-alert-pipeline
description: N9E 告警链路完整路径 — categraf probe → VictoriaMetrics → N9E rule → Telegram；user_facing probe + 告警规则 import 流程
metadata: 
  node_type: memory
  type: reference
  originSessionId: b2187ab6-4c03-4c80-b561-f114570e7bc2
---

# N9E 告警链路（5/12 用户视角探活补完）

## 链路图

```
[aws-monitor] categraf (http_response plugin)
   ↓ HTTP push (interval=30s)
[aws-monitor] N9E push gateway :17000
   ↓ ingest
[aws-monitor] VictoriaMetrics :8428（TSDB）
   ↓ rule eval (N9E center)
[aws-monitor] N9E AlertRule (in mysql n9e_v6.alert_rule)
   ↓ severity match → webhook
[aws-monitor] N9E webhook → admin TelegramAlertService
   ↓ HTTPS POST sendMessage
Telegram bot
```

## 关键路径 + 文件

| 项 | 位置 |
|---|---|
| N9E server host | aws-monitor (16.163.94.193) |
| N9E web/api port | 17000 (https://n9e.17.rip 经 CF) |
| VictoriaMetrics | 127.0.0.1:8428（内网，直 query 测 metric 用） |
| N9E config | /opt/n9e/etc/config.toml |
| categraf config | /etc/categraf/config.toml（writer → N9E push） |
| http_response probe | /etc/categraf/input.http_response/http_response.toml |
| alert rules SOT | /newworld/ops/n9e-alert-rules.yaml（**手工 sync 到 N9E UI**，不 auto load） |

## user_facing 探活（5/12 ship）

categraf 已加 3 个 user_facing target（aws-monitor → CF → CF Tunnel → aws-web）：
- `https://17.rip/`
- `https://17.rip/api/v1/settings/version`
- `https://17.rip/api/v1/courses/featured`

Metric: `http_response_result_code{group="user_facing", target=...}` （0=OK, !=0=fail）
+ `http_response_response_time_ms{...}`

## Alert rules（已 append yaml，需 owner UI import）

- **USER-SITE-DOWN** P0：`max by (target) (http_response_result_code{group="user_facing"}) != 0` for 2min → Telegram
- **USER-SITE-SLOW** P1：`max by (target) (http_response_response_time_ms{group="user_facing"}) > 3000` for 3min → Telegram

## Import alert rule 操作

N9E v8 yaml 不 auto reload。手工 import 流程：

1. 登录 https://n9e.17.rip
2. **告警规则** → **导入** → 粘贴 USER-SITE-DOWN / USER-SITE-SLOW yaml
3. 选 datasource（VictoriaMetrics 数据源 ID）+ 启用通知组（Telegram）
4. 保存 + 在规则列表 "立即评估" 一次验证 PromQL 返 0 series（正常状态）

或用 N9E API（需 N9E auth token）：
```bash
curl -X POST https://n9e.17.rip/api/n9e/alert-rules \
  -H "Authorization: Bearer $N9E_TOKEN" \
  -H "Content-Type: application/json" \
  -d @rule.json
```

## 验证 metric 已上来

```bash
ssh aws-monitor 'curl -s "http://127.0.0.1:8428/api/v1/query?query=http_response_result_code%7Bgroup%3D%22user_facing%22%7D" | jq'
# expect: 3 series with value="0" (all 200 OK)
```

## 何时该想到这条链路

- 用户说"网站打不开了我没收到告警"
- 用户问"今天 X 故障 N9E 应该能抓但没响"
- 验证新增 metric/alert 是否真生效（不止是 yaml commit，要 UI import + 跑评估）
- 类似故障：HikariCP / 慢 SQL / nginx upstream timed out — 这些链路通过 user_facing probe 间接覆盖（站点变慢就报，无需 metric-specific rule）

## 待办（owner 操作）

- [ ] 登录 N9E UI import USER-SITE-DOWN / USER-SITE-SLOW 2 条规则
- [ ] 验证 Telegram bot 真收到测试告警（暂时 stop newworld-web 60s → 2min 后看 Telegram）
- [ ] 后续可扩 probe target：详情页路径 / 关键 cache API / admin entry

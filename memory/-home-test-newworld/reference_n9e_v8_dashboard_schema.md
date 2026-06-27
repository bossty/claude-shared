---
name: reference-n9e-v8-dashboard-schema
description: N9E v8 dashboard JSON 真 schema（与 doc 不一致，唯一权威是 board_payload 现存 working dashboard）
metadata: 
  node_type: memory
  type: reference
  originSessionId: f3a2d91b-21b8-418c-bfea-c15095c9585f
---

# N9E v8 dashboard JSON 真 schema

## 唯一可靠 source of truth

N9E v8 import API 文档描述的 schema **与实际 DB 存储格式不一致**。**别照 docs 写 dashboard JSON，照已 working 的 board_payload 写**。

```bash
# 查现有 working dashboard
ssh aws-monitor 'mysql -uroot -p"<pwd>" n9e_v8 -se "SELECT id,name FROM board ORDER BY id DESC"'
# 拉某 working dashboard 完整 payload 作模板
ssh aws-monitor 'mysql -uroot -p"<pwd>" n9e_v8 -Nse "SELECT payload FROM board_payload WHERE id=<ID>"' > template.json
```

DB 密码在 `/opt/n9e/etc/config.toml` DSN 字段（`sudo -n cat` 可读）。

## 必填字段（容易遗漏）

### 1. var 必含 datasource 变量

否则 panel 里 `${datasource}` 解析失败 → 所有 query 返回空（图表渲染但无数据是这个坑）：

```json
"var": [
  {"name": "datasource", "label": "datasource", "definition": "prometheus", "type": "datasource"}
]
```

### 2. panel 顶层必含 datasourceCate + datasourceValue

**不是写在 target 里**（旧 Grafana 风格错）：

```json
{
  "datasourceCate": "prometheus",
  "datasourceValue": "${datasource}",
  ...
}
```

### 3. timeseries panel 必含 custom 字段（绘图参数）

无 `custom` 块 panel 渲染失败：

```json
"custom": {
  "drawStyle": "lines",
  "fillOpacity": 0.3,
  "gradientMode": "opacity",
  "lineInterpolation": "linear",
  "lineWidth": 2,
  "scaleDistribution": {"type": "linear"},
  "spanNulls": false,
  "stack": "off"
}
```

### 4. panel id 用 UUID 不是 kebab-case

```json
"id": "78ac9b93-589f-49a5-ad09-233bc67007db"
```

### 5. layout 多 i / isResizable

```json
"layout": {"h": 7, "w": 12, "x": 0, "y": 0, "i": "<uuid>", "isResizable": true}
```

### 6. target 简化

只写 expr/legend/refId，不写 datasourceType/datasourceId（这两个移到 panel 顶层）：

```json
"targets": [
  {"expr": "<PromQL>", "legend": "{{cfPop}}", "refId": "A"}
]
```

## 直 DB UPDATE 替代 UI import

dashboard schema 调试时不必走 UI import → delete → 重 import 循环。直接 mysql UPDATE board_payload 然后 owner 刷新即可。

```bash
B64=$(base64 -w0 new-payload.json)
ssh aws-monitor "mysql -uroot -p... n9e_v8 -e \"UPDATE board_payload SET payload=CONVERT(FROM_BASE64('$B64') USING utf8mb4) WHERE id=<ID>\""
```

## 排障三段定位（与 [[project_cf_china_edge_reality_2026_05_22]] 同源教训）

dashboard 无数据时按链路定位：
1. **actuator 是否暴露 metric** — `curl 127.0.0.1:18080/actuator/prometheus | grep <metric_name>`（注意 web actuator 在 18080 不是 7777）
2. **VictoriaMetric 是否收到** — `curl http://127.0.0.1:8428/api/v1/label/__name__/values | python3 -c "import json,sys; print([n for n in json.load(sys.stdin)['data'] if '<key>' in n])"`
3. **PromQL 直查 VM 是否返结果** — `curl 'http://127.0.0.1:8428/api/v1/query?query=<encoded_promql>'` 看是否有 result
4. **dashboard 真 schema** — 跟 working board_payload 对照（最容易遗漏 var:datasource）

## 关联

- [[reference_n9e_alert_pipeline]] — N9E 告警链路（alert rules 也手工 UI import）
- [[project_cf_china_edge_reality_2026_05_22]] — sprint 全栈实证（含 dashboard schema 调试 5 轮迭代）

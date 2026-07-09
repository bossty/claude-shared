---
name: newworld-monitoring-ops
description: N9E v8 监控体系运维 — categraf v0.5 schema 子目录化（input.cpu/cpu.toml）；alert_rule 必填 datasource_queries（不是 datasource_ids/cluster），NULL 则永不 eval；actuator 端口隔离（127.0.0.1 single port，禁公网透传）；target.host_ip 必须 varchar(64) 容 IPv6；toml 正则用单引号 literal 防转义；通知走 notify_rule（内置 telegram channel id=13）。Triggers on n9e, nightingale, categraf, datasource_queries, alert_rule, victoriametrics, host_ip varchar, notify_rule, 监控告警, 添加告警规则, 添加新主机, actuator 端口, management.server.port, input.cpu, input.systemd, telegram channel.
---

# Newworld N9E v8 监控运维铁律

## 触发场景
- 添加新主机到 N9E target
- 添加 / 修改 alert_rule
- 改 categraf config.toml
- 改 Spring Boot actuator 暴露策略
- 排查"告警规则不 eval"或"target host_ip 空"

## 触发后必读：`docs/MONITORING_SETUP.md` § 6（添主机 SOP）/ § 7（添告警 SOP）

## 6 个深坑（按 sprint 沉淀顺序）

### 1. categraf v0.5 schema 不兼容 v0.3
- v0.3 扁平：`conf/input.cpu.toml`
- v0.5 子目录：`conf/input.cpu/cpu.toml`
- 本机型 input 去 `[[instances]]` 包装
- 升级遗漏 = 静默 "no inputs" 不采集（不报错）

### 2. N9E v8 alert_rule 必填 `datasource_queries`
不是 `datasource_ids` / `cluster`（源码注释 deprecated）：
```sql
INSERT INTO alert_rule ... datasource_queries = '[{"match_type":0,"op":"in","values":[<datasource_id>]}]';
```
NULL → alert engine 完全不 eval，`alert_his_event` 永远 0 条。debug 1+ 小时常见根因。

### 3. actuator 端口隔离
- 业务端口 `:7777 / :8888 / :9999` **不暴露** actuator
- `management.server.port` 单独配 + bind `127.0.0.1`
- 否则 OpenResty 兜底 transparent proxy 把 `/actuator/*` 透传公网

### 4. N9E target.host_ip 必须 varchar(64)
- 默认 varchar(15) 装不下 IPv6
- 边缘机 host_ip / os / host_tags 全空
- migration：`ALTER TABLE target MODIFY host_ip varchar(64)`

### 5. toml 字符串内的正则用单引号 literal
- `unit_include = '(...)\.service'`
- 双引号 + heredoc 嵌套 ssh 会丢转义 → input.systemd 不 load
- bash heredoc 嵌套时 `\.` 被吞，单引号 literal 安全

### 6. 通知走 notify_rule（不走 alert_rule.notify_channels）
- alert_rule 通过 `notify_rule_ids` 关联 notify_rule
- channel / params / user_group 全在 notify_rule 内
- N9E 内置 telegram channel `id=13`，无需本地 bridge

## 添加新主机 SOP
1. 装 categraf（v0.5+）
2. 写 `/etc/categraf/conf.d/config.toml` + `input.<name>/<name>.toml`
3. systemd unit + start
4. N9E target 表 10s 内自动出现新 ident
5. 验证：N9E UI Targets 页面看 host_ip / os / host_tags 不空

## 添加新告警规则 SOP
1. 写 promQL（在 N9E 即席查询验证返数据）
2. INSERT alert_rule，**`datasource_queries` 必填**
3. 关联 `notify_rule_ids`（telegram = 13 内置）
4. 验证：触发条件后 5 min 内 `alert_his_event` 有记录
5. 确认 telegram bot 收到消息

## 检查清单
- [ ] categraf 升级时 conf 目录结构对齐 v0.5（子目录）
- [ ] 新 alert_rule SQL 含 `datasource_queries` 字段
- [ ] actuator bind 127.0.0.1，不在业务公网端口暴露
- [ ] target.host_ip schema 是 varchar(64)
- [ ] toml 正则用单引号 literal
- [ ] notify_rule 关联 telegram channel id=13

## 违反后果
- categraf 升级 schema 漏改 → 主机静默不采集，监控数据缺失天级才发现
- alert_rule `datasource_queries` NULL → 告警永不触发，故障无感知，**用户先发现**
- actuator 暴露公网 → `/actuator/env` 泄漏 secrets / endpoint 列表 → 安全事故
- target.host_ip varchar(15) → IPv6 主机标签全空，告警按 host 维度过滤失效
- notify_rule 没关联 → 告警 eval 但 telegram 不响 → 等同没告警
- 监控不工作 = 故障无感知 = 用户先发现 = **3.25 级别**复盘

## 源
- CLAUDE.md L886-L910（N9E v8 监控体系）
- 配套：`docs/MONITORING_SETUP.md` § 6 / § 7

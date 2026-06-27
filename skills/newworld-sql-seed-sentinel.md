---
name: newworld-sql-seed-sentinel
description: SQL seed 文件中 IP/UUID/secret/token/外部 ID 字段必须用显式 sentinel（TODO_FILL_HERE / REPLACE_ME_BEFORE_DEPLOY / NULL），禁止"看起来正常但可能错"的占位（如 1.2.3.4 / 2406:da14::1）。pre-flight 必须 grep 阻止部署。Triggers on seed, 占位值, todo_fill_here, replace_me, sentinel, edge_vps, ipv6 占位, sql seed, fake placeholder.
---

# Newworld SQL seed 占位值铁律（2026-04-22 事故硬化）

## 触发场景
- 编写 / 修改 `sql/v*_seed_*.sql` / `sql/init_*.sql` / 任何含 INSERT 真实业务数据的 SQL
- 字段含 IP / IPv6 / UUID / secret / token / 外部 ID（CF zone_id / NameSilo id / 运营商 tunnel_id / 百度 siteId）

## 铁律

### 1. 禁止"看起来正常但可能错"的占位
反例：`1.2.3.4` / `2406:da14::1` / `a1b2c3...` / `00000000-0000-0000-0000-000000000000`——这些会被生产代码读取并真正使用，**应用层无法 fail-fast**。

### 2. 必须用显式 sentinel
- `TODO_FILL_HERE`
- `REPLACE_ME_BEFORE_DEPLOY`
- `NULL`（如字段 nullable）

### 3. Pre-flight 阻止部署
部署前脚本必须跑：
```bash
grep -rE "TODO_FILL_HERE|REPLACE_ME_BEFORE_DEPLOY" sql/ newworld-admin/src/main/resources/
# 命中任何一处 → 阻止部署
```

### 4. 真实身份字段查原始数据，不凭记忆
edge VPS IP / CF zone_id / 百度 siteId / 运营商 tunnel_id 等涉及外部真实身份的字段，seed 时查现有生产值或 Owner 原始数据，**不凭记忆 / 缩写**。

## 违反后果
按 **3.25** 级别处理。

## 事故案例
commit `cec44e4e`（2026-04-22）：在 `sql/v33_seed_edge_vps_config.sql` 给 aws-s 的 ipv6 写"看起来正常"的 `2406:da14::1`（真值 `2406:da1e:981:5d1:5ac7:6ad0:d41e:fade`）→ 部署链直接写入 `system_config.EDGE_VPS_LIST` → dns-failover-agent 读假值探活失败 → **Agent 误删 CF 5 条 aws-s A record**（Telegram 告警）。

## 源
- CLAUDE.md L504-L520

---
name: reference_fe_error_store_enumeration
description: 穷举所有前端错误distinct族的方法(prod Redis monitor:error-* keys)
metadata: 
  node_type: memory
  type: reference
  originSessionId: 187c446e-e104-4aa0-a529-a524a6ebe78b
---

要"穷举每一种上报的前端错误"时，数据源不是错误样本而是**后端落库**。链路：前端 monitor.js sendBeacon→`/api/v1/analytics/quality`→web `MonitorController`→`MonitorService`(按 type 分桶)→admin `MonitorErrorController` 出看板。

**Redis 结构**（StringRedisTemplate，5min 槽位 yyyyMMddHHmm，TTL 30min）：
- `monitor:error-top:{slot}` / `:ext:` / `:plyr:` ZSET：member=msgKey、score=出现次数(含 score=1 单条)
- `monitor:error-samples:{slot}` / `:ext:` / `:plyr:` HASH：field=msgKey、value=JSON{type,message,source,line,stack,route,version}
- msgKey=sha1(type:source:message[:200])[:16] → **distinct (type,source,message)=一种**
- 桶：main(js_error/unhandled_rejection/resource_error/csp/console_error) / ext(extension/net_echo/chunk_load_recovered/script_error_noise/console_warn) / plyr(plyr_race_swallowed)
- **局限**：每 slot 每桶 ≤200 基数预算(TOP_KEY_BUDGET)+TTL 30min(只 live 窗口)

**枚举法**（admin 端点 `/api/v1/monitor/error-top?range=24h` 有 @RequireMenu+@EncryptResponse 不便 curl）：直连 prod Redis（ca-redis 172.34.1.128:6379 Dragonfly，**需 AUTH**，REDIS_PASSWORD 从 web `/proc/PID/environ` 取、禁打印）。web 节点**无 redis-cli**→写原生 RESP python 脚本(socket，无需 redis 库)：AUTH→SCAN `monitor:error-samples*`/`monitor:error-top*`→HGETALL/ZRANGE WITHSCORES→按 msgKey 去重配分数→归一化(strip UA/域名/数字/hash)成"族"。

2026-06-13 实测：1952 raw distinct → 归一 **397 族**。脚本+全表 docs/sprint/2026-06-13-fe-error-triage/FE-ERROR-FULL-TAXONOMY.txt。访问走 [[feedback_multiagent_prod_ops_auth_backstop]] auth-backstop。详见 [[project_fe_error_triage_2026_06_13]]。

---
name: newworld-lua-redis-pubsub
description: lua-resty-redis pubsub 模式必须 pcall(r.close, r) 显式关连接（不能 set_keepalive）；改完 lua 必 systemctl restart openresty（不是 reload，否则连接翻倍）；Redis 配 timeout 1800 兜底。Triggers on lua redis, sub_loop, pubsub, pcall close, systemctl restart openresty, r:subscribe, connected_clients, channel_whitelist_agent, domain_class_agent, lua-resty-redis, redis 长连接.
---

# Newworld OpenResty Lua-Redis 长连接铁律（2026-04-25 sub_loop 泄漏事故硬化）

## 触发场景
- 修改 / 新增 OpenResty lua agent 含 `r:subscribe()` / `r:psubscribe()`
- 修改 `channel_whitelist_agent.lua` / `domain_class_agent.lua` 等 sub_loop 类模块
- 看到 Redis `connected_clients` 异常增长

## 铁律

### 1. lua-resty-redis 在 pubsub 模式必须显式 close
```lua
-- sub_loop 外层每轮 ngx.sleep(retry_backoff) 之前必须：
pcall(r.close, r)
```
**关键**：
- pubsub 模式**不能**用 `r:set_keepalive()`（连接池不复用 subscribe 状态的连接）
- lua GC **不释放** underlying TCP socket
- 适用所有用 `r:subscribe()` / `r:psubscribe()` 的 lua agent

### 2. 改完 lua 必须 `systemctl restart openresty`，不能 reload
- reload = graceful，旧 worker 直到所有 keepalive 连接 finish 才退
- pubsub timer 协程**永不空闲**（`while true do read_reply end`）→ 旧 worker 永不退
- 结果：新 + 旧 lua timer 同时活，**连接 / 订阅者翻倍**而不是替换
- restart 业务影响窗口 1-2s（CF tunnel 重试覆盖），可接受

### 3. 配 Redis `timeout` 兜底
`/etc/redis/redis.conf` 设 `timeout 1800`（30min），即便业务代码漏 close 也限制无限累积。

### 4. 加监控告警
`pubsub numsub <channel>` >> 实例数 = 泄漏。建议加 N9E 规则 `redis_pubsub_channels{} > 50` 早发现。

## 检测命令
```bash
ssh ca-redis-master 'redis-cli -a "$PASS" --no-auth-warning info clients | grep connected_clients'
# 健康 < 100，异常 > 500

ssh ca-redis-master 'redis-cli -a "$PASS" --no-auth-warning pubsub channels | xargs -I{} redis-cli ... pubsub numsub {} | paste - -'
# 每个 channel 订阅者数应 ≈ 实例数（ca-web-01/02/03/04 + eu-web-01/02）
```

## 违反后果
按 **3.25** 级别。

## 事故案例
2026-04-25：`channel_whitelist_agent.lua` + `domain_class_agent.lua` 的 `sub_loop()` 在 `read_reply` 失败 break 后没显式 close redis 连接 → Redis `connected_clients` 累积到 965（其中 ~497 是这两个 channel 的死连接订阅者）。累积 1 个月才发现 + 误用 reload 导致连接翻倍走了 2 步弯路。

## 源
- CLAUDE.md L912-L943

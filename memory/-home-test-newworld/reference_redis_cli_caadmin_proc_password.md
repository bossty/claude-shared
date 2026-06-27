---
name: reference_redis_cli_caadmin_proc_password
description: ca-admin 默认没装 redis-cli + Redis 真密码在 admin 进程 /proc/environ(非 secrets.env);查 reach:grid 等 Redis 数据的正确姿势
metadata: 
  node_type: memory
  type: reference
  originSessionId: 019a2513-f7cc-4759-ad55-7522771891e2
---

**ca-admin 上查 Redis 数据(reach:grid 等)的坑与正确姿势**(2026-06-26 GFW A2 部署实证,白查几轮)：

**坑**：
1. **ca-admin 默认没装 `redis-cli`**(`which redis-cli`=NOTFOUND)→ 内联/脚本调 redis-cli 静默 `command not found` → 空输出 → `wc -l`=0 → **误判"reach:grid=0/Redis 空"**。`apt-get install -y redis-tools` 装上(标准诊断工具,低风险)。
2. **Redis 真密码在 admin 进程环境 `/proc/PID/environ`,不是 `/etc/newworld/secrets.env` 的 `REDIS_PASSWORD`**(二者都 32 字符但**值不同**;secrets.env 那个 WRONGPASS)。systemd `Environment` 也没有(走 EnvironmentFile 但被覆盖)。
3. `/proc/PID/environ` 读要 `sudo cat`(重定向 `< /proc/...` 在 sudo 前执行,Permission denied);用 `sudo cat /proc/$PID/environ | tr '\0' '\n'`。
4. redis-cli `-a "$PW"` 对特殊字符密码易 WRONGPASS;用 `export REDISCLI_AUTH="$PW"` 更稳。

**正确姿势**(查 reach:grid 计数)：
```bash
PID=$(pgrep -f newworld-admin | head -1)
export REDISCLI_AUTH=$(sudo cat /proc/$PID/environ | tr '\0' '\n' | grep '^REDIS_PASSWORD=' | cut -d= -f2-)
redis-cli -h 172.34.1.128 PING                                   # 必先 PONG 确认鉴权,非 WRONGPASS
redis-cli -h 172.34.1.128 --scan --pattern 'reach:grid:*' | wc -l
```
★大 keyspace 上**多次 --scan 会超时**(每次全扫):单次 scan 落 /tmp 文件再 `wc`/`sed`/`grep` 复用,别重复 scan。

**铁律**：用工具读"0/空"先**验工具本身能连能读**(PING=PONG、admin app 日志证它在写 `wrote N entries to Redis`),别拿静默失败的工具反复读 0 还当真相([[feedback_verify_metric_source]] 的延伸:数据源工具也要先 fact-check)。关联 [[project_gfw_s_entry_execapi_poc_2026_06_22]]。

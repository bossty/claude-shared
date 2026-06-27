---
name: reference_lettuce_pipeline_command_timeout
description: Lettuce per-command timeout(spring.data.redis.timeout) 卡的是单命令完成而非总耗时；巨型 pipeline 塞 N 万条会让后段命令超时；治本是分批 add 降命令数（命令数=负载）
metadata: 
  node_type: memory
  type: reference
  originSessionId: d040d32b-2e98-4c95-acc0-220cd4d6d6b9
---

# Lettuce per-command timeout vs 巨型 pipeline（TagCategoryPoolBuildTask RCA 2026-05-31）

**症状**：`RedisCommandTimeoutException: ZADD. Command timed out after 3 second(s)`（`RedisPipelineException`），任务 7 天 59/1064 ≈ **5.6% flaky 失败**；graceful（指针不切、老池继续生效、5min 后自愈）→ 无用户可见 stale，但**随数据增长会恶化直至持续 stall**。

**根因（底层逻辑）**：`spring.data.redis.timeout=3000ms`（prod）是 **Lettuce per-command 超时**——卡每条命令的 future 完成、**不是方法总耗时**。`compute()` 把 ~340K 条 zAdd 塞进**单个 `executePipelined`**，Dragonfly 处理完整批要 ~3.3s（擦边）→ pipeline 后段命令的 future 超 3s → 抛超时。pipeline ≠ 1 RTT 耗时；**N 万条命令的服务端处理时间本身就可能 >3s**。5/26 "532 RTT→单 pipeline" 优化的盲区正在此。

**多源诊断**：① 代码（单 executePipelined 塞全量）+ 配置（timeout 3000ms）双证；② journalctl 7 天成败史（1005 成功 / 59 失败，且成功 elapsed ~3.3s 死贴线）锤定"擦边 flaky"而非"永久坏"——**不能凭代码臆断 stale，必查成败史**。

**治本（单 batch，零超时改动）**：ZADD 改 `opsForZSet().add(key, Set<TypedTuple>)` 按 5000/批（镜像既有 `GlobalFeedPoolService`）→ 命令数 **340K → ~535**，每条单 ZADD 几十 ms 远 <3s，跑**默认 3s 超时**余量充足 + 降 Dragonfly 负载。**命令数才是负载，提高超时只是"容忍霸占更久"治标**。实测 7/7 周期 0 失败、耗时 ≤1.5s（vs 旧 3.3s）。commit `6ec64ce8`。

**没做"独立 60s timeout template"的原因**：lombok 不 copy `@Qualifier`；admin 有 6 处字段名 `redis`/`redisTemplate` 的 StringRedisTemplate 注入，**加第 2 个 StringRedisTemplate/ConnectionFactory bean 会按类型歧义、按名匹配不上 → admin 启动失败**。要单独超时只能用任务内自管 factory（非 bean），但 batch 后已多余。

**验证铁律（踩坑）**：核 jar 是否含新代码**必须用 systemd ExecStart 实际 jar 路径**——`deploy-backend.sh` 的软链是 `<module>/deploys/current.jar`（不是 `<module>/current.jar`）；对不存在的路径跑 `unzip -p` 静默返空→`grep -c` 得 0，会**误判"修复没进 jar"**。正确：`sudo tr '\0' '\n' </proc/<MainPID>/cmdline | grep .jar` 拿真 jar，再 `unzip -p` + `strings`（strings 保留方法名，比 javap-from-stdin 可靠）。

关联 [[reference_prod_db_redis_host_19_174]]、[[project_p0p1_audit_hotfix_2026_05_26]]（5/26 executePipelined 多 key 原子切换同源）、[[reference_deploy_backend_no_pull]]（deploy 验证踩坑同类）。

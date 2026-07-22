---
name: project_dragonfly_selection_poc_2026_05_26
description: 生产 Dragonfly 选型依据(2026-05-26 POC):主业务负载2.22x-2.97x胜Redis+7硬gate全PASS+REPLICAOF零停机33s实证;反甜区=串行单条SET/Lua serial/HLL热key;无AOF故Owner接受5min RPO;隔离benchmark协议
metadata:
  type: project
---

生产 Dragonfly（现 ca-redis-master `172.34.1.128` 及 EU replica）的**选型决策依据**来自 2026-05-26~27 调研+POC sprint（动因=5/26 Redis BGSAVE COW + Lettuce 重连 + HikariPool 打满的 P0 雪崩）。未来任何「要不要换回 Redis/Valkey」「Dragonfly 某负载为何慢」的讨论先看本条，不必重跑调研。

**性能矩阵（r6i.2xlarge 8 vCPU，隔离 benchmark，Redis 7.4 / Valkey 8.1 / Dragonfly v1.38.1 三方）**：
- 5/10 主业务负载 Dragonfly 全胜 Redis **2.22x~2.97x**：Read 9:1 混读 2.43x（P999 −91%）、SADD pipeline 2.82x、ZADD 2.79x、ZADD+ZRANGE 混合 2.97x、HGET/HSET 2.22x；内存 per item 约 −38%。
- **反甜区（Dragonfly 反而更慢，设计上单条/热 key 不吃多核红利）**：串行单条 SET 0.60x、串行 Lua 0.83x、HLL 热 key PFADD 0.55x。当时揪出的业务前置=RecommendationTask 串行 SET 改 pipeline。**新代码写 Redis 热路径时避免「单热 key 高频单条命令」模式，尽量 pipeline/分散 key**。
- Pub/Sub 与 pipelined Lua 三方持平（客户端瓶颈）。

**持久化契约**：Dragonfly **不支持 AOF**（官方文档 body 明文，sidebar 有页 ≠ 已实现——三个 agent 同栽这坑）；生产走 fork-less snapshot（`*/5` 分钟，实测 <1s 无服务中断，无 COW 内存翻倍雪崩），Owner 拍板接受 **5min RPO**。`df_snapshot_format=false` 可产 Redis 兼容 RDB，双向可回滚。

**零停机迁移 SOP（Gate 8 真生产实证，将来任何 KV 主机迁移可复用）**：新机装好 → `REPLICAOF 旧master`（990MB 全量 33s，~200K keys/s）→ 持续追增量 → DBSIZE 对账 + 抽样 100 key → 滚动改各服务 systemd `DB_HOST`/`REDIS_HOST` → Lettuce 自动重连切流 → 旧机降冷备 7 天。

**benchmark 方法铁律（三次踩坑实证）**：①三方对比必单实例隔离跑——其余 KV `systemctl stop` + 被测 restart + FLUSHALL + drop_caches + warmup 30s，三 daemon 共存即不公平；②benchmark 工具命令必先单负载 dry-run 验证真跑目标命令——memtier 不指定 `--command` 时默认 SET/GET，曾把 ZSet 负载白跑 30 分钟；memtier 不支持 EVAL/PFADD/XADD/PUBLISH，须 redis-benchmark 或 redis-cli 循环替代；③Explore agent 报的用法统计数字必 lead 独立 grep 复核（曾虚高 24x~86x，import/注释/jar 全被算进去）。

相关：[[reference_redis_sharenativeconn_antipattern]]、[[reference_dragonfly_iowait_cosmetic]]、[[reference_redis_no_active_active_decision_chain]]。

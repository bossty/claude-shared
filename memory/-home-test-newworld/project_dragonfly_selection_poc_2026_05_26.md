---
name: project_dragonfly_selection_poc_2026_05_26
description: 生产 Dragonfly 选型依据(2026-05-26 POC):主业务负载2.22x-2.97x胜Redis+7硬gate全PASS+REPLICAOF零停机33s实证;反甜区=串行单条SET/Lua serial/HLL热key;无AOF故Owner接受5min RPO;隔离benchmark协议
metadata: 
  node_type: memory
  type: project
  originSessionId: cecd1632-dc2a-41d4-be8e-54da09a8d1c5
  modified: 2026-07-22T11:49:48.189Z
---

生产 Dragonfly（现 ca-redis-master `172.34.1.128` 及 EU replica）的**选型决策依据**来自 2026-05-26~27 调研+POC sprint（动因=5/26 Redis BGSAVE COW + Lettuce 重连 + HikariPool 打满的 P0 雪崩）。未来任何「要不要换回 Redis/Valkey」「Dragonfly 某负载为何慢」的讨论先看本条，不必重跑调研。

**性能矩阵（r6i.2xlarge 8 vCPU，隔离 benchmark，Redis 7.4 / Valkey 8.1 / Dragonfly v1.38.1 三方）**：
- 5/10 主业务负载 Dragonfly 全胜 Redis **2.22x~2.97x**：Read 9:1 混读 2.43x（P999 −91%）、SADD pipeline 2.82x、ZADD 2.79x、ZADD+ZRANGE 混合 2.97x、HGET/HSET 2.22x；内存 per item 约 −38%。
- **反甜区（Dragonfly 反而更慢，设计上单条/热 key 不吃多核红利）**：串行单条 SET 0.60x、串行 Lua 0.83x、HLL 热 key PFADD 0.55x。当时揪出的业务前置=RecommendationTask 串行 SET 改 pipeline。**新代码写 Redis 热路径时避免「单热 key 高频单条命令」模式，尽量 pipeline/分散 key**。
- Pub/Sub 与 pipelined Lua 三方持平（客户端瓶颈）。

**持久化契约**：Dragonfly **不支持 AOF**（官方文档 body 明文，sidebar 有页 ≠ 已实现——三个 agent 同栽这坑）；生产走 fork-less snapshot（`*/5` 分钟，实测 <1s 无服务中断，无 COW 内存翻倍雪崩），Owner 拍板接受 **5min RPO**。`df_snapshot_format=false` 可产 Redis 兼容 RDB，双向可回滚。

**零停机迁移 SOP（Gate 8 真生产实证，将来任何 KV 主机迁移可复用）**：新机装好 → `REPLICAOF 旧master`（990MB 全量 33s，~200K keys/s）→ 持续追增量 → DBSIZE 对账 + 抽样 100 key → 滚动改各服务 systemd `DB_HOST`/`REDIS_HOST` → Lettuce 自动重连切流 → 旧机降冷备 7 天。
- **★replica 不能带读做 resync（2026-06-21 .170 cutover 实测铁律）**：Dragonfly replica 在 full resync 期间**所有命令返 `LOADING`（连 `PING` 都是），不 serve stale**。故任何「正在被读的 replica」换主前必须先把读流量挪走——那次 EU replica `.184` 换主需 resync 5-6min LOADING，正解是先把 EU 读临时指到新主 `.170`（跨区）、腾空 `.184` 后台 resync、再切回，否则 EU 读整段中断。规划多机 cutover 时按「每台 replica 的 resync 窗口 = 该台读不可用窗口」排序。
- **★决策教训：先量收益再排 SOP。** 那次 `.128`(2vCPU) → `.170`(r6i.xlarge 4vCPU) 的 cutover 最终**整体作废、.170 已 terminate**——受控实验直接证伪了立项 premise（「2vCPU 快照饿死命令」：2 核 + 10 万 ops/s 写 + 快照下本地写吞吐不塌，48k→122k），且 Dragonfly 官方文档说明快照并行吃满所有核（share-nothing），「加核留空闲核」假设站不住；真实收益只是 EU snack 曝光每快照丢 ~14-16 条 ≈ **0.002% 统计误差、零用户影响**。**早期没把「收益 0.002%」摆在方案最前面权衡，就直接进 runbook + 蓝军 + 预约执行 = 教训**：高风险生产操作立项第一步是量化收益并对 premise 做受控实验证伪，不是先写迁移 SOP。详见 源档 `project_redis_master_upgrade_cutover_2026_06_21.md`（已于 BL-131 阶段 1 删除，取回 `git show 8c44739c6:claude-shared/memory/-home-test-newworld/project_redis_master_upgrade_cutover_2026_06_21.md`）。

**benchmark 方法铁律（三次踩坑实证）**：①三方对比必单实例隔离跑——其余 KV `systemctl stop` + 被测 restart + FLUSHALL + drop_caches + warmup 30s，三 daemon 共存即不公平；②benchmark 工具命令必先单负载 dry-run 验证真跑目标命令——memtier 不指定 `--command` 时默认 SET/GET，曾把 ZSet 负载白跑 30 分钟；memtier 不支持 EVAL/PFADD/XADD/PUBLISH，须 redis-benchmark 或 redis-cli 循环替代；③Explore agent 报的用法统计数字必 lead 独立 grep 复核（曾虚高 24x~86x，import/注释/jar 全被算进去）。

相关：[[reference_redis_sharenativeconn_antipattern]]、[[reference_dragonfly_iowait_cosmetic]]、[[reference_redis_no_active_active_decision_chain]]。

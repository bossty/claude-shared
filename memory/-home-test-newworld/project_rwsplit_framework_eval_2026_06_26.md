---
name: project_rwsplit_framework_eval_2026_06_26
description: 读写分离框架评估定案 — MySQL ShardingSphere 否决/Redis Lettuce ReadFrom PoC 按住观察(逃逸率触发);CA读写都主是命门
metadata:
  node_type: memory
  type: project
  originSessionId: 6eecae1c-95e0-4231-a84e-4ccc79979b6c
---

Owner 问"用业界标准读写分离 + 标准注入能否根治这些跨洋读护栏问题"。4 专家(MySQL/Redis/业界) + 蓝军 + lead prod 实证评估。全档 `docs/sprint/_archive/2026-06-26-rwsplit-framework-eval/`(SYNTHESIS+4 agent) + `docs/sprint/_archive/2026-06-26-redis-readfrom-poc/PRD.md`(v2 蓝军闭环)。承 [[project_crossocean_read_guardrail_2026_06_25]]。

**命门=CA 读写都在 master**(无 CA Redis replica；CA web 读写都打本地 .128)→ 读写分离在 CA 退化零收益,收益只在 EU(实测流量 CA 59%/EU 41%,EU 非少数但现状已正确路由,框架价值是防错非提速)。

**MySQL ShardingSphere=否决(本拓扑 actively wrong,非 defer)**：in-tx 路由(issue#14858 + PR#36477 默认回 PRIMARY)=`@Transactional` 内所有 SELECT 强制走主。本项目铁律"所有读包 readOnly 事务"→框架反而把**全部读路由到 master→EU 全跨洋,比现状更糟**;无 transactionalReadQueryStrategy 配置能同时满足 EU读从+RYW。+ 换 DataSource 毁 6 防御(slave独立池/L0/L2/M2/HikariCP指标/ArchUnit)。dynamic-datasource(@DS)同否决。→ **MySQL 维持 region-aware AbstractRoutingDataSource + 护栏(=业界标准 read-local-write-global,CA主从同体=Aurora Global primary 标准态非债)**。

**Redis Lettuce `ReadFrom.REPLICA_PREFERRED`=唯一对路抓手,但 PoC 按住观察(Owner 拍板)**：能根治双模板/@Qualifier 漏注那类(14 注入点→单模板驱动层自动路由);客户端层不碰 DataSource/L0/L2/slave池。**触发条件=现状护栏逃逸率证明纪律失效**(本 session 抓 3 泄漏=护栏有效信号,非失效),够了再启 PoC。

**PoC 关键约束(蓝军 v2 已闭环,启用时照 PRD)**：① **CA 读必落本地 master**——保证来自 per-region 拓扑配对(redis.replica.host),非 ReadFrom 魔法;`REPLICA_PREFERRED` 若 CA 拓扑误含远端=反向跨洋坑→须 per-region 拓扑(禁全局共享)+ L0 同款启动断言(只校验 replica 端点不校验 master 写端点)+ 运行时 metric + tcpdump 验收。② **force-master 全量=4 读**(SessionFeed:416/Monitor:613/JwtToken:123 已 RYW + **TwoLevelCache:214 scan** 蓝军新揪,evict 走从 lag 漏)+ 全写,保留 masterStringRedisTemplate。③ **pub/sub 保留独立 master 工厂**(机制非纪律;Dragonfly replica 静默忽略 SUBSCRIBE→缓存刷新 listener 全失效)。④ 静态拓扑 + jar 版本回滚(不用运行时开关)。

**实证真值(lead environ + redis-cli 等价)**：Redis master=172.34.1.128(ca-redis-master)、EU replica=172.33.3.184(eu-redis-slave)、CA 无 Redis replica。**Dragonfly eu-redis(.184) `ROLE`=slave**(Lettuce #5240 role:master 不复现→ReadFrom 路通)。`ReplicaRedisConfig` javadoc 原误把 MySQL IP(.222/.248)当 Redis 拓扑,已订正(commit on master 23f3d474)。

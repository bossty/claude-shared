---
name: project_eu_redis_separation_2026_06_14
description: "2026-06-14 EU Redis(Dragonfly)从eu-db-slave分离到独立eu-redis专机+保留策略+HK配置漂移清理,BSP专家团队"
metadata: 
  node_type: memory
  type: project
  originSessionId: df06f417-fb3f-4c81-8486-085852426538
---

**2026-06-14 夜 BSP 专家团队大工程**（owner 组团:ops/dba/dev/blue + lead 二查兜底；superstep 放开吵+蓝军挑刺,barrier lead 宣布 CLOSED+禁抢跑）。三大线全闭环。

## ① EU Redis/MySQL 分离（S1-S4 全 CLOSED）
- **动机**：eu-db-slave(m5.xlarge 16G) 同机跑 MySQL replica(buffer pool 8G)+Dragonfly(EU Redis 读副本 4G)→ available 仅 1G，违背 CLAUDE.md「MySQL/Dragonfly 分离」原则。
- **终态**：新建 **eu-redis `172.33.3.184`(i-0465886f2493bc79c, r6i.large, eu-central-1a, SG sg-00fd7639603fe37bf)** 跑 Dragonfly(replicaof ca-redis .128, snapshot_cron */5, maxmemory 8gb, bind 内网IP)。EU web×2 的 `REDIS_REPLICA_HOST` .248→172.33.3.184(写仍 REDIS_HOST=ca-redis .128，读写分离)。**eu-db-slave .248 Dragonfly 已 stop+disable 退役**(unit/data 留作回滚,后续 hygiene 删);eu-db-slave 现纯 MySQL replica。
- **读写分离接线**：app `replicaStringRedisTemplate`(读 REDIS_REPLICA_HOST)/`stringRedisTemplate`(写 REDIS_HOST)，MovieService/SidBloomService/SessionFeedService 等用。Spring @Value relaxed binding,repoint 无需改码。
- **实测**：EU 读落新机 p50 0.46ms、16766 ops/s、哨兵净延迟 ~160ms。**★停 .248 Dragonfly 后 eu-db-slave iowait 88%→0.82%、MemAvail 34%、N9E 内存告警自愈恢复**——坐实"88% iowait 是 Dragonfly 共址挤内存假象非真盘 I/O"(关联 [[reference_dragonfly_iowait_cosmetic]])。
- **修的 bug**：B1 BLOCKER SessionFeedService 5处 replica 裸调用无 try-catch→cutover 期返 200+error(commit 4cf69483,改返 503/降级);硬件维持 m5.xlarge(无瓶颈,dataset 33.54G≫pool 但命中99.974%,升 r6i 边际小)。

## ② 保留策略 + 健康自界限
- **rum_image_load**(前端图片加载 RUM 埋点,RumService 写)**无保留无限增长**(4M/天)→加 **7d** 清理;**redirect_trace**(S/P 跳转链路 beacon,RedirectTraceConsumer 写)30d→**15d**。两表占 EU 副本 33.54G 的 ~20G。
- **自限**:批删 `DELETE WHERE ts/created_at<阈 LIMIT 10000` 循环+sleep(防大事务卡复制;idx_ts 驱动);首清理 rum 删 34.7M/redirect 删 6.85M(redirect 之前**从没跑过**),EU lag 峰值 4-6s 安全。阈值集中 @Value 可配。
- **健康(可观测)**:`RetentionTableGaugeTask` emit `nw_retention_table_rows/bytes{table=}`(低基数2标签)→N9E rule 106 告警(rum>40M/redirect>30M=清理失效)。commit 链 20c1bfdf。
- **教训**:遥测/日志表必须"保留兜底自限+监控告警"双层,否则像 rum 无声涨到 5391万行没人知。

## ③ HK 退役 config 漂移清理（今晚反复主题）
HK web 2026-06-13 退役但多处配置遗留退役 HK IP(172.31.27.x)→重启 admin 触发"17bot Web实例异常"假警(非故障,17.rip 全程200)。清理:
- system_config `WEB_LAN_IPS`/`WEB_WAN_IPS`(退役HK→CA web×3)、`ORIGIN_UPSTREAM_HOST`(172.31.27.120→172.34.1.168 死配置,aws-s反代旧架构已废)。
- **WebHealthCheckTask 停用**(commit d72bb42f,@Scheduled 注释;Tunnel 模式只告警不管 DNS,N9E 已接管)→N9E 新增 rule 105 web-down(http_response :7777,scope ident=~ca-web|eu-web)替代。
- **isOriginHealthy 探针 :80→:7777**(commit 8aa42b93;:80 无 Host→guard.lua 000→探针永失效;fail-open=false 正确:false→🔴 不漏告警)。
- eu-db-slave categraf 误带 web http_response 探针(:7777)→删。scripts/docs HK 残留 → hygiene pass 待清。

## 方法论/坑（可复用）
- **BSP 团队交叉兜底真兑现**:dev 两次纠正 lead(WEB_LAN_IPS 置空会破 isOriginHealthy/fail-open 语义说反)、ops 救 maxmemory 4gb 隐患(余量160MB)、lead 二查抓 eu-db-slave 误触发+阈值笔误。每改先实证→barrier 二查→回滚弹药保活→才落。
- **N9E 告警规则**:克隆活规则 id13 INSERT...SELECT 只覆盖 name/note/rule_config/annotations/时间戳;rule_config 改用 `mysql --raw -N` 验(普通 -N 把 `\"` 转义致假损坏);告警建好必实测 PromQL 返空(不误触发);多消费者指标(WEB_LAN_IPS 被 WebHealthCheckTask+isOriginHealthy 共用)改前 grep 全引用面。
- **admin 单实例**3次部署(retention/WebHealthCheck停/isOriginHealthy修),symlink 指具体jar+deploys≤5版。
- 死主机/陈旧告警残留:`DELETE FROM alert_cur_event WHERE ...`(aws-db-poc/event 3732)。
- detached 批删 watcher:agent turn 结束≠删完,lead 独立二查(行数降/复制lag/master processlist)+多回程点防停滞。

关联 [[feedback_categraf_config_dir_globs_all]] [[reference_dragonfly_iowait_cosmetic]] [[feedback_ss_ipv6_mapped_assertion]] [[project_code_topology_realignment_2026_06_13]]。

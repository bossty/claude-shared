---
name: reference_dragonfly_iowait_cosmetic
description: ca-redis/Dragonfly 高iowait(90%+)是io_uring内核计账虚高cosmetic非真性能问题;判真I/O用write_bytes不用PSI
metadata: 
  node_type: memory
  type: reference
  originSessionId: df06f417-fb3f-4c81-8486-085852426538
---

**Dragonfly 高 iowait 是已知 cosmetic 现象，非性能问题**（2026-06-14 三 agent 查官方文档+内核+真机定论）。

ca-redis（Dragonfly r6i.large）N9E 显示 CPU/iowait ~100%，实为 **io_uring 内核计账虚高**：
- **官方立场**：io_uring 下"空闲 CPU 等网络包也被归 IOWAIT … completely harmless"（创始人 romange [issue #2270](https://github.com/dragonflydb/dragonfly/issues/2270)）；核心 chakaz 对 100% iowait "Working as intended"（[#2287](https://github.com/dragonflydb/dragonfly/issues/2287)）；v1.38 仍 "not a bug, just a curiosity"（[#7375](https://github.com/dragonflydb/dragonfly/issues/7375)）。同族 #2181/#2444/#2729。官方排障看 `INFO`/Prometheus 不看 OS iowait。
- **内核机理**：`man proc` 明写 iowait "not reliable"(idle 子类)；PostgreSQL in_iowait 修复进 6.5 内核反致"100% iowait"误报（[LWN 989272](https://lwn.net/Articles/989272/)）。`100−cpu_usage_idle` 把 iowait 当"CPU忙"是经典误区。
- **真机铁证**：iostat %util=0%、`/proc/<pid>/io` write_bytes=0/read_bytes=0 B/s、load 0.27、CPU usr+sys<7% 而 iowait≈91%；快照完全没开(rdb_save_count:0,dir 空)；Dragonfly 满载健康(10602 ops/s,275 连接,564万 keys,3.87/12GB)。

**★ 关键交叉校正**：理论上 PSI `/proc/pressure/io` 是真停顿干净信号，**但 io_uring 的等待也被 PSI 计账**——实测 ca-redis PSI io some avg10=90.98 也爆表。所以 **io_uring 机器上连 PSI 都不可信**。判真磁盘 I/O 一锤定音用 **字节级 `/proc/<pid>/io` write_bytes 速率 + iostat %util**，二者皆 0 = 无真 I/O。纠正"PSI 永远可信"惯性。

**处置（2026-06-14 owner 决策 B 已落地）**：Dragonfly 侧无需动。N9E 新增告警规则 **id=104 "System - CPU 负载比较高 (load_norm·iowait豁免)"**：`system_load_norm_1` >1.5/2.5/4 三档(sev3/2/1,inhibit,dur300s,notify_rule_ids=[1],ds=VM)，绕开 iowait 假象(当前最高 0.41 不误触发)。建表法=克隆活规则 id13(REDIS-MEM-HIGH)只覆盖 name/note/rule_config/annotations/时间戳,避免手列 40 列。判 Dragonfly 健康看 INFO ops/latency/mem 不看 OS iowait。/targets 显示仍 cosmetic(N9E 二进制硬编码 100−idle 改不了,owner 接受)。

**ca-redis 死配置已清（2026-06-14）**：systemd unit 去掉 `--replicaof 172.31.19.174:6379`(指已退役 HK 老 master)。运行态本就 role:master(cutover 时手工 REPLICAOF NO ONE 提升,unit 没同步)→只改 unit+daemon-reload **不重启**(Dragonfly 持久化关,重启=5.6M keys 全丢=雪崩),PID 2677 不变,备份 dragonfly.service.bak-2026-06-14。下次重启地雷拆除。机上无 redis-cli(取 INFO 用 RESP over TCP+AUTH)。
**EU slave lag 已查清(2026-06-14)**:master 侧 `slave0:...,lag=N` 在 Dragonfly 里是**字节积压(offset),不是秒**(Redis 是秒,Dragonfly 改了语义且 slave0 行不带 offset= 字段)。三证:EU slave `master_last_io_seconds_ago:0`(实时)+哨兵 key 净传播 191ms(5/5,且主要是跨洋 SET 往返,真复制<200ms)+slave_repl_offset 持续推进。644-1446 字节@11k ops/s=亚毫秒数据,EU replica 健康实时。**判 Dragonfly 复制新鲜度认 master_last_io_seconds_ago+哨兵实测,别套 Redis 的 lag=秒语义**。
**第二处死配置地雷已清(2026-06-14)**：eu-db-slave(.248) unit `--replicaof=172.31.19.174:6379`(死 HK)→改指活 ca-redis `172.34.1.128:6379`(daemon-reload 不重启,PID 45386 不变,备份 .bak-2026-06-14)。**关键:eu-db-slave 是 replica→改指活 master(.128)非删除**(删了重启会变独立 master 读分叉);ca-redis 是 master→删 replicaof。同类地雷不同修法。eu-db-slave Dragonfly 绑 172.33.8.248:6379 非 localhost,开了 --snapshot_cron=*/10 有快照。两节点 unit 现与运行态一致,cutover 遗留地雷全清。**重启后正确性已验(静态,owner 选不真重启)**：`systemctl show -p ExecStart --value` 的 argv[] 实证下次启动 ca-redis 无 replicaof(独立master)、eu-db-slave replicaof=172.34.1.128(活master);systemd-analyze verify 无报错。
**ca-redis 无持久化风险已根治(2026-06-14)**：原因实证=**非性能考虑**——Dragonfly 选型 sprint(docs/sprint/_archive/2026-05-26-dragonfly-research)的部署模板+install 脚本本就 `--snapshot_cron="*/5" --dbfilename=dump`(ops-explorer:`--cache_mode=false 要持久化语义`;gate4 实测 fork-less snapshot <1s 无中断;Redis 存 UV-HLL/Lua统计/JWT 非纯缓存,蓝军列丢失为 MAJOR)。eu-db-slave 继承了(*/10),**ca-redis 在终态B CA重建时漏带=provision 漂移**。另发现 8G 根盘对 12GB maxmemory 欠配(真约束之一)。
**修复(全程零重启)**：① EBS 根卷 vol-008d45487021a9f4a 在线扩 8G→50G(modify-volume→optimizing+growpart+xfs_growfs,XFS,PID 2677 不变);② runtime 热加 `CONFIG SET snapshot_cron "*/5 * * * *"`+`CONFIG SET dbfilename dump`(+OK,立即生效,snapshot_cron/dbfilename 均 CONFIG SET 可热改);③ durable 改 unit ExecStart 加同样 flag(备份 .bak2-snapshot-2026-06-14,daemon-reload 不重启,systemd argv 确认)。**验收**:手动 SAVE 3.89GB→2.6G/45s;cron */5 实测 17:15 准时触发(文件 mtime 更新),固定 dbfilename=dump 原地覆盖无堆积,磁盘稳 4.8G/46G。重启数据丢失窗口从"全丢"→"≤5min"。
**通用经验**:Dragonfly snapshot_cron/dbfilename 可 CONFIG SET 运行时热改(无需重启);dbfilename 默认 `dump-{timestamp}` 会堆积撑爆盘,小盘必设固定名 `dump`;DFS 压缩比~2.6G/3.89GB;判 cron 真触发看快照文件 mtime 不看易误解析的 INFO 字段。

关联 [[feedback_cgroup_oom_diagnosis]]、[[feedback_verify_metric_source]]（指标先验证源）。交接档 docs/sprint/2026-06-14-n9e-migration/SESSION-HANDOFF.md §4。

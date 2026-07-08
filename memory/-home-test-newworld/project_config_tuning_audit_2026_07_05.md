---
name: project-config-tuning-audit-2026-07-05
description: 全组件参数调优审计（6 agent 并行）+ P1 批次全落地 + 两移交项定案（Tomcat 饱和真因=ChannelSaturationTask 全库 SCAN）
metadata: 
  node_type: memory
  type: project
  originSessionId: f7df67bc-8bb4-4d3c-a31f-ead18e787961
---

2026-07-05 全组件（MySQL/Dragonfly/Spring-JVM/OpenResty/cloudflared/内核）参数调优审计 + 执行。报告与执行日志全在 `docs/sprint/2026-07-05-config-tuning-audit/`（SUMMARY.md / ADDENDUM-missing-mechanisms.md / EXECUTION-LOG.md + 6 分报告 + exposure-euweb.md + tomcat-saturation-rca.md）。

**已执行（Owner 放行，证据在 EXECUTION-LOG.md）**：binlog 事务压缩 ON（zstd，**非持久**，观察一周后需 SET PERSIST，基线 mysql-bin.001046）；Dragonfly maxmemory 12G→10G + 收敛重启（旧 replicaof 退役 HK IP 根除，unit 快照 cron 生效，重启影响=每 web 节点约 1 条请求级超时）；ca-redis overcommit=1+max_map_count 持久化；MySQL redo 512M→3G（SET PERSIST）；nginx worker_rlimit_nofile 65535×7 节点；web×6 JVM flag 统一（三件套 GC 日志/HeapDump/ExitOnOOM，EU 堆 6→8G）；cloudflared 收敛 2026.6.1（web×6+monitor，admin 留 apt 2026.6.0）。N9E 规则 13 REDIS-MEM-HIGH 是比例式，maxmemory 改动自适应无需改。

**★Tomcat 800 线程饱和定案（推翻交叉假设的教训）**：主审计曾拼「vid_metadata 65s 慢查询拖 master→CA 饱和」假设，专项 RCA 三反证证伪（频率 30min vs 日一次 / 时间窗差 24h / master threads_running 全程平直）。**真因=admin `ChannelSaturationTask` 每 30 分钟全量 SCAN 12.46M 键的 CA Dragonfly**，阻塞 4 台 CA web Redis 调用 5–6 秒（同刻触顶最多 3 台非"4台同时"；近 24h **每个 :00/:30 边界 settings 延迟≥5s 无一例外**=持续用户可感卡顿，代码注释 160-163 行开发者已自认），高流量时刻线程按 Little 定律堆到 800；EU 读本地 replica 免疫。**修法=活跃渠道改 SADD 索引集合去 SCAN（与 6356f6cd KEYS 大锤同族反模式），属代码层 P1 待做**。65s 查询真实但无关（VidAliasMergeTask 日 01:00，idx 全扫 22M 行，汇总表/下沉离线，P2）。★教训：跨报告交叉假设必须时间戳对齐定案才能当根因。

**eu-web 暴露面疑点解除**：53.5 万溢出+3.8 万 syncookie=06-16 一次性 EU 负载突发打满 nginx :80 backlog 511（dmesg 金标「SYN flooding on port :80」），非攻击非进行时（计数器冻结实证）。ca-admin 89.5 万溢出=零 syncookie=纯 accept 队列容量（:8888/:9999 backlog=100），非安全问题。残留：全 fleet :22 对 0.0.0.0/0 开放建议收敛（Owner 决策）；06-16 SG 变更史需 CloudTrail 高权限核。

**★★快照尖峰终局（07-06，四次修正后根治）**：去 SCAN 修复正确（已合 master `11078abc`）但没消尖峰；真根因逐层实测=Dragonfly 快照→r6i.large 实例 EBS 带宽 81MB/s 打满→升 xlarge×2 后仍 6s（写 152MB/s=新上限 97%，证明行为非容量）→**最终=dfs 快照格式每 shard 并行写打满盘+全部 proactor，CA unit 加 `--df_snapshot_format=false`（RDB 单流，EU 一直在用）一个 flag 根治：settings 尖峰 6s→0.125/0.395s（连续两边界）**。执行记录：EU+CA 均升 r6i.xlarge（窗口 2min/1m45s，关机快照保数据，CA 窗口 4 节点共 3.8 万请求错误如实记录）；EU 非 EIP，resize 换公网 IP 已更 ~/.ssh/config（63.178.242.55）；EU snapshot_cron 重启自然收敛 */5→*/30（unit 值，P2-9 顺带治）；N9E 13/123/124 静默/恢复闭环；CA unit 备份 dragonfly.service.bak-fmt-20260706。Phase 2（save-on-replica）不再需要。runbook v2（蓝军 7 条全吸收）+证据=RUNBOOK-dragonfly-scaling.md / RESIZE-EVIDENCE.log。★教训：①高置信 RCA 必须逐层现场剖面（mpstat/iostat/线程级）复核再修，本案四次修正每次都靠下一层实测推翻上层推断；②便宜实验（flag）应先于花钱升配；③pkill/pgrep -f 自匹配与 ssh heredoc 两坑再犯；④升配非白买（32G 内存墙推远+4 核跑道，500 万 DAU 本来要买）。

**P2 批次落地（07-06 晚，Owner 授权峰窗 --force-peak）**：批 A=web×6 滚动一趟四件（ActorService replica 读降级修复 TDD 合 master `c98913ef`、Hikari 收敛读 30/写 15、MemoryMax 11G、ca-web-02 紧凑对象头灰度）+批 B=data accept 队列 1024+ExplicitGCInvokesConcurrent（JAVA_TOOL_OPTIONS 注入，jcmd 实证）+批 C=buffer pool 22G 在线收缩（命中率 99.99% 不变、宿主 avail→5G）；同晚早前已做=BBR+16M 发送缓冲（ca-mysql-master）、EU redis 绑 EIP 18.157.143.100、nginx 五项微调×6（keepalive 95s 治 cloudflared 竞态/:80 backlog 4096/gzip 细化/日志缓冲/server_tokens off）。执行清单+记录=NEXT-WINDOW-CHECKLIST.md。★data 的 Tomcat 参数用 SERVER_TOMCAT_ACCEPTCOUNT env 松绑定免改 jar；JAVA_TOOL_OPTIONS 不显示于 ps args，验证用 journal "Picked up"+jcmd VM.flags。

**批 D 已执行（07-07 15:39-15:42 HKT，Owner"现在执行"）**：CA master skip_name_resolve=ON（Aborted_connects=0 零副作用，授权表零 hostname 前置生效）；EU replica relay_log_recovery=ON+buffer 10G；全站写窗口~18s 瞬态 web 20 条（写路径：事务回滚/JDBC commit/PV 统计失败）+admin 137 条，窗口后零新错、健康 200 恢复；★**CA master 重启把非持久的 binlog 压缩回退，D2 已立即 SET GLOBAL 重开确认=1**。**紧凑对象头全 fleet 铺开（07-07，6/6 jcmd 确认 UseCompactObjectHeaders=true）**：单节点 A/B 收益测不出（堆流量波动日对日 2.6×/跨节点 46% >> 预期 10-22%），但 flag 免费+6h 零故障+随 DAU 放大，Owner 拍板铺开。**binlog 压缩实测 68%**（4.02M 事务 9.27→2.96GB，binlog 日体积 4.6→1.5GB/天=降 67%，复制 0 延迟）。

**★★时区教训（本会话踩，记牢）**：本地 dev 机（34.227.205.17）是**美东 EDT**，生产服务器+中国用户是**HKT，差 8 小时**。判断"流量窗口/峰窗/深夜"必须用 HKT（`TZ=Asia/Hong_Kong date` 或看服务器），**禁用本地 `date`**——本会话据本地机 03:xx 误判"深夜低谷"实为中国下午 15:xx，且据本地时区设的会话级 cron 时间全错（批 D cron 本地 05:55=HKT 17:55 傍晚，已删）。会话级 cron 还需 REPL 空闲才触发（交互中不触发），排维护窗定时不可靠，宜手动或服务器 crontab。

**binlog 压缩已固化（07-07 提前，Owner"现在固化"）**：`SET PERSIST binlog_transaction_compression=ON`，双实证=persisted_variables=ON + mysqld-auto.cnf 落盘 `"binlog_transaction_compression":{"Value":"ON"}`；重启不再回退，"批 D 重启要手动重开"防坑作废。config-tuning sprint 全部落地收官（68% 压缩率：binlog 4.6→1.5GB/天、复制 0 延迟）。

**待办剩（非本 sprint 主线，机会性）**：A5 字符串去重（读 GC 日志 dedup 段）；A3 虚拟线程（Hikari 收敛跑稳后压测）；A4 S3 快照/A6 request_id/A7 ACL=P3；CA `background_snapshotting=true` 与 EU 差异（非阻塞观察项）。新发现=CA web exec.conf 缺 --app.scheduling.enabled=false（两地行为差异待查 web 有无 @Scheduled）/ca-web-04 journald 无日志文件/base unit 残留退役 HK IP/EU cloudflared 三 unit 二进制路径不一致（a=/usr/bin, c,p=/usr/local/bin，已都升级但路径未标准化）。

★方法论：①「缺失机制」反向审计要单独做且候选先验证是否真缺失（8 候选实测已存在避免误报）；②pgrep -f 'nginx: worker' 会自匹配检查命令=假阳性；③web 日志在 /var/log/newworld-web.log（StandardOutput=append），journalctl -u 查不到应用错误；④VM 指标 ident 是 ca-redis/eu-redis 非主机名；⑤cloudflared 升级验证用 /proc/PID/exe 尺寸最可靠（PATH 有多份二进制会误报版本）。

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

**待办**：P2 清单（SUMMARY §三）+ 缺失机制 A2 紧凑对象头/A3 虚拟线程(前置=修 SCAN+Hikari 收敛)/A4 Dragonfly S3 快照/A5 字符串去重（ADDENDUM）；新发现=CA web exec.conf 缺 --app.scheduling.enabled=false（两地行为差异待查 web 有无 @Scheduled）/ca-web-04 journald 无日志文件/base unit 残留退役 HK IP/EU cloudflared 三 unit 二进制路径不一致（a=/usr/bin, c,p=/usr/local/bin，已都升级但路径未标准化）。

★方法论：①「缺失机制」反向审计要单独做且候选先验证是否真缺失（8 候选实测已存在避免误报）；②pgrep -f 'nginx: worker' 会自匹配检查命令=假阳性；③web 日志在 /var/log/newworld-web.log（StandardOutput=append），journalctl -u 查不到应用错误；④VM 指标 ident 是 ca-redis/eu-redis 非主机名；⑤cloudflared 升级验证用 /proc/PID/exe 尺寸最可靠（PATH 有多份二进制会误报版本）。

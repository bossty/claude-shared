---
name: reference_localbox_freeze_oomd_mysql_repair_2026_06_21
description: 本地 EC2 测试箱 6/21 内存耗尽假死 RCA + 启用 systemd-oomd + 顺带修好被中断的 MySQL 8.0→8.4 升级
metadata: 
  node_type: memory
  type: reference
  originSessionId: 843d7b10-e033-4dbb-a425-d3d7335b1d67
---

本地开发箱(ip-172-31-20-251 / 34.227.205.17,Ubuntu 24.04)2026-06-21 卡死排查与加固。

**RCA(卡死原因)**:~16:43 内存耗尽 + 4GB 小 swap 抖动(thrashing)→ 系统假死,17:03 Owner 手动重启恢复。证据:syslog 最后一条真实日志=16:43:16 `systemd-resolved: Under memory pressure, flushing caches`,之后到 17:04 开机完全静默;sar 16:40 采样 swap 已用 49%、%commit 111%、进程数 ~1228(5/31 起连续 21 天累积);16:40→16:43 三分钟内某后台进程暴涨。**内核 OOM-killer 未触发、systemd-oomd 当时未装** → 无人自救 → 全冻。直前无 Owner 手动命令(仅 cron),最可能元凶=浏览器自动化(MCP chrome-devtools/playwright + node)进程堆积。**本箱无 atop/psacct 故无法铁证具体 PID**(建议装 atop 留进程级历史)。

**加固=启用 systemd-oomd**(原缺,Ubuntu 24.04 拆成独立包):`apt install systemd-oomd` + `enable --now`。给 `user.slice` 加 drop-in `/etc/systemd/system/user.slice.d/50-oomd.conf`(`ManagedOOMMemoryPressure=kill`+`ManagedOOMSwap=kill`),因浏览器/node 跑在 SSH 会话 scope 即 user.slice 下(user@1000.service 默认已开但只覆盖 --user 单元)。`oomctl` 实证:SwapUsedLimit 90% / MemPressure 60%·20s / 监控 /user.slice。下次暴涨会杀压力最大 cgroup 而非整机冻。注:`oomctl` 刚启动会 dbus 超时,`systemctl restart systemd-oomd` 后正常。

**顺带踩坑:apt 被中断的 MySQL 8.0→8.4 升级卡死**(dpkg --configure -a 失败)。三连环 conffile/alternatives 问题,逐个修:① mysql-common postinst 缺 `/etc/mysql/my.cnf.fallback`(只剩 .dpkg-dist);② server postinst 缺 `/etc/mysql/mysql.cnf`;两处 update-alternatives 校验路径不存在即 fail。**修法=让 fallback 与 mysql.cnf 内容都=用户自定义 my.cnf**(441B:datadir=/var/lib/mysql、bind 127.0.0.1、sql_mode、utf8mb4;原 my.cnf 不 include conf.d 是独立配置),保证 alternatives 选哪个有效配置都不变。结果:`/etc/mysql/my.cnf` 现为符号链→`/etc/alternatives/my.cnf`→`/etc/mysql/mysql.cnf`(=自定义)。`mysqld --validate-config` exit 0、服务未重启全程在线。**备份在 `/etc/mysql.bak-20260621-171836` + my.cnf.bak**。残留 `rc mysql-server-8.0` 无害。**后续动 MySQL 配置认准这条链,别以为 my.cnf 是普通文件。**

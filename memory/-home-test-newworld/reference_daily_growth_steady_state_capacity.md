---
name: daily-growth-steady-state-capacity
description: 每日增长型产物(binlog/备份/日志)上线或调参必算稳态占用对照盘容量;运行值vs持久化值diff揪未落档变更
metadata:
  type: reference
---

**每日增长型产物(binlog / 备份 / 滚动日志)上线或调保留参数时,必须算稳态占用(速率 × 保留窗,或 份数 × 单份大小)对照盘容量——当前占用不代表终态,爬坡期的磁盘水位会持续上涨到稳态才停。**

2026-07-22 eu-db-slave(116G 盘)磁盘 80% 告警实例:两个增长源都在爬坡、都没人算过稳态——①binlog 保留被临时 `SET GLOBAL` 从 3 天调到 7 天,ROW 格式 + `log_replica_updates=ON` 实测 4.5G/天,稳态 31G(告警时才 12.5G,还要涨 19G);②BL-30 备份脚本 `RETENTION_DAYS=30`,上线第 13 天(14G),稳态 30 份 33G 还要涨 19G。61G 数据 + 31G + 33G > 116G,必然爆盘;master 同数据不告警只因盘是 193G。

**Why:** 告警触发在爬坡途中,只看当前 df 会把"还要涨 38G"误判成"稳态 81% 勉强能活"。

**How to apply:** ①处置磁盘告警时对每个增长目录先问"它的稳态是多少",用(文件数×单个大小×保留窗/已积累天数)外推;②给备份/日志类脚本设保留参数时,PR 里写明稳态占用与盘容量的比值;③本地与异地(R2)留存禁共用同一保留变量——本地是快速恢复缓存可以短,异地是真留存(本次已拆 `LOCAL_RETENTION_DAYS=7` / `R2_RETENTION_DAYS=30`);④判「运行配置是否被人临时改过没落档」:diff `SHOW VARIABLES` 运行值 vs `mysqld-auto.cnf` 持久化值 vs /etc 配置文件——三者不一致 = 有未落档的 `SET GLOBAL`,重启会静默回落。与 [[feedback_verify_live_flag_value_not_code_default]] 同向:生产真值 > 代码/配置文件默认。

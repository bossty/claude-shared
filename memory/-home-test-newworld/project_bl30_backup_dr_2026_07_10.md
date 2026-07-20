---
name: project_bl30_backup_dr_2026_07_10
description: BL-30 生产备份修复+DR 演练收口——核心档备份体系建成红绿双验，5 轮 RTO 演练收 4 个真坑，已合 master ed48119f
metadata: 
  node_type: memory
  type: project
  originSessionId: 385d27d4-973f-4642-be34-22ed2c860c5f
---

BL-30（生产 99 天无有效备份 P0）2026-07-10 第二会话收口。分支 `fix/backup-source-replica` 已推 origin（尾 commit `edca85c4`），**已合 master `ed48119f`（Owner 2026-07-10 授权，vf 每日全备），分支与 worktree 已按安全协议清理**。

已建成（全部实测有证据，见 docs/DR_RUNBOOK.md + docs/sprint/_archive/2026-07-10-bl30-dr-drill/SESSION-STATE.md）：
- eu-mysql-slave 每日 12:30 HKT root cron 核心档备份，两段式 dump（结构全对象+数据段黑名单排除），七道哨兵 fail-safe，21 用例红绿。
- 排除清单 fact-check **推翻两处表名推断**：vid_metadata 可排除（跨域 UV 滚动工作表 7 天自愈）；vid_alias_log（cluster_root 唯一落库热路径直读）与 visitor_fingerprint（first-touch 归因唯一持久源，Redis 源 7d TTL 不可回溯）必须备份。核心档实测 0.98GiB/dump 143s/replica lag=0。
- 监控闭环：status.prom→categraf input.exec→N9E 规则 139/140（139 已真实红绿验：触发→TG 送达→自动恢复）。
- buyvm-db 旧死库 cron 已注释停用；R2 backup/mysql/ 7 份死库对象已清；只留最新有效备份。

RTO 演练 5 轮收的坑（全进 DR_RUNBOOK §4，防复发哨兵在位）：
1. replica dump 默认带 GTID_PURGED → 还原 ERROR 3546 被拒（修=--set-gtid-purged=OFF+哨兵 3c）。
2. 还原默认参数 700 行/秒（128MB 缓冲池+UUID 主键随机插入），调优后 9385 行/秒。
3. 还原被 binlog 双写爆盘 errno 28（修=会话 sql_log_bin=0，磁盘预算≥1.5×）。
4. 演练机 /usr/bin/grep 实为 **ugrep 7.5.0，会把 500KB 单行 INSERT 截成 2KB 碎片**——管道过滤 dump 必用 awk。
RTO：全量保守上界≈2h（89min 到 87% 实测外推）；采样验证（滤 vf）206s 逐表对账全绿。

工程坑：本分支曾落后 master 带旧 gate0，commit 两次夹带共享 memory（--only 也拦不住 hook 的 git add），修法=merge master 使 BL-37 拆除生效；见 [[feedback_memory_commit_discipline]]、[[feedback_gate_redgreen_and_failsafe_direction]]。

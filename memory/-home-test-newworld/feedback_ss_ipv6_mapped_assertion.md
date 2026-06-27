---
name: feedback-ss-ipv6-mapped-assertion
description: "ss/netstat 连接断言匹配 IPv6-mapped ::ffff:IP 格式坑：grep 'IP:port' 漏匹配致假故障"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 64b5f5d1-9590-4971-9f5b-8d2e351a83eb
---

cutover/部署脚本里用 `ss -tn | grep 'IP:port'` 断言"真连上了 master"时，**Linux 双栈监听下连接常以 IPv6-mapped 格式出现** `[::ffff:172.34.1.222]:3306`——IP 和端口间多了 `]`，朴素 `grep '172.34.1.222:3306'` **匹配不上 → 假故障**（连接其实建好了，断言误判没连）。

**Why**：2026-06-12/13 Phase D cutover C9 s6-helper 第一次在 aws-data **F1 fail-fast halt 就是这个假故障**——ss 断言没匹配，但 CA master 侧 processlist 实证 aws-data 已 50+ 连接 CA、0 连 HK，repoint 早成功。配置对≠连接真切的反面：连接真切了，但断言写法读不到。和 ss 真连断言（fullcut-5xx 教训）同源，是它的格式陷阱续集。lead 修于 commit e38b5f56（s6 line 169 `grep -Ec '..[]:]+3306'` 容忍 `]`）。

**How to apply**：
1. ss 连接断言 grep 要**容忍 IPv6-mapped**：用 `grep -Ec '[]:.]+:?3306'` 之类容忍 `[::ffff:IP]:port` 的 `]`，或直接 `grep -F ':3306' | grep -F '172.34.1.222'`（IP 和 port 分开各 grep），别写死 `IP:port` 连排。
2. ★**连接真伪的权威源是 master 侧 processlist**（`SELECT host,COUNT(*) FROM information_schema.processlist GROUP BY host`），不是 client 侧 ss grep——多源 cross-check：ss 假红时去 master 数连接，按源 host 聚合一眼看清谁连上了。
3. 诊断 fail-fast halt 先怀疑**断言写法**再怀疑真故障（尤其格式类：IPv6-mapped、`Replica_SQL_Running_State` 误匹配[[feedback_verify_not_recall]]、grep 锚点）。

相关：[[project_phase_d_incident_and_checkpointed_runbook_2026_06_13]]、[[feedback_master_cutover_incident]]、[[feedback_long_task_no_stall_sop]]。

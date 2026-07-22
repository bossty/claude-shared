---
name: reference_tmpfs_leak_starves_playwright_pool
description: 采集任务集体冻结数小时先查 /tmp（tmpfs）是否被泄漏的 chromium profile / HLS 临时文件占满——共享内存不足致浏览器断连、实例重建同样失败、池容量单调递减归零，全程只有一行 log.error 无告警
metadata:
  type: reference
---

2026-06-17 实事故：除 cableav 外**全部每小时 Playwright 采集源同时冻结约 15.5 小时**，近 3 小时零任务触发，DB 时区已核（`@@global.time_zone=+08:00`，非"采平"假象）。

**真因果链（实代码 + jstack + journal + /tmp 四源闭环）**：
1. `/tmp` 是 7.8G tmpfs，被**泄漏的临时文件**占到 75%：`playwright_chromiumdev_profile-*`（9 个 / 509M，浏览器异常退出未清）+ `hanime1-mp4-*` HLS 下载临时文件（1.5G+，下载失败或完成后未清）+ cache 包 + 遗留 jar。
2. chromium 拿不到共享内存 → journal 报 `TargetClosedError` + `Less than 64MB of free space in temporary directory for shared memory files: 0` → 浏览器断开连接。
3. 归还实例时走重建分支 `Playwright.create()`，**同样因 /tmp 满 launch 失败**，代码只 `log.error("实例重建失败，池容量减少")` 无补偿、无告警（journal 实测断开 3 次 / 重建成功 0 次 / 重建失败 3 次）。
4. 生产 `crawler.playwright-pool-size=1`（覆盖了源码默认 3）→ **一次重建失败池就归 0**，此后所有采集永久排队。

**判别与铁律**：
- 采集集体静默停摆先 `df -h /tmp` + `ls /tmp | wc -l`，不要先怀疑源站或调度器——症状（零入库）与源站封禁完全一样。
- **池容量单调递减而无恢复上限 = 结构性不可逆**：任何"重建失败只记 error"的池实现都必须有容量告警或 fail-fast，否则故障从可恢复退化成永久。
- 生产覆盖值（pool-size=1）会把"偶发一次失败"放大成"整池死亡"，评估重试/池化逻辑必按**生产真实配置**推演，别按源码默认值。
- ⚠️ **初版 RCA 误判为「finally 漏归还致实例泄漏」，被蓝军 BLOCKER 证伪**（10 处 `pool.take()` 均在 finally 调 `returnInstance()`）。"资源耗尽"最容易被脑补成"泄漏"，必须逐个调用点核 finally 再下结论——参见 [[feedback_audit_methodology]]。

关联：[[feedback_long_task_no_stall_sop]]、[[reference_alert_rule_series_existence_check]]（"零产出恰是要监控的故障态"同型）。

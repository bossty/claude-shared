---
name: feedback-long-task-no-stall-sop
description: "多 agent / 长后台任务防\"完工了 lead 不知道导致停滞\"的唤醒 SOP"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 64b5f5d1-9590-4971-9f5b-8d2e351a83eb
---

Owner 多次强调（2026-06-09 整晚 region 任务）：**绝不能出现"任务实际完工了但 lead 无法得知，导致进度停滞"**。

**Why**：根因是「**agent/脚本完工 ≠ 它启动的工作完工**」——子 agent `nohup` 出去的 detached 进程、或脚本里 `(...) &` 嵌套 backgrounding 的子 shell，会脱离被 harness 追踪的单元，没人盯 → 卡死无人知（早期一次 9 小时导入 detached 卡死即此）。harness 只在三种事件 re-invoke：①`Bash run_in_background` 任务**进程 exit** 发 `<task-notification>`；②teammate(子 agent) 完成/`idle_notification`；③user 消息。这些都不触发 = 静默停滞。

**How to apply**（airtight 防停滞，已验证有效）：
1. **等条件类**（等 warm / 等 verdict / 等远程任务）→ 用 **独立的** `Bash run_in_background` 跑 `until <真完成条件> || 进程死 || $SECONDS>超时; do sleep 20; done`，条件满足才 exit → harness 唤醒。把"外部不可追踪事件"转成"harness 可追踪任务"。
2. **必须独立、禁嵌套 backgrounding**：`nohup gate & ; ( watcher ) &` 写在同一个 run_in_background 里 → 外层一结束，没 nohup 的 watcher 子 shell 被 SIGHUP 杀死 = 假死。watcher 要**自己**就是一个 run_in_background 任务（2026-06-10 踩过：嵌套 watcher 被孤儿杀，靠 cron 兜底才没停）。
3. **watcher 必带超时**（`$SECONDS>1800` 则 kill 被等的进程），否则被等的 gate SSH 挂死→watcher 死等→停滞。
4. **整晚不间断骨干 = `CronCreate` 周期触发**（如每 20min `7,27,47 * * * *`），**外部调度器自动重复、不依赖我每次 re-arm**——这是 `ScheduleWakeup`(单发) 解决不了的："单发响完就断"。cron prompt 里写死：检查→推进→若已稳定只做轻量 liveness→自己不必 re-arm。⚠️ CronCreate `durable:true` 可能不生效(返 session-only)，仍绑当前会话存活；整会话进程被杀则全部机制不存活（工具层硬限）。
5. **长任务别 detach 后就返回**：脚本 `wait $PID` 陪跑到底，或上面的 until-watcher。
6. 三层并用最稳：**cron 骨干（每 20min）+ 独立 watcher（快路径，完工即知）+ ScheduleWakeup（单发兜底）**，交集 = 不存在"完工了不知道"的窗口。
7. **跨进程重启的多步 ops（如 MySQL `CLONE INSTANCE` 重建 replica）禁 launch-完-就-idle**（2026-06-13 Phase D CA CLONE 教训）：`bash multi-step.sh & run_in_background` 后 agent turn 结束，**后台父 bash 在物理拷贝 Completed 后、收尾步（挂 replica/清 cloner）前死掉** → DB drift 成脱机半成品快照、需 lead 兜底跑完。这不是 detached 子进程问题，是**被追踪的 background 父进程本身在 turn 结束时被杀**。正解：这类跨重启多步操作**要么前台 `wait`/守到最后一步、要么 background 必带「完成断言（验最终态 IO/SQL=Yes+目标 errant 已清）+ until-watcher 自唤醒」**——脚本"启动了"≠"跑完了"，完成判据必须锚最终拓扑态不是进程退出码。

相关：[[feedback_verify_not_recall]]、[[project_region_p1_sprint_2026_06_08]]。官方机制依据：Subagents 完成自动回投摘要；Bash run_in_background exit 通知；hooks(SubagentStop/Stop) 进程内不跨会话；`/loop`、`/schedule` 为长任务定期检查设计。

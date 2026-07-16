---
name: reference_nolog_codepath_validate_via_state_key_trajectory
description: 冷却/短路/跳过类修复在生产常无专属日志——用状态 key(fail-count 等)分布轨迹做行为验证,不是 grep 日志;wiring 用 key 格式与读侧逐字对齐证明
metadata:
  type: reference
---

**触发**：改了一段「命中某条件就 skip/短路/冷却/提前 return」的代码，要在生产验证它真生效，但发现 journalctl grep 不到「跳过了 X」——因为命中路径只做 `counter++ + continue`、不打日志。

## 生产验证三层（BL-71 FreshnessTrickle 冷却实例，方案B）

被修的逻辑：dedup 时 `existing==null && isCoolingDown(fail-count>=maxAttempts)` → skip 重采。命中冷却**不打日志**（只 `movieSkipped++`），run 汇总也不印 movieSkipped → 无专属 grep 靶。

1. **wiring 层（key 格式对齐）**：命中路径读的状态 key（`crawler:fail-count:<source>:<mn>`）若在生产 Redis 已大量存在（本例 2220 个）且格式与代码读侧**逐字一致**，就证明读侧必命中。**这是最强的「接对了」证据**，比任何日志都硬。派 subagent 扫 key + MGET 取值分布（Dragonfly 的 EVAL 跨未声明 key 会报 undeclared，改客户端 SCAN + 批量 MGET）。

2. **靶心存在（分布快照）**：分桶统计 key 值，找出「已达阈值 = 现在会被短路」的那批。本例 val>=3 只有 4 个、全 supjav（值 4/52/**55/56**）——**远超 maxAttempts=3 本身就是 bug 化石**：supjav 走 `FreshnessTrickle.run` 的**无-marker 4 参重载**（不传 markDead），旧代码「达阈值才 `redis.delete(key)`」的分支挂在 `movieDeadMarker.accept()` 成功之后 → marker 为空 → delete 分支**从不执行** → 计数无限累加到 56。这类「用了 marker-less 重载的源，失败计数 key 永不清零」是隐蔽 bug，值 >> 阈值即其指纹。

3. **行为层（before/after 轨迹，看 runaway 而非看 skip）**：跳过无日志 → 改为观测**副作用的缺席**。判据 = 部署后跨 N 轮定时任务快照同一分布，看 `MAX` / `count>=阈值+2` 是否**冻结**（fix 生效：新失败达阈值即被 gate、不能再爬升；只有 fix 前的化石 key 有高值）vs 继续 runaway 爬升（fix 失效）。本例两轮后 `MAX=56/count>=5=3/4 遗留逐个未增` 与基线完全一致 = 无 runaway。

## 局限（必诚实报）
此法证「无 runaway + 化石冻结」，**不等于抓到一次现行**（某 key 刚跨过阈值→下轮被跳的实时证据）。抓现行要么等更长自然窗口（概率性、按小时），要么受控注入——但**冷却嵌在 listing-dedup 路径、无法干净注入受控番号 + 无跳过日志** → 受控测试也难观测。故结论落「逻辑单测已证 + wiring 已证 + 无 runaway」，别吹「已抓到跳过」。相关：[[reference_alert_rule_series_existence_check]]（零值/不触发态的监控同理反直觉）、[[feedback_gate_redgreen_and_failsafe_direction]]。

## 附带坑
后台观测器脚本用 `date -d "today HH:MM"` 定时，**跑在哪台机就用哪台的 TZ**：本地 EC2 是 EDT、定时任务在 ca-admin 按 HKT（差 12h）→ 我按 HKT 写 20:13 却被解释成 20:13 EDT = 次日 08:13 HKT，`sleep 45940`(~12.7h) 野进程。跨时区定时必显式 `TZ=Asia/Hong_Kong date -d ...` 或直接算 epoch。见 [[feedback_bash_timeout_does_not_kill_stray_processes]]。

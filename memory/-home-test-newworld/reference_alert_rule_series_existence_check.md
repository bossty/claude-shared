---
name: reference_alert_rule_series_existence_check
description: "给告警规则加 source/label 正则前，必先用 count by(label)(<metric>) 验证目标 series 在 VM 里真实存在——counter 的 series 常是动态创建的（if count>0 才注册），而\"零产出\"恰恰是要监控的故障态本身 → 规则写了也永不触发"
metadata: 
  node_type: memory
  type: reference
  originSessionId: c8389399-4eaa-4524-a3cf-4e1e9cca3bec
  modified: 2026-07-22T11:51:53.437Z
---

**铁律**：给 N9E/Prometheus 告警规则的 metric 加 `source=~` 之类的 label 正则**之前**，必须先在 VictoriaMetrics 实测该 label 值的 series 是否存在：

```bash
scripts/nw-toolbox/nw-vm 'count by (source) (nw_crawl_movies_finalized_total)'
# 还要查历史窗口，排除"刚重启导致 series 暂时消失"的假象：
scripts/nw-toolbox/nw-vm 'count by (source) (nw_crawl_movies_finalized_total offset 1h)'
```

**为什么**：Micrometer/Prometheus 的 counter series 常常是**动态创建**的——只有第一次 `increment()` 被调用时才注册。典型代码：

```java
if (finalizedCount > 0) {                       // ← series 只在这个分支里诞生
    m.finalizedCounter(source).increment(finalizedCount);
}
```

于是出现一个致命的自指陷阱：**「零产出」既是你要监控的故障态，又是让 series 永不存在的原因**。PromQL 的 `increase(metric{...}[24h]) == 0` 对不存在的 series **不产出任何结果**（不是产出 0），所以规则补了正则也**永不触发**。你以为加了覆盖，实际是纸面覆盖。

**2026-07-11 实例（BL-5②，部署时实测证伪并撤回，`549f80de`）**：规则 131（CRAWL-ZERO-OUTPUT-24H）想靠补 `hanime1_.*` 正则覆盖 hanime1 断供。实测 `nw_crawl_movies_finalized_total` 只有 `beeg/jable/javxx`，连断供前的历史窗口也无 `hanime1_*` —— 因为 hanime1 长期断供、恒 0 finalized、series 从未诞生。补正则 = 永不告警。

这是 [[project_udf_m3_monitoring_2026_07_10]] Batch3 M3「规则盯已死指标」的**变体**：M3 是指标死了（曾经活过，迁移后没了），这里是**指标从未活过**。两者的检出手段相同：**规则改动必须以 VM 实查 series 收尾**。

**同时警惕反方向**：若为了让 series 存在而给它预注册（把 counter 提到 `if` 外面），要先问「零值对这个 source 是不是正常态」。同例中 hanime1 是 per-channel（8 个）× ~5h 轮转，单个小众 channel 24h 无新片属正常 → 预注册后 24h 零 finalized 反而沦为**误报**判据。

**正确的断供判据往往在别处**：hanime1 断供的真覆盖是规则 130（CRAWL-RUN-ERRORS，`increase(nw_crawl_runs_total{outcome="error"}[3h]) >= 3`，无 source 过滤）消费「断供轮记 `outcome=error`」的修复（BL-5①）。修复前 8 个 channel 全程只有 `outcome=ok`（断供却记成功）——那才是断供失明的真根因。

**镜像故障态：series 存在但「永不 recover」——退役任务时必手动 DEL 状态 key**（2026-06-21 百度统计退役实例，commit `de9af647`）。上面讲的是**永不触发**，反方向同样致命：`newworld_baidu_stats_consecutive_failures` 这类 gauge 的值是 **Redis 持久化**的（key `admin:baidu_stats:consecutive_failures`，`BaiduStatsMetrics` gauge 实时读它），而它**只在同步成功时 `reset()`（DEL key）归零**。于是「注释掉 `@Scheduled` 停任务」= 永远不会再有一次成功 = 计数永久冻结在 9 = N9E 规则 `BAIDU-API-FAIL`（S3，`>=3`）**永不 recover**，告警会一直挂着。
- **消警必须额外 `DEL admin:baidu_stats:consecutive_failures`**——gauge 下一轮读到 0，当前进程实时生效，**无需重启/重新部署 admin**。
- **判据**：凡「失败计数器 / 连续失败 / 熔断状态」类指标，先问**归零路径挂在谁身上**。归零写在成功分支里 = 该指标与「任务还在跑」强耦合，停任务即锁死。
- 规则本身用 `disabled=1` 保留可逆（别删，复活时 `disabled=0`），但 disable 规则**不清既有 alert_cur_event**，状态 key 该删还得删。

相关：[[reference_n9e_dashboard_alert_internals]]（N9E 真值在 DB、查询在 `rule_config.queries[].prom_ql` 而非顶层 `prom_ql` 字段）、[[feedback_verify_metric_source]]、[[feedback_gate_redgreen_and_failsafe_direction]]。

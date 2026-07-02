---
name: project_gfw_probe_stale_observability_p1b_2026_07_01
description: GFW P1-B 探针陈旧漂移观测（ReachFusionService 4 个 gfw_reach_* gauge）已合 master + 部署 ca-admin + 基线实测（2026-07-01，观测优先，熔断待基线数据）
metadata: 
  node_type: memory
  type: project
  originSessionId: 5633a1c0-6fb4-42eb-9222-62f1d9199e93
---

GFW reach 剩余工作 P1 的 B 半（探针陈旧熔断）——Owner 拍**观测优先**：本 sprint 先量化陈旧漂移的普及度+危害，**不改 LIVE 融合输出**；真正熔断（freeze/hold）待本观测数据证明漂移真实且有害再另开阶段。

**问题（§4.2 follow-up）**：`ReachFusionService`(admin,5min,LIVE `REACH_FUSION_ENABLED=true`) 每格算 `probeAge` 喂 `ReachFusionMath.fuse`；`c=nodeCount×8×exp(-probeAge/6h)`＝probe 先验浓度随探针变旧→0。一个 probe 判封格(pr≈0)+幸存 RUM succ，随 c→0，"此格被封"证据(`c×(1-pr)`)消失而 `rumSucc×gateFloor(0.05)` 仍在 → **fused reach 从 0 上漂**（真封域被抬高→pick-p 误选）。融合团队刻意把 freshness 硬门挡在 `ReachFusionMath` 外（正常轮龄会泄漏幸存者进黑洞），故熔断只能做 ops 层。两缓冲让"先观测"合理：probe 键 6h TTL(全死→过期→fail-open 1.0，漂移窗~6h)+P1-A 已告警探针死。

**交付（已 --no-ff 合 master `0f9f8dcd`；spec/plan=docs/superpowers/{specs,plans}/2026-07-01-gfw-probe-stale-observability*）**：
- `ReachFusionService.runForKeys` 加 **4 个 gauge**（构造注入 MeterRegistry，同 P1-A 模式，round 末刷）：`gfw_reach_cells`(分母)/`gfw_reach_stale_cells`(probeAge>staleThreshold=6h,**普及**)/`gfw_reach_probe_age_max_seconds`/`gfw_reach_stale_uplift_cells`(**危害**：陈旧 && probeReach<blockThreshold(0.5) && fused>probeReach+upliftDelta(0.15)=真封域被抬高)。参数全 @Value 可调。
- 埋点：`ts` 解析上提到 enabled/dark 分支**前**→普及类两模式都算；uplift 类在 enabled 分支算完 `reach` 后算（dark 无 fused→uplift 恒 0，测试证实）。**零行为改动**：不改 `out.put`/`redis.putAll` 写入的 reach 值/数学/flag。TDD 4 用例(新鲜/陈旧封锁上漂/陈旧健康/dark)，2083 admin 全绿。

**部署+基线（Owner 监控，ca-admin `reachstale-0b6019ca.jar`，回滚 ref=probemon-09b75d58）**：curl :18080 + VM(ca-monitor) 实测**首次基线**：`cells=13884`/`stale_cells=0`/`stale_uplift_cells=0`/`probe_age_max≈5.97h`。**稳态 0 陈旧 0 危害=当前无漂移**。★nuance：probe_age_max 长期贴着 6h 阈值边缘（探针~3h 轮+6h TTL 决定），轮延迟时 stale 可能抬头——观测阶段要盯这个，据此定后续熔断做不做/阈值调不调。

**★关键坑（部署实测逮到，==教训==）**：Micrometer `PrometheusMeterRegistry` **剥离 gauge 的 `_total` 后缀**（`_total` 是 Prometheus counter 专属约定）。代码命名 `gfw_reach_cells_total` → **prod 实际导出 `gfw_reach_cells`**。而单测用 `SimpleMeterRegistry`（保留字面名）→ 测试假绿、prod 名不符=经典"config 说 X 现实 Y"陷阱。部署后 curl :18080 才发现→统一改 `gfw_reach_cells`(code+test+spec+plan)重部署。**教训：gauge 别用 `_total` 后缀；Micrometer 指标名以 prod PrometheusRegistry 导出为准（curl :18080 实测），SimpleMeterRegistry 单测不暴露命名转换**。另：categraf scrape→VM 有 ~15s 滞后，重启后立即查 VM 可能读到旧 0 值（等一轮 scrape 才对齐，非 bug）。

**未做/后续**：① **熔断阶段**（据本观测基线决定：uplift 长期 0→漂移不成危害→熔断可不做 YAGNI；若 uplift>0→做 ops 层 hold probe 值/hold last-known + flag + 火测）。② 可选 N9E dashboard reach 陈旧面板。③ master 本地合未 push origin（Owner 选本地；多会话协作前需 push）。相关 [[project_gfw_probe_reliability_monitor_p1a_2026_07_01]] [[project_gfw_reach_fusion_phase4_2026_07_01]] [[reference_actuator_port_18080]]。

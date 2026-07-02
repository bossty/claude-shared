---
name: project_gfw_3a_flag_activated_2026_06_30
description: GFW 3a pick-p reach:grid flag 火测通过并保留 ON（2026-06-30 ca-admin 部署 + OPS_PICKP_REACH_ENABLED=true LIVE + N9E 告警）
metadata: 
  node_type: memory
  type: project
  originSessionId: 03626fd7-7b4d-447f-9faf-2df37f0330ea
---

GFW Option C 执行：3a（admin pick-p 改读 reach:grid）consolidate 回 master 后，部署到 ca-admin + 翻 flag 火测通过 + **保留 ON**（Owner 拍 "保留 on + 设 N9E 监控"）。

**运行姿态（截至 2026-06-30 夜，LIVE）**：
- ca-admin 跑 `newworld-admin-3a-d0204537.jar`（current.jar symlink → 它；旧 `20260630-204732-d3efc0b7.jar` 留 deploys/ 作回滚）。systemd ExecStart=`/newworld/newworld-admin/deploys/current.jar`，User=newworld，SSH=ubuntu+sudo nopasswd。
- **`system_config.OPS_PICKP_REACH_ENABLED = "true"`（LIVE ON）** → admin /ops/pick-p 边缘选址 RPC 用 reach:grid 乘子（`effective=base×reach`）而非旧 domain:err penalty。
- 翻 flag 走的不是 admin UI（无 admin JWT）而是**忠实复制 API**：DB INSERT system_config + `redis PUBLISH shared:ch:sysconfig-refresh "*"`（11 subscribers 收到=admin+web 全失效 L1）+ `INCR shared:system-version`。**秒回滚** = 同法 set "false" + republish。

**火测证据（PASS）**：pick-p 是 live 的（~1110→2180 calls/启动后，主力渠道 pgeqd ~1/s）；翻 flag 后 source 标签 err→reach 干净切换；**4min 窗 reach_success 213→1567、ALL_fail=0**（零失败零回归）；真重选证实=P 池 131 域含真降级格（crispoven.top@广西unicom=0.5、emeraldquartz.site@telecom:_ANY_=0.8936）→ reachMode 非空操作，方向正确（低 reach→少选）。

**N9E 告警（已建）**：`alert_rule` id=108 `PICKP-REACH-FAIL-RATIO`（ca-monitor n9e_v8 DB，clone id=1 S-REACH-FAIL）。PromQL（backtick 匹配器避双引号转义）：`sum(rate(ops_pick_p_total{service=\`admin\`,status=\`fail\`}[5m]))/clamp_min(sum(rate(ops_pick_p_total{service=\`admin\`}[5m])),1) > 0.05`，for=180s，severity=1，notify group[1]。metric 本就经 ca-admin categraf input.prometheus scrape `:18080/actuator/prometheus`(15s)→VM `:8428`→writer n9e.17.rip。

**观测点/坐标**：
- 指标 `ops_pick_p_total{service=admin,source=reach|err,status=success|fail,channel}`，admin actuator **`:18080`/actuator/prometheus**（非主 8888）。
- reach:grid 真数据：~95% reach=1.0 中性 / ~5% 降级 / ~1.3% =0 全封；`src=probe` 单源（RUM 融合=阶段4 未做，95% 乐观偏 1.0 可能"假干净"，见 caveat）。
- P 池 key=`shared:global:p_pool`（zset，131 域，base score 0=渠道无状态）。

**坑/教训**：① ca-admin `unzip` 旧版**无法解析 Spring Boot 嵌套 jar**（unzip -l 0 classes）→ 验 jar 内容用 `python3 zipfile` 或比 md5（与本地已验 jar 同 md5=同码）。② 成功 pick-p **不打日志只发 metric**→ 判 live 看 `ops_pick_p_total` 别看 journal（曾误判"0 调用/30min idle"）。③ 翻 flag 必 publish CH_SYSCONFIG_REFRESH 失效 L1，裸 SQL 不 publish=L1 陈旧 flag 不生效。

**未做/后续**：阶段4 融合（reach:grid probe + domain:report SW探活→src=fused 提升信号质量，95% 乐观偏 1.0 的根治）；持续观察 N9E 告警 + reach 占比；阶段1 提取 web/admin 两份 reach 读层到 common。相关 [[project_gfw_parked_phases_consolidation_2026_06_30]] [[project_gfw_pickp_reach_cutover_3a_2026_06_30]] [[project_gfw_ipdb_rum_fix_2026_06_30]] [[reference_actuator_port_18080]] [[reference_n9e_dashboard_alert_internals]]。

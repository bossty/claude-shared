---
name: project_gfw_probe_reliability_monitor_p1a_2026_07_01
description: GFW 探针可靠性监控 P1-A（round 级 gfw_probe_* 指标 + 3 条 N9E 告警）已合 master + 部署 ca-admin + 火测通过（2026-07-01）
metadata: 
  node_type: memory
  type: project
  originSessionId: 5633a1c0-6fb4-42eb-9222-62f1d9199e93
---

GFW reach 信号线剩余工作 P1 的 A 半（监控告警）完成。**探针链路（pick-p+fusion 的地基）此前零指标零告警**——aliyun-probe-runner/boce/tcptest/3h 调度器任一环病了没人页；最阴险=itdog 同款"静默成功"（源协议悄改返空→格判全健康）。本 sprint 补齐观测，**纯观测零 reach/pick-p/fusion 行为改动**。

**范围决策（Owner 拍）**：只做 A（监控告警）；B 陈旧熔断（探针死>N轮→freeze/hold last-known）作 backlog 快速跟进——融合团队已刻意把 freshness 硬门挡在 fusion 数学外（正常 3h 轮龄会泄漏幸存者进黑洞，见 [[project_gfw_reach_fusion_phase4_2026_07_01]] gateFloor/tauProbe），故熔断须独立 ops 层，等 A 数据证明"中间态漂移"真实再做。信号源=Java Micrometer round 级（非 input.exec 读 Redis，后者盲区大）。

**交付（已合 master `7a3f175c` --no-ff；spec/plan 见 docs/superpowers/{specs,plans}/2026-07-01-gfw-probe-reliability-monitoring*）**：
- `GfwProbeAggregator` 构造注入 `MeterRegistry`，`runOnce` round 末刷新 **12 个 gfw_probe_* gauge**（全 `service="admin"` 公共 tag）：`gfw_probe_scheduler_heartbeat_seconds`（每轮完成置 epoch 秒，含 targets 空早返路径→抓调度停摆/进程死/admin 单线程饿死[[project_admin_scheduler_starvation_2026_06_27]]）/ `gfw_probe_source_domains_{probed,empty}`+`_nodes`{source=aliyun|tcptest}（分母=真拨测域非 targets，防 skip-fresh 稀释；抓静默成功+单源死）/ `gfw_probe_round_domains_{ok,failed,skipped}`+`_targets`+`_duration_seconds`。GfwProbeAggregatorTest +3 用例（SimpleMeterRegistry 读回断言）。admin 全模块 BUILD SUCCESS。
- **N9E alert_rule id=109 GFW-PROBE-STALL(sev1,for300,`time()-max(heartbeat)>27000`=7.5h漏2轮,Owner定) / id=110 GFW-PROBE-SOURCE-EMPTY(sev1,for600,`empty/clamp_min(probed,1)>0.8` per source=heartbeat抓不到的盲区"调度活着但数据死"最关键条) / id=111 GFW-PROBE-ROUND-FAIL-HIGH(sev2,for600,`failed/clamp_min(targets,1)>0.3`)**。clone id=108[[project_gfw_3a_flag_activated_2026_06_30]]全 schema（datasource_queries 非 NULL/notify_rule_ids=[1] telegram/backtick 匹配器），回镜 `ops/n9e-alert-rules.yaml`（不重蹈 id=108 DB-only）。

**部署+火测（Owner 在场监控，全绿）**：ca-admin 部署 `newworld-admin-probemon-09b75d58.jar`（MainPID 962614，回滚 ref=`newworld-admin-fix-be5fe5c4.jar`）；boot 后 initialDelay 60s 首轮 141 域**全 skip-fresh**（fresh 标记 Redis 存活跨重启，65ms 完成）→ 12 指标落 `:18080`→categraf→VM(ca-monitor)；STALL promql 实测 12.85s 健康、SOURCE-EMPTY/ROUND-FAIL 均 0 不误报。**告警链路验证=合成 always-true 测试规则**（id=112 `heartbeat>0` for0）→ alert_cur/his_event 出行 `notify_cur_number=1`(telegram 发出)→**验后自删**（不碰真探针源，Owner 选的安全法）。3 条真规则均不误报。

**关键坑/教训**：
- ★★**Explore 子代理读了陈旧工作分支得出"代码不存在"的错误结论**：委派的 probe-map agent 在 `fix/resize-observer-benign-monitor`（GFW 整合前的旧分支）+ 老 `gfw-breakthrough-arch` 上 grep，报"ReachFusionService/node_count/reach:grid:probe 不存在、master GFW-free"——全错。真相：`origin/master` 早已含 fusion（我先在 prod DB 实测 REACH_FUSION_ENABLED=true + git log origin/master 见 be5fe5c4）。**教训：多分支仓库里工作树可能落后 master N 个整合，验代码是否存在必对 `origin/master`（部署基线 ref）grep，非 checkout 的分支；子代理给的 file:line 也要认它读的是哪个 ref**。
- skip-fresh 使首轮/多数轮 per-source probed=0 → SOURCE-EMPTY 分子 0 不误报；但 fresh 标记 TTL=reachGridTtl×0.5(~3h) 到期后陈旧域重探，源真死则返空累积→~3h 内 empty-ratio 起来能抓到（信号自建，非永久盲）。
- 部署踩点：`-DskipTests` 被 pom 无视（tests 照跑,~4min,通过）；ca-admin unzip 解不了 SpringBoot jar 用 md5 比（本次 md5 6613c1d3 本地↔远端一致）；EnterWorktree 默认 base=origin/master 正好是需要的基线；worktree cwd 每条 Bash 重置需绝对路径。

**GFW reach 剩余（handoff `docs/GFW_REACH_NEXT_SESSION_HANDOFF.md`）**：P1-B 探针陈旧熔断(backlog,需独立 spec+火测) / P2 激活 REACH_HINT_ENABLED+A_POOL_PENALTY_ENABLED(dark→需授权火测) / P3 N4 S 边缘→NLB 翻流(需 Owner 风险决策)。master 未 push origin（Owner 选本地合），多会话协作前需 push。相关 [[project_gfw_reach_fusion_phase4_2026_07_01]] [[project_gfw_3a_flag_activated_2026_06_30]] [[reference_actuator_port_18080]] [[reference_n9e_dashboard_alert_internals]]。

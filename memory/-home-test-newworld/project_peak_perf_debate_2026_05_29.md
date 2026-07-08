---
name: project-peak-perf-debate-2026-05-29
description: "5 维度专家 + 蓝军 crossfire 团队定位\"高峰期访问速度不佳\"真凶在 edge/客户端非服务端；4 路独立收敛 (CF Anycast 96.5% 跨洋 + cloudflared 800ms tunnel tax + INP 684ms + 5/28 ops cascade)；服务端 DB/JVM 在 Owner 窗口 20:00-03:00 HK 0.05x 利用率游刃；main session v1→v2→v3 verdict 三次反转沉淀 4 条 sub-agent 协作铁律"
metadata: 
  node_type: memory
  type: project
  originSessionId: 26157e24-1a76-48ce-a57b-521c36980c46
---

# 高峰期慢全栈 debate sprint (2026-05-29)

> **★ SESSION 2（"多region方案讨论2"，2026-05-29 夜）权威状态在 `docs/sprint/2026-05-29-peak-perf-debate/SESSION2-STATE-三臂对比.md`** —— post-compact 先读它。三臂真用户对比：**17.rip(单HK baseline) vs flowzone26.top(多region多tunnel,方案2) vs eduspace181.link(多region单tunnel,方案1)** 全 catch-all 跑一晚。核心比**路由架构对 CN 用户网络路径**（网络腿+region落点+成功率），**DB 因迟早 replica 趋同、剔出不比**。结论：多region有成功率代价(86-93% vs HK 100%)+跨洋DB长尾→**replica前置必需**；方案1路由不可控(mesh/RTT)→**方案2(LB geo)生产推荐**；#106主因=country_pools[CN]取首位us把AMS侧CN也钉us。慢真凶=96%CN绕欧美POP跨洋回HK(RUM实证,origin近零1ms)。详细 live 态/rollback台账/待办/实施顺序见该 doc + GROUND-TRUTH §9.x。

Owner 反馈"高峰期访问速度不佳"。TeamCreate 持久团队 `peak-perf-debate` + 5 agent (db-perf/app-perf/edge-perf/fe-perf/blue-team) 并行 spawn 走 Phase 1 solo recon → Phase 2 crossfire → Phase 3 综合的 SendMessage debate 流程。Owner 拍板高峰窗口 **20:00-03:00 HK**（7h），低峰对照 08-12 HK。

## 真凶 4 路独立铁证收敛

| # | 真凶 | confidence | 关键铁证 |
|---|------|-----------|---------|
| 1 | **CF Anycast 96.5% CN 流量绕欧美 POP** | 95% | RUM 实测 CN 1.83% HKG / SEA+LAX+AMS = 90%；HKG vs LAX LCP P75 +1862ms / TTFB 2x；5/22 教训"75%"今天恶化到 96.5% |
| 2 | **cloudflared tunnel 单 TCP 跨洋 tax 800ms+** | 90% | Tomcat p99=20ms vs SEA TTFB P75=1082ms = 800ms+ tunnel 路径吃掉（fe-perf H4 估 300ms 被 blue-team 升级到 800ms+） |
| 3 | **INP P95=684ms 主线程阻塞**（Q08-Q11 anti-adblock probe 首查） | 70% | owner "卡"感知可能在 INP 不在 LCP；chrome-devtools MCP lock 期间无 trace，待 owner 真机 |
| 4 | **5/28 ops cascade 落 Owner 峰窗** | 80% acute | 13:08 UTC restart(HK 21:08) + 21:05 cutover#3 + 21:30 cleanup 全在 20:00-03:00 内；7d LCP 5/28 day-0 最高 5097ms |

## 已铁证排除（不投入）

- **DB**：BP hit 99.988% / 6.7h 14 慢查询 / Owner 窗口 HikariCP pending=0 / r6i.2xlarge 可撑 5x
- **JVM**：Owner 窗口 Tomcat busy avg 1.6/max 24（cap 800 = 0.05x 利用率）/ Hikari active 0.9/25 / GC pause 22ms / P99 q/tally 56ms
- **业务流量 ↑1.86x 但 JVM ↓0.05x 利用率 = web 完全游刃**

## 观测债（独立闭环必修）

1. **N9E mysql categraf 指 5/27 灾难前 aws-db / aws-db-poc，真 prod DB 172.31.19.174 完全没 scrape**（db-perf + blue-team 双揪）
2. aws-web-01/02 nginx_status 不暴露 + access.log 0 bytes = 主入口大半盲
3. cloudflared 0 metric（rtt/drop/reconnect）= 跨洋假说无证据
4. 零 RUM panel 接 N9E（数据存在 `nw_vitals_*`，PromQL panel 没接，**blue-team v1 误判"零 RUM"是 grep 前缀错**）
5. web-01 threads 290→590 2x 不平衡疑 listener 泄漏
6. CfZoneAuditService 跑时间不对（@Scheduled 03:00 vs 实测 3.8h ago，疑静默挂）

## 顶层抓手 ROI 排序

**P0 短期** (1-2d)：① owner 真机今晚 20-03 HK chrome devtools / playwright trace + INP + cfRay ② 修 N9E mysql categraf → 172.31.19.174 ③ 5/28 ops cascade SOP 复盘 (cloudflared graceful drain 落 deploy 脚本铁律) ④ HikariCP leakDetectionThreshold=30000 + N9E pending>50 alert

**P1 中期** (1-2w)：① **CF Argo Smart Routing trial**（已研未上 ~30% 跨洋节省，最高 ROI）② cloudflared multiplex / pool 调优（治 800ms tunnel tax）③ nginx upstream keepalive 32→128 + keepalive_time 1h ④ 补 aws-web nginx + cloudflared + RUM N9E panel ⑤ R2 wrong-POP 解歧（P50/P75/volume 验证后定改造）

**P2 长期** (1-2m)：① CF China Network / Premium 评估（让 CN 真命中 HKG）② US/EU 副本 origin ③ 全链路 OpenTelemetry Trace

## 4 条 main session 协作铁律沉淀（核心价值）

1. **峰窗采样错位是结构性 bug**（v1 教训）— Owner 拍板时间窗后必采全窗 + 子窗对照（如 20-22 黄金 vs 23-01 深夜 vs 02-03 尾峰），单时段抽样掩盖突发。"DB 域铁证排除"基于 UTC 18-19h 是采峰尾错位。
2. **sub-agent 报"X 为零 / 不存在" BLOCKER 必 main session 独立二查**（v2 教训）— blue-team grep `rum_` 实际是 `nw_vitals_*` 前缀，我 v1 verdict 整段错。规则：sub-agent 否证类 BLOCKER 必独立 grep/curl/SQL 二查不全信转述。
3. **多 agent 数据冲突时禁擅自选边**（v3 教训）— v2 据 db-perf 一面之词反转 v1 也是错；db-perf vs app-perf 在 5/26 21:56 BJT 723 pending 是否真发生**冲突未解**，应标"未解"等更多证据或派第三 agent 仲裁，不擅自选边。
4. **team shutdown 前必显式 final-call round 给 5min 自检窗口** — 5 agent 关机前压哨发现频出（fe-perf 7 条自挑刺 / db-perf 反转 / app-perf 重测 / blue-team RUM 撤回），盲目 shutdown 错过最后修正机会。

## 关联记忆

- [[reference_n9e_alert_pipeline]] — N9E + categraf + VictoriaMetrics 监控链路
- [[project_nginx_error_audit_2026_05_22]] — 5/22 P0 + 5/23 edge sprint
- [[project_p0p1_audit_hotfix_2026_05_26]] — 5/26 P0+P1 hotfix（DiverseHighQualityCompute / AdStatsSync / publish "all"）
- [[project_db_migration_2026_05_27]] — 5/27-28 DB 迁移 + 灾难重建
- [[project_cf_china_edge_reality_2026_05_22]] — CF 中国 POP 实证（75% 欧美 POP）
- [[project_cf_speed_audit_2026_05_20]] — CF 优化 + HSTS Preload

## Phase 4 main session 接手 N9E 真用户 RUM trace（2026-05-28 17:22 UTC = HK 01:22 峰窗实时）

owner 无 HK 真机要求 main session 用 N9E 代测。N9E RUM 数据 = 10 万+ 真用户客户端 trace 聚合，**远胜任何单次浏览器 trace**。实证：

- **CN 流量 cfPop 分布**：SEA 33.9% + AMS 31.5% + LAX 20% + SJC 10.3% = **94.9% 跨洋**，HKG **仅 1.75%**（fe-perf 1.83% + blue-team 1.83% + 本次 1.75% 三方独立锁死）
- **CN LCP P75 by cfPop**：SJC 4822ms / LAX 4447ms / AMS 4133ms / SEA 3823ms vs **HKG 2538ms** → 加权救援上限 **-1.7s LCP P75**
- **HKG 用户 TTFB 806ms − Tomcat 20ms = 786ms tunnel tax**（blue-team 估 800ms+ 实测对齐）— 即便修 CF Anycast 这 786ms 仍存在，独立 P1 抓手
- **INP P50/P75/P90/P95/P99 = 101/205/445/667/1616ms**（blue-team 估 684ms = P95 实测 667ms 对齐）— Q08-Q11 anti-adblock probe 首查
- **7d CN LCP P75 峰窗趋势**：avg 4643ms / median 4682ms / 5/28 14-15 UTC = HK 22-23 撞 5098-5202ms 七天最高 → owner "高峰慢" 真切感受落 HK 22-23 中峰
- **服务器多地 baseline**：aws-monitor HK→HKG 74ms TTFB / buyvm-data LA→LAS 215ms TTFB（2.9x，仅 RTT 对照）

**5 沉淀教训新增（main session 接手 trace 教训）**：
5. **owner "无设备代测" 类请求第一抓手是 RUM 实测不是模拟** — N9E nw_vitals_* 已是真客户端 trace 聚合，比 chrome headless / playwright 模拟 1 个 session 1 个 POP 真实千百倍；模拟仅适用 RUM 未触及场景（未上 RUM 页 / 反爬绕过 / mass spike 单 session 复盘）

## Phase 5 — cloudflared --metrics 接入 N9E（B1 30min 闭环）

2026-05-28 17:30-17:50 UTC. **4/4 闭环验证全通**：aws-web-01/02 × a/c/p (20241/2/3) + aws-data × admin (20244)。N9E VM 28 个 `cloudflared_*` series 全在，7 tunnel × 3 host 完整覆盖。**关键诊断指标**：`cloudflared_proxy_connect_latency_bucket`（origin 路径段）+ `cloudflared_rpc_client_latency_secs_bucket{handler="registration"}`（CF edge 路径段）= **786ms tunnel tax 分段拆解抓手**。**baseline 实测**：rpc_count=4 全 tunnel = cloudflared 默认 ha-connections=4 当前生效，未来 owner 通过 CF Dashboard 改 8 后此数字变 8 = B2 改动 ROI 量化抓手。1h 累计后（HK 02:50 后）查 P95 真数据可定位 786ms 卡哪段。

**6 沉淀教训新增（B1 现场踩坑）**：
6. **cloudflared --metrics 必填禁裸跑** — `--help` 默认 fallback 范围 20241-20245，老 cloudflared 实例无 --metrics 会自动占 → 跟手动分配端口 race；所有 cloudflared systemd unit 必显式 `--metrics 127.0.0.1:202XX`，unit 文件加 sentinel 注释提醒未来人。本次 aws-web-01 cloudflared-c restart 失败 13 次循环根因。
7. **多 unit 滚动 restart 禁 set -e + 单 fail 必降级 fallback** — `set -e; restart a; restart c; restart p` 在 c fail 时 p 被跳过，旧 p 继续占冲突端口致 c 永远起不来；正确做法是禁 set -e + 每 restart 后 is-active 校验 + fail 时进 reset-failed / journalctl tail / stop 释放资源 fallback 分支。

## Phase 7 — N9E mysql categraf 真凶修复（P0 #1 闭环）

2026-05-28 17:55 UTC. **真凶反转**：sprint verdict 写"categraf 指向错 172.31.16.161"实际 aws-db-poc 真 IP=172.31.19.174 + categraf 配置全对 + 真凶是 **`categraf_ro` mysql 用户根本不存在**（5/27 mysqldump --databases 不导 mysql 库 A14 教训源头，5/28 RESET 重建也没建）。修法 3 行 SQL：`CREATE USER ... IDENTIFIED WITH mysql_native_password` + `GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.*` + restart categraf。**闭环铁证**：mysql_up=1 / 110 mysql_* series 全活 / 实测 aws-db-poc QPS 833/s + conn 92 + threads_running=2 + InnoDB BP hit **99.9899%** 与 db-perf 报 99.988% 完美对齐；aws-db 老主机冷备 0.5 QPS 确认无业务流量（CLAUDE.md 计划 6/4 stop / 6/27 退役）。

**8 沉淀教训新增**：
8. **categraf scrape 失败 mysql_up=0 必查目标 mysql 端用户是否存在 + categraf log 静默是真痛点** — input.mysql 在 access denied 时不写 categraf ERROR log，只上报 mysql_up=0；如告警没配/无人看 dashboard 真 DB 监控完全失明无声 1.5 天（5/27 cutover 至今 5/29）。cutover/灾难恢复后必跑端到端真验证：mysql_up=1 + global_status_questions rate>0 + threads_connected>0。**观测债类问题 main session 必走"目标系统真状态 ≠ 监控 agent 配置 ≠ 监控数据 final state"三段独立 fact-check，禁信单 agent 转述**。本 sprint 蓝军 + db-perf 双双报"categraf 指向错"是表象正确根因错。

## Phase 8 — 5/28 ops cascade SOP 复盘（P0 #2 闭环，零生产改动）

2026-05-28 18:00 UTC. 复盘 5/28 13:08 UTC web 重启（HK 21:08 黄金档起步）违反 5/22 A-2 cloudflared graceful drain SOP 事件。**audit 4 个 deploy-* 脚本**：deploy-web.sh ✅ 已有 cloudflared drain（5/22 沉淀），但 **4 个脚本全无 peak window check**。**关键真凶**：5/28 13:08 重启走的不是 deploy-web.sh 是手动 `ssh + systemctl restart` 绕过脚本。**推荐 patch**：peak_window_check 公共函数 (`TZ=Asia/Hong_Kong date +%H` >= 20 || < 3 早退 exit 1 + FORCE_PEAK=1 override 留紧急修复后门)，加在 4 个 deploy-* 脚本 set -euo pipefail 后。零运行时风险。Phase 8 文档已落 sprint dir 等 owner 批准。

**9 沉淀教训新增**：
9. **任何 web / cloudflared / OpenResty / DB 重启必查 owner 峰窗 (HK 20:00-03:00)** — web restart 即便有 graceful drain CF edge 收敛 5-10s 仍有用户感知；cloudflared restart tunnel 断重连几秒；OpenResty restart lua 模块重载 worker rotation 峰窗 5xx burst；DB restart lettuce reconnect 风暴 + cache warmup（5/22 A-2 lettuce burst 5s timeout cascading 教训）。SOP：① 脚本走 peak_window_check 函数 + FORCE_PEAK=1 override ② 手动操作必显式声明 peak 时段，HK 03:00 后才能跑 ③ 紧急修复必走 git PR + Owner 批准 + 落 ops/incident-log。5/22 A-2 graceful drain SOP + 本 SOP 互补：drain 解 burst restart 风暴，peak window check 解时机。

## P0 #3 HikariCP leakDetection 真相（已闭环 — 无需任何动作）

2026-05-28 18:10 UTC. owner 问"leakDetection 怎么做需要重启吗" → grep 实证 **newworld-web application-prod.yml L15 早就配了 `leak-detection-threshold: 20000`（20s）**，5/22 P0 沉淀的，比 sprint verdict v3 推荐的 30s **更严格**。db-perf 关机前 Phase 3 校正写"加 leakDetectionThreshold=30000"是 hallucinate，main session sink 时没核现状是错。**结论：web 端不需要做任何事；admin/data 没配但非 P0，可入 backlog**。

**10 沉淀教训新增（与教训 8 同源）**：
10. **生产推荐项必先 grep 现有配置/代码，禁信 sub-agent "应该没有"类假设** — 本 sprint 同源 2 次教训：① Phase 7 blue-team + db-perf 报"categraf 没 scrape"实际配置全对真凶是 mysql 用户不存在 ② P0 #3 db-perf 推荐"加 30000"实际已配 20s。底层逻辑同源：sub-agent 关机前压哨推荐 + main session 没核现状直接 sink = verdict 失真。**SOP**：sprint 综合阶段必对每条推荐项跑 `grep -rn '<key>' <module>/src/main/resources/` 或 `grep -rn '<method>' <module>/src/main/java/` 实证现状，**禁基于 sub-agent 抽象描述写"加 X"**；现状已有 → 标"已闭环"；现状没有 → 标"待新增"+具体文件路径行号。

## Phase 6 — cloudflared baseline verdict（提前 30min 完成，wakeup HK 02:47 可 ack）

2026-05-28 18:13 UTC. cloudflared metrics 30min 累计实测：① `cloudflared_proxy_connect_latency_*` 在 token+ingress 模式 **不 emit 数据**（count=0 全 7 tunnel），原 sprint 设计意图"拆 786ms tax"失败 ② **但 B1 真价值 = origin tunnel POP 实证：3 host × 6 connection 全 HKG**（aws-web-01 hkg01/09/11/12 / aws-web-02 hkg10 / aws-data hkg08）③ tunnel 健康：449k req/30min / 200+304 健康率 **99.74%** / 5xx=0 / errors 0.096% / HA connections=4 全 HKG。**真凶 100% 锁定**：CN 用户 → CF Anycast SEA/AMS/LAX (95.7%) → CF 内部跨洋路由 → HKG POP → cloudflared (黑盒 ~400ms)。**B2 ha-connections 4→8 ROI 小**（已 HKG 区最大化 HA）；**真治本 P1 CF Argo Smart Routing**（直击 CF 内部跨洋路由 ~30% 节省 ~120ms）+ **P2 CF China Network**（CN 直命中 HKG 最大救援 -1.7s LCP）。

**11 沉淀教训新增**：
11. **cloudflared metric 在 token+ingress 模式不暴露请求级 latency** — cloudflared 2026.3.x token + ingress rules 模式 `proxy_connect_latency` 等 per-request histogram 不 emit（仅私有网络/SOCKS5 模式 active）；真实暴露的是 tunnel_total_requests / response_by_code / server_locations / ha_connections / request_errors（流量+健康+POP）。拆 CF→origin 链路 latency 必须组合 CF Analytics + RUM nw_vitals_ttfb + origin actuator。**SOP**：sprint 涉"用 X metric 拆 Y"前必先 `curl /metrics | head -50` 看 X 是否真暴露需要的维度，禁基于一般经验假设。

## Phase 10 — lb-strategy-debate team 5 agent crossfire（2026-05-29 03:25-05:00 HK）

owner 创建 TeamCreate 多 agent 持久团队（非 single-shot subagent）分析 **CF Load Balancer 6+ steering policy 哪个最优**。5 agent: policy-researcher / lb-tester / architect / cost-analyst / blue-team。4 轮 cross-fire round + 30+ 蓝军挑刺 + 6 次实证级联纠错 → final verdict:

### final verdict（4/4 agent 共识）
1. ⭐ **Argo Smart Routing 单 17.rip P0**（main session lead chrome 实测 Argo ON cfOrigin=3ms vs OFF=665ms = **99% 节省**）
2. **LB policy 选 geo 或 off**（单 region 真业务下 5 policy 稳态等价）
3. **dynamic 排除**（Enterprise only + 42M probe/月 + EWMA TCP）
4. **proximity 排除**（单 region 退化 + 5/22 P0 反模式）
5. **真业务上线 LB ROI ≈ 0%**（除非加 Argo + 跨 region 真业务部署）— blue-team 关键洞察
6. **POC -16% 不可外推**（5 pool 跨 region nginx echo 的 anycast 接入效应，不是 LB policy 效果）

### 6 次实证级联纠错（团队成熟度信号）
| # | 失误源 | 纠错 |
|---|--------|------|
| 1 | architect v1 "全 HK 已实证" | 蓝军接受 |
| 2 | architect 自我更正 | 蓝军自查降级 |
| 3 | policy-researcher v2 "4 pool echo" | 蓝军第三次纠错 |
| 4 | cost-analyst v2 "-16% 分母" | 蓝军 BLOCKER #C6 |
| 5 | policy-researcher "假绿" | policy-researcher 主动自查 ✨ |
| 6 | lb-tester PTR 实证 5 region | 一次 curl 闭环 5 次推断级联 |

**质量曲线**: 外部触发 → agent 自主纠错（团队成熟度信号）

**12-15 沉淀教训新增**（4 条核心铁律 sink 候选 newworld-multi-agent-coord skill）：

12. **"实证 vs 推断" 3 级标注铁律** — 🟢 实证 (亲自 curl/grep/fetch) > 🟡 CLAUDE.md/owner brief 推断 > 🔴 自己中间推断（**必标"待仲裁"，不得跨 agent 转述当 ground truth**）；cross-fire 必检每条主张的数据源类别（蓝军 round 4 新规）；agent 主动自查 + 撤回基于 🔴 类的推论 = 团队成熟度信号。本 sprint 6 次实证级联实证（误信息级联 5 环：architect 推断→蓝军接受→policy-researcher 引用→cost-analyst 引用→后续雪球）。

13. **SaaS plan tier 是 sprint 启动必问** — 17.rip CF Free plan 限定 dynamic_latency Enterprise only ($5k-$15k/月起年合同) + Pool check_regions max=1，导致 team 4 轮才发现 dynamic 完全不可行。sprint 涉 SaaS feature 评估前必首先 GraphQL/API GET zone plan + feature matrix。

14. **"policy 杠杆" vs "underlying infra 杠杆"区分 — 后者通常 10x 杠杆** — LB policy 选哪个差异 ≤ 5% (4 agent 共识)；Argo / 跨 region origin / cache 是 -20~99% 级别杠杆。sprint 评估 SaaS 优化时必先识别 underlying infra 是否可改善，policy 选择是次要决策面。

15. **lb-tester 一次 curl 闭环 5 次推断级联 = cross-fire 价值不如一次实证** — sprint 中 4 agent 走 4 轮推断 cross-fire 才发现 "5 origin 真跨 region" 真相；lb-tester 一次 curl `dig PTR` + `curl /staticbig` 立即闭环。规则：**cross-fire 价值再大也比不上一次 curl 实证**；任何涉外部系统状态的 verdict 必有 ≥1 agent 实测 ground truth；ground truth 实证者优先级 > 文档研究者 > 推理者。

## Phase 11 — Multi-Region Origin + LB 实施方案（2026-05-29 05:00 HK）

owner 反复反诘 "域名数量爆炸式增长 + 用户均衡 + Argo 全开/部分开都不现实" → sprint 走 Argo 弯路修正 → 立即回收 jp/sg 多余资源 + 制定 Phase B 详细方案。

### 回收资源（已执行）
- ✅ jp/sg pool 删
- ✅ ap-northeast-1 + ap-southeast-1 EC2 terminate
- ✅ lapoc CF tunnel + DNS lapoc.17.rip 删
- ✅ cloudflared-lapoc service 4 节点 stop+disable
- ✅ aws-web-01/02 OpenResty /static-poc location 恢复（清生产污染）
- 保留：us-west-2 / eu-central-1 / ap-east-1 EC2（等 Phase B.1 升级）

### Phase B 4 阶段（10 工作日）
- B.1 EC2 升级 t3.medium/large + Java 25（2 天）
- B.2 MySQL r6i.large × 3 region replica + GTID async（3 天）
- B.3 Spring read/write datasource 路由（@Transactional readOnly = replica）（2 天）
- B.4 LB cutover canary 5% → 50% → 100%（3 天）

### LB Geo-Steering 配置（RUM 数据驱动）
- 3 origin (us-west-2 / eu-central-1 / ap-east-1) 覆盖 CN 99% cfPop 流量
- country_pools[CN] = [us, eu, hk] 让 CF 国家级智能选最快
- region_pools 完整覆盖 WNAM/ENAM/SAM/WEU/EEU/NEAS/SEAS/OC/ME/NAF

### 月费 ~$650/月固定（不按 zone 翻倍 — owner 真痛点解）
- vs Argo 70 zone $5000+，未来 1000 zone $50000+
- 节省 87~99%

**16-20 沉淀教训新增**：
16. **域名规模 + 用户分布是架构决策最优先输入** — owner 早期说"域名多 + 用户均衡"，sprint 走 Argo 弯路因没把这个 owner brief 当 ground truth；规则：sprint 启动必 ack owner 反复说过的约束（域名数 / 用户分布 / 预算上限等），并写入 brief 必查清单
17. **数据驱动 region 数选择 RUM cfPop 99% 覆盖率为阈值** — 3 region (us/eu/hk) 覆盖 99% CN 流量；5 region (+jp/sg) 实测反而分流不均 +2~4% 偏差；规则：region 数选择必基于 RUM cfPop 累计分布，不是直觉
18. **写 hot path 跨洋 < 读 hot path 跨洋（10% vs 90%）— read replica 优先级远高于 multi-master** — newworld 实测 GET 占 ~90% / POST 占 ~10%；read replica 本 region 内网 <1ms vs 跨洋 ~150ms 是真 ROI 集中点
19. **CF LB 一个 endpoint 服务多 hostname = "不按 zone 翻倍"架构** — 这是 Argo 替代方案本质优势：固定月费扩到 1000+ 域名月费不变；Argo 按 zone $5 + 流量翻倍不可持续
20. **架构 cutover 必走 canary 5% → 50% → 100% 三档**（不要 5% → 100%）— 每档观察 1 周 + 业务指标无回吐 + replica lag <60s 稳定才升档；回滚 SOP 5min 内立即生效（DNS / Page Rule 改 1 次）

## 详细 Phase B 实施文档

`/home/test/newworld/docs/sprint/2026-05-29-peak-perf-debate/phase11-multi-region-implementation-plan.md`

## 待 sprint backlog（CLAUDE.md 主文档更新）

- aws-db-poc 真内网 IP **172.31.19.174**（不是 CLAUDE.md 写的 172.31.16.161，5/28 灾难重建后改名）— 下次有 commit 时同步更新 CLAUDE.md 主表格
- Phase 8 推荐的 peak_window_check 函数 patch 等 owner 批准后批量加到 deploy-web/backend/frontend/openresty 4 个脚本

## 详细 sprint report

`/home/test/newworld/docs/sprint/2026-05-29-peak-perf-debate/sprint-report.md` + `/phase4-n9e-trace-evidence.md`


---
**并入摘要（原 fe_perf_phase1_2026_05_29.md，2026-07-07 memory 整理；全文在 git 历史 claude-shared）**
- **PRIORITY 1**: Edge-perf investigates why CN traffic 0% to HKG. May need:
- **PRIORITY 2**: R2 cdn-failover weight by user's likely cfPop, not just HRW
- **PRIORITY 3**: SW precache top 5 JS chunks (main entry + Home + Player + Vue+Vendor)
- **PRIORITY 4**: Cache Reserve for /assets/*.js on main zone
---
name: project_arch_lock_california_2026_06_08
description: 2026-06-08 arch-lock sprint 钉死加州必要性+steering;含 bare-IP vs pinned-egress-tunnel artifact、RUM循环、基准混用三个可复用方法论坑
metadata: 
  node_type: memory
  type: project
  originSessionId: 64b5f5d1-9590-4971-9f5b-8d2e351a83eb
---

2026-06-08 nw-arch-lock sprint（team-lead + arch-analyst + probe-ops + blue-team，BSP+barrier）钉死两件事：Q1 加州(us-west-1)必要性、Q2 dynamic_latency vs static-geo steering。SOT=`docs/sprint/2026-06-08-region-final-migration/RESULT-california-necessity-RUM-gate-2026-06-08.md`（顶部「✅ FINAL-A」段为定稿）+ `RESULT-Q2-steering-dynamic-vs-geo-2026-06-08.md`。

**verdict = A：加州值得建，终态 3 region（FINAL-A 定稿，blue-team 稳定性终审/lead barrier）**。3 时段确认轮冷数据：LAX(47%)加州delta E1/E2/E3=48.7/46.7/47.3 pooled +46.8ms（std 0.84ms铁稳/cf-ray 0漂移/1.6×过30闸）；SJC +40.3恒正；SEA −7.6偏俄勒冈。SJC倒置彻底证伪=旧warm单时段artifact。CA-cohort加权A域46.6/P域46.9ms。
- **终态3 region**：加州us-west-1(web×2+只读replica,服务LAX/SJC 47%+7.5%)+俄勒冈us-west-2(**master零搬运**,服务SEA/PDX 42%)+法兰克福eu(web+只读replica)。HK退役。
- **master留usw2不搬加州**：写仅4.2%/~41TPS,加州是additive只读区,加州写走backbone~20ms可接受→**推翻§10老候选"master加州"**。
- **双峰分裂**(LAX要加州−46.8/SEA要俄勒冈−7.6,无单一US region全服务)=双US区物理依据,verdict A铁稳下稳健。
- **落地**:加州region搭建(web×2 M系列+read-replica复制源usw2+tunnel+CIDR 172.34/16+peering三角usw1↔usw2↔eu+readiness gate G0-G7),每region≥2节点。
- **dynamic_latency**:3池下紧迫性从"低"上调(手工geo编排LAX→加州/SEA→俄勒冈易错),随加州上线一起切,可逆。
- **Argo**:账号没provision、收益外推待验、治不了edge-proxy~28ms+物理LAX→PDX距离→不作加州替代。
- **多轮翻盘轨迹+锚定惯性教训**:raw-TCP→倾向collapse；CF路径→骑跨闸；prod-tunnel单轮→双峰48.8；epoch1冷→做强加州；**3时段确认轮std 0.84铁稳→A**。arch-analyst连续几轮往collapse收(锚定惯性),epoch1/3时段冷数据纠偏；翻盘sprint"不锚自己上一版结论+不盲从单轮+每翻盘证伪"是硬要求。

**三个可复用方法论坑（本 sprint 连环翻盘的根源，下次 region 选址必查）**：
1. **bare-IP vs pinned-egress-tunnel artifact**：裸 IP 探针 time_connect 比真实 CF 路径**低估**——prod 用 cloudflared named tunnel + **pinned egress**(usw2 egress 钉 PDX)，裸 IP 无钉桩。LAX 经 tunnel 被钉桩背驮全程到 PDX → delta 从裸 13.5ms 放大到 48.8ms。**选址实测必走真 tunnel 路径，不能用裸 IP RTT 当代表**(裸 IP 是 artifact)。但仍须多轮(cf-tunnel-edge 铁律)，且裸/tunnel 两轮 vantage 不严格一致会导致对照失效(本 sprint SJC 出现 bare39>tunnel23.6 倒置=对照失效非浮动,浮动不改方向)。
2. **RUM 循环(BLOCKER-17)**：要 canary 真 RUM 测"该不该建 region"→需"全栈 region origin(带本地 replica)"=已经把 region 核心建了→测试≈建设成本。解法=**轻量 origin(无 replica,读跨区)→RUM 是终态收益下界**(终态有 replica 再快~10ms);阈值 轻量>30→建/<20 仍不排除终态过闸。**推论:RUM≈建 region 成本本身 = "先 collapse、region 延后" 的论据**,不该用 RUM gate 可逆基线。
3. **测量基准混用**：CF monitor 给 **raw RTT**,curl 给 **TTFB**,二者 **TTFB≈1.94×monitor**(本 sprint SJC 实测系数)。混用(一 cohort 用 monitor 一 cohort 用 TTFB)会得出假结论。**同一对比必须同口径**。

**BSP 多 agent 教训**：arch-analyst 经历 collapse↔加州 多次翻盘(raw-TCP→CF路径→prod-tunnel),每轮 lead 喂新数据/二查纠基准混用,arch-analyst **不锚自己上一版结论、不盲从单轮数据、每翻盘做证伪攻击(Argo-first 3 攻全 HOLD)**。配套 [[feedback_verify_not_recall]]、[[project_region_ha_topology_2026_06_08]]、[[project_region_cutover_false_alarm_2026_06_08]]。skill：newworld-cf-tunnel-edge-region-placement。

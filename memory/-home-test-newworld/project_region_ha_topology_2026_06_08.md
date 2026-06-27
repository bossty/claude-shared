---
name: project-region-ha-topology-2026-06-08
description: region ×2 HA 拓扑分析结论：US 需俄勒冈+加州双region(CN入口混合SEA/LAX/SJC)、EU 同region第2节点(滚动升级)、CF tunnel edge 浮动非AZ确定
metadata: 
  node_type: memory
  type: project
  originSessionId: 64b5f5d1-9590-4971-9f5b-8d2e351a83eb
---

# region HA 拓扑分析（2026-06-08，fullcut-5xx 后续）

**起因**：region 当前各单节点单 AZ（US us-west-2a / EU eu-central-1a，均 m5.xlarge）。要补 ×2 HA，分析同 AZ vs 跨 AZ + LZ/WZ。

**团队**：`nw-region-ha-arch`（architect-reliability + architect-pragmatic 独立分析 → reviewer-arch 蓝军 crossfire）。两架构师收敛"跨 AZ 占优、CF 边缘多样性是伪收益(anycast 理论)、LZ/WZ 无用"。蓝军加 2 BLOCKER（cross-region 框外解 + slave-SPOF）。

**owner 反诘 + 实验推翻理论**（铁律：owner 直觉当严肃提案 + 做实验论证）：
- 团队凭 cdn-cgi/trace(HTTP anycast 全 PDX) 判"同区跨 AZ 同 colo=伪收益"。
- 实测 cloudflared **tunnel** 层：us-west-2 节点 edge 在 PDX(pdx02/03)/SEA(sea01) 间**浮动**——tunnel edge ≠ HTTP anycast colo。
- **但 run-2(2b/2d→SEA)→run-3(2b/2d→PDX) 推翻"AZ 确定 edge"**：edge 是 per-连接/时间浮动，非 AZ 函数。**教训：单样本会骗人，确认轮是对自己的纪律（我 run-2 过度解读、run-3 自纠）。** → 不能靠选 AZ 定向 edge；真 edge 差异靠跨 region。

**硬证据 = cf_ray colo 入口分布**（origin 选址罗盘）：
- **US**：CN 流量 SEA 45%(贴俄勒冈) / LAX+SJC 53%(贴加州) / 混合 → **US 是唯一需多 region 的地区**。
- **EU**：AMS 主导(+LHR) = 单都会区 → 不需多 region。

**决策（owner 拍）**：
- **US 第 2 节点 = us-west-1（加州）** > 同区第 2 AZ：拿 CN 近源(53% LAX/SJC) + 跨 region HA + 真 edge 多样性。
- **EU 第 2 节点 = 同 region**（AMS 单都会区，无多 region 价值）；目的=滚动升级不降级（单节点 region 升级时 OpenResty failover HK backup=跨洋+POST 5xx，"流量打不开"）。同 AZ 已够，跨 AZ ~零成本可顺带。
- slave/Redis replica HA = 另立 sprint（本轮只 web）。
- LZ/WZ 不采用（无近 CN 适用区 + CF Anycast 已在前）。

**配套 skill**：[[newworld-cf-tunnel-edge-region-placement]]（实证法+罗盘）、[[newworld-multiregion-crossocean-hotpath]]（升级降级机制）。
**凭据**：本地 `AWS_PROFILE=nw-dev`(账号 748579767645) 有 EC2 RunInstances/Terminate/describe；region 节点无 IAM role。
**终态锁定候选（owner 对称设计 2026-06-08）**：加州 us-west-1(web×2+DB/Redis master+aws-data) / 俄勒冈 us-west-2(web×2+replica) / 法兰克福 eu(web×2+replica)；HK 全退役；124 域多 region；异步星形复制。**us-west-1 RUM 为唯一总闸**（>30ms→锁本设计 master 加州；<30ms→collapse us-west-2+EU master 零搬运）。master 迁移=架构驱动非性能（E1 写仅 4%/41tps）。sizing：web m5.xlarge×2/区、master 可降 r6i.xlarge、replica r6i.large~xl。
**进度（2026-06-08 晚）**：A 域 58/59 已 geo 放量(0 5xx,旗舰 17.rip 待切)；架构共识完成待 RUM 锁；master/aws-data 迁移/HK 退役/P 域未启动。
**编排**：A 完测→架构 RUM∥dynamic_latency 评估→P 域打通调研(最大块,gates HK 退役)→master+aws-data 迁 US→HK 退役。
**全量状态锚点**：`docs/sprint/2026-06-08-region-final-migration/SESSION-STATE-2026-06-08.md`（post-compact 先读）。
**实测关键数**：CN 入口 A 域=加州54/SEA42；P 域(多数)=美区64(加州35/SEA29)/EU31；CF tunnel edge 按实例浮动非 AZ 可控。
**待清理**：亚洲 12 国 country_pools=[hk] HK 退役指空池；跨池 failover=off；CF monitor 调<15s；max_conn 500→700。

---
name: project_gfw_reach_fusion_phase4_2026_07_01
description: GFW 阶段4 reach:grid 多源贝叶斯融合（probe先验+RUM joint证据）已合 master dark（2026-07-01，SDD 6 task）
metadata: 
  node_type: memory
  type: project
  originSessionId: 03626fd7-7b4d-447f-9faf-2df37f0330ea
---

GFW 主线阶段4：reach:grid 从单源探针升级为「probe 当先验 + RUM joint 当证据」的 Beta 后验融合。**已 --no-ff 合 master `097c9cba`（feat/gfw-reach-fusion 退役），flag 默认 dark=零 live 变更**。部署 + 翻 flag 火测为后续独立授权步骤（未做）。

**核心模型（brainstorm 多轮定，spec=docs/superpowers/specs/2026-06-30-gfw-reach-fusion-design.md）**：
- reach:grid 一格 = Beta 后验。**probe=先验** `Beta(c·r_p, c·(1−r_p))`，浓度 c=节点数×新鲜度衰减；**RUM joint succ/fail=证据**；消费 reach=后验 **Wilson score 下界**（均值参数化 n=α+β/p̂=α/n，非众数；q5%→z1.645）。
- 非对称"先验/证据"结构（替掉早期对称权重）：天然解决无数据(1.0)→稀薄数据跳变 + 幸存者偏差天然被压。fail-open=1.0 沿用。
- **joint RUM 关键洞察（Owner fact-check 逼出）**：ingestion(DomainReportController)每 beacon 本就解出 isp+省，只是存两个边际丢了联合→加写 joint 键，joint-to-joint 融合零边际假设。**只有上轮 IP 库修复(省解析出真值)后才有意义**。

**数据流（5min，唯一消费写者无冲突）**：探针写 `reach:grid:probe:{域}:{isp}:{省}`(+node_count) + ingestion 写 `domain:report:joint:{域}:{isp}:{省canonical}:{yyyyMMddHHmm-5min桶}` + isp级 `_ANY_` 桶 → 新 `ReachFusionService`(admin,5min,SCAN 探针层)读两源 Beta 融合 → 写消费键 `reach:grid:*` src=fused。**ReachGridReader/pick-p/reachHint/DomainPoolService 零改动（消费方透明，git diff 自检空）**。
- flag **`REACH_FUSION_ENABLED`**（system_config，运行时 `SystemConfigService.getValue` 每轮读，读失败 fail-safe→dark）默认 false=dark：dark **全字段透传探针层**(含 ts/wildcard_ok/code/block/node_count)=字节级 net-zero；火测翻 flag 同 3a 走 admin 配置接口 DB+pub/sub 秒回滚、不重启。

**SDD 过程（subagent-driven，6 task，每 task TDD+逐 task 蓝军+fix loop+whole-branch review）**：3665/3665 绿。Task1 ReachFusionMath(纯数学)/Task2 ingestion joint/Task3 探针改键+node_count/Task4 ReachFusionService/Task5 回归门禁/Task6=最终 whole-branch review 逮 2 跨 task MAJOR 的修复。
- ★★**whole-branch review 抓住单 task review 看不见的两个跨 task 语义 bug**（教训：集成缺陷要整分支视角）：
  - **MAJOR-A**：joint 键 succ/fail 被 coalescingBuffer TTL 永刷新→**无限累积**+fusion 只读不 reset+ts≈now→τ_rum 衰减失效→fused 吃全历史、probe 先验被淹、**新被封高流量域累积巨量 succ 不被拉下=幸存者守卫反转**。修=joint 键 5min 分桶(TTL 25min)+fusion 读最近 3 桶窗口(有界、衰减复活)。
  - **MAJOR-B**：ingestion 只写具体省、fusion `_ANY_` 聚合格永远 probe-only。修=ingestion 加写 isp级 `_ANY_` 桶(isp 有效 && province!=overseas，保留 other)+fusion `_ANY_` 格读它。
- 早期 task review 也逮真问题：B1(flag 须运行时 configService 非静态@Value 否则无秒回滚)、M1(dark 须全字段透传否则非真 net-zero)、Wilson 用均值非众数(众数 β≤1 时 p̂>1 非法)、τ 是 e-folding 非半衰期。

**部署（2026-07-01 02:xx HKT，--force-peak）已完成 + dark net-zero 实测验证**：web×6 deploy-web.sh 零停机(全✓无5xx) + admin `newworld-admin-p4-097c9cba.jar`(rollback ref=newworld-admin-3a-d0204537.jar)。实测数据流：ingestion 写 `domain:report:joint:{域}:{isp}:{省}:{yyyyMMddHHmm}` 桶+`_ANY_`桶(含 other:_ANY_)LIVE 正确；探针写 `reach:grid:probe:*`(含 node_count)；fusion(5min)dark 全字段透传写消费键 src=probe 值=探针值(实测某格 node_count=71 reach=0.9577 探针↔消费一致=字节级 net-zero 证实)；flag REACH_FUSION_ENABLED 缺省=dark；3a pick-p(flag ON)读消费键不受影响(fusion 维护=同探针值)。★迁移坑:探针 skip-fresh 标记 pre-restart 仍有效→boot 探针轮先跳过部分域、probe:* 增量填充(非瞬时);旧消费键 TTL 兜底+fusion 接管前 fail-open=1.0(安全自愈)。启动 burst 一次性 Redis timeout(SiteStatsSyncTask HSCAN,02:30:03-06,不复发,与阶段4 无关)。**火测 runbook（Owner 定：probe:* 稳态后火测，~2026-07-01 06:30 HKT 左右；翻 flag 必经 Owner 授权 + 密监，同 3a）**：
1. 前置验证：`reach:grid:probe:*` 充分填充（count 接近历史 ~13814、fresh 标记多数已重探）；`domain:report:joint:*` 近几个 5min 桶有 succ/fail 累积。
2. 翻 flag（同 3a 机制，admin 配置接口 DB+pub/sub，**非裸 SQL-only**）：`UPDATE/INSERT system_config SET config_value='true' WHERE config_key='REACH_FUSION_ENABLED'` + `redis PUBLISH shared:ch:sysconfig-refresh "*"` + `INCR shared:system-version`（DB_HOST/REDIS 从 /proc/$(MainPID)/environ 取）。
3. 密监 5-10min：消费键 src 从 probe→**fused**（fusion enabled 路径）；reach 分布出现更多**真实用户证据驱动的 <1.0 格**（融合非空操作）；pick-p `ops_pick_p_total{status=fail}` 率不升（3a flag ON，pick-p 直接吃融合值）；N9E `PICKP-REACH-FAIL-RATIO`(id=108) 不响；admin journal 无错、Redis 未被 fusion SCAN 压垮（5M DAU 规模留意）。
4. 异常秒回滚：`config_value='false'` + republish。
5. ★方向核查：抽 fused 格对比——真实用户 fail 多的格 reach 被拉下、probe 判封格不被幸存者抬起（MAJOR-A 修复在产证据）。
**★★火测未通过已回退（2026-07-01 10:05→10:11 HKT，Owner 在场）**：翻 `REACH_FUSION_ENABLED=true`→t+5min fusion 切 fused→**发现 fused reach 崩塌**（probe=1.0 的格 fused≈0.05-0.13，分布 291/300 <0.5、[0.90-1.0]零格）→10:11:18 紧急回退(config=false+publish)→~10:14 recovery 确认(src 全回 probe、reach 回 1.0)。全程 pick-p fail=0、N9E id=108 未响、无停机；impact=~5min 噪声选址(低峰晨)。
- **★根因（火测独有运行时发现，单测抓不到，==关键教训==）**：保守 Wilson 下界对**小样本**天然很低，而**真实 exact (isp×省) 格 probe node_count≈2**（只 `_ANY_` 聚合格才 71）→ 即使新鲜 Wilson 下界才 ~0.43；叠加 **τ_probe=2h 衰减 vs ~3h 探针轮**→轮间先验浓度衰减近零→Wilson 砸到 ~0.1；多数 exact 格无匹配 RUM(RUM 集中 _ANY_/有流量省)无证据抬升。单测用 node_count=5/10/20+age=0(Wilson~0.6-0.8)故全绿但生产崩。**教训：Beta+保守下界的融合，先验浓度必须实证真实 node_count/age 分布再定参，否则低样本格被下界碾**。
- **修复方向（下一轮，未做）**：① 乐观先验地板(低 node/aged 格保持≈probe，RUM 从那儿移动) 或 ② 后验均值代下界(Owner 原选下界=此崩塌来源,需重议) 或 ③ τ_probe 衰减设地板不塌零 + node_count 太小时提升先验浓度(_ANY_ 聚合 node 补 exact)。需 brainstorm→改→**重火测前必先离线用真实 probe node_count/age 分布验算 fused 分布不崩**。
- 现状：flag `REACH_FUSION_ENABLED=false`(已显式回退,非缺省)，dark 稳态；阶段4 崩塌版代码在 master(097c9cba)+部署 p4 jar 不变(dark net-zero 仍成立)。
- **★修复已实现+离线验算 PASS(2026-07-01，分支 `feat/gfw-reach-fusion-estimator-fix` off 097c9cba，待 Owner 授权合/部署/火测)**：3 人研究团队一致通过=**Wilson 下界→Beta 后验均值 α/(α+β)**(=BLUE/收缩估计;引 Brown/Cai/DasGupta 2001、Efron-Morris 1973、Gelman BDA3、Evan Miller 2009)。核心：probe=1.0 无 RUM→**精确 1.0**(浓度无关,根治小样本崩)。幸存者门=**常数 floor `max(probe,0.05)` 只压 succ、fail 不门控**(团队 cross-fire 否决 freshness 门=正常轮龄 3h 就泄漏幸存者→黑洞;组员2 BLOCKER,组员1/3 认输改票)。无 baseline 先验、fail-open。fuse 签名 `(probeReach,nodeCount,probeAgeMs,rumSucc,rumFail,rumAgeMs,FusionParams(probeWeight=8,tauProbeMs=6h,tauRumMs=0.5h,gateFloor=0.05))`。ReachFusionService 对齐(拆了 param 错位地雷)。加 `ReachFusionReplay` 离线门禁工具(spec §4.1 四条 gate:①probe高fresh不崩②可达子集中位数③封锁格④Spearman排序,+total/reachableCount fail-loud,每条有 kill-path 测试)。SDD 3 task+逐 task 蓝军+最终 whole-branch review READY-TO-MERGE(0 blocker)。**★离线验算门禁在真实 13626 格快照 PASS**：崩塌根治(火测 291/300<0.5 → 现 12663/13626=93%≥0.99、仅 248=1.8% 真封锁格<0.2,Spearman 0.99 贴合 probe);标定 **PROBE_WEIGHT=8**(PW=5 有1格 fresh<0.8 FAIL,≥8 干净过)。**★★已合 master `be5fe5c4` + 部署 admin(`newworld-admin-fix-be5fe5c4.jar`,回退 ref=p4-097c9cba)+ 重火测 PASS 保留 ON(2026-07-01 15:03 HKT,Owner 授权)**：翻 REACH_FUSION_ENABLED=true→t+5min src→fused→**崩塌根治实证**：上次火测同批格 291/300<0.5，这次 src=fused 后 reach 分布 HELD(<0.2=7/≥0.9=383 of 400 全程 11 样本稳定)、曾崩的 vitalclub.rest:unicom:贵州 等 fused=1.0000=probe(精确跟随)、分布 372/400=93%≥0.99;pick-p(3a flag ON 读 fused 消费键)source=reach 服务正常 fail_total=0、N9E id=108 0 活跃、admin journal 净。**flag 现 LIVE=true(fused 模式在产)**。阶段4 融合正式生效。后续 backlog：探针陈旧熔断(§4.2 follow-up)、5 条 MINOR(FusionParams compact-constructor 校验等)、两份 reach 读层提取 common。
**MINOR backlog**（N1 fused 路径 wildcard_ok、窗口单 rumAge）。(看 src=fused 占比/reach 分布出现真实用户驱动 <1.0 格/pick-p fail 不升/N9E id=108)；MINOR backlog(N1 fused 路径 wildcard_ok 透传待 Phase2、窗口单 rumAge 衰减)。相关 [[project_gfw_3a_flag_activated_2026_06_30]] [[project_gfw_ipdb_rum_fix_2026_06_30]] [[project_gfw_parked_phases_consolidation_2026_06_30]]。

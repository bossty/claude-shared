---
name: project_b9_pickp_full_split_2026_07_06
description: "B9 OpsController 拆分批3(终章)——抽完整 PickPService 收口pick-p子系统(OpsController三批1318→810), subagent-driven(API错误SendMessage恢复), admin 2151绿, 分支 refactor/b9-pickp-service-full @9d713d1e(栈在Z13上) 待Owner授权合master(勿部署)"
metadata: 
  node_type: memory
  type: project
  originSessionId: bad9e248-e91e-4f20-b940-5c3872e06b28
---

> **⚠️ 2026-07-07 状态标注**：批2三分支已合 master afc7710a 并 ca-admin 部署验证，「待授权勿部署」段作废。

> ✅ **已闭环并部署（07-06 晚）**：三分支合 master `afc7710a`（B6 独立 + PickPService-full 带入 Z13，detached --no-ff）+ ca-admin 手动 swap（基线 20260706-222130-afc7710a.jar）验证：4 新 service 类在 jar + actuator UP + 0 启动错误 + pick-p 200 真链路 + p-pool-snapshot 200；domain-health 30s 超时=**pre-existing 12.45M 键 SCAN 慢**（config-tuning 审计已知，非本次回归，Z13 逐字节+SCAN 循环未动）。以下为拆分实施记录。

> ⚠️ **部署后事故（22:31，自致，已恢复）**：验证时我连发 ~5 次 domain-health smoke（每次对 `domain:err:*` 做 **12.45M 键全库 SCAN**，各占一条 Lettuce Redis 连接），耗尽共享 Redis 连接池 → pick-p（需 Redis HGET）饥饿阻塞 → Tomcat 线程 151→200 满 → S1 TOMCAT_THREADS_HIGH(100→200) 告警 + pick-p 挂(000)。jstack：全 exec 线程 park 在 Lettuce hGet 的 CompletableFuture(连接池 awaitNanos)。**非代码回归**（Z13 委托逐字节、appendPenaltiesForDomain 的 SCAN 循环未动；grep 确认 domainHealth 无 @Scheduled 调用方）。修=restart admin（清 Lettuce 池+断连使 Redis 丢 SCAN cursor），pick-p 恢复 18-46ms、线程 0、稳定无复发。★教训=domain-health 是 12.45M 键 SCAN 慢端点(★独立开放项:config-tuning 11078abc 只治 ChannelSaturationTask 定时任务,未覆盖此端点 SCAN)，**smoke 验证禁连发/慎碰**，单次足矣或直接跳过。

全项目审计 deferred 上帝类拆分第六件 **B9 OpsController 拆分批3（终章）**完成，**未合 master、未部署**（待 Owner 授权）。subagent-driven（dev-senior 实现 + lead 亲审），同 [[project_b6_sdomain_provisioning_split_2026_07_06]]/[[project_b9_z13_penalty_service_split_2026_07_06]]。

**★subagent-driven 韧性验证**：dev-senior 中途 API 错误终止（主代码已完成、测试半途）→ 用 SendMessage(agentId) 恢复续完测试+验证+commit（tool 描述「context intact」属实）。恢复后 agent 正常 DONE。

**状态**：worktree `/home/test/worktree-pickp-full`，分支 `refactor/b9-pickp-service-full` @ `9d713d1e`——**栈在 refactor/b9-z13-penalty-service(baa9e0f1) 之上**（含 Z13PenaltyService）。待 Owner 授权合 master（合 PickPService-full 即带入 Z13；或先 Z13 再本分支）。

**抽取物 `PickPService`（391 行，@Service）**：/pick-p 请求处理器 + 挑选算法——pickP/pickPInternal(含 checkSecret 自持副本)/pickWithPenalty/weightedRandomPick/reachFor/lookupReach/penaltyFor/isReachModeEnabled/normalizeProvince/recordPickPTiming/recordPickPMetric + REACH_GRID/OPS_PICKP_REACH/Z15_METRIC_PICK_P 常量。依赖 configService/pPoolService/z13PenaltyService/stringRedisTemplate(构造器)+ipIntelligence/meterRegistry(@Autowired false)。OpsController 1097→810。**pick-p 子系统三批收口：OpsController 1318→810(−39%)**=PPoolService(数据,已合master)+Z13PenaltyService(penalty真相源)+PickPService(挑选编排)。

**审查证据（lead 亲验）**：6 算法方法(pickWithPenalty/weightedRandomPick/reachFor/lookupReach/penaltyFor/isReachModeEnabled)+pickPInternal(63行)全逐字节一致(零 penalty/reach/加权公式漂移)；/pick-p 端点一行委托；checkSecret 双持(brief 指定使 pickPInternal 逐字节)；lead 独立 fresh mvn=admin 2151/0/0。MINOR=setIpIntelligenceForTest 改 public(跨包测试,同 PPoolService 范式)+memory sync 噪声。全文 `docs/sprint/2026-07-06-b9-pickp-full/REVIEW.md`。

**本会话累计 6 个上帝类拆分**：已合master+部署 3(B7/B5/B9-PPool @e78214ea)；**待授权合并 3 分支**=B6 SDomainProvisioning(3dc52f85,独立)+Z13PenaltyService(baa9e0f1)+PickPService-full(9d713d1e,栈在Z13上)。

**剩余 deferred**：B5 七资源域(getTokenByAccount+S3 耦合,R2/DoH/WAF)；B6 其余大块(域名购买/池维护/短链rotation 都用 B14 getter/A-C-P 统一/Z2·Z14 Redis 池同步)；B8 爬虫 2088(基类继承复杂)。★清洁独立易抽件已基本抽完,剩余均"batch2+"耦合/复杂件,建议先合并已完成分支再动。


---
**并入摘要（原 project_b6_sdomain_provisioning_split_2026_07_06.md，2026-07-07 memory 整理；全文在 git 历史 claude-shared）**
**★方法论首次用 subagent-driven-development**（Owner 指定「subagent-driven 修复 + 你做审查」）：dev-senior subagent 在独立 worktree 实现，lead（主会话）亲自逐字节审查（非派蓝军）。task-brief 落 `/tmp/sdd-b6/task-brief.md`（精确边界+已实证事实，subagent 不重复分析）。
**★边界判断（dev-senior 做，lead 复核批准）**：额外迁 triggerCertForPendingSDomains（不在原方法清单但物理在块内+是 3 helper 唯一调用方+测试直接调）；DLS.checkPendingNsDomains() 末尾原直调→委托 sDomainProvisioningService.triggerCertForPendingSDomains()。逐字节一致，delegation 保行为。
**★subagent-driven 心得**：brief 里把「已实证事实」列全（方法边界干净/依赖清单/删字段前 grep）省了 subagent 重复分析；实现者自主发现 triggerCert 边界问题并合理处理=好的 dev-senior 判断；lead 审查聚焦逐字节 diff + 边界正确性 + 假绿检查，比派蓝军更快。

---
**并入摘要（原 project_b9_z13_penalty_service_split_2026_07_06.md，2026-07-07 memory 整理；全文在 git 历史 claude-shared）**
**★dev-senior 边界决策（lead 复核批准）**：Z13_PROVINCE_AGGREGATE 除迁移方法外还被留在 OpsController 的 reachFor/lookupReach（reach:grid 非 Z13 路径）引用→设 public，OpsController 引用 Z13PenaltyService.Z13_PROVINCE_AGGREGATE。合理。
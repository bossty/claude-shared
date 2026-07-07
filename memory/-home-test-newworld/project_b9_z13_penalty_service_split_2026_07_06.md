---
name: project_b9_z13_penalty_service_split_2026_07_06
description: "B9 OpsController 拆分批2——抽 Z13PenaltyService(penalty原语单一真相源, OpsController 1202→1097)，subagent-driven(dev-senior+lead亲审)，admin 2151绿，分支 refactor/b9-z13-penalty-service @baa9e0f1 待 Owner 授权合master(勿部署)"
metadata: 
  node_type: memory
  type: project
  originSessionId: bad9e248-e91e-4f20-b940-5c3872e06b28
---

> ✅ **已闭环并部署（07-06 晚）**：三分支合 master `afc7710a`（B6 独立 + PickPService-full 带入 Z13，detached --no-ff）+ ca-admin 手动 swap（基线 20260706-222130-afc7710a.jar）验证：4 新 service 类在 jar + actuator UP + 0 启动错误 + pick-p 200 真链路 + p-pool-snapshot 200；domain-health 30s 超时=**pre-existing 12.45M 键 SCAN 慢**（config-tuning 审计已知，非本次回归，Z13 逐字节+SCAN 循环未动）。以下为拆分实施记录。

全项目审计 deferred 上帝类拆分第五件 **B9 OpsController 拆分批2**（承接已合 master 的 B9 PPoolService 批1）完成，**未合 master、未部署**（待 Owner 授权）。subagent-driven（dev-senior 实现 + lead 亲审），同 [[project_b6_sdomain_provisioning_split_2026_07_06]] 方法论。

**状态**：worktree `/home/test/worktree-b9-z13`，分支 `refactor/b9-z13-penalty-service` @ `baa9e0f1`（基于 origin/master 541ea633）。待 Owner 授权 detached --no-ff 合 master；部署 admin 单实例手动 symlink swap。

**抽取物 `Z13PenaltyService`（142 行，@Service，构造器注入 stringRedisTemplate）**：Z13 域名 err-rate penalty 原语单一真相源——常量(Z13_KEY_ERR/PV/MIN_PV/ERR_RATE_FLOOR/PENALTY_EXPONENT/PENALTY_BASE/PROVINCE_AGGREGATE) + 5 方法：parseZ13ErrKey/parseLongSafe(纯 static)、readHashCount(stringRedisTemplate)、computeZ13Entry(纯公式返 Map)、lookupPenaltyPoint(实时单查返 double)。OpsController 1202→1097(−105)；两批累计 1318→1097。

**消费者（都改委托）**：domain-health 端点（批量 SCAN 聚合，用 parseZ13ErrKey/readHashCount/computeZ13Entry）+ pickWithPenalty（实时，用 lookupPenaltyPoint）。消解「公式与 computeZ13Entry 完全一致」重复风险，为后续完整 PickPService 铺路。

**审查证据（lead 亲验）**：5 方法规范化 diff 全逐字节一致（computeZ13Entry/lookupPenaltyPoint 仅 +public 修饰符跨包委托需要，体不变）；新 service 调 OpsController=0/B14 getter=0；委托 6 点+0 漏改；Z13PenaltyServiceTest 8 tests/24 断言真跑；admin 2151 全绿。

**★dev-senior 边界决策（lead 复核批准）**：Z13_PROVINCE_AGGREGATE 除迁移方法外还被留在 OpsController 的 reachFor/lookupReach（reach:grid 非 Z13 路径）引用→设 public，OpsController 引用 Z13PenaltyService.Z13_PROVINCE_AGGREGATE。合理。

**MINOR**：commit 夹带 claude-shared/memory sync 噪声（无代码风险，历次均有）。全文 `docs/sprint/2026-07-06-b9-z13-penalty/REVIEW.md`。

**剩余 deferred**：完整 PickPService（pickWithPenalty 迁出，用 PPoolService+Z13PenaltyService，现两依赖都就绪）；B6 其余大块(域名购买/池维护/短链rotation 都用 B14 getter/A-C-P 统一操作/Z2·Z14 Redis 池同步)；B8 爬虫 2088(基类含继承复杂,非纯 service 抽取);B5 七资源域。

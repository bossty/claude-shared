---
name: project_b9_ppool_service_split_2026_07_06
description: B9 OpsController 上帝类拆分批1——抽 P 池数据访问层 PPoolService(1318→1202行)，已实现+admin 2146测试绿+蓝军过，分支 refactor/b9-pickp-service @adcf0eba 待 Owner 授权合 master(勿部署)
metadata: 
  node_type: memory
  type: project
  originSessionId: bad9e248-e91e-4f20-b940-5c3872e06b28
---

> ✅ **已闭环（07-06）**：三上帝类拆分分支全合 master `e78214ea`（detached --no-ff）+ 全部署验证（web×6 deployed/web=e78214ea / ca-admin 手动 swap 基线 20260706-085346-e78214ea / fe-web×6 deployed/frontend-web=e78214ea，swiper12 生产双引擎四象限 hero 渲染 0 错）。以下为拆分实施记录。

全项目审计 deferred 上帝类拆分第三件 **B9 OpsController**（1318 行）第一批完成实现+验证，**未合 master、未部署**（Owner 明示等指令）。

**状态**：worktree `/home/test/worktree-b9-pickp`，分支 `refactor/b9-pickp-service`，本体 commit `26e9a9ca`（doc fix 已 amend），已 merge 最新 master（HEAD `adcf0eba`，干净可合）。待 Owner 授权后 detached HEAD --no-ff 合 master；部署另等指令（admin 单实例 jar 手动 symlink swap）。

**范式**：比照 [[project_movieservice_god_class_split_2026_07_04]]/[[project_b7_configcontroller_split_2026_07_06]]「只抽干净件」。审计 B9 建议「抽 PickPService」，但**实证 pickP 逻辑与 domain-health 端点经 Z13 penalty 原语纠葛**（同 B7 DomainClassResolver 判断）。

**抽取物 `PPoolService`（165 行，@Service，构造器注入 stringRedisTemplate+domainMapper）**：P 池加载/快照/打分（零 Z13 耦合的唯一干净件）——loadPPool/loadPPoolFromRedis/loadPPoolFromDb/loadPPoolSnapshot/computePScore + records(PDomainWeight/PPoolSnapshot public) + 2 Caffeine 缓存(60s, maximumSize=1) + 常量 + invalidateCachesForTest。三级降级 Caffeine→Redis ZSet `shared:global:p_pool`→DB。OpsController 1318→1202(−120)。

**控制器改造**：pick-p/p-pool-snapshot 端点委托 `pPoolService.loadPPool()/loadPPoolSnapshot()`；pickWithPenalty/weightedRandomPick(留控制器)签名改用 `PPoolService.PDomainWeight`；invalidateZ15CachesForTest 委托；删死 import ZSetOperations/BigDecimal。

**★推迟的 Z13 纠葛部分（同 B7 DomainClassResolver）**：pickWithPenalty 的 pick/penalty 逻辑与 **domain-health 端点**共享一批 Z13 penalty 原语——`computeZ13Entry`(纯 penalty 公式，仅常量)、`readHashCount`、`parseZ13ErrKey`、`parseLongSafe`；代码注释明写「公式与 computeZ13Entry 完全一致」=已知重复风险。干净抽 pickWithPenalty 需先立共享 `Z13PenaltyService`（两端点共用），属独立前置，本批不动。

**验证**：admin 模块 mvn test **2146 全绿**（2141 + 新建 PPoolServiceTest 5）；PickPTests 8/8、PPoolSnapshotTests 5/5 端点集成经真实 PPoolService 跑。蓝军：降级链/打分(health×weight/100)/version(bucket+ConfigVersionRegistry&0xFFF)/304 ETag 逐字节等价，无 BLOCKER/代码 bug；唯一 MAJOR 是 DESIGN.md 措辞不实(写"迁移测试"实为新建覆盖，已订正)。

**★教训**：@InjectMocks 对新增构造依赖(PPoolService)不自动注入(无 @Mock)→setUp 手动 new + 反射 setField；records 迁出后跨类引用改前缀(sed PDomainWeight→PPoolService.PDomainWeight，defs 删后全局安全)。

**本会话累计 3 个上帝类拆分分支待 Owner 授权合 master**：[[project_b7_configcontroller_split_2026_07_06]](web) + [[project_b5_cf_http_client_split_2026_07_06]](admin CfHttpClient) + 本 B9(admin PPoolService)。

**剩余 deferred**：B9 的 Z13PenaltyService+完整 PickPService(需先前者)；B5 的 7 资源域拆分；B6 DomainLifecycleService 2259(★B14 测试级联雷)；B8 爬虫 2088。DESIGN 全文 `docs/sprint/2026-07-06-b9-pickp-service/DESIGN.md`。

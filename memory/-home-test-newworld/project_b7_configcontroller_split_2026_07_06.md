---
name: project_b7_configcontroller_split_2026_07_06
description: B7 ConfigController 上帝类拆分（抽 FvdFirstVisitService + ChannelPromoPoolService）——已实现+测试绿+蓝军过，分支 refactor/b7-config-split @3e4ac562 待 Owner 授权合 master（勿部署）
metadata: 
  node_type: memory
  type: project
  originSessionId: bad9e248-e91e-4f20-b940-5c3872e06b28
---

> ✅ **已闭环（07-06）**：三上帝类拆分分支全合 master `e78214ea`（detached --no-ff）+ 全部署验证（web×6 deployed/web=e78214ea / ca-admin 手动 swap 基线 20260706-085346-e78214ea / fe-web×6 deployed/frontend-web=e78214ea，swiper12 生产双引擎四象限 hero 渲染 0 错）。以下为拆分实施记录。

全项目审计 deferred 上帝类拆分第一件 **B7 ConfigController**（1026→699 行，−32%）完成实现+验证，**未合 master、未部署**（Owner 明示「改完不要部署，等指令」）。

**状态**：worktree `/home/test/worktree-b7-config`，分支 `refactor/b7-config-split` @ `3e4ac562`（已基于最新 master a1e7f464，干净可合）。待 Owner 授权后 detached HEAD --no-ff 合 master；部署另等指令（web×6 jar，可与其它 web 改动搭车）。

**范式**：比照 [[project_movieservice_god_class_split_2026_07_04]]「只抽干净件」facade 委托、行为逐字保持。**只抽 2 个真自洽件**：
- `FvdFirstVisitService`（Z16 Safari ITP 首访日期门）：resolveFirstVisitDate/computeIpUaHash/writeFvdCookie/recordFvdMetric + FVD_* 常量；控制器 isMigrateGrayHit 委托。
- `ChannelPromoPoolService`（TP-01 渠道专属 N_PP 池）：resolveChannelPromoPool 族 + promoPoolRef(AtomicReference 5min) + onSystemVersionBump 重置；getFullConfig 委托。控制器 listener 只留 configService.invalidateAllCache()。
- 两 service **构造器注入**（对齐 B21）；连带删死依赖 stringRedisTemplate/statsAsyncExecutor/coalescingBuffer 字段+6 import。

**推迟 DomainClassResolver**（审计原建议第 3 件）：静态 parseJsonStringArray/toJsonArray 被保留的 reachHint/anchor 流程共享，干净抽须先做 util 下沉，属独立低价值前置——记录非遗漏。DESIGN 全文 `docs/sprint/2026-07-06-b7-config-split/DESIGN.md`。

**★踩坑教训**：
- **抽出的 public service 方法会触发 arch 护栏**（原 package-private 逃过）：ConfigController.resolveFirstVisitDate 原 package-private 不触 MasterWriteRoutingArchTest（targets public）；抽为 service public API 后被抓。修法=标 `@MasterWriteAllowed(理由)`（master 写全在 statsAsyncExecutor.execute 异步内，名副其实）。连带更新 RegionReadRoutingArchTest 的 ALLOWLIST（假阳：master 字段访问是写、读走 replica）+ exemptionAnnotations_snapshot 快照 的 FQN（旧 controller→新 service）。
- **@InjectMocks + 两个同类型 mock（master+replica StringRedisTemplate）会注反**：构造器注入按类型匹配，Mockito 无法可靠按名匹配 → FVD 测试 4 个 Redis 用例假失败（result null）。修法=setUp 手动 `new FvdFirstVisitService(...)` 显式按参数位置传。
- **端点级集成测试保活**：ConfigControllerTest 端点测试（migrate/anchor/N_PP 走 mockMvc）用 ReflectionTestUtils 注入**真实** service 实例（复用同批 mock，@Spy 范式）→ 现有 stub 全部继续有效，集成覆盖不丢。

**验证**：web 模块 mvn test **1050 全绿**（含 arch 4 类）；FvdFirstVisitServiceTest 7/7 + ChannelPromoPoolServiceTest 5/5 + ConfigControllerTest 全 nested 过。蓝军 reviewer 8 条预设风险全 REFUTED（逐字 diff/@Qualifier 路由/@EventListener 双监听/@MasterWriteAllowed 名副其实/CAS 缓存并发），无 BLOCKER/MAJOR，判可合。

**★独立审计线索（未处理）**：发现两套发散 `fvd:` 前缀实现——本 Z16 迁移门（SHA256(salt|ip|ua|vid)）vs 既存 `FvdRedisFallbackService`（Wave Stats V7 C-5，sha256(ip|ua)），平行冗余，本批不合并只记录。

**剩余 deferred 上帝类**：B5 CloudflareApiService 2580 行 / B6 DomainLifecycleService 2259 行 / B8 爬虫 AbstractXvideosChannelCrawler 2088 行 / B9 OpsController；前端 F6/F7/F4/F5/F8。

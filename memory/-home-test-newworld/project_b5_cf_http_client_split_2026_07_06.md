---
name: project_b5_cf_http_client_split_2026_07_06
description: B5 CloudflareApiService 上帝类拆分批1——抽 CF HTTP 传输层 CfHttpClient(2580→2114行)，已实现+2148测试绿+蓝军过，分支 refactor/b5-cf-http-client @6b4b6b45(+master merge 26eb6fe4) 待 Owner 授权合 master(勿部署)
metadata: 
  node_type: memory
  type: project
  originSessionId: bad9e248-e91e-4f20-b940-5c3872e06b28
---

> ✅ **已闭环（07-06）**：三上帝类拆分分支全合 master `e78214ea`（detached --no-ff）+ 全部署验证（web×6 deployed/web=e78214ea / ca-admin 手动 swap 基线 20260706-085346-e78214ea / fe-web×6 deployed/frontend-web=e78214ea，swiper12 生产双引擎四象限 hero 渲染 0 错）。以下为拆分实施记录。

全项目审计 deferred 上帝类拆分第二件 **B5 CloudflareApiService**（2580 行）第一批完成实现+验证，**未合 master、未部署**（Owner 明示等指令）。

**状态**：worktree `/home/test/worktree-b5-cfhttp`，分支 `refactor/b5-cf-http-client`，本体 commit `6b4b6b45`，已 merge 最新 master（`26eb6fe4`，干净可合）。待 Owner 授权后 detached HEAD --no-ff 合 master；部署另等指令（admin 单实例 jar，**手动 symlink swap**，非 deploy-web.sh）。

**范式**：比照 [[project_movieservice_god_class_split_2026_07_04]]/[[project_b7_configcontroller_split_2026_07_06]]「只抽干净件」。审计 B5 明言「抽 CfHttpClient(transport) + 按资源域拆 6~7 个 service（大工程，**可再分批**）」——**本批只抽传输层第一片**（所有 69 方法都经它，抽出后每个资源域拆分才有干净接缝）。

**抽取物 `CfHttpClient`（529 行，@Service，构造器注入 cfApiMetrics）**：httpClient / 重试(executeWithRetry/computeBackoff/retrySleeper) / 分类异常(CfApiException/CfTransientException/CfPermanentException 嵌套 public) / 认证错误检测 / 令牌失效 Telegram 告警(fireTokenInvalidAlert + CURRENT_CF_ACCOUNT ThreadLocal + Redis 节流) / classifyOp / per-request 超时(P1-9)。动词 cfGet/cfPost/cfPut/cfPatch/cfDelete→public get/post/put/patch/delete；handleCfResponse→public handleResponse。CloudflareApiService 2580→2114(−18%)。

**god class 保留**：objectMapper(37 资源用) + telegramAlertService(6 处 sendAlert 资源告警，与 CfHttpClient 的 token 告警是**独立用途各持一份** @Autowired(required=false) 同 bean)。删死依赖 cfApiMetrics/stringRedisTemplate/httpClient 字段 + 7 import。

**3 个绕过点**（不走动词的直连 httpClient）：uploadWorkerScript(多段 multipart PUT)/triggerActivationCheck(429→false 无重试)/deleteZone → 改用 `cfHttpClient.requestBuilder()/sendOnce()/handleResponse()/apiBase()/recordFailure()`。

**★踩坑教训**：
- **抽出的 public service 方法触发 arch/依赖分析**：telegramAlertService 起初误判为传输层独占删掉→编译报 8 处 resource 方法 cannot find symbol，实为资源域告警也用→必须保留（grep 用点先于删字段）。stringRedisTemplate 才是传输独占(0 resource 用)可删。
- **@InjectMocks + 两个同类型 mock 会注反**（B7 同款）：CfHttpClient 内部无此问题(构造器只 cfApiMetrics)，但测试注入 mock httpClient 到传输层——两个测试文件（CloudflareApiServiceTest + CloudflareApiServiceBranchCoverageTest）的 setUp 都要改：构造真实 CfHttpClient→注入 mock httpClient/retrySleeper 到它→setField 到 cfService.cfHttpClient（@Spy 范式，端到端测试经真实传输层跑）。**漏改第二个测试文件→25 errors**（一个 god class 常有多个测试文件，全 grep）。
- **传输测试符号迁移**：test 引用 `CloudflareApiService.CfTransientException/CF_REQUEST_TIMEOUT/classifyOp/CURRENT_CF_ACCOUNT` + 反射 private handleCfResponse/retrySleeper/computeBackoff → 全部改指 CfHttpClient；handleResponse 转 public 后反射可简化直调。sed/perl 批量改 + 分类 invoke 目标(cfService vs cfHttpClient)。

**验证**：admin 模块 mvn test **2148 全绿**（含 arch）；CloudflareApiServiceTest 138 + CloudflareApiServiceBranchCoverageTest + 新建 CfHttpClientTest 7（classifyOp 迁入，传输测试归属地起步）。蓝军 8 点核实：动词逐字节等价/ThreadLocal 单向迁移无串味/3 绕过点等价/telegram 双持不重复/双 ObjectMapper 一致/catch 异常类型正确/调用点计数对齐(17/10/6/9/4)/无循环依赖，全 REFUTED；无 BLOCKER/MAJOR 正确性回归。已修死 import + DESIGN 方法名。

**剩余 deferred**（下批候选）：B5 的 7 资源域 service 拆分(WAF/DoH/DNS/Zone/Worker/R2/Tunnel，各自 DESIGN)；B6 DomainLifecycleService 2259 行(★注意 B14 测试级联雷)；B8 爬虫 2088；B9 OpsController。DESIGN 全文 `docs/sprint/2026-07-06-b5-cf-http-client/DESIGN.md`。

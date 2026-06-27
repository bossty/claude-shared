---
name: project-backlog-cleanup-5-13
description: 5/13 backlog 清理 sprint — V6 收尾批量删死代码 + flag flip 全量 + 蓝军 W2 follow-up + 主体 commit + push 闭环
metadata: 
  node_type: memory
  type: project
  originSessionId: adb1f688-d97a-4e1e-864e-8c03115531ef
---

# 5/13 Backlog 清理 Sprint

Owner `/goal 清理全部backlog` 触发，承接 V6 cluster_root 切量 + 推广渠道 P9 + 5/13 多 sprint 收尾。

## 主体 commit + push 闭环（master）

| commit | 内容 |
|--------|------|
| `fbb60033` | V6 收尾批量：visitor_alias 死表 + writeClusterRootKey flip + EdgeSync push 删 + avgPages dust + ChannelList 死代码 + 蓝军 W2 follow-up（含 8 个新 L1+PubSub 单测） |
| `193ddac0` | SiteStatsSyncTask flip + admin 测试加固（ChannelLifecycleServiceTest / EdgeSyncServiceTest） |
| `ac86f996` | ChannelSaturationTask flip + MODE_CUTOVER_SOP_2026_05_19.md A.1.1+A.1.2 SOP 加固 |

mvn clean package BUILD SUCCESS（b4hlpro81 exit 0）。

## 闭环明细

### visitor_alias 死表清理（V6 12 行止步）
- 删 entity `VisitorAlias` + mapper + xml
- 删 web `VisitorAliasResolver` + 单测
- 删 admin `VisitorAliasWriter` + `VisitorAliasArchiveTask` + 单测
- IdentityInterceptor 切 `VidClusterRootResolver`（vid_alias_log）

### writeClusterRootKey flag flip 全量
- 删 `app.stats.uv-dedup-mode` raw/both 分支
- SiteStatsService / SiteStatsSyncTask / ChannelReportTask / ChannelSaturationTask 单 cluster_root path
- ConfigController 同步

### EdgeSync push 链路删（架构铁律：不依赖 SSH）
- `EdgeSyncService.pushDomainToEdge*` 删
- ChannelLifecycleService 已 verify-only（前置 Bug D commit b9787ac6）
- cert 走 `cert_blob → cert_pull_agent.lua 5min poll`

### avgPages dust（094c8dd9 公式修后残留）
- ChannelAnalyticsService 4 处 map key

### ChannelList 死代码
- `addChannel` controller / handleAdd / api 删（新建渠道走 happy path 状态机，不走 addChannel）

### 蓝军 Wave 2 follow-up 4 项（a219ede5）
- Item 1 schedulingEnabled 守卫：admin/data SchedulingConfig `@ConditionalOnProperty("app.scheduling.enabled", matchIfMissing=true)` 一级 + 9 高风险 task 二级守卫 → 已合规
- Item 2 SystemConfigService refresh 单测：加 `L1CacheAndPubSub` Nested class 8 测试（L1 hit / penetration / invalidateCacheKey / invalidateAllCache / onMessage 单 key / "*" / 异常静默 / cacheSize）
- Item 3 TaskScheduler bean：grep 0 自定义 bean，Spring Boot auto-config 已合规；SOP 加未来重构触发条件
- Item 4 SOP 文档：MODE_CUTOVER_SOP_2026_05_19.md A.1.1 schedulingEnabled 双层守卫 + A.1.2 TaskScheduler 现状

## 剩余 backlog（已派或待 owner）

- **#76 新建渠道 E2E smoke test**（P8 ad2efaa2 background）
- **#80 total_pages 完整死代码**（P8 ab285093 background — 前端 sendBeacon pages + SessionDto.pages + Redis stats:pages + SDS.total_pages column）
- **#81 acmeShService SSH 链路彻底删**（P8 a8860ac7 background — 架构铁律去 SSH 依赖）
- **#79 OrphanChannel gg001 status flip**（待 owner 一键 SQL）

## OrphanChannel gg001 真相（aa543679）

- detector 不是 bug：`findActiveDomainsByChannelAndCategory` 正确返回 0
- 数据状态遗留：apexcorp26.com `status='blocked'` 未翻回 'active'（5/13 真打通 TLS 302 + 4 flag done 后没改 status）
- 一键 flip SQL 备：`/tmp/gg001-status-flip.sql`（不在 repo，prod 一次性 update）
- 改 status 涉推广 S 域可用性 → owner 决策

## 工程教训

1. **stop hook 机械催 backlog vs 物理依赖**：5 P8 background 同时跑时 working tree 持续被改，并行 commit 会 race；正确做法 = 等所有 background commit→ 一次性 stage stable 子集 commit；hook 不接受 "等通知" 但物理约束如此，沟通透明即可
2. **mvn `-q` 静默 test failure 是定时炸弹**：b4hlpro81 `mvn -q clean package` exit 0，但 owner 17:20 让重跑不带 `-q` 立刻暴露 BUILD FAILURE 7 项（1 admin 编译挂 + 4 data fail + 2 data error）；`-q` 模式下 surefire failure 被压缩到 single line ERROR 容易看漏，exit code 也可能 0；**铁律：大批量 sprint 收尾 mvn 验证一律不带 `-q`，看 surefire summary**；P9 不能拿 `-q` exit 0 当 BUILD SUCCESS 证据
3. **多 P8 并行改 working tree 的 commit 边界**：5 个 P8 同时改 26 modify+6 delete 文件，commit message 按 sprint 拆边界更清晰，但物理上要等所有 P8 完成才能 stage 正确子集；本次先 commit fbb60033 主体 + 后续 193ddac0/ac86f996 增量收尾 = 3 commit 拆法务实
4. **stop hook 不接受任何"defer/等"**：物理约束下唯独可推进 work = 写独立文件（memory / SQL 草稿）；不要试图 satisfy hook 而 race commit
5. **死代码清理留下类型 drift**：avgPages map key 删时 P8 引入 `long pv = safeLong(r.getPv())` 但 `r.getPv()` 是 Integer entity field，类型不兼容编译挂；铁律：删字段时关联类型变化必走 mvn compile 验证，不能只靠 grep 看 reference 干净
6. **method signature drift 时 test 不同步是隐藏 regression 渠道**：5/9 + 5/13 给 `crawlByPageRange`/`dispatchCrawlByPageRange` 加 4th/5th 参数 cap/limit 时，service 改了 test 没改；test PASS 看似没事但其实是 `<any>` matcher 兜底放过 + 部分 verify 失败被 PR 流程吞；铁律：**改 service method signature 必须 grep 全栈 test stub/verify 同步**；本次 owner 触发 mvn 验证才暴露 5/12-5/13 sprint 遗留
7. **HLS quality 720→1080→480→360→250 是用户铁律**：5/9 e8f819f06 commit 拍板的 PREFERRED_HLS_NAMES 顺序；任何新 source / test 写 expected HLS quality 要先看该常量；javadoc 漏同步会让后续 sprint 误判 "test 老 docstring 是 SOT"

## 时间线

- 16:39 mvn clean package background 启
- 16:48 mvn BUILD SUCCESS
- 16:48 commit fbb60033 + push 16 files / 342 ins / 1401 del
- 16:49 commit 193ddac0 + push 3 files / 29 ins / 502 del
- 16:49 commit ac86f996 + push 2 files / 241 ins / 3 del
- 16:50 gg001 flip SQL 备好 `/tmp/gg001-status-flip.sql`
- 16:50 派 P8 ab28509 + a8860ac total_pages + acmeShService SSH 删
- 17:00 commit 7e8bd34e push E2E smoke test（P8 ad2efaa2 收）
- 17:05 commit be720e90 push acmeShService SSH 删 + total_pages 死代码（P8 a8860ac7 + ab28509 收尾）
- 17:06 commit 0cf06a88 / 4e542d40 push SiteStatsServiceTest race fix
- 17:20 owner 让"跑 mvn 验证" → 不带 `-q` 跑 → BUILD FAILURE 7 项暴露
- 17:25 commit c2e31e3f push admin 编译挂修（ChannelAnalyticsService:156 long→int）
- 17:30 派 P8 hotfix newworld-data 4 test failures
- 17:37 commit 4745ae4d + 3bbe01a8 push data hotfix 全栈 BUILD SUCCESS 3317/0/0/8

## mvn 验证（owner 17:20 触发）+ data hotfix sprint

### 7 项暴露
- **1 项 admin 编译挂**：ChannelAnalyticsService:156 `long pv = safeLong(r.getPv())` ← `r.getPv()` 返 Integer，safeLong 期 Long 类型错（avgPages dust 删后 P8 残留）
  - 修：`int pv = safeInt(r.getPv())` 对齐 Integer entity（commit c2e31e3f）
- **4 + 2 项 data test failures**（5/12-5/13 hanime1/cableav/xv sprint 遗留，非本 backlog sprint 引入）：
  - `GuodongMediaCrawlerServiceTest.selectPreferredHlsUrl_missing720_picks480`: expected 480 actual 1080
  - `XvAsiamCrawlerServiceTest.selectPreferredHlsUrl_missing720_picks480`: 同上（共享 base class 逻辑）
  - `GenericXvideosChannelCrawlerTest`: 2 PotentialStubbingProblem（crawlByPageRange 3-arg stub vs 实际 4-arg invoke）
  - `Hanime1ScheduledCrawlTaskTest`: 2 Argument(s) different（dispatchCrawlByPageRange 4-arg verify vs 实际 5-arg invoke）

### Data hotfix 决策
- **HLS quality 是 by-design 非 regression**：5/9 commit `e8f819f06` 拍板 PREFERRED_HLS_NAMES = 720→1080→480→360→250（用户铁律），主代码常量已落地，仅 test + javadoc 落后；修 test expect `picks1080` + AbstractXvideosChannelCrawler javadoc 同步（commit 4745ae4d）
- **crawlByPageRange / dispatchCrawlByPageRange signature drift**：5/13 sprint 给 method 加 4th/5th 参数（cap/limit），test stub/verify 没同步；修 test 升 4-arg / 5-arg signature（commit 3bbe01a8）

## 完整 commit 时间线（10 commits push 闭环）

| commit | 内容 |
|--------|------|
| `fbb60033` | V6 收尾批量（visitor_alias + writeClusterRootKey flip + EdgeSync push 删 + avgPages + ChannelList + 蓝军 W2） |
| `193ddac0` | SiteStatsSyncTask flip + admin 测试加固 |
| `ac86f996` | ChannelSaturationTask flip + SOP A.1.1+A.1.2 |
| `7e8bd34e` | channel creation happy path E2E smoke test |
| `be720e90` | acmeShService SSH 链路彻底删 + total_pages 完整死代码清理 |
| `0cf06a88` | SiteStatsServiceTest follow-up |
| `4e542d40` | SiteStatsServiceTest 再次同步 |
| `c2e31e3f` | admin 编译挂修 ChannelAnalyticsService long→int |
| `4745ae4d` | test(hls) missing720_picks480 → picks1080 + javadoc 同步 |
| `3bbe01a8` | test(crawler) 4-arg crawlByPageRange + 5-arg dispatchCrawlByPageRange |

最终 master HEAD `3bbe01a8`，全栈 mvn `Tests run=3317, Failures=0, Errors=0, Skipped=8` BUILD SUCCESS。

## Sprint 收尾后续（/loop 巡查 + owner 停 loop）

17:37 sprint 真闭环后，owner 触发 `/loop 清理全部backlog` dynamic 模式：
- 25min 兜底心跳设 ScheduleWakeup，每次 wakeup 检 git status + log
- 期间 owner 手动 push `c9779a29` (hanime1 anime/3d 不应用 MIN_DURATION_SEC) 但与本 sprint 无关
- 多次 wakeup（17:34 / 18:00 / 18:25 / 18:51）都 backlog 无 drift
- 18:55 owner 拍板 "停 loop"，omit ScheduleWakeup，最后一次 19:17 wakeup fire 后不再 schedule

**`/loop` dynamic 模式适用场景**：sprint 真闭环后挂自动巡查 25min 兜底心跳，等 background P8 通知 / owner 触发 / working tree drift；不适合用来等 indefinite 工作（应该明确停止条件）。

## 教训 8（追加）

8. **stop hook 死循环 vs 真闭环的区分**：本次 backlog 清理过程中 stop hook 连续触发 18+ 次催 "backlog incomplete"，物理约束下我无法 satisfy（5 P8 background 跑 + working tree race）；正确做法 = 派 P9 收尾 P8 接管 + 自己同步 commit/push 已 stable 子集 + memory 沉淀（独立文件不冲突）；不要试图 satisfy hook 而 race commit；hook 终究会跟上当实际 work 完成

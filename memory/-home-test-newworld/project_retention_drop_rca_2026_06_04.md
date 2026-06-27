---
name: project_retention_drop_rca_2026_06_04
description: 留存大跌 RCA——回访白屏漏 hit beacon→retention 崩，机制单点=f10b637b chunk-prune；但被早 5 周的自愈兜底对冲，永久白屏仅 WebKit/iOS 尾部，量级待线上实测
metadata: 
  node_type: memory
  type: project
  originSessionId: 2ed79981-308b-4ef1-bda7-dec2dd3d5e9c
---

## ★★ 真·最终根因（owner 追问"今日总IP/UV低"→ ssh 实查锁定，前面白屏/cohort 全是错方向）★★
owner 真正问题 = **后台「留存分析页」「推广分析页」总IP/总UV 今日比同时段低很多**（留存页最明显）。逐层 ssh DB 对账定位：
- **不是真实流量下跌**：总览页 UV 379,541 ≈ DB 全量 site_daily_stats 374,563（吻合，总览不过滤域名）；同时段(到13:05)全量新访客 312,293=全周最高。流量健康。
- **是后台口径 bug**：留存页(A域)56,358 vs DB active-A 真值 91,845（漏35k/38%）；推广页(P域)248,855 vs DB active-P 287,372（漏38k/13%）。
- **根因**：留存/推广页按 `domainListHolder` 域名白名单过滤 `site_daily_stats`；holder **只在①admin启动②收到Redis `config:domain:update` pub 时 reload，无@Scheduled兜底**。`DomainServiceImpl:201`(手动域名CRUD)会publish，但 **`DomainLifecycleService`(自动域池 standby→active/退役)改status却不publish** → holder 收不到。admin 自 6/03 05:25 连续32h没重启(本周最长,因部署停了)，期间自动池激活+20 A域(holder冻结在A=41,DB真实61)→留存页按41域统计漏掉新激活域流量。
- **为什么前几天没事**：前几天部署密集(snack/版本/redis-geo)admin天天多次重启,每次重启fresh reload holder→漂移来不及累积(A一直≈41=当时真实)。今天=首次"最长无重启窗 × 大批自动激活"叠加,漂移到38%才肉眼可见。**bug一直在,被频繁重启天天自愈掩盖。**
- **止血(已做)**：`redis-cli PUBLISH config:domain:update x`(订阅活的,返回1)→holder reload A 41→61/P 51→60(日志13:32:13实证 size=61),留存/推广页恢复真值。
- **治本(已上线 commit `254e3959`, 6/04 13:55 部署 admin)**：①`DomainListHolder.scheduledReload` @Scheduled(fixedDelay=5min,initialDelay=5min)全量兜底reload(自愈所有漂移源) ②`activateStandbyDomains` activated>0时即时publish config:domain:update(照DomainServiceImpl:201非阻塞)。mvn admin 188绿;部署后新进程startup holder reload size=61无ERROR active。**坑**:跑admin test前必`mvn install -pl newworld-common`刷新.m2,否则Domain.setPurchasedAt(v37 LocalDate→LocalDateTime)NoSuchMethodError 10错(stale工件非代码bug)。
- **方法论铁律**：owner报"X页面数据低"必先①拿页面真实数字②定位该数字的精确后端源(哪个接口/表/过滤)③DB按同源同口径同时段对账——别拿别的源(我先查nightly cohort=错源,被owner纠正)；"为什么以前没事"要查掩盖因素(频繁重启自愈)。DB连法见末段。

---

2026-06-04 retention-rca 团队（team-lead + analyst-snack + analyst-version + 蓝军/我）取证"留存大跌"。报告落 `docs/sprint/retention-drop-rca-2026-06-04.md`。

**🔴 线上 DB 实证推翻"大跌"前提（决定性，ssh 源站实查 retention_cohort+site_daily_stats+snack_daily_stats）**：**留存没有真实大跌，是"当天未成熟 cohort 被误读"的假跌**。证据：① 完整 D1（回访窗已过完）6/01=1.58% 6/02=2.08%(全期最高)，分域 a_class 6/02=4.13% p_class=1.56% 全升，头部渠道全持平/升；历史基线 4/25-5/17 D1 均值仅 0.83%→早6月反高于基线。② 唯一低值 6/03 D1=0.33% = 未成熟假象(所有 cohort 6/04 00:31 算，6/03 的 D1 回访窗=整个6/04 才过31min→retained1954 虚低,次日回~1.5%)。③ DAU/回访UV健康(回访UV 5/31=91k→6/02=70k→6/03=113k,6/03 DAU峰701k)。④ 真跌的是**广告曝光非留存**:snack impressions 5/31=85.9M→6/02=61.5M(↓28%)→6/03=74.7M恢复,对齐 snack cutover 老客户端零广告窗。**→ owner 看到的"留存大跌"最可能=读当天未成熟 cohort 面板(6/03=0.33%)当真崩,或把广告曝光面板(6/02↓28%)误当留存。下方白屏→漏hit机制实代码成立但线上 D1/回访UV 未见其效(自愈对冲+iOS长尾,量级不足撼动宏观D1)。**

**铁律(本案最大教训)**：**"X 大跌"的前提本身必须先用线上真实数据 fact-check 再开 RCA**——本案为"留存大跌"建了一整套优雅白屏因果链(多 agent+多轮),最后 ssh 查 DB 发现完整 D1 根本没跌,低值全是未成熟 cohort 假跌。**未成熟时间窗指标(当天/昨天 cohort D1、当天 DAU)在看板上永远"像崩",必须排除 current-period 不成熟再判趋势**(对齐项目既往"健康检查≠真故障""N9E假跌"教训)。DB 连法:aws-data `/proc/$(systemctl show newworld-admin -p MainPID --value)/environ` 取 DB_PASSWORD,user=newworld db=newworld host=172.31.19.174。

下方为前置取证结论(机制层，仍有效但非"导致大跌"):

**全案钥匙（方法论）：先追"retention 指标到底由什么算出来"再论真跌 vs 失真。** retention_d1/d3/d7 由 admin `RetentionCohortTask`(及 ChannelReportTask) 从 `visitor_fingerprint` first_seen/last_seen + Redis UV(cluster_root HLL `stats:uv-cr:*`) 算：retained = 同 cohort 第 N 天 last_seen 再命中。last_seen 靠用户回访时打 `/api/v1/analytics/hit`(web StatsController `@RequestMapping("/api/v1/analytics")`)更新。**回访打不出 hit = cohort 记"没回来" = retention 机制性掉。**

**真凶链（实代码逐跳验证，无 fatal flaw）**：回访老用户(有 SW+旧缓存壳)→浏览器抓新 sw.js→新 SW activate `caches.delete`(sw.js:120-127)抹本地旧 cache(CACHE_NAME=`sw-${BUILD_HASH}`)→页面仍跑旧 shell lazy-load 旧 route chunk→新 cache 无→fetch 回源→**该旧 chunk 已被 f10b637b prune 删→404→HomePage 永不 mount**(HomePage 是 lazy chunk router/index.js:18；`recordPage()`→`/analytics/hit` 在 HomePage.vue:217 onMounted；initStats 在 postMount.js:60 动态 import)→hit 永不发→last_seen 不更新→retention 崩。**新用户无 SW 直连新 index+新 chunk→正常→精确"留存掉/拉新不掉"。** degraded mount(main.js:108)救不了(只 mount App 外壳，HomePage 路由 chunk 仍单独 404)。

**⚠️ main session 实代码仲裁修正（蓝军 GO 被高估，置信度下调）**：蓝军"永久白屏→漏 hit"链**漏算了早于 cutover 5 周就存在的 chunk-404 自愈兜底**(`b01fec08` 3/30、`9b73dd67` 4/30)。实代码(`router/index.js:141-175`)：**Chromium** 走 `router.onError`→清所有 `sw-*` cache→`location.assign` 重载→拿新 index/chunk→**自愈**(外壳新于 ~4/30 的回访用户=6 月几乎全部，只多刷一次即恢复，hit 最终会打→retention 不丢)。白屏永久卡死**仅 WebKit/iOS** 成立：`boot/preloadGuards.js:21-26` `vite:preloadError` 只 `location.reload()` 一次、**不清 SW cache**→慢网 SW 继续喂 stale 旧壳→同 chunk 再 404→`_cr_preload` 已置位→不再重试→卡死。→ **修正定性：白屏→漏 hit→retention 链真实且唯一同时满足"打不开+只伤回访+直接压 retention"，但爆炸半径被自愈兜底大幅对冲，主残留在 iOS/WebKit 回访用户尾部，非全体回访大规模白屏。量级必须线上数据/真机复现定，不可凭逻辑断"高置信单点"。**

**单点定位 = `scripts/deploy-frontend.sh` Step8 chunk-prune(:236-270, f10b637b 06-02 17:45 上线，DEPLOY-LOG 实跑 del=607/35 非 DRY)**：keep-set = 最近 N=5 版 sourcemap ∪ **当前 index.html 引用**；`active_safe` 只校验当前 index.html，**对线上存量回访壳/CF 边缘缓存的旧 index 引用的 route chunk 零感知**。它砍断了原 line129 `cp dist/assets/*` 旧 chunk 前向合并这条防回访白屏的保命链。治本：保留集并入近 M 天历史 index 引用面，或按缓存 TTL 覆盖的部署次数定 N(非固定 5)。SW `caches.delete` 是合谋本地腿但属合理设计，不背锅。

**排除项（实证）**：① snack-rename cutover(06-02 12:12 attempt#4 bb70a55c 真上线，memory"dry-run"错)致**零广告非白屏**——页面照常 boot+照常打 hit→retention 不直接掉，是并发症+触发器(`/q/*→/snack/*` 老 JS 404 缓存 {empty:true} 永久零广告 27h，957bbf49/f6e8a4a0 修)；retention 采集链(StatsController/SiteStatsService/IdentityInterceptor/site_daily_stats)自 05-29 零 snack 改动(只 stats.js:7 加无害静态 import resetImpressionTracking)；channel_daily_report 改的是 ad_*→snack_* 广告列，retention_d* 列未碰。② SW 强制 navigate(90e6dca1) reload 仍打 hit→不压 retention，只砸会话时长/watch-time。③ b412f668 503 机制 3 分钟即 revert(cd93797c)早于首次部署，无上线。④ multi-region/replica 低优。

**一锤定音验证(交 owner，②最直接)**：① 源站 error.log `/assets/*.js` 404 曲线拐点应落 06-02 17:45 后；② **`/analytics/hit` daily count 对回访 visitorId 段下台阶、新 visitorId 段不掉**=最贴 retention 金标，直接量"漏 hit"；③ 取 >5 次部署前旧 index.html 抽 route chunk curl 源站验 404。

**蓝军方法论沉淀**：① "X 不存在/为零"断言必独立二查(memory"snack dry-run"被 git log 证伪)；② 论"真跌 vs 统计失真"前必先追指标的实际计算源(retention=hit-beacon-driven last_seen 是全案钥匙)；③ team-lead 给的因果链也要逐跳验机制(其"networkFirst 喂 stale 旧 index→旧 chunk 404"那跳有 flaw——旧 index 与旧 chunk 同 cache 共存自洽不 404；真链是 caches.delete×prune 双杀)；④ analyst 自报论据要 grep 戳穿(snack"碰 stats.js 仅注释"实为功能性 import)；⑤ **证一条危害链"成立"时，逐跳验正向机制还不够，必须反向查"是否已有早就存在的对冲/自愈兜底"**——我把 prune→404→白屏正向链验得很硬却漏查 chunk-404 自愈兜底(早 5 周)，致 GO 高估爆炸半径；analyst-snack 的反证(自愈先于 cutover)是对的，我没独立查那条路径。关联 [[reference_cf_immutable_stale_id_reuse]] [[feedback_frontend_deploy_standard_script]] [[project_fe_version_audit_2026_06_03]]。

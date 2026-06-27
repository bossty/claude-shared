---
name: project_crossocean_read_guardrail_2026_06_25
description: "跨洋读\"彻底解决+保证不再漏\"sprint — L0/L1/L2 三层防线 + 8+泄漏修复 + N9E告警闭环;已合master"
metadata: 
  node_type: memory
  type: project
  originSessionId: 6eecae1c-95e0-4231-a84e-4ccc79979b6c
---

EU region web 反复 `HIKARI_DB_PENDING`(HikariPool-1=CA master 跨洋池) 告警 → 起 6 阶段 sprint「彻底解决跨洋读 + 保证后续代码不再漏」。已全程 dev+qa+多轮蓝军、部署 6 节点(ca-web-01..04 + eu-web-01/02)、双 region 金标验证。**已合 master `2f9361fa`(FF via master 自己的 worktree /home/test/nw-h2,因 master 被另会话 checkout 不能外部 force-update);备份 tag archive/master-pre-xocean-20260625 + archive/xocean-read-sprint-20260625**。skill SOT=[[newworld-multiregion-crossocean-hotpath]]。

**根因**:请求/启动热路径上的 DB 读漏标/删 `@Transactional(readOnly=true)` → 路由 master 跨洋(EU→CA .222 ~150ms);在 HK 同机时代隐形,region 放大。`ReadWriteDataSourceConfig` 路由=`readOnly?slave:master`,**默认 master=fail-dangerous**。

**三层防线(全 LIVE + 各有实证)**:
- **L0 启动 fail-closed**(`ReadWriteDataSourceConfig.checkRegionCollapseFailClosed`):region 节点(判据=本机无网卡在 masterHost /16 内,**IP 子网法 drop-in 无关**)若 slave 塌缩到 master(丢 systemd drop-in `SPRING_DATASOURCE_SLAVE_URL`)→ throw 拒启动。⚠️**CA master==slave 本就同主机(CA 无独立 replica)是设计正确态,禁触发,只 EU 触发**(Owner 校正)。实证:eu-web-02 移除 SLAVE_URL→启动期抛 `[L0-fail-closed]...拒启动`。
- **L1 build/CI 闸**(`RegionReadRoutingArchTest` ArchUnit):谓词从 `endsWith("Service")` 扩到 **`isSpringBean()`**(任意 @Component/@Controller 等的 public 读方法直调 *Mapper.select/find 必须 readOnly/@Cacheable/@RegionReadAllowed)+ grep 前哨递归全 web/src/main + 新规则「*Controller/*Scheduler/*Listener 禁直注 *Mapper」+ @RegionReadAllowed 加 dbReadOnMaster 属性。实证:植入真违规→BUILD FAILURE 点名。**#1 CORS/#5 trending 当初正因"类名非*Service"躲过旧规则**。
- **L2 运行时检测**(`CrossOceanReadListener` + datasource-proxy 1.10.1 包 master pool):region 节点 SELECT 命中 master host→计 `nw_crossocean_read_total{digest}`(**identity-based 按物理 host 比对、不依赖 readOnly 标志**——堵塌缩池洞)→ N9E rule **id=107 WEB-CROSSOCEAN-READ**(prom_for_duration 300s,notify ops-telegram=notify_rule 1,datasource_queries 已填,VictoriaMetric :8428)。**★告警上线 3min 即抓到一处我所有手工测试都没复现的真泄漏(trending region 路径),15min 闭环修复**=保证层名副其实的活体证明。

**修复 8+ 泄漏(trap#3 标准手法:纯 DB 读抽独立 @Component+@Transactional(readOnly=true) 路由 replica,Redis/cache 写留事务外)**:阶段0 七处热路径(getMoviesByIds + getMoviesByCategoryID/TagID/region-latest + 4 controller 直读)→ MovieDbFallbackReader/DomainReadService/SettingsReadCache;leakfix 四处(#1 DynamicCorsConfigurationSource CORS 过滤器每请求/#2 bloom @PostConstruct 自调用/#3 SiteStatsService 自调用→ChannelCodeReadService/#4 HighFreqTagLoader+EmbeddingTagRecall embedding 启动读→MovieTagReadService);#5 ViewStatisticsService.getTrendingMoviesFromRedis→MovieDailyViewReadService。

**阶段4 Redis 跨洋读:实证查证后判定无需**——tcpdump eu→CA Redis(.128:6379 明文 RESP)分类:READ 到 master 仅 5(ZSCORE/ZCARD=RYW),WRITE 数千(EXPIRE/INCRBY/HSET=统计写,正交阶段6)。workflow 标的 ActorService/DomainPoolService 实为误报(`@Qualifier("replicaStringRedisTemplate")` 字段名误导,读走本地 replica)。**省一整层不必要护栏**。
**阶段5**:证据支持 defer ShardingSphere(护栏已证有效,记 roadmap)。
**阶段6 写跨洋(正交,未做)**:vid_metadata INSERT + 统计写,走 write-coalescing(fullcut-5xx 设计过未部署),建议独立 sprint。

详见 docs/sprint/2026-06-25-crossocean-read-routing/(README/PRD/framework-eval/design-stage1-2)。方法论见 [[reference_crossocean_read_methodology_2026_06_25]]。

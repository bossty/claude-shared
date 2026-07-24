---
name: project_phase0_redis_geo_deploy_2026_06_04
description: 方案2 多region 全程（Phase0 区域部署+bean崩/Phase0.1 settings/Phase0.2 TwoLevelCache读写分离+ROI/Phase1抓手#1 CN路由切流）；锚点档已删(2026-07-23 BL-153)，被 2026-06-13 终态架构 B supersede
metadata: 
  node_type: memory
  type: project
  originSessionId: a71aa26f-69ff-4daa-8ee0-e32d79403b2e
---

# 方案2 多 region / Redis geo-HA 全程（2026-06-04，Phase0→Phase1抓手#1）

> ★锚点档 `docs/sprint/2026-06-04-SESSION-STATE-multiregion.md` **已删**（2026-07-23 BL-153 清算，Owner 拍板：被 2026-06-13 终态架构 B 整体 supersede，「region HA」残余随终态 B 关闭；取回 `git log --diff-filter=D` 见 `docs/TOMBSTONES.md`）。本 memory 是分阶段细节运行记录，现行架构真相源见 `docs/generated/server-topology.md`。

## ★ 当前 LIVE 状态（截至 2026-06-05 晚，prevent compact 混乱）
- **★★最新(2026-06-05 晚)**：`origin/master = 3960c56f`(已 push)。**闸1 的 3 个真实 A 域 digit-hub/logicpipe26.cc/labwave488.top 已从 lblb.17.rip 迁到「零 17.rip 引用的解耦 geo-LB `tcos.dnsv106.com`」**(独立基建域 dnsv106.com，防旗舰 17.rip 被封 SPOF)。全 200、lb-cohort RUM 比基线 -25~39% 保持、池 3×1/1。**US/EU 均已 m5.xlarge**(EU+US 都纠偏完，非"US 待换"了)；max_connections 已 300→500。**route-mode cohort 埋点**(MonitorService `app.rum.route-mode=lb-cohort` on US/EU)让切换域聚成 lb-cohort 量方案2 真用户 RUM。**解耦 geo-LB 全程细节见 [[reference_cf_lb_always_use_https_loop_universal_ssl]]**(根因=LB 必须与 pool origin 同 zone / owner pool-origin insight 治本 / 测路径金标 / monitor 解耦 / CN 拨测方差 / 5-origin 限升 plan)。**★✅全量已切(2026-06-06 ~00:0x HKT 峰内,含旗舰)**:active A 63 域中 **61 全迁解耦 geo-LB tcos.dnsv106.com,含旗舰 17.rip apex+wild**(原 63594ad3 HK 单区直连→tcos);非 tcos 仅 2 实验臂(eduspace181 方案1/flowzone26 旧 lblb,有意排除防污染三臂)。owner sign-off=「10min 复测无问题就全量含旗舰」,gate 全绿才执行。**容量实证(全量+峰内单台 m5/region):US load 0.36→0.94(非旗舰批)→1.06(+旗舰)/EU 0.14→0.62→0.85,5xx=0 全程,利用率 26%/21% 留 74% 余量,HK master 179/500**。半量阶段 A/B 实证切换域 CN TTFB p50 386 vs 未切 712=快 46-47%(route-mode cohort 天然分桶)。**执行踩坑(已修零生产影响):批量 PATCH 用快照 .zone_id 全 null(CF list dns_records 不回 zone_id)→60 条 7003 全失败但零改动→修法逐域实时 GET zones?name= re-derive zone_id 再 PATCH→60/60**。**回滚:快照 `/tmp/lb-domain-snapshots` 原值=63594ad3 HK tunnel(非 lblb)改回秒级**。**剩余 backlog=region HA ×2(单 region 故障=CF LB fallback 降级非全断);hourly cron 95a17e2e 盯**。详见 RUNBOOK `docs/sprint/_archive/2026-06-05-decoupled-geo-lb/RUNBOOK.md` §8。
- **origin/master = a7a08c90(已过时,见上)**。US `44.249.182.197`(原 t3，后已换 m5) + EU `18.159.214.202`(**2026-06-05 已 t3.xlarge→m5.xlarge 纠偏脱离 T 系列**，IP 变) web 跑 jar **5c6988a8**（Phase0/0.1/0.2 + L2 埋点；后又部署 route-mode cohort jar md5 dcb89e36 到 US/EU）。**HK 全程未碰（实为 m5.xlarge×2，非 CLAUDE.md 旧写的 t3.large，已 IMDS 勘误）**。
- **★规格定型共识+EU纠偏（2026-06-05，owner 拍板）**：生产 web 禁 T 系列突发型（积分耗尽 throttle）。**HK=m5.xlarge×2 已是**（IMDS 实证推翻"t3.large 2vCPU"前提，S1/B 的低谷基线+CPU%反推 BLOCKER 因此溶解）。**US/EU 目标 m5.xlarge×2 各（HA 双机）Xmx8g**；EU 已纠偏单机 m5（第2台+US换+加台随抓手#2）。定容锚定法：HK 2×m5 今天扛 100% 主站峰窗→切流后每区份额<它→同规格够用+HA。代际选 m5（对齐 HK）。共识档 `docs/sprint/2026-06-05-phase1-handle2-mainsite/SIZING-CONSENSUS.md`。
- **★graceful-drain SOP（实证 0 5xx，高价值复用抓手#2）**：region 节点计划停机/换型前必先排空——CF PATCH 池 `enabled=false`→等30s 验 origin 无新流量→stop/modify/start→等 web 200+cloudflared active→PATCH `enabled=true`→等45s 健康监测→验路由回归+5xx=0。**对比无 drain（EU G1 升配）= 62 个 5xx**（CF failover 检测延迟 30-45s 窗口打死旧 origin）。EU 池 id `da6fceba1d01eb4833a348e18e5373b4`，快照 `aws-data:/tmp/pools-snapshot-eu-fix.json`。教训：僵尸 agent pane 判活死金标=看 pane 当前命令(卡工具调用 vs claude REPL idle)+末行有无"Shutdown confirmed"，别凭 idle 心跳猜；清法 `tmux kill-pane`（产物落盘后）。
- **★G4 容量基线 + 容量定容铁律（owner 揪头发）**：抓手#2 前置量 HK master 余量。**先查 N9E/VM 历史峰值，别 live 采样低谷也别干等峰窗**（live 凌晨低谷 threads_connected=156 严重低估真峰）。VM 在 `aws-monitor:8428`，`max_over_time(mysql_global_status_threads_connected[7d])` 等。**真峰值**：HK master MySQL threads_connected **7d 峰 201/300（唯一约束）**，但 threads_running 峰仅 20 + QPS 2098（DB 不缺算力，201 多是 HikariCP 空闲池连接，连接由节点数×池大小驱动非负载）；Dragonfly 317/64000 clients + 88k ops（非瓶颈）。**抓手#2 +2 节点→峰 ~261/300(87%)紧→go-gate=max_connections 300→500(→52%)**。写路径直写 master 无需 region 写聚合/replica 化。categraf 未采 com_insert/update/delete（要写 TPS 需补采集）。**G3 批量切换脚本** `docs/sprint/2026-06-05-phase1-handle2-mainsite/batch-domain-lb-switch.sh`（dry-run 默认+快照+fail-fast+幂等+回滚，未执行）。本轮 commit `3a83bce8`（12 files +1487/-5，仅 doc+脚本+CLAUDE.md 实例勘误，**未 push**，领先 origin/master a7a08c90 一个）。
- **已上线**：Phase0（replica 路由 feed/markSeen）+ Phase0.1（settings/version multiGet）+ Phase0.2（TwoLevelCache 读写分离）+ Phase1 抓手#1（CF LB 删 country_pools[CN]，AMS 侧 ~23% CN 切就近 EU，零 5xx）。
- **进行中**：峰窗监控 background `blnhrufg6`（异常自动回报，~03:00 HKT all-clear）；L2 埋点阈值 200 在跑。
- **★三臂+RUM 真用户定论（6/04 18:30 峰前实测）**：方案2(flowzone LB-geo)CN TTFB p50 **330ms** vs 基线 17.rip 502 / 方案1 eduspace 502（p75 408 vs 864 vs 1318；LCP p50 1784 vs 2109 vs 3302）→ **方案2 真用户全面最优**（比单 HK 快 34-53%），方案1 mesh 误路由拖坏尾，Phase0.x 把 region origin 打到 8-11ms（降 ~30×）是兑现前提；残留 ~320ms 网络腿=CN 落远 POP（#106 核心，LB 改不了，需 CF China Network）。RUM 查法见 SESSION-STATE §1.5（VM nw_vitals_ttfb_ms by rum_host+cfCountry=CN，aws-monitor :8428）。
- **回滚弹药**：jar `/opt/newworld/newworld-web.jar.bak-pre<sha>`（每节点）；CF LB `aws-data:/tmp/lb-snapshot-20260604T101330Z.json`。
- **未做**：抓手#2（扩主站 17.rip+~84 A 域上 LB，高 stakes，单独 consensus+canary）/ Phase0.3 FVD salt。

**原始目标**：Phase 0（Redis read-replica 路由 + markSeen 异步 + config poller）部到 US/EU 区域 web，激活读卸载（reads→本地 Dragonfly replica，writes→HK master）。HK 不碰。

## 最终状态（全实证）
- **origin/master = `248922b7`**（fixed）。链：`59f91e96`→54303a09(Phase0 feat)→bc0003e1→f636d386→2d7d045f→**bed94146(fix)**→**248922b7(gate test)**。
- **US web** `44.249.182.197`（i-0b647009df3ed40b6, us-west-2, t3.xlarge, 内网 172.32.14.241）：jar md5 `870454...`，`REDIS_REPLICA_HOST=172.32.9.19`，Started 39.6s 0 致命 bean，feed 读 200@13ms。
- **EU web** `18.153.83.137`（i-078cd4680a5057272, eu-central-1, t3.large, 内网 172.33.6.211）：同 jar，`REDIS_REPLICA_HOST=172.33.8.248`，Started 50.4s 0 致命 bean，feed 读 200@10ms。
- **HK** aws-web-01/02：未动，200@3ms。Dragonfly replica：US 172.32.9.19 / EU 172.33.8.248，均 role:slave / master_link_status:up / sync_in_progress:0（replicaof HK 172.31.19.174）。

## 🔴 根因（4 次烧 deploy 的 bean 歧义启动崩）
引入 `StatsRedisConfig`(statsRedisConnectionFactory) + `ReplicaRedisConfig`(replicaRedisConnectionFactory) 两个用户自定义 `RedisConnectionFactory` 后，Spring Boot `RedisAutoConfiguration` 的 `redisConnectionFactory` 带 **`@ConditionalOnMissingBean(RedisConnectionFactory.class)`** → **整体退避不再创建**。而 `RedisConfig.stringRedisTemplate` + `redisMessageListenerContainer` 上的 `@Qualifier("redisConnectionFactory")` 无 bean 可解 → **NoSuchBeanDefinitionException 启动崩**。
**修法**（`bed94146`）：本类显式产出 master 工厂 `@Bean("redisConnectionFactory") @Primary RedisConnectionFactory`（Lettuce+池，host/port/pwd 取 `spring.data.redis.*`，复刻 ReplicaRedisConfig 模式）。按类型注入→master，@Qualifier 可解，replica 工厂仍不 @Primary 不抢主。

## 🟢 闸门：ApplicationContextRunner hermetic bean-wiring 测试（`248922b7`，还 @Disabled 欠债）
`@SpringBootTest(classes=WebApplication)` 载全 context 需 DB（masterDataSource 无驱动崩）→ 只能 @Disabled = 无闸门。**改写为 ApplicationContextRunner**：只注册 3 套 Redis Config + `RedisAutoConfiguration`（复现退避现场），4 断言（context 无 NoUnique/NoSuch/Override / 3 工厂按名解析 / @Primary CF=master / 3 StringRedisTemplate @Primary=master），秒级无 DB/Redis。两个 harness 坑：① 裸 runner 无 `ApplicationConversionService` → "5000ms"→Duration 转换崩 → `.withInitializer(ctx->ctx.getBeanFactory().setConversionService(ApplicationConversionService.getSharedInstance()))`；② `redisMessageListenerContainer` 是 SmartLifecycle，refresh 真连 Redis → 用 `BeanFactoryPostProcessor` removeBeanDefinition 移除它保 hermetic。`mvn test` 验证需 `-am`（否则用陈旧 .m2 common，snack VO "cannot find symbol" 假象）。

## ⚠️ 救命教训（每条都差点栽）
1. **git ref 断言前必 fetch**：我两次误判 master 状态——继承 summary 凭印象、我"纠偏"又凭没 fetch 的 stale 本地 master ref（显 59f91e96），fetch 后真相 origin/master=broken 的 2d7d045f。
2. **文件日志历史异常会骗死人**：US `/var/log/newworld-web.log` 累积 63 个历史 NoSuchBean（02:34 broken jar 残留），**必须时间戳 scoped 到本次 boot**（`awk '$1==date && $2>=time'`）才是真相。光看 health 200 会误判成功（致命错会 ABORT context 不打 "Started" 行 → 有 "Started WebApplication in Xs" 才是真起来）。
3. **假 0 陷阱**：EU 日志不在 /var/log（在 `/logs/web/all.log` + journald），awk 打错路径 file 不存在 → grep 无输入返 0，差点当"0 异常"。每节点日志 sink 不同必先 find 真路径。
4. **误归因代价**：dev 未提交的 RedisConfig 改动（就是缺的 bean）被我误判"冗余"让 owner 丢弃 → 合了起不来的版本。dangling blob 找不回（未提交不在 git）→ 重实现。

## 区域部署机制（durable）
- `scripts/deploy-web.sh` **硬编码只打 HK aws-web-01/02**，禁用于区域。
- 区域节点经 **EC2 Instance Connect**（profile **nw-dev**）：`aws ec2-instance-connect send-ssh-public-key --profile nw-dev --region <r> --instance-id <id> --instance-os-user ubuntu --ssh-public-key file://~/.ssh/id_ed25519.pub` → `ssh -i ~/.ssh/id_ed25519 ubuntu@<公网IP>`（key TTL 60s，每次 scp/ssh 前重 push）。本机(172.31.20.251 HK VPC)+ aws-data 均有 nw-dev 凭证。
- 区域 web jar = **`/opt/newworld/newworld-web.jar`**（直 `java -jar`，非 symlink-current；root:root）。部署=备份 `.bak-pre<sha>` + scp 到 /tmp + `sudo mv` + chown + `systemctl restart newworld-web`。EnvironmentFile=`/opt/newworld/secrets.env`。
- **replica 路由 drop-in** `/etc/systemd/system/newworld-web.service.d/redis-replica.conf`：`Environment=REDIS_REPLICA_HOST=<本区 Dragonfly>`。**密码默认回落** `spring.data.redis.password`（master 密码）——US Dragonfly 用 master 密码 PONG 实测通（replica 共 master auth），故 drop-in 无需放密码。EU 历史上显式设了 REDIS_REPLICA_PASSWORD（冗余但无害）。**两区起始不对等**：EU 有 replica drop-in、US 只有 slave-datasource.conf(MySQL)——US 这次补上 redis-replica.conf 才对等。
- build：aws-data `git pull origin master` + `mvn package -pl newworld-common,newworld-web -am -DskipTests`，jar 拉本机再 Instance Connect scp 到区域（aws-data→区域 web 22 不在 SG 白名单）。

## dedup + 双引擎验证（✅ 完成 2026-06-04）
- **服务端 dedup 确定性测**（权威，`agents/feed-dedup-api.js`）：复刻 AESUtil AES-256-CBC 解密（MASTER_KEY=`NewWorld2024SecretKey@AES256!`，key=SHA256(MASTER_KEY+`(ts/300000)*300000`5min窗)，iv=SHA256("IV"+MASTER_KEY+原始ts)[:16]，X-Timestamp header 定 key），EU 新代码 localhost 真翻 8 页 cursor（稳定 cookie jar + X-NW-Visitor-Id）：192 项**同 cycle 跨页重复=0** → markSeen 异步后服务端去重正确。
- **前端 4 象限**（`agents/t7b-feed-dedup.js`）：Chromium/WebKit×PC/Mobile **console error 全 0**。本次只换 backend、frontend bundle 未动 → 渲染零回归。
- **dedup 教训**：① 加密响应（`{encrypted:true,data:base64}`）API 测必复刻解密（AESUtil 权威非文档）；feed/v2 非 @SkipEncrypt。② T7/t7b 浏览器 DOM-based 测假 fail——首页轮播多区块重复渲染同一 item=DOM 噪声非翻页 dedup 失败（feedV2Responses=1 没真翻页）；可靠 dedup 测要么确定性 API 解密、要么浏览器导航到 cursor feed 专面 + 滚正确容器 + cycle-aware（cycle 递增设计内允许重复）。③ 真 cursor feed endpoint=`GET /api/v1/courses/feed/v2?cursor=&size=&tab=feed`（courses=movies 隐写），item 链接 `/lessons/<id>`；`/feed/session` 不存在(404 body)。④ dedup 双层：服务端 markSeen Bloom + 客户端 seenIds Set(feedCursor.js 主防线)。

## Phase 0.1（✅ 完成 2026-06-04）：settings/version 走 replica + multiGet
- **RCA**（真流量实测）：`ConfigController.getConfigVersion()` 调 `redisVersion()` **7 次串行 master `opsForValue().get()` 跨洋** = US 1014ms / EU 1321ms urt（openresty web.log 实测，调用量 3000+/样本=区域 origin urt 头号拖累，远超 feed）。
- **修法**（commit 482d3f63，蓝军 CONDITIONAL GO 3 MAJOR 全修）：注入 `@Qualifier("replicaStringRedisTemplate")` + 1 次本地 `multiGet(6 去重 key)`；F3 安全模板=static final VERSION_KEYS（顺序绑索引防错位）+ null/NumberFormat 防护 + try-catch 全 0 降级。adVersion 复用 snackVersion 值（向后兼容老 JS）。范围仅 version 端点（FVD salt L625 + getFullConfig 不碰）。
- **真流量验证**（scoped 部署后）：US settings/version urt **1014→5ms**，EU **1321→7ms**（~200×）。两区 Started 干净 0 致命 bean，HK 不碰。ConfigControllerTest 60 PASS。
- **教训**：① 部署后量指标必 **scoped 到重启时戳之后**——`tail -n N` 含部署前老流量会让 p50 仍显旧值（又一次"还是慢"假象，同 stale-log/假-0 同源）。② 加 @Qualifier replica 字段后 ConfigControllerTest 必同步补 mock（@InjectMocks 按字段名注入 null）+ 连带 CorsIntegration 等打同端点的测试（STRICT_STUBS UnnecessaryStubbing）。
- 设计/蓝军档：`docs/sprint/_archive/2026-06-02-redis-geo-ha/PHASE0.1-settings-version-replica.md` + `agents/reviewer-phase0.1.md`。

## Phase 0.2（✅ 完成 2026-06-04，commit 939fe6e4）：TwoLevelCache L2 读写分离
- **nw-consensus 团队首战**（章程 `docs/sprint/TEAM-CONSENSUS-CHARTER.md`：独立分析→crossfire→一致通过→不串轮次）。Round1 RCA + Round2 SOLUTION + Round3 diff review，全 docs/sprint/_archive/2026-06-04-phase0.2-crossocean-audit/。
- **头号发现（团队价值兑现）**：`CacheConfig.java:43` 按类型注入 @Primary **master** 传给 TwoLevelCache → 所有 `@Cacheable("web")` L1-miss 的 **L2 GET 全跨洋 master**（最高频未卸载面）。**lead solo scout + 分析成员 A/C 都漏了（只 grep replicaStringRedisTemplate 注入点），蓝军 D 独立揪出 BLOCKER，lead 实证仲裁确认**。
- **修法**：TwoLevelCache 读写分离——`readRedisCache`(replica，L2 GET) + `writeRedisCache`(master，put/evict/clear) + `stringRedisTemplate`(master，expire+scan)。约束=expire/scan 写同模板**不能简单换 replica**（READONLY 拒写），必须分离。CacheConfig **用同一 createRedisCacheManager 工厂方法**建 master+replica 双 manager（保 key prefix `computePrefixWith(cacheName+":")` 一致，防 L2 静默 miss）+ @Qualifier 精确。ReplicaRedisConfig 池 20→40+maxWait=500ms。**fvd 保 master 不卸载**（read-after-write）。
- **验证**：US/EU Started 干净 0 致命 bean（双 @Qualifier wiring 过）+ **运行时 READONLY=0**（实打 @Cacheable 端点触发缓存读写，证写→master/读→replica 分离真生效，蓝军最担心的 BLOCKER 风险运行时不存在）。TwoLevelCacheTest 5 PASS（防呆验读→replica/写→master，杜绝未来误接写 op）。
- **ROI 诚实口径**：≠ Phase 0.1 干净 200×；TwoLevelCache 卸载聚合收益**取决于 L1(Caffeine) 命中率**（L1 命中不碰 Redis，只 L1-miss+L2-hit 才吃本地 replica），蓝军 Round1 早点问号。**架构卸载落地+正确性证，聚合幅度需 L2 命中率埋点量化（backlog）**。
- **教训**：① 缓存基建（TwoLevelCache/CacheConfig）的 master/replica 注入是 grep `replicaStringRedisTemplate` 注入点扫不到的盲区——必须追 `@Cacheable` 的 CacheManager 注入源。② 读写同模板的组件卸载必读写分离（readCache=replica/writeCache=master），写 op 漏一个=运行时 READONLY 500。③ 双 RedisCacheManager 必用同工厂方法（prefix 一致），否则 L2 静默永久 miss。④ 部署后量缓存类 ROI 要看 L1 命中率，别期望 settings/version 式干净倍数。

## Phase 0.2 ROI 真埋点量化（✅ 2026-06-04，commit fe679fed 埋点 + 5c6988a8 阈值降 200）
- **埋点实测**（US，200 次缓存访问采样）：`[L2CacheMetrics] total=200 L1hit=63(32%) L2reads=137(69%) L2hit=85(62% of L2reads) L2miss=52`。
- **关键数据 L1 命中率仅 32%**（远非"L1 抓大头"）→ **69% cacheable 缓存访问走 L2 Redis**（长尾内容高基数，Caffeine 20000/24h 留不住）→ Phase 0.2 对这 69% 全部生效卸载到本地 replica，每次省 ~143(US)/188(EU)ms。
- **缓存访问率三角印证 ~0.084/s**（访问日志 541 cacheable 端点/107min + 埋点 ~177/35min）→ L2 读率 ≈ 0.058/s → US 聚合 ≈ 8ms/s（日累计 ~5000 卸载读/~12min 延迟）。
- **结论（诚实+准）**：**per-access 卸载效率高（69% cacheable 读受益）**，但 canary 聚合 ROI 小**纯因 volume 低**；**价值随内容浏览量线性放大**（全量/方案2 切流后内容浏览是主流量）。不是"缓存没用"，是 L1 留不住长尾→多数缓存读真打 L2 跨洋（正是卸载意义）。
- **方法论教训**：① 量缓存 ROI 别假设 L1 命中率高（实测 32%，凭印象会严重低估卸载价值）。② 埋点阈值要匹配流量（20000 在 0.084/s 下 28h 才出，降到 200 才分钟级；高流量节点反之）。③ `--scan --pattern` 跨洋全扫 280 万 key 必超时返假 0（差点据此误判"缓存空 Phase0.2 净负"）→ 用 RANDOMKEY 抽样 + 单批 SCAN。④ 缓存基建 master/replica 注入是 grep replicaStringRedisTemplate 注入点的盲区（追 @Cacheable CacheManager 注入源）。

## 方案2 Phase1 抓手#1 切流（✅ 执行成功 2026-06-04 ~10:18Z，nw-consensus + owner sign-off）
- **动作**（CF LB `lblb.17.rip` id ebe3286…/zone 17.rip/account A）：删 `country_pools[CN]`（原=[us,eu,hk] us 首位=#106 元凶）+ region_pools 改多池有序（修容灾）。
- **效果实证**：US origin CN-AMS 1213→9（清空）、EU origin 收 119 → **AMS 侧 ~23% CN 从钉 US 改走就近 EU**，POP→origin 腿省 ~145ms；零 5xx、CN 成功率 US 98.9%/EU 98.1%；SEA/LAX-CN（WNAM 77%）仍 us 不变。
- **改善面仅 ~23%（AMS 侧）**：CN POP 分布实测 SEA 55%/LAX+SJC 22%/AMS 23%；WNAM(SEA/LAX)→us region_pools 也是 us 故不变。**#106 非 LB 可解**（真因=CN 落远 POP=CF Anycast/中国网络，LB 只管 POP→origin）。
- **🔴 CF LB API durable 教训**（高复用）：① **CF LB PATCH 对 country_pools/嵌套字段空转**（返 success:true 但 GET 复核零改动）→ 必须 **PUT 全量**（剥 id/created_on/modified_on）；**success≠生效必 GET 复核**（又一次 success≠生效）。② **`failover_across_pools` 不是 CF LB 真字段**（FINAL-PLAN 档名错，PUT 后仍 null）→ CF 真 failover = **region_pools/country_pools 列表多池有序 + LB 级 fallback_pool**（本次 fallback_pool=us 已设）。③ 分阶段（只读前置快照 + 每步 GET 复核）救命：揪出 jq 引号坑致快照 0 bytes + PATCH 空转，未在脏状态上 PATCH。
- 快照/回滚：`aws-data:/tmp/lb-snapshot-20260604T101330Z.json`（全回滚=PUT 它；部分回滚=PUT 当前+country_pools.CN）。文档 `docs/sprint/_archive/2026-06-04-phase1-cn-routing/`（SOLUTION-LOCKED + EXECUTION-RESULT + agents R1）。
- **抓手#2**（未做）：扩主站 17.rip + ~84 A 域上 LB（高 stakes，单独 nw-consensus + canary）。

## 剩余 / backlog（交 nw-consensus 团队）
- Phase 0.2 后续 MINOR：applyTtlJitter prefix 耦合、replica 池 N9E 告警、disableCachingNullValues 语义、L2 命中率埋点量化 ROI。
- Phase 0.3 候选：FVD salt（ConfigController L668/677，read-after-write 需 lag-tolerant 设计）。
- 方案2 CN 切流 canary（峰窗，Phase 1）。

相关：[[project_db_replica_us_eu_2026_05_30]]（MySQL replica + ROI：真瓶颈是跨洋 Dragonfly 非 MySQL，本 Phase 0 正是补 Dragonfly 读卸载）、[[reference_lettuce_pipeline_command_timeout]]（5/31 加第2个 RedisTemplate bean 致 admin 启动崩同类雷）。

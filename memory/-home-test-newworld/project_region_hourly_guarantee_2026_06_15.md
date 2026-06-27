---
name: project_region_hourly_guarantee_2026_06_15
description: "2026-06-15 每地区每小时≥1真入库保障(ProbeHelper深翻标准化)+ cableav封面首帧兜底 + finalize boolean对齐5源 + 3爬虫bug + 编号/批量去重\"已存在勿重造\"分析"
metadata: 
  node_type: memory
  type: project
  originSessionId: ce27c9bf-720e-4350-ba00-8892b604bf34
---

2026-06-15 owner 从"cableav 封面 403/cn 地区每小时 0 部入库"发起,演进为**每地区每小时≥1 真入库的标准化保障** sprint。延续 [[project_data_hourly_collection_fix_2026_06_15]](同日前序:wowstream 代理/hanime1 FlareSolverr/jable CF)。

## 核心结论(各点都经多 agent + lead 二查 + 生产实锤)
1. **"翻页找新数据"机制早已存在 = `ProbeHelper.probeAndCrawl`**(5/12 建,5 个每小时源共用):page1 latest → 全 skip 则从 Redis 页号 cursor probe BACKFILL_WINDOW 页 → 命中即返,否则 cursor 推进。**勿重造**(同 ProbeHelper-本身/批量去重 教训:owner 设想常=已存在的最优实现)。本次只**扩展**它真正"保证 ≥1"。
2. **编号/批量去重标准已存在**(BSP agent team 分析定论):每源 `toMovieNumber(id)=前缀+站内id`(确定性纯函数,list 页 id 直接算不抓 detail;jable 例外=裸番号无前缀;avjiali=下划线);现网主路径 = list 推 number → `findByMovieNumbers` 批量 IN 查(movie_number UNIQUE+索引)→ status==1 skip(**不抓 detail**)→ 只对 DB-miss 抓 detail。比逐条抓 detail ~10×。Bloom 是 web 读侧(BloomFilter<Integer> movieId),**非爬虫去重**(爬虫用 DB 精确比对,Bloom 假阳会永久漏采)。owner"预生成编号+批量比对"=此现状,**非待建新方案、非低性能**。

## 改动(commit 链 692f06ed→df02af1c→8b8ee5c3→0d699adf,merge `d56c60d1`,jar 20260615-201846,605 tests)
- **ProbeHelper.probeUntilFinalized(新,标准可复用)**:循环推进 backfill window 直到本源 ≥1 **真 finalized** 或撞 `crawler.region-guarantee.max-pages`(20)/`max-duration-sec`(2700);5 源全接;Javadoc 写清"新源接入3步法"+ movieCount=finalized 契约。页内分析不限量(便宜),只 cap 真下载。
- **finalize 判据对齐(蓝军 B3)**:`finalizeMovieWithDispatch` 从 void 改 **boolean**(P7-Gate total_segments≤0 拒绝返 false),caller `success=videoOk&&finalizeOk`——**5 源(cableav/beeg/javxx/AbstractXvideosChannelCrawler 家族含 hanime1/xvgay/xvtrans)**,确保 movieCount=真 status=1(否则 ≥1 保证是空头)。
- **cableav 封面首帧兜底(cn 硬阻塞)**:封面 host(sex8sex8sex8.com 老/pic7.sex8sex866.com 新,**轮换**)对老内容 **IP 地域封**(403 "region denied",CA+buyvm LA 都被拒,**非 TLS 指纹**——lead 一度误判 TLS 被 POC 纠正:FlareSolverr 200 实为 region-denied 错误页 len386)。修=封面 403 不清理→HLS 后用本地 plain ts `FfmpegPreviewService.extractFirstFrameJpeg`(concat→temp.mp4 -c copy → keyframe seek 抽中段帧,避 concat -ss 顺序解码超时)抽帧当封面;**首帧也失败则回滚不入库(owner 选保画质)**。新内容封面(pic7,Java 直取 200)不受影响。host-rewrite 无效(轮换 host 非镜像,新 host 对老路径 404)。
- **hanime1 动漫/3D 两池各≥1**:anime 池(libang/paomian/motion)+ 3d 池(3dcg/25d/2d/aigen/mmd)各自 probe,池内换 channel 直到各 ≥1;全局预算 GLOBAL_BUDGET_SEC=3300(两池共享,传 remainingSec,防双倍超支跨小时占满 2 线程调度池)。
- **深翻老内容 create_time=publishDate**(非 now,蓝军 M5)防插队首页"最新"Tab;backfill 不触发 CONTENT_VERSION。
- **3 爬虫真 bug(蓝军 Round2 实证,非每小时源但真缺陷)**:XHamster toMovieNumber 自递归(StackOverflow)+ allNumbers 双前缀 dedup 失效;Kanav 无批量去重(加 findByMovieNumbers 层);Pornhub viewkey 正则 [a-z0-9](本轮一度加大写又因无实证回退)。

## 生产验证(jar 201846,13:00 UTC 整点)
**cableav(cn)0→9 入库**(封面降级6→首帧兜底6→回滚0);深翻 backfill page=6 命中 ok=1;javxx/jable=1;代理切 859 次兜底也失败 0(无回归);NRestarts=0 无 OOM 无跨小时占线。beeg 本轮 0=真无新货(深翻已尽,guarantee 造不出不存在内容)。

## 方法论(BSP agent team)
编号分析用正式 agent team(TeamCreate `crawl-dedup-analysis`,3 analyst+蓝军,superstep 放开吵+互证纠错+barrier lead 二查收口);蓝军两轮+实现 review 共发现 4 BLOCKER/多 MAJOR,lead 二查驳回 1 条误判(ProbeHelper all-skip→深翻是有意正确,蓝军 F6 提的"skip>0 停"会破坏深翻)。agent 被 context-mode hook 拦 mvn → lead 经 ctx 跑全量验证兜底。CloakBrowser 评估见 [[reference_cloakbrowser_cf_bypass]],owner 定不替 FlareSolverr。

## ★部署后第二章:cursor-runaway 啃老死内容 → 近期优先重写(commit cbc4a04f,jar 215457)
首版部署(jar 201846)后**实测 cn 仍 0**:cableav probeUntilFinalized 旧逻辑用 **Redis 远游标越翻越老**,撞到老 backfill 内容——老内容不光封面老 host 地域封(首帧兜底),**视频/AES 密钥也死**(downloadEncryptionKey keyUri=null → NPE "已重试3次): null" 26次/轮),45min 撞 max-duration 才 4 页、movieCount=0。
- **根因纠正(我先前误判两次)**:① 把运行中 stage-1 INSERT(status=0)当 finalized 误报"cn 0→9",owner 看 DB 没数据戳破(铁律:movieCount=真status=1 才算,日志 INSERT≠入库);② cableav 封面 403 我一度判 TLS 指纹被 POC 纠为 **IP 地域封**(同前序教训)。
- **修(owner 拍板)**:① probeUntilFinalized 改**自顶向下扫 page2..maxPages 优先近期未采、去远游标 runaway(绝不进~480页老死区)**,近期采平诚实返0;② downloadEncryptionKey keyUri/keyUrl null → 干净 IOException 非 NPE。commit cc618312+测试修8c28ba30→merge cbc4a04f,641 tests。
- **实测验证(jar 215457,22:00轮)**:cableav **7min39s**(旧45min)、NPE **0**、近期20页全skip诚实返0、首帧兜底8。
- **★cn=0 终判=真采平(DB root socket 实证)**:站上最新8唯一id(到91219)**全在DB status=1**,DB max cableav id=91219=站上max → 一部不缺、非误跳。cn=0 是"没新货"非坏。jp/动漫/3D 本轮有新货均≥1。
- **可复用坑**:① **agent isolation worktree 会拿过期基线**(dev 首次在缺 region 工作的 8ba4852d 上改错了 legacy probeAndCrawl,生产调的是 probeUntilFinalized;lead 二查 `git merge-base --is-ancestor`+测试数 543<605 识破 → 用 `git worktree add <branch> <显式commit>` 锁基线重做);② **newworld DB 用户 CLI 连不上(grant/认证差异,app 能连 CLI denied),直查走 ca-db-master(ssh aws-region-usw1-db)`sudo mysql` root socket**;③ dev 新测试反复漏 import(java.util.Map/java.io.IOException)→ lead 二查 mvn 兜。
- **遗留**:≥1 保证受 maxPages=20/轮 限制 + 造不出不存在内容(源采平则诚实0);老内容死媒体(视频/key)不可 finalize;jable 裸番号命名空间隐患;buyvm DB 拓扑;均非阻塞。

## ★★第三章:细水长流标准重构 FreshnessTrickle(2026-06-15 夜,owner 多轮澄清后定稿)
**真需求(owner 最终拍板,推翻"1h内采到最大页/全量回填"过度设计)**:每轮每区 ≥1 部"用户没见过的新货"(常鲜),**但别太快采干**——源未采内容=储备水库,细水长流放。owner 一句话点破前几版盲区:**记页码会分页漂移(新增1页→老第10页挤成第11页,记游标必错)→ 标识驱动(movie_number 查库)非位置驱动**。
**方案(DESIGN-incremental-freshness-standard.md)**:① 扫新片=永远从 page1 扫前 recentPages(5)页,按编号 findByMovieNumbers 去重(不记页码=防漂移);② 仅当①零 finalized→从 Redis 书签 `crawler:backfill-bookmark:<src>` 往深走 backfillChunk(20)页补 1 部老内容、书签推进(书签只管旧史、新片永远前页兜→漂移无害);死片 finalize 失败≥maxAttempts(3)→markDead status=2、skip 判据放宽 status∈{1,2}(放开页上限/治 runaway 的前提)。**标准可复用组件 5 源共用,新源只插 crawlByPageRange**。
**实现**:`FreshnessTrickle.java`+`FreshnessConfig.java`(@ConfigurationProperties `crawler.freshness.*`,禁 @Value relaxed-binding 坑);commit 链 4652b22f→137316ee(markDead)→27147089(蓝军F1-F7)→30e73e28(lead修编译/测试)→merge **870d03d9**,689 tests。jar `newworld-data-20260616-003557`。
**质量门**:蓝军7条(1BLOCKER F7 计数器误重置+3MAJOR)全坐实无误报;**lead 二查另抓1 BLOCKER:deadMarker 5源全没接通(都用无回调5参版)→runaway 复发**。★**dev 被 context-mode hook 拦 mvn=结构性盲改**,交付带 16 编译错(merge(Integer::sum)在Map<Object>非法/updateById(any())歧义/assertEquals歧义)+1测试失败(F7 mock increment恒3L致reset调8次),且一度为编译不过的原码辩护→lead 经 ctx 跑 mvn 兜底逐个修绿(put+cast/any(Movie.class)/(int)强转/atLeastOnce)。教训:**agent 盲改循环时 lead 直接接管修+mvn验最快,别空转往返**。
**生产实测(部署后17:00/18:00两轮)**:javxx/jable ①扫新片各+1;hanime1 动漫(motion)+1/3D(25d)+1(paomian真末页采平);**beeg 冷启首轮(书签1)在已采前段6-25空转→0,次轮书签26进未采区 page31命中+1、DB794→795=自愈成功,核心设计在backlog源验证通过**。
**★cableav 例外=老内容 host 网络拦截(owner直觉纠错,我"死密钥/fMP4"表面结论错)**:backfill 进未采区但每部"整部回滚"0入库;实测真因=老 host **`picc.sex8sex855.com` Read timed out + `xing.sex8sex833.com` HTTP 403 geo-block(连 buyvm LA 代理209.141.48.177:3128兜底也403)**;新内容 host `pic7.sex8sex866.com` 正常。**与 wowstream 同类的 host 级 geo-block/节流,独立跟进(需换出口IP/代理),非细水长流锅**。另暴露设计缺口:**回滚型源(cableav)HLS失败删行→deadMarker(UPDATE WHERE status=0)标不上→死片churn**(beeg/jable是skip型未暴露);待修=回滚留 status=2 墓碑或 markDead 不存在则 INSERT 墓碑。

---
name: project_crawler_convergence_batch_2026_07_04
description: "爬虫批量收敛(B4)——9家迁 AbstractStandaloneCrawler + 4家排除,基类+6钩子,dry-run PASS 逮到video_duration回归,未部署待Owner"
metadata: 
  node_type: memory
  type: project
  originSessionId: 293fba68-3676-40ca-9c18-59b8e428181f
---

代码精简 **B 组·爬虫收敛(B4)**:9 家迁移 `extends AbstractStandaloneCrawler` + 4 家排除,行为保持,dry-run PASS。**已合 master `3152a5fa` + 部署 ca-admin(data 单实例,current.jar→20260704-142902.jar md5 42dd1467,NRestarts=0 active 启动无 ERROR,含 Beeg video_duration 生产 bug 修复)**。收敛分支已清理。

**范围结果**(backlog 原写"剩 13 家 Jsoup 同构",实证偏乐观):
- **迁移 9 家**:Porcore/XvTrans/XvGay/Pornhub/Kanav/Cableav/Avjiali(MP4→ffmpeg→HLS,override downloadHls)/Javxx/Hanime(+Beeg pilot 已在 master)。净删 **−1549 行**。
- **★排除 4 家(三源实证不兼容 HLS 基类,强迁破坏行为,不删除)**:Tranny/Rule34/HqPorner=2026-04-14「拒切片即放弃」休眠 MP4 哑管道(0 VideoDownloadService、P7-Gate 永卡 status=0、ConditionalOnProperty 默认 false);XHamster=元数据-only(无视频阶段)+ 逐条 inferRegion(基类 region() 签名级不兼容)+ metadataChanged→CH_METADATA_REFRESH 追踪(基类无通道)。

**基类演进 +6 protected 钩子(defaults 零回归)**:isAlreadyProcessed(三态 status=3)/resolveTitleZh(确定性繁→简 vs LLM)/resolveCreateTime(源发布日期驱动 StockPublisher)—Cableav;afterItemPersisted(bloom-add 即时可见性)—XvTrans/XvGay/Hanime override;rollbackOnVideoFailure(Hanime resume-backfill incident-fix,HLS 失败留 status=0 待补片)—Hanime override false;useDraftVideoDuration(见下 bug)—Cableav/Beeg override false。

**★★dry-run 逮到并修复的框架级真回归(单测 815 全绿都漏)**:基类 crawlOneItem Stage1 无条件 `setVideoDuration(draft)` → Stage2.6 saveVideoSegments 从真实切片算准确值 UPDATE DB 但不同步内存 → Stage3 `updateById` 用 stale 内存对象(MyBatis-Plus NOT_NULL)覆盖回 draft。各家语义本不同:多数用 draft(基类默认对)、Cableav+Beeg 用 saveVideoSegments 权威值(Cableav draft=5439 是列表页解析 bug)。修:`useDraftVideoDuration()` 钩子。**牵出生产 Beeg 潜伏 bug**(pilot 36e6a4a8 引入,Task9 样本 durationSec 恰空躲过)——一并纠正(部署后生效)。**这是逐字节 dry-run > 单测的铁证**。

**dry-run 验证(buyvm-data 隔离,Task9 式)**:6 家真逐字节 0 diff(Porcore/XvTrans/XvGay/Kanav/Cableav 复验/Hanime ★真触发 resume-backfill 失败路径且一致)+ 3 家代码级 PASS(Pornhub/Avjiali/Javxx 站点阻断,关键解析函数静态 diff 逐字节相同 + 两 jar 同失败复现)。铁律 [[reference_crawler_dryrun_id_collision_mock_llm]]:AUTO_INCREMENT=90000000 防 R2 撞键(Beeg pilot 曾覆盖 6 部生产)+ mock LLM 破富化门 + 生产 DB 黑名单 guard。before jar=172bd4d0/after=fe958322。

**★方法论亮点(可复用)**:①9 dev-senior 并行独立 worktree 迁移(禁改基类,需加钩子则停下上报,单一写者协调防冲突);②**4 家诚实上报结构性阻塞停工待决**(未强迁破坏行为)——蓝军式发现,我逐条三源核实;③Decision Point 由我集中加基类钩子**保住**行为(非默默丢);④ops-senior 跑 dry-run(production-adjacent ops 交 ops-senior);⑤dry-run 是行为保持金标,单测漏的框架回归靠它逮。

**待 Owner surface(不阻塞)**:Kanav review-gate fix 从未合入(现状自动上线,设 status=0 会被基类误删待审);XHamster 因无视频从未上线过一部(半成品 vs 废弃);Avjiali+Hanime 页内并发退化为基类单线程串行(吞吐降,离线批处理可接受);Beeg 生产 video_duration bug 已随本 fix 纠正。

关联 [[project_crawler_pilot_task9_dryrun_2026_07_03]](Beeg pilot)、[[reference_crawler_dryrun_id_collision_mock_llm]]、[[project_movieservice_god_class_split_2026_07_04]](同期 B5)。代码精简 A/C/D/B5/B4 全完成。

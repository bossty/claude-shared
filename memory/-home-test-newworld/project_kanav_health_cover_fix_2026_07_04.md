---
name: project_kanav_health_cover_fix_2026_07_04
description: "Kanav 采集健康核查(2026-07-04):视频端到端OK但封面潜伏NULL(取错页面),已修从列表页配对;生产0部;review-gate从未生效"
metadata: 
  node_type: memory
  type: project
  originSessionId: a747b1bc-a1d7-4c6e-a88e-920bc5cc6423
---

Owner 问"Kanav 采集代码是否正常工作",buyvm 隔离 live dry-run 复确认(2026-07-04),结论分三层:

**① 视频采集端到端 OK(live 实证)**:CF Turnstile 靠 FlareSolverr 绕过(列表页+play 页均 200)→player_aaaa base64 解码→m3u8→HLS 处理+R2 上传→total_segments/video_duration 有值→入库。mock LLM 富化门过。movieCount=2 fail=0。

**② 生产 0 部**:`source='kanav'` = 0/43849。因默认 `@ConditionalOnProperty app.crawler.kanav.enabled=false`(生产 aws-data/ca-admin 不加载)+无 @Scheduled/无 CrawlTask+只 buyvm 手动 `POST /crawler/kanav/crawl-pages`(或 /batch)。不是自动采集,从没往生产落过。

**③ ★封面潜伏 bug(已修,commit `db45133a`,分支 fix/kanav-cover-from-listpage 未合 master)**:
- 现象:cover_image/thumbnail/blurhash 恒 NULL(生产 0 部所以从没被发现)。
- 根因=取错页面:`parseDetail` 从 **play 页**找 og:image(现站无)+MacCMS 兜底 `/upload/vod/{vodId}.jpg`(现站 404,146B);而 `crawlListPage` 只用 VOD_ID_PATTERN 抽 vodId、**丢弃列表页 card 里 `<img data-original>` 的真封面**。真源在列表页每个 card:`img.11yun.xyz/RGAV1/{picId}/{picId}.jpg`,**picId≠vodId 只能按条目配对取**(live 抓验证真源 200/25KB/jpeg,无 CF 无 referer 门)。非迁移引入(downloadWithReferer 逐字对齐原版)。
- 修:新增 VOD_ITEM_COVER_PATTERN + 静态 `parseVodIdCoverPairs(html)` 按 card 配对;crawlListPage 额外 populate 实例字段 pageCoverUrls(vodId 发现口径不变零回归);parseDetail 优先取 map,单条路径回退旧解析。3 单测+863 全绿。dry-run 修复后 cover+blurhash 全入库。
- ★方法论:Owner 用域知识反诘"列表页不是有封面吗"逼出完整根因——我最初只验了 play 页误判"站点漂移",列表页才是真源。见 [[feedback_verify_not_recall]] 锚现象。

**④ ★review-gate 已解决(2026-07-05,commit `f429ee67`,分支 fix/kanav-review-gate-status3 未合)**:2026-05-26 铁律"入库待审、admin 审核后手动上架"从未落地(修复 commit d8bb0256/137b3a2a 从没合入,实际 `setStatus(1)` 自动上线,dry-run status=1 实证)。
- **★纠正历史误判(Owner 反诘逼出)**:我和迁移作者 DP#1 都错在——收敛设计表 §6 误写 hold 值 `onlineStatus() Kanav→0`(撞基类 `status==0→cleanupIncompleteMovie` 清理重采),据此错推"需新增 reviewStatus 字段解耦"。Owner 指出"cableav 不是有类似字段值么"→正解 hold 值应为 **status=3**(Cableav 三态存量模型早跑通),status=3 因 `isAlreadyProcessed` 短路天然到不了清理分支,**无需新字段/改基类**。=包装决策而非算法决策的又一例([[feedback_declarative_over_procedural]])。
- **实现(照抄 Cableav 两钩子)**:`onlineStatus()→3`(存量非1) + `isAlreadyProcessed()→1||2||3` + 移除采集侧 `notifyAfterBatchCrawl`(存量不 bump CONTENT_VERSION,可见性由发布时负责)。
- **variant a 人工审核**:Kanav **不**入 `StockPublishConfig.enabledSources`(默认仅 cableav)→不自动放水;status=3 存量等 admin 后台(movie 列表 `findByPageWithKeyword` 按 status=3+source=kanav 筛)逐部人工放行 status=3→1。824 clean 全绿。
- **status 语义权威**:0 草稿/未完成(cleanup 清)、1 上线、2 dead、3 存量待上线(用户不可见)。基类钩子 `onlineStatus()`(默认1)+`isAlreadyProcessed()`(默认1||2)为三态家而设。
- 待办:admin 放行 status=3→1 若走通用 movie-edit 而非 StockPublisher.publishOne,可见性(bloom/CONTENT_VERSION)靠 RecomputeQueue≤2min 兜底;若要即时可考虑 admin"审核放行"端点复用 publishOne 语义。

**dry-run 环境(buyvm-data,ssh 用户 test)**:`/home/test/dryrun/` harness(run-one-generic.sh + reset-db.sh + mock_llm.py + 种子 SQL),Docker dryrun-mysql(8.4)/dryrun-redis(7-alpine)手动重建,FlareSolverr 常驻:8191。Kanav 跑法:`FAMILY_NAME/PATH=kanav FAMILY_ENABLE=app.crawler.kanav.enabled FAMILY_CAP_ENV=CRAWLER_KANAV_HARD_CAP_PER_RUN FAMILY_CAP_VAL=2 FAMILY_EXTRA_ENV="FLARESOLVERR_URL=http://127.0.0.1:8191/v1" FAMILY_EXTRA_ARGS="--cf.bypass-hosts=...,kanav.ad"`。铁律 AUTO_INCREMENT=90000000 见 [[reference_crawler_dryrun_id_collision_mock_llm]]。

关联:爬虫收敛 B4 见 [[project_crawler_convergence_batch_2026_07_04]];同会话删除 4 家排除爬虫(分支 chore/data-remove-excluded-crawlers,commit 5c9c31d9,未合)。

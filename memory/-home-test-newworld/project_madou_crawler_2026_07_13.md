---
name: project_madou_crawler_2026_07_13
description: BL-59 madou.club 采集接入——开发+测试完成未部署，分支 feat/madou-crawler，含多机厂牌分片
metadata:
  type: project
---

**BL-59 madou.club 采集接入**：region=cn 新采集源，31 厂牌全采、囤后放(status=3)、源站中文标签三分流(题材→movie_tag/女优→actor/厂牌→传媒公司 tag group id=1000)、region=cn 强制注入三 category(8无码/18国产/3中文字幕)+置 is_uncensored/has_subtitle 字段。**不需金标**(源站标签已人工标好，确定性查表)。

**状态(2026-07-13)**：开发+测试完成，**未部署**(Owner 指令不部署)。分支 `feat/madou-crawler`(worktree `/home/test/worktree-madou`)，15 commits，未合 master。占坑 BACKLOG BL-59 进行中(master `71cbe7724`)。全量回归 1621 测试 0 失败。

**source/number 命名(Owner 定)**：movie.source=`madouclub`(须与 source_tag_mapping.source_name/stock-publish.enabled-sources/FreshnessTrickle 书签四处一致)；movie_number 前缀=`madouclub-`(对齐 cableav-/supjav- 惯例)；lock/config 键保留 madou 内部命名空间。

**封面/预览**：封面=源站原图(/covers 去-240x180 缩略后缀)；预览=downloadHls 保留解密明文 ts→ffmpegPreviewService.buildFromLocalTs 生成 mp4 传 R2 写 preview_video(照 cableav；初版漏做后补)。

**两轮 review(蓝军+fable5 设计复核)已修**(`BLUE-TEAM-RESOLUTION.md`/`DESIGN-REVIEW-RESOLUTION.md`)：
- 蓝军 F1(跨源判重 null→NPE 假失败)：初版加基类 null→SKIPPED 守卫有跨爬虫副作用(削弱 supjav 等熔断:源挂 parseDetail 返 null 被当中性跳过)→**revert 基类**、madou 本地去掉 content_number crawl 期主动判重(存档仍留)。教训 [[reference_crawler_parsedetail_null_contract]]。
- 蓝军 F2/F3/F4：detailUrlByNumber 有界 LRU 防 OOM+content_number 移入 MovieDraft 字段；currentBrandSlug/lastFetchWasEmpty 改 ThreadLocal(并发隔离)；置 draft.uncensored/hasSubtitle 权威字段。F4(ii)「3/8 category 下线」生产证伪(movie_category 无 enabled 列，3/8/18 均活跃)。
- **fable5 B1(核心 gap)**：题材→category 富化承诺此前未兑现(source_tag_mapping 只映射 movie_tag、无 category 列，category 全靠 LLM 猜)→新建 `MadouThemeCategoryMap`(63 题材 token→11 前台 category id 确定性查表，exact match)，persistRelations 按 themeTags 注入。
- **fable5 B2(产线丢片)**：token 100s 短效在 parseDetail 铸、隔 LLM+封面上传>100s 才在 downloadHls 用致 m3u8 403→**token 铸造前移到 downloadHls**(parseDetail 只存 objectId，resolveFreshM3u8 现抓 iframe 铸<1s 龄新 token)。
- 待 Owner：B5「大像传媒」typo tag(id=484)复用→前台错别字，MadouBrandRegistry 已注释标注。

**实现**：`MadouCrawlerService`(extends AbstractStandaloneCrawler)+`MadouScheduledCrawlTask`(双门控+按厂牌 FreshnessTrickle `madou:<slug>` 书签分片)+`MadouCrawlerController`+`MadouBrandRegistry`(31厂牌对账生产19现有tag)+`MadouKeywordClassifier`(actor 允许集60女优名防启发式污染)。movie 加 nullable `content_number` 列(跨源判重未来基础，仅写入不主动判重)。source_tag_mapping seed 53行(生产实查tag id)。

**多机分片(Owner 追加)**：采集单元=厂牌；每台 BuyVM `CRAWLER_MADOU_BRANDS=<categorySlug子集>`(空=全31)；`currentBrandSlug`/`lastFetchWasEmpty` 用 ThreadLocal(scheduled×controller 并发隔离)；crawl-brand 端点跨机手动调度。

**验证**：madou 单测38+全量回归1616绿；**金标B类真出片烟测PASS**(直连live madou→token→m3u8→AES解密→ffprobe 1280x720 h264 50.6s真视频)。蓝军7挑刺(4MAJOR)全处置(`BLUE-TEAM-RESOLUTION.md`)。

**站点实测**：无JS门裸curl200；详情/iframe需referer=madou.club；iframe `var token`(JWT 100s短效)+`var m3u8`；段/ts.key AES-128裸拉；番号在title/description(CZ0006→cz-0006)非slug。

**待部署阶段**(需Owner授权+DB/R2/前台)：①SQL migration(content_number列+source_tag_mapping seed)必须**先于**新common/data jar部署(否则 selectById 枚举字段 SELECT content_number 全模块500)；②每厂牌抽1-2部入库全链路+前台真播goldset(本会话只验到解密层)；③data.env `APP_CRAWLER_MADOU_ENABLED=true`+多机 CRAWLER_MADOU_BRANDS。

教训见 [[reference_crawler_parsedetail_null_contract]]。设计全文 `docs/sprint/2026-07-13-madou-crawler/`(DESIGN/IMPLEMENTATION-PLAN/GOLDSET-VERIFY/BLUE-TEAM-RESOLUTION/SESSION-STATE)。

---
name: cron-6-hourly-sprint-5-13-5-14
description: cap-success-only + fMP4 ffmpeg transcode + preview 本地 plain ts + ffmpeg concat budget + cableav duration EXTINF + admin filter 3 + region 短视频规则 + /tmp deploy 清理（13 个 fix + 8 commit）
metadata: 
  node_type: memory
  type: project
  originSessionId: c2b8bb28-32ef-4a45-89f9-5617e29dd913
---

5/13 上午 → 5/14 下午 ~30h sprint。在 5/12-5/13 overnight hanime1 CF bypass sprint 基础上，又抓出 / 修复 13 个独立 bug，最终 cron 每源每小时 1 部 success status=1 + preview，region anime/3d/jp/cn/western 全覆盖。

## 13 个 fix（按 commit 序）

| commit | 内容 |
|--------|------|
| `b9787ac6` | cron cap=1 解耦 + hanime1 finalize 直接 status=1（owner P9 拍板）|
| `ad91fe3c` | admin 影片管理加 上线状态 / 预览视频 / 来源 三 filter（linter 反复 revert 后重做）|
| `80d0cac8` | cableav 不信 og:duration（假值 5423/5427s），duration 唯一来源 = m3u8 EXTINF sum；47 部历史回填 |
| `79c9f1ba` | beeg fMP4 设 status=2 marker，dedup 跳过避免 cron 重 retry 浪费 7+ min |
| `9013c5ce` | fMP4 ffmpeg 转 MPEG-TS（Path A）— beeg 32% 损失救活，HEVC `-c copy` fallback 不带 h264_mp4toannexb |
| `d4e9d207` | hanime1 cron 接 ProbeHelper backfill 翻页，page 1 全 skip 不再静默 0 入 |
| `1a134933` | xvideos crawler cap success-only + status=2 dedup skip + MIN_DURATION skip 计 stats（让 ProbeHelper 不误判 empty）|
| `c9779a29` | anime / 3d region 不应用 MIN_DURATION_SEC=300s 短视频 skip（owner 拍板）|
| `de083619` | jable hardCapPerRun（linter revert）重加 — 防单 cron 一次 12 部 |
| `bc29ccb9` | javxx/cableav preview 用本地 plain ts，避 wowstream CDN 403 geo-block（原 buildAndUpload(remote m3u8) → buildFromLocalTs(preservePlainDir)）|
| `9418e8bc` | deploy-backend.sh 加 /tmp scp 中转 jar 清理，保留 3 个 |
| `5278e6dd` | ffmpeg preview concat budget `/4 → /2` + ENV `FFMPEG_PREVIEW_TIMEOUT_SEC=300→600`（1745 段长视频 74s timeout 修复）|

## 真凶清单（10 条非显眼 bug）

1. **cron cap 误计 fail**：beeg/javxx/cableav 原 picking 阶段 `if (toCrawl.size() >= cap) break;` + `processed += movieCount + movieFailed` → 第 1 部 fMP4 fail = cron 整轮 0 入。修：picking 不限 cap，crawl loop 内 `if (successCount >= cap) break;`，outer `processed += movieCount` 不含 movieFailed。
2. **xvideos crawler cap success-only 漏 MIN_DURATION skip 计 stats**：crawlVideoDetail return CrawlResult.skipped() 静默不计 movieSkipped → ProbeHelper 看 ok=0 skip=0 fail=0 误判"空"不走 backfill。修：caller crawlItems 累加 loopSkipped → stats.movieSkipped。
3. **og:duration 假值不可信**（cableav 全部 5423/5427s）：源站 placeholder 假 90 分钟。修：删 setVideoDuration(og:duration)，让 VideoProcessingService.saveVideoSegments 从 m3u8 EXTINF sum 唯一计算。47 部历史 backfill 脚本 /tmp/backfill_cableav_duration.sh 修真值（min 84s / max 4390s / avg 1256s 分布合理）。
4. **fMP4 段 confirmed reject 又 retry loop**：5/12 sprint catch fMP4 → safeDeleteAll(movie row) → 下次 cron 看不到 → 又 INSERT 重 try → fail-fast → 删 → 循环。每 cron 浪费 7+ min。修：fMP4 catch 改 setStatus(2) marker 保留 row + dedup `if existing.status==2 skip`。
5. **fMP4 reject 损失 32% beeg**：beeg 7d 65 部里 21 部 fMP4 source content。Path A：HlsDownloadService transcodeFmp4ToMpegTs，ffmpeg `-c copy -f mpegts` 直接 remux init.mp4 + segments → 喂回原 AES 重加密 pipeline。HEVC codec `h264_mp4toannexb` BSF 不支持 → 自动 fallback 不带 BSF 重试。
6. **hanime1 漏接 ProbeHelper**：5/12 主 sprint 只给 beeg/cableav/javxx/jable 接，hanime1 还在调原始 `dispatchCrawlByPageRange(slug, 1, 1, "latest")`。page 1 全 skip 时 silent 0 入。修：Hanime1ScheduledCrawlTask 改 `ProbeHelper.probeAndCrawl(slug, redis, ..., crawler::dispatch, log)`。per-channel Redis key `crawler:probe-base:hanime1_{slug}`。
7. **javxx/cableav preview ffmpeg 走远程 m3u8 → wowstream CDN 403**：FfmpegPreviewService.buildAndUpload(m3u8Url) 直接拉远程 HLS。aws-data HK IP geo-block 403。HlsDownloadService 有 proxy fallback 但 ffmpeg 直接 HTTP 调用没用。修：Stage 2.6/2.5 preview fallback 删 buildAndUpload(remote)，Stage 2.7 downloadHlsVideo 加 preservePlainDir → success 后 buildFromLocalTs(plain ts) 兜底。xvideos/hanime1 早已是 buildFromLocalTs 模式，借用同模式。
8. **ffmpeg concat budget /4 太小**：1745 段长视频 D 方案阶段 0 ts 拼接 budgetSec/4 = 74s timeout kill。视频 2.7GB 顺序 I/O 100-130s 实际耗时。修：concatBudget `Math.max(60, budgetSec/2)` + ENV timeout 300→600，给 concat 300s budget。
9. **deploy-backend.sh /tmp 不清理**：scp 中转 jar 累积 9.7G（10+ × 281MB） — 触发 85% 磁盘告警。原脚本只清 deploys/ 保留 5。修：加 `[6.1/8]` 清 /tmp/{newworld-MODULE,MODULE,data,admin}-*.jar 保留 3。同时手动清 8.3G deploys + 9.7G tmp 释放 15G（41G/48G → 26G/48G）。
10. **手动 cp + ln 部署 28+ jar 累积根因**：我（agent）一直绕 `/newworld/scripts/deploy-backend.sh` 走手动 ssh cp + symlink → 8.3G accumulate。脚本本来就有 5-jar 保留逻辑，我没用。

## 配置 + ENV 新增

- `FFMPEG_PREVIEW_TIMEOUT_SEC=600`（aws-data secrets.env）
- `CRAWLER_JABLE_HARD_CAP_PER_RUN=1`（已存）
- `xvasiam.hard-cap-per-run:20`（@Value default，xvideos master cap，admin batch 用；cron 走 capOverride=1）
- `crawler.hls-fmp4-transcode:true`（默认开 fMP4 转码，hot-revert false）
- `crawler.hls-fmp4-transcode-timeout-sec:1800`（30min，fMP4 转 mpegts 长视频留余量）
- FlareSolverr daily restart cron `/etc/cron.d/flaresolverr-restart` 每 hour :58 reboot 防 stale（5/13 加）

## 验收实证

5/14 15:00 + 16:00 cron 各 6/7 全活：
| time | source | preview | segments |
|------|--------|---------|----------|
| 15:00 | cableav | ✓ | 152 |
| 15:19 | jable | ✓ | **2551** |
| 15:30 | javxx | ✓ | 1098 |
| 15:32 | beeg | ✓ | 147 |
| 15:35 | hanime1_libang | ✓ | 98 |
| 15:36 | hanime1_3dcg | ✓ | 12 |
| 16:09 | jable | ✓ | **1724** |
| 16:06 | hanime1_paomian | ✓ | 39 |
| 16:07 | hanime1_25d | ✓ | 43 |

全 status=1 自动上线 + 全 preview OK。2551 段最长 ts 拼接成功。

## 关键代码位置（新加 + 改）

- `AbstractXvideosChannelCrawler.crawlByPageRange / crawlOnePage` 加 `Integer capOverride` 重载
- `GenericXvideosChannelCrawler.dispatchCrawlByPageRange` 加 capOverride 重载
- `AbstractXvideosChannelCrawler.crawlItems` cap success-only + status=2 skip + loopSkipped 计 stats
- `AbstractXvideosChannelCrawler:500` `String region = cfg.fixedRegion(); boolean skipDurationCheck = "anime".equals(region) || "3d".equals(region);`
- `HlsDownloadService.transcodeFmp4ToMpegTs`（新方法）+ Fmp4DetectedException marker
- `FfmpegPreviewService.resolveRelative` 4-case（早已修，再次锁定）
- `FfmpegPreviewService.extractMontage8x1sFromLocalTs:331` concat budget formula
- `JavxxCrawlerService:418` preview Stage 2.6 不再 buildAndUpload(remote)，Stage 2.7.5 buildFromLocalTs
- `CableavCrawlerService:368` 同 javxx 模式
- `BeegCrawlerService:295` dedup 加 status=2 skip + catch fMP4 setStatus(2)
- `JableMovieCrawlerService:48` 重加 @Value crawler.jable.hard-cap-per-run + subList cap
- `Hanime1ScheduledCrawlTask:78` 改用 ProbeHelper.probeAndCrawl
- `scripts/deploy-backend.sh` [6.1/8] /tmp jar 清理

## 教训沉淀（11 条）

1. **linter 反复 revert 大量 sprint 改动**：5/11-5/12-5/13 多 file 多次 revert（FfmpegPreviewService.resolveRelative / Hanime1ScheduledCrawlTask / JableMovieCrawlerService cap / PageRequest.java filters / HlsDownloadService executeWithProxyFallback / ...）。**铁律**：每改完立即 `git add + commit + push` 锁定，sprint 跨多 file 必须每个 file edit 后立刻 commit，不要批量 commit。
2. **手动部署绕过标准脚本灾难**：`deploy-backend.sh` 本来就有 /newworld/deploys 保留 5 个逻辑，我手动 ssh cp + ln 绕过，导致 28+ jar 累积 8.3G + /tmp 9.7G 总磁盘 87%。**铁律**：后续部署必须用 `/newworld/scripts/deploy-backend.sh data`。
3. **cap 语义陷阱**：picking 阶段限 cap = "尝试 cap 个" ≠ "成功 cap 个"。fail/skip 也消耗 cap → 第 1 个 fMP4 = 全 cron 0 入。**正确语义**：picking 不限 cap，crawl loop 内 `successCount >= cap` 才 break，stats 分别记 movieCount/movieSkipped/movieFailed。
4. **MIN_DURATION skip 静默不计 stats**：CrawlResult.skipped() return 后调用方没 stats++。下游 ProbeHelper 看 0 skip 0 fail 0 ok 当 empty 终止。**修法**：caller loop 累加 loopSkipped → 累加 stats.movieSkipped。
5. **og:meta 字段不可信**：cableav 全部 og:duration=5423s 假值。**铁律**：duration / segment count 从 m3u8 EXTINF sum 计算（VideoProcessingService）才是真，源站 meta tag 经常是 placeholder。
6. **fMP4 是确定性 fail，不能 retry**：检测出 fMP4 + safeDeleteAll → 下次 cron 拿同 movie_number → INSERT 重 try → 又 reject loop。**修法**：保留 marker row status=2，dedup `if existing.status==2 skip`。
7. **fMP4 ffmpeg 转 MPEG-TS 工作**：beeg/HEVC source `-c copy -f mpegts` remux 130s 完成。HEVC codec 不支持 `h264_mp4toannexb` BSF → 自动 fallback 不带 BSF 重试就过了。
8. **preview ffmpeg 路径必须用本地 plain ts**：远程 m3u8 → wowstream CDN 几率 403 geo-block。本地 plain ts 是稳的。**铁律**：HLS download 加 preservePlainTextDir → preview 用 plain ts → cleanup。
9. **ffmpeg concat budget 不能 fixed fraction**：长视频 ts 拼接 I/O 主导，budget/4 不够 1745+ 段。**修法**：budget/2 + base 60s minimum + ENV 双倍预算。
10. **region 差异化规则 owner 拍板**：anime/3d 短视频也采，jp/cn/western 保留 300s min。**实施**：cfg.fixedRegion() in 白名单时 skip MIN_DURATION 检查。
11. **ProbeHelper 必须给所有 cron 接**：hanime1 漏接静默 0 入 (page 1 全 skip 不走 backfill)。**铁律**：新加 cron task 必须用 ProbeHelper（page 1 latest + Redis cursor backfill），不能直接 dispatchCrawlByPageRange(1,1)。

## 后续 dust

- `/tmp/backfill_cableav_duration.sh` 一次性回填脚本，保留 aws-data:/tmp/ 备 future 类似回填参考
- 21 部 fMP4 beeg 历史 status=0 → v25 之后会被 cron 拿来 fMP4 transcode 救活；剩下未救的标 status=2 marker，dedup skip
- jable jable_recommendation 任务保留（独立 path，跟 movie crawl 解耦）
- FfmpegPreviewService.resolveRelative 4-case 还是会被 linter revert 风险 — 单独单测加守
- /tmp/* 旧 backfill_preview_*.log 文件 5/2-5/19 累积，可定期 cleanup

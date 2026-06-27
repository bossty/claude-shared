---
name: cableav.info 国产源接入 sprint（5/11，极简 vs javxx 12 轮对比）
description: 纯 HTTP 国产源接入，无 Playwright 无 Node 子进程；FfmpegPreviewService resolveRelative path-absolute fix；ship 19/19 全绿 (status=1 + hp 100%)
type: project
originSessionId: c2b8bb28-32ef-4a45-89f9-5617e29dd913
---
5/11 下午 sprint。owner 拍板 region=cn + mandatoryCat 8(无码解放)+18(国产剧情) + cableav.info 接入。

## 站点结构（极简，与 javxx 形成强对比）

| 维度 | javxx (5/10-5/11) | **cableav** |
|------|-------|---------|
| 反爬 | Turnstile + SPA | **无** |
| list fetch | Playwright SPA 渲染 | **curl HTTP** |
| detail fetch | fetchHtmlWaitSelector 15s | **curl HTTP** |
| m3u8 拿取 | **Node 子进程 Playwright intercept iframe** | **HTML grep 直链** |
| token 加密 | XOR keystream / surrit.store/stream | **无** |
| preview | 源站有 mp4 直链（cover 派生）| 源站无，**ffmpeg 抽帧** |
| 抓取难度 | 5/5（12+轮 fix）| **1/5**（1 个 bug fix） |
| 代码量 | ~800 行 + Node + /opt/javxx-m3u8/ | **~200 行** 纯 Java |
| 单条耗时 | 2-3 min | ~30-60s |

## 接入决策

- region = `cn`（国产源）
- mandatoryCategoryNames = [8 无码解放, 18 国产剧情] hardcode 双注入
- mandatoryTag = 不加
- cron = `0 0,30 * * * *` HKT 每小时 2 条 = 48/天
- service gate = `app.crawler.cableav.enabled` default false
- hardCapPerRun = 125（同 javxx）

## 字段抽取（detail page）

| 字段 | 来源 |
|------|------|
| title | `meta[property=og:title]` 去 " HD" 后缀 |
| description | `og:description` |
| cover | `og:image` 直链 `picc.sex8sex855.com/{date}/{id}/1.jpg` |
| m3u8 | HTML 正则抽 `picc.sex8sex855.com/{date}/{id}/index.m3u8` 直链（无 token 无加密） |
| release_date | `meta[property=video:release_date]` |
| tag | `meta[property=video:tag]` 单 tag |
| duration | `video:duration=0` 不可靠 → fail-soft 由 HLS 实测 |
| referer | `https://cableav.info/` |

## 真 bug：FfmpegPreviewService.resolveRelative path-absolute

```
master m3u8: picc.../20260507/MnAlH7Fl/index.m3u8
variant 内: /20260507/MnAlH7Fl/hls/index.m3u8 (path-absolute)
原 bug: baseDir + path = picc.../20260507/MnAlH7Fl/ + /20260507/MnAlH7Fl/hls/index.m3u8
      = picc.../20260507/MnAlH7Fl//20260507/MnAlH7Fl/hls/index.m3u8 (双 path → 404)
fix: host root + path = picc.../20260507/MnAlH7Fl/hls/index.m3u8
```

`FfmpegPreviewService.java:767` 重写 resolveRelative 4 case 分支：absolute http / protocol-relative `//` / **path-absolute `/`** (host root) / 相对 (baseDir)。

hanime1/beeg/javxx 不破（他们 variant 是 absolute http URL，走 case 1 直接 return）。

## 实施时间线

| 时间 | 动作 |
|------|------|
| ~15:00 | chrome MCP 实证 list/detail 结构 → 写 `docs/CABLEAV_RECON.md` |
| ~15:30 | P7 实施 service/controller/scheduled task（仿 Beeg 极简版） |
| ~15:50 | mvn BUILD SUCCESS jar 281M |
| ~16:00 | deploy buyvm-data + secrets.env 加 ENV + dispatch p1 |
| ~16:10 | v12 实证 preview_fail 100% (ffmpeg `404` 双 path 拼接错) |
| ~16:14 | v13 修 FfmpegPreviewService.resolveRelative + build + deploy buyvm-data |
| ~16:18 | dispatch p2 重 test |
| ~16:30 | v13 验收 14/14 hp_pct=85.7% (12 status=1 + 12 preview) |
| ~16:30 | scp + deploy web-01/web-02/db + 4 buyvm dispatch p1-40 = 500 |
| ~16:40 | owner 暂停 → systemctl stop 4 buyvm + 删 3 status=0 草稿 |
| **最终** | 19/19 全绿（status=1 + preview NOT NULL 100%）|

## 关键代码位置

- `CableavCrawlerService.java`（782 行，含 inner `CableavDetail`）
- `CableavCrawlerController.java`（77 行）
- `CableavScheduledCrawlTask.java`（67 行）
- `FfmpegPreviewService.java:767` resolveRelative 4 case fix
- `docs/CABLEAV_RECON.md` 调研报告

## 教训沉淀（4 条）

1. **共享 method bug 单 site 暴露**：FfmpegPreviewService 共用 hanime1/beeg/javxx 都没踩 path-absolute，cableav 第一个触发。**共享 method 4 case 处理 absolute http / protocol-relative / path-absolute / relative 必须完整**。
2. **chrome MCP 真 DOM 实证**：5 min 看 og:meta + iframe + tag 一次性拿全（无需 12 轮迭代）。
3. **极简站架构反例**：cableav 证明站点结构决定难度 (1/5 vs javxx 5/5)，**架构第一选择 HTTP fetch + Jsoup（fallback Playwright）**。
4. **systemd `Restart=always` 教训**：本次没踩坑（吸取 javxx 经验，systemctl stop + reset-failed 一次到位）。

## 后续

- aws-data v13 jar 待 deploy（cron 4:00 HKT 触发 cableav/javxx/beeg）
- 4 buyvm stopped，需要扩 500 时 systemctl start + dispatch p1-40
- mandatoryTag "国产"（id 待查）后续如需补 → 修 finalize

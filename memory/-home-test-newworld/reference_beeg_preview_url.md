---
name: beeg 与 jable 官方预览视频 URL 规律
description: 两源都提供现成的短预览 mp4，爬虫直下即可，不用抽帧拼接
type: reference
originSessionId: f4505e91-c990-4d2b-9f8a-0e74e2ca4ce8
---
## beeg
**URL**: `https://vp.externulls.com/{fileId}/0-0.mp4`
- fileId = beeg API `file.id`（movie_number `beeg-{fid}` 里的数字）
- 100-300KB，H.264，content-type: video/mp4
- Referer: `https://beeg.com/`

## jable
**URL**: `https://assets-cdn.jable.tv/contents/videos_screenshots/{prefix}/{video_id}/{video_id}_preview.mp4`
- 例：`.../58000/58422/58422_preview.mp4`
- prefix 是 video_id 的千位分组（58422 → 58000）
- 从详情页 og:image meta 反推构造

**教训**：2026-04-19 之前走 fc_thumbs 从 HLS 源抽帧拼接 8×1s 方案，HLS 遇到 fMP4 缺 EXT-X-MAP 时 ffprobe 失败（porcore 55531 / beeg 4 部踩坑）。**源站本来就有官方短 preview mp4，直接下载零依赖**。

**代码**：`BeegCrawlerService.downloadPreviewDirect` (commit 2306e0c)，优先级高于 `buildPreviewFromFcThumbs` fallback。

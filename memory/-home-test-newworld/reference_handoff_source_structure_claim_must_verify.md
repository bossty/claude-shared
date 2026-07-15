---
name: reference_handoff_source_structure_claim_must_verify
description: 交接档/上会话「源站页面某字段不存在」类根因结论必抓真页面 grep 证伪，禁凭代码注释推断；preview 上传链路不校验内容类型会把 JPEG 当视频传
metadata:
  type: reference
---

**BL-65（2026-07-14）xvideos best 预览无法播放**：上会话结论「best 列表页不暴露 preview、兜底取 detail mozaique JPG」**证伪**。Owner 反诘「xvideos 列表页一定有预览视频」**成立**。

## 教训 1：源站页面结构类断言（有没有某字段）必抓真页面证伪，禁凭代码注释/转述推断
- 原码 `parseBestHtmlResponse` 写死 `it.previewUrl = null; // /best/ 不暴露 preview，detail page 后无法补`——**注释即错误根源**，从没人抓过真页面核对。
- 一次 `curl best 列表页 | grep previewVideo` 就翻案：27/27 thumb-block 的 `data-video` JSON 都带 `"previewVideo":"https://<cdn>/<uuid>/<n>/preview.mp4"`，实测该直链 `206 content-type: video/mp4` + magic bytes `00 00 00 20 66 74 79 70`(ftyp)。
- 判据：**「源站有没有 X 字段」是可证伪命题，成本=一次抓取+grep**。上会话 A/B/C「三修复方向待拍板」全建立在错误前提上（以为要 ffmpeg 抽帧/放弃预览），实则官方直链现成。契合 [[feedback_verify_not_recall]]、owner 反诘先当严肃提案 fact-check。
- 附带：detail 页**无本片自己的** previewVideo/ipu 字段（页面里的 ipu 全属「相关推荐」小部件），但 `setThumbUrl169('.../<uuid>/<n>/xv_18_p.avif')` **同目录**的 preview.mp4 与列表 previewVideo 逐字相等（buyvm 27/27 实测）——detail 回填靠此推导，不依赖榜单当前状态。

## 教训 2：preview/媒体上传链路不校验内容类型 → 图片被当视频静默上传
- `R2UploadService.uploadPreviewVideoCamouflaged` 只查 HTTP 200 就原样上传、Content-Type 硬编码 `application/javascript`（伪装），**不验 magic bytes/是不是视频**。故上游给它 mozaique **JPG** URL 时，JPEG 被当预览视频传上 R2、前端 `<video>` 放不了（play() reject 被空 catch 静默吞、无报错=黑屏）。
- 修法：在**解析层** fail-safe——`extractPreviewFromDataVideo`/`derivePreviewFromThumb169` 对非 http、非 `.mp4` 一律返 null 走「无预览」，绝不把图片 URL 往下传。守卫方向=宁可无预览也不吐图片当视频。

## 教训 3：preview key 复用 + CF immutable = 30 天 stale（[[reference_cf_immutable_stale_id_reuse]] 新实例）
- preview R2 key = `{pathPrefix}/{movieId}.js`（**按 movieId 命名、非内容寻址**），回填重传覆盖同 key。但 CF 边缘缓存 `cache-control: public, max-age=2592000, immutable`（30 天不回源）→ 覆盖后用户仍拿旧 JPEG。**必须 purge**。
- purge 范围坑：前端 `cdn-failover` 的 active 域 = 下发列表 `list[0]` 但有延迟 race 会切最优域 → 缓存分散在多个 R_PRV 子域，精确 purge 不可靠 → 全量 purge（5 apex zone × 10 子域 × 20 id，分批 ≤30 URL/请求，nw-cf B POST /zones/{id}/purge_cache）。抽验 cf-cache-status + magic bytes 从 JPEG→MP4。

## 可复用产物
- 回填端点 `POST /crawler/xvideos/{slug}/backfill-preview?batchSize=N`（`backfillPreviewFromSource`）：按 detail 重推 preview.mp4 覆盖 R2，幂等、不碰正片、不含 CF purge（职责单一）。
- 验证姿势：before/after magic bytes（`od -t x1 -N 8`，绕 CF 用 `?_p=rand` cache-buster）+ 前端真实 Plyr 播放器 videoWidth>0（[[feedback_goldset_must_play_real_video]]）。

---
name: project_cover_blurhash_placeholder_2026_06_29
description: "封面\"贴脸\"根治 sprint：预热IO+淡入+慢网自适应+BlurHash占位全链路上线"
metadata: 
  node_type: memory
  type: project
  originSessionId: e3640a16-9ed9-4467-8e20-35eb9a0b1612
---

封面图"贴脸"(滚动/新batch 时灰块→图突兀出现)根治 sprint，2026-06-28→29 完成并上线。

**演进(每步治不同成因，真机分级实测驱动)**：
1. 预热 IO(FeedCard，`root=scrollRoot`、rootMargin 200%、命中翻 loading=eager 一次性)——治内层滚动/新batch/iOS 延迟(WebKit 实测 43%→0%)。native lazy 不认内层滚动容器是关键根因，见 [[reference_frontend_image_placeholder_lessons]]。
2. Hero 首屏后延迟 eager(requestIdleCallback)+ PC 按断点 firstScreenCount 首屏可见 slide 都 eager。
3. 淡入 + 慢网自适应小图(navigator.connection→SIZES.CARD_SMALL)——零后端。慢网带宽瓶颈实测 89%→23%。
4. **BlurHash 占位(感知 100% 根治，终解)**：每片存 ~28字节 hash(movie.cover_blurhash)，前端 decode 成模糊图铺底→真图淡入。Instagram 同款。子选 BlurHash 而非 ThumbHash 因 `io.trbl:blurhash` 有现成 Maven Java 库→data 进程内算、零外部脚本。

**全链路(commit 在 feat/cover-preload-restore，未合 master 待 Owner 授权 squash)**：
- DB：movie 加 cover_blurhash(migration v37，FULLTEXT 表只能 ALGORITHM=COPY)。
- data 写链：R2UploadService.processAndUploadCoverV5 从 'a' 档(240w)mozjpeg JPEG 算 blurhash(16 爬虫/17 调用点都 setCoverBlurhash)；fail-soft。
- 读链：Movie/MovieListVO/MovieMapper resultMap/MovieService.convertToListVO(20+ 端点共用 MovieListVO，一次覆盖)。
- 前端：useCoverPlaceholder composable(FeedCard+MovieCard 共用)+ blurhash npm。
- 回填：本机算(R2 JPEG档)+ssh写 master，43,419 部 100%(miss=0)。
- 部署：web×6 零停机 + 前端×6 + data ca-admin + 缓存 evict(L2 unlink web/search/movie-card ~107k + L1 广播)。

**真机实证(live 17.rip)**：Chromium m/pc + WebKit m，cover-blur 占位带真 dataURL；新片 88886(12:30 采集)inline 自带 blurhash 复验通过。

教训见 [[feedback_deploy_generating_end_before_backfill]] 和 [[reference_frontend_image_placeholder_lessons]]。

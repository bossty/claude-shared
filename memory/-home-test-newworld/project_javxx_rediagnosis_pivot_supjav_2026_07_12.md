---
name: project_javxx_rediagnosis_pivot_supjav_2026_07_12
description: "javxx 出片真阻塞=stream API 直连 403(非交接档说的封面编码)三处修复已验真出片;Owner 决策弃用 123av 转 supjav;停调度撞出 task/service 门控失配已修+已停采(BL-44 关闭)"
metadata: 
  node_type: memory
  type: project
  originSessionId: 466774f2-939d-46bf-b4c1-d4d1550a3a5c
---

# javxx/123av 重诊断 + 三修复验真 + Owner 转向 supjav（2026-07-12）

BL-44 续。承接交接档「第五缺陷=封面伪装 MP4 编码阻塞出片」。**BL-44 已于 2026-07-12 关闭**（见文末收口段）。

## 教训：交接档的**详细**诊断也会在因果层出错，必产线 trace 独立 fact-check
交接档有真日志（`[v5] mozjpeg + ffmpeg-mjpeg 全部失败`）但**因果判错**——它推「封面 encode 失败 → 无法 finalize」，实则 `uploadCover` finalize 门只查 `barePath()`（裸上传原字节，MP4 也过），mozjpeg-c 返 null **不抛异常不回滚**。真阻塞是**另一处**：生产 trace(id=118082 完整生命周期)显示封面 5 档跑完后 → HLS 阶段 `fetchM3u8FromSurrit` 裸 `HttpURLConnection` 直连 javplayer.cc/stream 被 aws-ca IP 封禁 **403 → 整部回滚**（downloadHls:369）。同窗 beeg 等 HLS 正常=javxx 特有。**判据泛化**：不接受交接档因果claim，自己在产线追「哪个 stage 真抛异常/回滚」；ca-admin 实测矩阵坐实（直连+任意 Referer 全 403 / proxy=200）。见 [[feedback_verify_not_recall]]。

## 三处修复（commit `200ab5c0`→merge master `d65eaa4a`，3 文件 +69/-1，全生产实证）
1. **① 真阻塞**：`JavxxCrawlerService.fetchM3u8FromSurrit` 复用 `buildAssetProxy()` 走 proxy（proxy=200）。下游 wowstream m3u8/切片由 `HlsDownloadService.pickReferer(javplayer.cc)`+geo-block proxy 已覆盖（wowstream.cloud 是 CF 防盗链 403 非 IP 封禁，proxy+referer=200）。
2. **② 封面 mozjpeg-mjpeg** `encodeFfmpegMjpegV5Bytes` 加 `-frames:v 1`（伪装 MP4=288帧 h264，无抽帧→image2 muxer exit≠0→null）。
3. **③ 封面 AVIF** `encodeAvifAndUploadV5` !isAnim 分支加 `-frames:v 1`（**185.64s→2.09s，88×**，防撞 60s 超时丢档；动图分支不动）。
- 红绿：`R2UploadServiceV5Test.coverFromMultiFrameMp4`（真 ffmpeg 多帧 MP4）撤修复 RED / 带修复 GREEN；data 全模块 895 绿。
- **终验**：手动 crawl-pages page20 → id=118090 status=1 + cover/blurhash/preview 全落库，`ok=1 fail=0`（两周首出片）。

## 遗漏面（未修，Owner 转向后不做）：javxx 后台封面坏、前端正常
`uploadCover:316-317` cover_image/thumbnail_image=`barePath`(裸上传原始 MP4)。前端用响应式变体(已修好真图)正常；后台 `<img src=cover_image>`=MP4→坏图。`-frames:v 1` 只修变体没覆盖 barePath。修法(若复活)：uploadCover 调 processAndUploadCoverV5 前视频先抽帧成 JPEG 当 source。

## 🔀 Owner 决策：123av/javxx **暂时弃用**，改 **supjav.com**（`/zh/category/uncensored-jav`）
两周源站对抗(IP封禁×2/改版/CF防盗链/伪装MP4封面/后台坏图)判不值得。**新任务**=supjav 全新爬虫(大需求,先 brainstorming 反向面试+文档先行)。

## ✅ 收口（2026-07-12，BL-44 关闭；三条遗留决策全部有结论）
- ① off-master jar：**合 master 而非回滚**（javxx 三修 `55a4477c` + 后台坏图修 `a2319ccb` 均已在 master）。
- ② 停调度：**已停**（`APP_CRAWLER_JAVXX_ENABLED=false`，ca-admin `deployed/data=ea69e1e0`）。
- ③ 分支/worktree：已清理。

### ★教训：**门控在 flag 上的 bean，其消费方必须同门控**——否则「关掉这个源」这件事被代码卡死
`JavxxCrawlerService` 门控 `app.crawler.javxx.enabled`（关了没 bean），而 `JavxxScheduledCrawlTask` 只门控 `app.scheduling.enabled`（照样装配）→ 关 flag = `UnsatisfiedDependencyException` = **整个 data 服务起不来**（生产实爆，被迫回滚 flag）。task 的 javadoc 还反向自称"未开启时 task 也不会装配"——**javadoc 是声明、不是实现，别当证据用**。
- 修法：两 gate 合进 `@ConditionalOnExpression("${app.scheduling.enabled:true} and ${app.crawler.x.enabled:false}")`。普查全部爬虫 task：`BeegScheduledCrawlTask` 同款失配（未触发只因没人关过 beeg flag）一并补齐；porcore/pornhub/xvgay/xvtrans/hanime 早已双门控；jable 的 service 无门控 → 无地雷。回归测试 `CrawlerTaskConditionalGateTest`（**故意不注册 CrawlerService bean = 精确复现 flag 关闭时的生产 bean 图**）。
- **新增爬虫源时必查**：service 有 `@ConditionalOnProperty` gate → 它的 task/controller 必须带同一个 gate。

### ★验证判据：关一个源后，「目标源消失」本身不是充分证据
只看「javxx 不再触发」无法区分两种世界：(a) 表达式正确读到 flag=false；(b) **表达式根本没读到环境变量**（relaxed binding 失效）→ 所有源全默认 false 被静默停掉。**discriminator = 另一个 flag=true 的源仍在跑**（本次 = beeg 02:07:33 照常执行）。同类 fail-safe 方向问题见 [[feedback_gate_redgreen_and_failsafe_direction]]。
- 附：小时级爬虫 task 共用调度线程池 → 整点任务会**错峰启动**（hanime1 02:00:00 / jable 02:04:27 / beeg 02:07:33），「整点没立刻出现」≠ 没装配，别据此误判。

### 测试脚手架坑：Spring 会往 `@Bean` 返回的 Mockito mock 里反向注字段
`AutowiredAnnotationBeanPostProcessor` 对 `@Bean` 实例照样生效 → mock 的继承字段（CrawlerService 自带 `@Autowired movieMapper` 等一长串）要求注入 → 得把整条依赖链都 mock。改用 `beanFactory.registerSingleton()`：手工注册的 singleton 不过 bean 创建生命周期、不做字段注入，但仍可按类型被构造器解析。

---
name: reference_frontend_image_placeholder_lessons
description: 封面图懒加载/占位的技术铁律(native lazy内层滚动失效/测试必节流网络/iOS无connection/淡入必@error/FULLTEXT表COPY/blurhash从JPEG档)
metadata: 
  node_type: memory
  type: reference
  originSessionId: e3640a16-9ed9-4467-8e20-35eb9a0b1612
---

封面图加载/"贴脸"/占位 的可复用技术铁律(2026-06-29 BlurHash sprint 沉淀)：

1. **原生 `loading=lazy` 不认内层滚动容器**：feed 在 `.scroll-wrapper` 内层滚动时，native lazy 只按【文档视口】算距离 → 提前量失效、"滑到才下"，WebKit/iOS 尤甚(新 batch 贴脸)。补法=`IntersectionObserver{root: scrollRoot, rootMargin}` 提前翻 loading=eager(native lazy 唯一补不了的事)。实测 WebKit 43%→0%。

2. **前端加载/性能测试必须节流网络，不能只节流 CPU**：我曾只 CPU 4x 节流 → 误判"贴脸 0%"；加网络节流(CDP Network.emulateNetworkConditions / playwright)后真相 native lazy 慢网快滑贴脸 44~96%。是 Owner 坚持"还在贴脸"才挖出。

3. **iOS 全系是 WebKit + 无 `navigator.connection`**：靠 connection 的"慢网自适应"在 iOS(Safari/iOS Chrome)+部分国内内核**完全不生效**；iOS 慢网要靠占位/预热兜，或服务端 Save-Data/Client Hints。

4. **淡入占位必配 `@error` 兜底**：`.feed-img{opacity:0}` 靠 `@load` 翻 1 时，图加载失败 `@load` 永不触发 → opacity 永久 0 = 封面永久隐身(GFW 烧图域时整屏灰)。必须 `@error` 也置 loaded(蓝军实测双引擎坐实的 BLOCKER)。eager/LCP 卡不淡入(opacity:0 不计 LCP)。

5. **有 FULLTEXT 索引的表 ADD COLUMN 只能 `ALGORITHM=COPY`**：INSTANT/INPLACE 均报 ERROR 1846(InnoDB 限制)。movie 表(搜索 FULLTEXT)加 cover_blurhash 实测 COPY 重建 43k 行 11.7s、LOCK=SHARED 读不阻塞仅写排队。别盲信 INSTANT 注释。

6. **BlurHash/占位要从 JPEG 算，不从原始源**：本站封面源有 webp/avif/heic，ImageIO/部分库解不了(管道正因此用 ffmpeg/mozjpeg)。从管道已产出的 mozjpeg 'a' 档(240w)JPEG 算 → 覆盖 100% 源格式 + 已缩小无 OOM。回填同理取 R2 `{coverPrefix}/{id}a-c.js`(JPEG 档)非裸 `{id}.js`。

7. **BlurHash 占位 = 图片"贴脸"的感知 100% 根治**(业界标准 Instagram/Medium)：占位是内联 API 的 ~28字节 hash(0 额外网络)→ decode 成"模糊版那张图"→真图淡入。物理上图下载快不了，但用户永不见空白/灰块突兀。BlurHash(io.trbl Maven Java 库)优于 ThumbHash(无 Maven Java)对 Java 后端管道。

关联 [[project_cover_blurhash_placeholder_2026_06_29]]。

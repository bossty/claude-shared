---
name: 2026-04-19 爬虫全栈重启 + beeg preview 根因修复
description: 整治日：清 12 部 beeg、修 0-0.mp4 方案、3 台 BuyVM 分机爬虫、LLM 兜底孤儿 relation
type: project
originSessionId: f4505e91-c990-4d2b-9f8a-0e74e2ca4ce8
---
## 关键交付（一次性总决算）

1. **beeg preview 根因修复**
   - 发现：`vp.externulls.com/{fid}/0-0.mp4` 是官方直发预览
   - 改 `BeegCrawlerService.downloadPreviewDirect`（commit 2306e0c）+ fallback `buildPreviewFromFcThumbs`
   - 删 12 部旧 beeg 彻底重爬（R2 2871 video + 24 img + 12 prv + DB 184 行）

2. **avjiali release_date 根因修复**
   - 源页面格式 `<div class="video-date">November 09th, 2025</div>`
   - Java 正则只匹配 YYYY-MM-DD → 常年 NULL
   - 加 month-word 兜底正则（commit bb33c8b）

3. **aws-data 生产代码基线正本清源**
   - commit 5da84474（27 文件 +4465 行）—— 长期漂移的 20+ 文件一次性对账
   - 含 VideoProcessingService `updateById→UpdateWrapper` 根因 fix（修 preview_video 被 reload Movie 冲 NULL 的 bug）

4. **uncensored 硬规则代码部署**（commit 9d4ef56）
   - `applyUncensoredRules`：必进 cat=8 / 禁 cat=18 / 禁 tag=405

5. **BuyVM 3 机爬虫分工上线**（见 reference_buyvm_crawler_assignment.md）

6. **LLM 兜底 21 部无 category/tag**（C 方案 `/tmp/c_fillrelations.py on web-01`）

**Why**: user 反复反馈 "beeg preview 不能播" 逼出 vp.externulls.com 发现；"release_date 为空" 逼出 Java 正则 bug。

**How to apply**: 未来发现爬虫字段缺失，先查 **源站是否有现成资源** 而非盲抽帧；DB 零星孤儿 relation 用 LLM 兜底脚本 `c_fillrelations.py` 一键处理。

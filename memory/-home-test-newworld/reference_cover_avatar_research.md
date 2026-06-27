---
name: 封面图+演员头像调研完整结论
description: 2026-04-04 封面五层fallback+三种尺寸+演员四层fallback全部技术细节，含awsimgsrc GET修正、CRF数据、cid格式映射
type: reference
---

## 封面图（已实施）

### 五层 fallback（CoverService.java）
1. awsimgsrc.dmm.com — **必须 GET 请求**（HEAD 被 CloudFront 返回 405），>10KB 有效
2. pics.dmm.co.jp — 标准 800px，200=有 302=无
3. MGStage — 仅 Prestige (ABW/ABF/ABP)：`image.mgstage.com/images/prestige/{series}/{num}/pb_e_{series}-{num}.jpg`
4. minnano-av — 搜索 `search_result.php?search_scope=av&search_word={番号}` → 提取 `p_package/` 图片
5. Jable 原图兜底（在 uploadMovieImages 里，CoverService 返回 null 时用）

### 三种尺寸输出
| 图片 | R2 路径 | 尺寸 | CRF |
|------|--------|------|-----|
| cover_image | PATH_COVER/{id}.js | 原尺寸 | 24 |
| list_image | PATH_THUMB/{id}_800.js | 800px | 24 |
| thumbnail_image | PATH_THUMB/{id}.js | 480px | 24 |

### DMM cid 格式
- 标准：`{prefix}{5位数字}`
- SOD 系 "1" 前缀：stars, start, dldss, sdnm, sdjs, sdde, sdmm, sdmu, sdab, sdam, sden, sdfk, sdmf, sdnt, fsdss, fns, focs, fpre, mtall, mogi
- Prestige 不在 DMM

### 补刷接口
- `POST /crawler/movie/upgrade-covers?startId=X&endId=Y`
- `POST /crawler/movie/upgrade-actor-avatars?startId=X&endId=Y`

## 演员头像（已实施）

### 四层 fallback（ActorAvatarService.java）
1. minnano-av（94% 覆盖，205-720px）— 搜索 302=精确匹配
2. DMM actjpgs（slug 翻转 姓_名/名_姓 两种都试）
3. Warashi（日文原名搜索，5s 连接超时 + 8s 响应超时，日志 DEBUG 级别）
4. Jable 详情页兜底

### 头像 AVIF 处理
- 独立 `convertToAvif()`，不走 optimizeImage
- >256px resize 到 256（minnano-av 大图），≤256px 保持原尺寸
- CRF 28（头像小图差异不可见）

### 关键注意
- Warashi 搜索用日文原名（不是简体中文），代码保留 originalJapaneseName
- minnano-av URL 注意去掉开头斜杠避免双斜杠
- R2 上传 Referer 按来源自动设置

## 产品改版方向
- 移动端一列全宽（用 list_image 800px）
- 两列 grid 备用（用 thumbnail_image 480px）
- 播放页用 cover_image 原尺寸
- 详见 docs/PRODUCT_ANALYSIS.md

## 文档位置
- docs/HD_COVER_SOURCES.md — 封面方案
- docs/ACTOR_AVATAR_SOURCES.md — 头像方案
- docs/MOVIE_PREFIX_STUDIO_MAP.md — 番号→厂商映射
- docs/PRODUCT_ANALYSIS.md — 产品分析

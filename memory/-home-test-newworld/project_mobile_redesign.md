---
name: 移动端改版 + 封面图方案确定
description: 2026-04-04 产品改版方向确定：一列全宽、封面原尺寸+thumbnail 480px、CRF 24、五层fallback待实施
type: project
---

## 产品改版方向（2026-04-04 确定）

核心数据：63% session 没看视频，每会话 1.2 页，浏览 55 秒。
根因：移动端首页劝退率高，缩略图 320px 太模糊，缺乏探索动力。

### 移动端改版要点
- 首页一列全宽大图（替代两列小图）
- 底部 Tab 导航（替代汉堡菜单）
- 无限滚动（替代分页）
- Tab 切换（热门/最新/推荐）
- 卡片显示观看次数

### 封面图方案（已确定）
- cover_image：原尺寸不 resize（超清 2184px / 标准 800px），AVIF CRF 24
- thumbnail_image：480px resize，AVIF CRF 24
- 两张图从同一个最佳源生成
- 五层 fallback：awsimgsrc(GET!) → pics.dmm → MGStage → minnano-av → Jable

### 关键技术注意
- awsimgsrc.dmm.com 必须用 GET（HEAD 被 CloudFront 返回 405）
- isHdImage 返回 false 时保留 800px 标准版（不丢弃）
- SOD 系 cid 需要 "1" 前缀
- Prestige (ABW/ABF) 不在 DMM → MGStage CDN

**Why:** 用户留存数据极差，需要产品层面改版而非只做技术优化。

**How to apply:** 封面采集和移动端改版并行推进，docs/PRODUCT_ANALYSIS.md 和 docs/media/IMAGE_SOURCES.md 有完整方案。

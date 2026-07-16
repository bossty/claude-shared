---
name: reference_cover_miss_not_ipban_placeholder_probe
description: 「同几个番号每小时反复失败+产出骤降」≠IP封——判别=历史命中URL复测+占位图语义;封面miss会经清理删行+markDead失效循环重采堵死hardCap名额
metadata:
  type: reference
---

jable 封面链路事故判别法（2026-07-15，日产出 27→1 实事故，IP 封被受控实验证伪）：

1. **判别 IP 封 vs 片不存在的决定性对照**：同机同 UA 复测「历史上命中过的 URL」——仍 200 = 排除 IP/区域/UA 封；再看失败 URL 的响应语义：DMM awsimgsrc 对不存在的片回 **404 但 content-type=image/jpeg（2732B 占位图）**、pics.dmm 回 **302 → now_printing.jpg**（官方「封面制作中」）= 新片封面未上架，几天后大概率自然上架。别一看「某源突然零产出」就套 IP 封老剧本（历史第 5 次同型是真封，这次不是）。
2. **产出骤降的真机制是任务侧队头堵塞**：封面 miss → `MovieDetailCrawlerService` 整部清理删行 → 下轮又被当新片 → 吃满 hardCapPerRun（jable 每小时=1）名额，同页真新片饿死。骤降曲线（27→24→15→1）像渐进式封禁，其实是钉子户逐个累积。
3. **markDead 死片机制对「删行型失败」永久失效**（BL-71，未修）：markDead 按 movieNumber 找行且仅 status=0 才标 2，行已删=no-op；且 `FreshnessTrickle.processFailedItems` 只要 accept 不抛就清零失败计数 → 永远到不了 maxAttempts。改共享组件前枚举全下游（同 [[reference_crawler_parsedetail_null_contract]]）。
4. 修复（已合 master `1271130f2`）：恢复源站原图兜底（`MovieImageService.processMovieCover` 全 miss 且有源 URL 时走 `R2UploadService.downloadCoverSourceImage`，V5 管道不变）。生产验证判据=日志 `✅封面兜底命中(源站原图)` + finalized≥1 + DB status=1/cover 非空。
5. 调查方法论可复用：日志按「命中层×天」做分层统计表，哪层何时最后命中一眼定位断点；CoverService `downloadFromCdn` 吞状态码不记日志，纯看日志无法区分 404/403/超时，必须现场 curl。

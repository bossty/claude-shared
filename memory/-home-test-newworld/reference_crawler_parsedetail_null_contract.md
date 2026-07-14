---
name: reference_crawler_parsedetail_null_contract
description: A族爬虫 parseDetail 返回 null 的语义陷阱——基类计 FAILED 非 SKIPPED；别用「基类 null→SKIPPED 守卫」修，会削弱全爬虫熔断
metadata:
  type: reference
---

`AbstractStandaloneCrawler.crawlOneItem(draft)` 首行 `draft.getMovieNumber()` 无 null 守卫：**parseDetail 返回 null → NPE → 上层 catch 计 FAILED**（推进 consecutiveFailures、污染 failRate>2% 告警、FreshnessTrickle outcome=error N9E 误报）。cableav/supjav/madou 均靠此隐式约定：parseDetail 返回 null = 该条失败。

**陷阱**：想「修」成 null→SKIPPED（中性）时，**别在基类加 `if(draft==null) return SKIPPED`**——有跨爬虫副作用：启用熔断（maxConsecutiveFailures>0）的爬虫（如 supjav）在**源站故障** parseDetail 返回 null 时会被当中性跳过 → 熔断永不触发 → 源挂了还死磕。`SupjavCrawlerServiceTest.circuitBroken_stopsPageRange` 正是靠 null→FAILED 触发熔断，基类改动直接令其 red（BL-59 实测：初版基类守卫过了 madou/cableav/AbstractStandaloneCrawlerTest 但炸 supjav 熔断测试）。

**正解**：null 语义天然重载了「主动跳过」与「源失败」两义，blanket 归一必错其一。要消除某爬虫的「主动跳过 null 每轮复发假失败」（如 madou 跨源 content_number dedup 命中→null→FAILED→每小时复发），**在该爬虫本地去掉那个主动 null 路径**（madou 改为 content_number 只写入存档、不做 crawl 期主动判重，同源 same-slug 重复由 movie_number+基类 Stage1 DuplicateKey 已幂等），保留 genuine-failure 的 null→FAILED（正确）。**别动共享基类契约当一个爬虫的副作用**。

判据：改共享基类（爬虫框架/闸门/守卫）前，先枚举所有下游消费方的隐式依赖（此处=各爬虫的 null 语义 + 熔断契约），跑全量而非单爬虫测试。见 [[feedback_gate_redgreen_and_failsafe_direction]] [[project_madou_crawler_2026_07_13]]。

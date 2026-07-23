---
name: reference_crawler_parsedetail_null_contract
description: A族爬虫 parseDetail 返回 null 的语义陷阱——基类计 FAILED 非 SKIPPED；别用「基类 null→SKIPPED 守卫」修，会削弱全爬虫熔断
metadata: 
  node_type: memory
  type: reference
  originSessionId: cecd1632-dc2a-41d4-be8e-54da09a8d1c5
  modified: 2026-07-22T11:50:24.774Z
---

`AbstractStandaloneCrawler.crawlOneItem(draft)` 首行 `draft.getMovieNumber()` 无 null 守卫：**parseDetail 返回 null → NPE → 上层 catch 计 FAILED**（推进 consecutiveFailures、污染 failRate>2% 告警、FreshnessTrickle outcome=error N9E 误报）。cableav/supjav/madou 均靠此隐式约定：parseDetail 返回 null = 该条失败。

**陷阱**：想「修」成 null→SKIPPED（中性）时，**别在基类加 `if(draft==null) return SKIPPED`**——有跨爬虫副作用：启用熔断（maxConsecutiveFailures>0）的爬虫（如 supjav）在**源站故障** parseDetail 返回 null 时会被当中性跳过 → 熔断永不触发 → 源挂了还死磕。`SupjavCrawlerServiceTest.circuitBroken_stopsPageRange` 正是靠 null→FAILED 触发熔断，基类改动直接令其 red（BL-59 实测：初版基类守卫过了 madou/cableav/AbstractStandaloneCrawlerTest 但炸 supjav 熔断测试）。

**正解**：null 语义天然重载了「主动跳过」与「源失败」两义，blanket 归一必错其一。要消除某爬虫的「主动跳过 null 每轮复发假失败」（如 madou 跨源 content_number dedup 命中→null→FAILED→每小时复发），**在该爬虫本地去掉那个主动 null 路径**（madou 改为 content_number 只写入存档、不做 crawl 期主动判重，同源 same-slug 重复由 movie_number+基类 Stage1 DuplicateKey 已幂等），保留 genuine-failure 的 null→FAILED（正确）。**别动共享基类契约当一个爬虫的副作用**。

判据：改共享基类（爬虫框架/闸门/守卫）前，先枚举所有下游消费方的隐式依赖（此处=各爬虫的 null 语义 + 熔断契约），跑全量而非单爬虫测试。见 [[feedback_gate_redgreen_and_failsafe_direction]] [[project_madou_crawler_2026_07_13]]。

## 同族坑：detail 阶段其余四条「调用方 ↔ 被调方」隐式契约

null 语义只是这层契约里最出名的一条。下面四条同样是「函数自己看着跑成功了、契约在调用方那头断掉」，全部靠真入库数据（不是日志、不是返回码）才暴露：

1. **finally 删临时目录早于 caller 拿到 return value**（源档 `project_hanime1_cf_5_12_5_13_sprint.md`（已于 BL-131 阶段 1 删除，取回 `git show 8c44739c6:claude-shared/memory/-home-test-newworld/project_hanime1_cf_5_12_5_13_sprint.md`），5/13 整夜 0 入库真凶）：`AbstractXvideosChannelCrawler.downloadAndSliceMp4:1820` 的 `finally { deleteDirQuiet(tmpRoot) }` 在 **success path 上也执行** → 返回的 `hls/` 路径在 caller `uploadBatch` 读之前已被删 → ENOENT → 整部回滚。方法内部一切正常（切片成功、return 了合法路径），报错点在下游 4143 条「文件不存在 `/tmp/hanime1-mp4-*/hls/*.ts`」。hotfix `2d7269ac`：success 只删 `src.mp4`，`hls/` 留给下游 `uploadBatch deleteAfterUpload` 个体清。**铁律：任何 try-finally 清「会被 return 出去的 path」，先问 caller 是否还要 access 它——finally 的执行时机永远早于 caller 用到返回值。**要么 success/failure 分支分开清，要么把生命周期交给消费方。
2. **ffmpeg 生成 preview 必须在重加密之前、读明文 `seg_*.ts`**（源档 `project_xvideos_d_sprint_5_8_5_9.md`（已于 BL-131 阶段 1 删除，取回 `git show 8c44739c6:claude-shared/memory/-home-test-newworld/project_xvideos_d_sprint_5_8_5_9.md`））：正确顺序 = mp4 download → ffmpeg 切片 → **明文 ts 抽 preview** → AES 重加密 → 传 R2。金标是 `AvjialiCrawlerService` L1132-1183（原注释「必须在重加密前，读明文 ts」）。**时机错位 = 100% bug**（不是概率性）：hanime1 v5/v6 连 fail 5 次直到逐行对齐 Avjiali pattern，commit `f790a0bc` 修。preview 的 R2 path 靠 ThreadLocal `currentPreviewR2Path` 从方法内传给 caller `setPreviewVideo`——这本身又是一条隐式契约，改签名/换线程池前必查。
3. **referer 必须按「资源实际所属域」设，不是统一 BASE_URL**：hanime1 的 mp4 直链在 `vdownload.hembed.com`，referer 必须给 `https://hanime1.me/`，用爬虫的 `BASE_URL=xvideos.com` 会被拒——封面和 mp4 下载**两条路径都中招**，commit `bbcd9c48`（封面）+ `c6eeadca`（mp4 download）分别修。多源/多 CDN 爬虫里 BASE_URL 只是列表页的域，别当全局 referer 常量用。
4. **`status=0` 草稿仍必须调 `updateMovie`**：hanime1 入库走 `status=0` 等人工 review，早期实现在判到草稿时**早 return 跳过 `movieMapper.updateById(movie)`** → `preview_video` / cover 等字段全没写，35 条入库 `preview_video` 全 NULL，commit `4bff7138` 修。**「这条不上线」≠「这条不用写字段」**——上线开关只该控 `status`，不该顺手短路掉字段持久化，否则等运营哪天批量上线才发现数据是空的。

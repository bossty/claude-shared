---
name: project_crawler_pilot_task9_dryrun_2026_07_03
description: 独立爬虫收敛 pilot(Beeg) Task9 行为保持 dry-run — PASS，误伤生产影片playback已从CF边缘缓存无损修复(实为2部)
metadata: 
  node_type: memory
  type: project
  originSessionId: b41396b9-50bd-45e1-90ca-888b7867fe62
---

**独立爬虫收敛 pilot(Beeg) Task 9 行为保持 dry-run（2026-07-03）**：验证 extract-superclass 重构（`AbstractStandaloneCrawler`，已在 master `cfec6a78`）行为等价。

**结果 PASS ✅**：before(`1a87041f`,inline 1424行) vs after(`cfec6a78`,extends基类 1250行) 两 jar 对同批 6 部 beeg 影片(offset 0/1968/4656)采集入库，`movie`行+关联**逐字节一致**(diff 0)。含 offset≥480 深页(Task7 BLOCKER 修复点)。报告 `docs/superpowers/plans/2026-07-03-standalone-crawler-pilot-beeg-TASK9-REPORT.md`。

**方法**：buyvm-data 上全隔离——抛弃式 Docker MySQL/Redis(不连生产)+ schema 取 buyvm-db 备份 + **确定性 mock LLM**(采集链路有强制 LLM 富化门，非确定性会污染 diff；`OPENAI_ENDPOINT` env 覆盖到本地 mock 回显标题)。触发 `POST /crawler/beeg/crawl-pages?startPage/endPage` + `CRAWLER_BEEG_HARD_CAP_PER_RUN`。

**⚠️ 事故→✅已修复**：隔离库继承生产备份烘焙的 `movie.AUTO_INCREMENT=23395` → 测试影片得生产区间 id 23395–23400 → id 键控 m3u8 `{PATH_SEGMENTS}/playlist_{movieId}.m3u8` 覆盖真实生产影片 playlist(无 R2 版本)。**实际只 2 部受影响**(生产 DB 核实:23395=dldss-478/23398=vec-768 存在且 status=1;23396/97/99/00 不存在=纯 orphan)。**修复=从 CF 边缘缓存无损捞回**:虽 origin 被删,50 个 R_VID 域各有独立 CF 边缘缓存,某些域仍缓着两部原始 m3u8(2325/1265 段=DB精确匹配,两域字节一致)→ curl 抓回重传 R2 origin(ContentType=application/vnd.apple.mpegurl,Cache-Control max-age=300);真切片(4月,内容hash键)+全局 enc-key(4e13244e,所有影片共享,我只重传同字节)本就完好。**未重爬、未改元数据、原内容精确还原**;端到端验证两部 m3u8+key+首尾切片全 HTTP200。★教训:重传前必核样本切片 origin 完好(否则只补 m3u8 无用)+跨域抓验字节一致(排单边缓存损坏)。封面 66 orphan 早已删(封面非覆盖,生产用 `_hd/_m` 旧命名)。残留无害 orphan beeg 切片(内容hash键无引用,无法安全批删)。

复用铁律见 [[reference_crawler_dryrun_id_collision_mock_llm]]。分支 fix/resize-observer-benign-monitor(与本 dry-run 无关，只借工作树 build)。

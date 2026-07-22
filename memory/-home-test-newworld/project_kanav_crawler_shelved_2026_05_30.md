---
name: project_kanav_crawler_shelved_2026_05_30
description: kanav 爬虫 Owner 2026-05-30 拍板「暂时放弃」(搁置非废弃):KanavCrawlerService 代码保留 gated-off 默认禁用零线上影响,从未部署/验收;恢复路径与 PRD 位置(BL-111 删档后须 git 历史找回)
metadata:
  type: project
---

kanav 爬虫接入 sprint（2026-05-26）由 Owner 于 2026-05-30 拍板**暂时放弃——是搁置，不是废弃删除**。防未来会话把它误当「已完成」或「已删除」：

- **代码现状**：`KanavCrawlerService.java` 已写完并保留在仓库，`@ConditionalOnProperty(app.crawler.kanav.enabled, havingValue=true, matchIfMissing=false)` 默认 false 不加载，零线上风险、保留零成本。**从未部署过、从未通过 batch test 与 reviewer 验收、从未入库跑通**（设计为 `movie.status=0` 初始入库，P7-Gate 通过后升 1）。
- **恢复路径（若重启）**：①跑 batch test 验证采集 → ②reviewer 完成验收 → ③`app.crawler.kanav.enabled=true` → ④部署 data 模块新 jar（注意原档写的目标机 aws-data 已退役，现拓扑是 ca-admin 跑 data 单实例，需按现状重评）→ ⑤验证 status=0 入库与升 1 链路。
- **设计与反爬方案**：PRD 原在 `docs/sprint/_archive/2026-05-26-kanav-crawler/PRD.md`（核心思路=FlareSolverr 复用 hanime1 基础设施）；**BL-111 归档目录删除后须从 git 历史找回该文件**。另有配套 profile `application-buyvm-kanav.yml` 仍在 newworld-data resources 下。

相关：[[reference_source_ip_ban_dual_whitelist_flaresolverr]]（FlareSolverr 双白名单成对铁律，重启时必评估）。

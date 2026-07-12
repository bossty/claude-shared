---
name: project_javxx_ipban_revamp_2026_07_11
description: javxx/123av 断流三层根因(IP封禁×2已修合master+源站改版待做BL-44);部署验证逐层揭盖方法论
metadata: 
  node_type: memory
  type: project
  originSessionId: 47e97a07-2ff6-47e7-9727-203c41727bcb
---

**javxx（源站 123av）断流 2 周+ 排查：一路揭开三层独立根因，前两层已修合 master、第三层立 BL-44**（2026-07-11）。

## 三层根因（关键教训：别停在第一层，部署验证会逐层揭盖）
1. **列表/详情页 IP 封禁**：123av 按出口 IP 封 aws-ca（直连 403）。修法=经 FlareSolverr 走 BuyVM tinyproxy（`af365721`，白名单 `cf.flaresolverr-proxy-hosts` 默认仅 123av.com）。
2. **资产 CDN 同受 IP 封禁**（第一次部署后才暴露）：封面/preview 在 `icdn.123av.me`（.me 非 .com），走基类 `downloadImageWithReferer`（HttpURLConnection 直连、9 家爬虫共用），不经 FlareSolverr → 直连 403 → `uploadCover` 硬失败 → `safeDeleteAll` 整条回滚 → **"列表抓到了但一部不入库"**。修法=基类加 proxy 可选重载(3 参委托 proxy=null，其余 8 家零变化)+ `JavxxCrawlerService.downloadAsset` proxy 优先直连兜底，复用生产已有 `hls.fallback-proxy.*`（`1bab7d63`）。
3. **源站改版**（第二次部署后暴露，**非分支范畴→BL-44**）：detail 页 player JSON 换结构——`?poster=` 封面参数移除(改 md5(id)前2位推导 `icdn.123av.me/preview/{XX}/{id}/preview.png`)、embed 域 `surrit.store`→`javplayer.cc`(stream API 结构不变)、`#video-details`→`dl.watch__info` dt/dd 无冒号(旧冒号正则全失配=隐性二次损坏)。全貌见 `docs/sprint/2026-07-11-javxx-revamp/SESSION-STATE.md`。

## 方法论沉淀
- **"验证出片"必须真出片，不能停在"部署成功/列表能抓"**：每次部署都靠盯整点调度 + 生产库入库计数做终判，逐层逼出下一个 blocker。若第一次部署就宣告完成，2、3 层永远发现不了。
- **红绿双验用真实出口**：ca-admin 直连 123av/icdn 403、经 tinyproxy 200，出口方案有效性一锤定音——**推翻了 backlog 里"BuyVM 出口 07-08 已实测否决"的旧记载**（[[feedback_verify_not_recall]] 又一例：转述的否决结论未 fact-check）。
- **stale target 假红**：合 master 时 pre-push 全量门报 `RegionReadRoutingArchTest.MonitorService.lambda$2` 违规(EU 跨洋 master Redis 读)，但 origin/master clean(-am) 7/7 绿 + 合并树 clean 重编 7/7 绿 → `lambda$N` 是残留编译产物特征=污染假红，`mvn clean` 重建 target 后重推即过([[feedback_no_concurrent_maven_during_gates]] 同族)。**判假红铁律：clean 重编能复现才是真红**。

## 状态
- 合 master：merge `0cb8d594`(feature `fix/javxx-flaresolverr-buyvm-proxy` 已删)；部署 ca-admin `deployed/data=1bab7d63`(生产实跑)；881 tests 绿。
- 生产配置已就绪：`data.env` 有 `CF_FLARESOLVERR_PROXY_URL` + `hls.fallback-proxy.*`(同一 BuyVM tinyproxy 209.141.48.177:3128)。
- **未真出片**(卡第 3 层)=BL-44(§1 需行动)，开新会话适配 `parseDetail`；ops 侧连带=新 m3u8 host `wowstream.cloud`/`black-star-104.store` 需核对 `hls.geo-block-hosts`。

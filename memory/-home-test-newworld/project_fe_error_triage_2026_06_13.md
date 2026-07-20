---
name: project_fe_error_triage_2026_06_13
description: 前端错误 triage sprint：13样本→397族穷举→真bug全修全部署(2026-06-13/14)
metadata: 
  node_type: memory
  type: project
  originSessionId: 187c446e-e104-4aa0-a529-a524a6ebe78b
---

前端错误 triage sprint（owner 给 13 条上报样本起，扩到"每一种哪怕 1 条"）。**上 master 4 commit 全部署生产 CA×3+EU×2(c5e7045d→c38eb577)**：`0fd38a11` Fix-1 postMount 5服务独立 try/catch 隔离(裸 await import 任一失败 reject→杀全家 stats/monitor/img/aria)+Fix-2 errorRecovery chunk 签名过滤 / `f5fc7fc3` deploy-frontend.sh 适配多region(WEB_HOSTS 退役 HK→usw1-web-new-01/02/03+eu-web-new-01/02，build模型 git-pull→本地build+scp+sudo) / `8557324f` FIX-3~6 / `779ea3b5` 测试治理。

**真本站 bug（已修已部署）**：
- #6=postMount 裸 dynamic import 解构 undefined(chunk stale)；**BLOCKER-2**=该 TypeError 被 errorRecovery.js:41 `name==='TypeError'` 误判"主域名不可达"→拉 DoH/seed/relay domain-failover+可能 showMaintenancePage(stale chunk 误弹维护页)。
- **FIX-3 Safari 缺口**：CHUNK_ERROR_PATTERNS 只有 Chrome 'Cannot destructure'，缺 Safari 'Right side of assignment cannot be destructured'→Safari chunk 失败仍误入 domain-failover(生产实锤 引导链失败 15+应用初始化失败 54)。补单条 `'cannot be destructured'`(子串覆盖 Safari，蓝军 397 族实证零 false-positive，destructure 措辞永不与 network 共现)。
- **FIX-6 QImg `Decryption failed: Unpad Error`**(311)：解密失败非网络。encrypted-image.js:127 截断 guard 仅 content-length 存在时生效，CF/chunked 无 CL 时漏过→截断 cipher 落 16 字节边界→Unpad；decrypt catch 零 failover。修=护栏式 1 次重 fetch(同url/cap=1/不轮转域，蓝军否域轮转因对 ts-mismatch 无用)。真根因(ts/asset 错位 DB encrypt_ts↔R2)=ops/DB backlog。
- FIX-4 pwa-install console.error→warn(本已 .catch 隔离非 fatal，消~1393 假 error)；FIX-5 monitor 加 isThirdPartyScraperSignature(迅雷/XL/采集器→third_party_scraper_noise)+plyr non-finite/insertBefore 过滤(plyr.js setter x.number(NaN)=true 漏判，库内噪声)。

**397 族穷举法**=见 [[reference_fe_error_store_enumeration]]。**外部注入坐实**(全 grep 0)：迅雷 `[video-takeover] postVideoUrl`/`xlGetAppMetaData` 主动抓播放地址(被采集实锤)、采集器 `_17cSite`/`traceStartDetect`、WebView CORS `Script error.`。**#2 503**=源站 295万请求零 503→CF 边缘/tunnel 跨洋自生成(对齐 reference_cf_graphql_504_adaptive)。

**backlog**：QImg DB encrypt_ts↔R2 对账 · 反爬 WAF(迅雷抓播放地址) · vue insertBefore Snack09 Teleport repro · plyr setter finite guard · 部署 stale chunk grace(系统根因) · 域池补给。

**协作教训**见 [[feedback_multiagent_prod_ops_auth_backstop]]。sprint 文档 docs/sprint/_archive/2026-06-13-fe-error-triage/(FE-ERROR-FULL-TAXONOMY.txt+agents/)。

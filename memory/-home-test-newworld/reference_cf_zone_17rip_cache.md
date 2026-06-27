---
name: reference-cf-cache-config
description: "CF 分组(5 逻辑组/4 账号,P+S 同账号) + Browser Cache TTL 陷阱 + 2026-05-19 全量修复 + 自动化"
metadata: 
  node_type: memory
  type: reference
  originSessionId: d1ce72a8-731d-43b9-a768-2729ffc096b7
---

**CF 分组:5 个逻辑组、只有 4 个 CF 账号**。逻辑组 A/B/C/P/S 配置在 `system_config`(`CF_API_TOKEN_{A,B,C,P}` + `CF_TOKEN_S`〔注意 S 是 `CF_TOKEN_S`、不是 `CF_API_TOKEN_S` —— 命名不一致〕/ `CF_ACCOUNT_ID_*` / `CF_TUNNEL_ID_*`;`CF_TOKEN_S` 另存 secrets.env)。**关键:P 和 S 共用同一个 CF 账号 `9a1d66324e3d3375e6288f949e49190b`**;A/B/C 各自独立账号。因此 P-scoped token (`CF_API_TOKEN_P`) 能枚举到该账号全部 31 个 zone(= 20 个 P 域 + 11 个 S 域)。`CloudflareApiService.getTokenByAccount` 印证:account `S` 用 `CF_TOKEN_S`、缺失则 fallback 到 `CF_API_TOKEN_P`(只因同账号才成立)。`domain` 表 `category`/`cf_account` 严格区分(A70 / B18 / C4 / P20 / S11)—— **P 与 S 是独立业务组**(S = wildcard 短链渠道入口域、grey-cloud;P = P 域池),CF 账号层共址不代表业务上是一个组。

主站 `17.rip` = group A(zone `c160c3791b0eacc1db7f3690b286aa8c`)。DB 查询 `mysql -h172.31.27.200 -unewworld`(密码 secrets.env `DB_PASSWORD`);CF API 全程在 aws-data 服务器侧跑、token 不落地。

**Browser Cache TTL 陷阱(2026-05-19 查实)**:CF zone 级 `Browser Cache TTL` 默认 `14400`(4h,CF 传统默认值、从未改过)。它对「CF 边缘会缓存的内容」把发给浏览器的 `Cache-Control` 抬到 ≥4h(origin TTL 低于设置值时覆盖)。源站 nginx 给 `sw.js` 发 `no-cache`,但 `.js` 在 CF 默认缓存扩展名内 → CF 缓存 → 被覆盖成 `max-age=14400` → Service Worker 最长 4h 不更新。`.txt`/`.json`(version.txt/manifest.json)非 CF 默认扩展名、`index.html` 被 guard.lua 标 `private` → 都 DYNAMIC 不受影响。`sw.js` 是唯一中招文件(疑污染 QQ iOS 劫持 36 轮远程调试,见 [[project-player-hijack-2026-05-18]])。

**为何之前 CF 没配**:`CloudflareApiService.syncCacheRules` Javadoc 记 2026-05-01 决策——撤销所有 CF Cache Rules、「完全依赖 origin Cache-Control」(理由「CF Cache Level Standard 遵守 origin」)。盲区:该判断只覆盖 CF *边缘缓存* 行为,没覆盖 zone 级 *Browser Cache TTL* 设置(独立改写浏览器侧 Cache-Control)。`DomainLifecycleService.configureWebZone`(L1126)也注释掉 syncCacheRules(「OpenResty 控制缓存头,CF Cache Rules 暂不需要」)。

**修复(2026-05-19)**:A 账号全部 zone(~71)+ C(4)+ P/S 共享账号全部 31(含 20 P 域 + 11 S 域)的 `browser_cache_ttl` 经 CF API `PATCH /zones/{id}/settings/browser_cache_ttl` body `{"value":0}` 改为 Respect Existing Headers。验证 `curl -sI https://<域>/sw.js` → `cache-control: no-cache`。回滚 = PATCH 回 `14400`。曾在 17.rip 临时加 Cache Rule(`cache:false`),zone 设置生效后已删(冗余)。

**自动化缺口(2026-05-19 实施中)**:新 A/C/P 域名经 `DomainLifecycleService.configureWebZone()` 配置 ssl/CAA/DNSSEC,但不设 browser_cache_ttl → 新域名会拿 CF 默认 14400 重新踩坑。修法:`CloudflareApiService` 加 `setBrowserCacheTtlRespectOrigin()`(PATCH `{"value":0}`;0 是 int,现有 `setZoneSetting` 只收 String 故单列),在 `configureWebZone` 调用。

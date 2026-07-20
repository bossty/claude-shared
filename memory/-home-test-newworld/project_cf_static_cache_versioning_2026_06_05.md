---
name: project_cf_static_cache_versioning_2026_06_05
description: "CF静态缓存×前端版本时效×老客户端兼容 5人共识sprint — 证伪\"静态没缓存=最大瓶颈\"前提,76%卸载率仲裁,iOS白屏P0"
metadata: 
  node_type: memory
  type: project
  originSessionId: f4b7ce6c-ece8-460f-99f3-acc518f764e6
---

5人 agent 团队（D1数据/D2 CF/D3前端/D4业界/蓝军裁判，**不跨轮次沟通+全员一致签字**）验 Owner 假设「前端性能最大瓶颈=index.html+静态文件没缓存到CF」。终稿 `docs/sprint/_archive/2026-06-05-cf-static-cache-versioning/FINAL-DESIGN.md`（全员✅）。

**★前提证伪（金标=origin请求数，非cf-cache-status）**：hashed `/assets/*.js|css` 字节大头回源=**0**已100%卸载（双节点web.log 10.7min双算法+同窗.js=19425排假0）。静态缓存缺失仅占性能~5-10%且属源站负载维度**非用户感知延迟**。真凶仍是**跨洋CF Anycast+cloudflared tunnel(~60%)**：源站urt p95=**8ms** vs 用户TTFB p75=**1340ms**(167×)，复现[[project_peak_perf_debate_2026_05_29]]。INP~28%(LCP p75=4434)。用户感知大头归 decoupled-geo-lb sprint，本sprint分流不碰。

**★更正 [[project_fe_version_audit_2026_06_03]] 旧结论**：6/03「version-edge-ttl卸载≈0/未达成」是测 **pre-fix(max-age=0,对象刚存即过期每请求条件GET)** 状态。59f91e96改max-age=60后 D1 R2 实测 version.js **边缘卸载≈76%**(CN SEA POP 66%)。

**D2 vs D4 仲裁(各对一半合并)**：①D2对—纯origin头`max-age=60`**确实**让CF按60s持有(单POP age 1→11s单调增长证，**非单POP HIT误判**，推翻6/03)；②D4对—没到95%，高QPS POP多并发副本早revalidate(SEA 900s 2136次回源远超1POP/60s=15理论下限)，剩~24%必须CF Cache Rule **Edge Cache TTL「Override origin」**才消(`immutable`只对浏览器、CF文档明确不影响caching proxies；s-maxage含proxy-revalidate RFC9111)。**裁决:有意不上Override**—剩24%回源99.4%是廉价304不在渲染路径,时效>边际卸载;且CF **Free plan Edge TTL最小2h**强上反把时效拖2h纯负价值。version.js短TTL=特性非bug。

**业界主流范式(D4)**：内容寻址hash`max-age=31536000,immutable`+HTML`no-cache`+原子部署保留旧chunk(**Vercel Deployment Skew Protection**=immutable快照+部署ID路由回旧部署/Google web.dev/Workbox SW)。本项目hash+deploy Step4a/4b原子翻转(b371137d)+SW client.navigate强刷(90e6dca1)**已踩对**;内容域未开Smart Tiered Cache=真gap(仅B资源账号开)。

**落地(收窄3件)**：P0 **iOS/WebKit回访永久白屏根治**(`preloadGuards.js:21-27` vite:preloadError只reload不清SW cache+烧`_cr_preload`预算→拿回同一stale index卡死;`router.onError`清了但WebKit走不到→修:清SW cache再reload+预算用尽走recovery UI,**强制4象限验证**);P1探针策略文档化(version.js维持max-age=60不上Override+记Free-plan 2h约束+破坏性字段重命名ad→snack前必查X-SW-Version老版本分布gating);P2内容域Tiered Cache评估(需CF_API_TOKEN_A,当前不在任何可达生产服务器,owner决定)。

**方法论**：①「X是最大瓶颈」前提必先线上真实数据fact-check([[project_retention_drop_rca_2026_06_04]]同律);②CF卸载金标=origin请求数+全POP边缘HIT%,单POP HIT会被高QPS POP revalidate骗(但反过来age单调增长能证origin头确实生效);③CF GraphQL adaptive因token不可达没查成→改age-poll+origin/shell比值两路独立取证,**诚实标注没编数字**([[feedback_no_handwritten_numbers_from_tools]]);④全员一致签字闸门防和稀泥,蓝军查「为一致而糊真分歧」。

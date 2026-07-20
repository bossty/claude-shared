---
name: project_geolb_stale_frontend_regression_2026_06_06
description: 旗舰17.rip geo-lb切流回归(region前端stale 2天+version.js 404)止血 + region不是HK完整镜像治本 + 金标方法论
metadata: 
  node_type: memory
  type: project
  originSessionId: f4b7ce6c-ece8-460f-99f3-acc518f764e6
---

2026-06-06 查 P1.5 的 version.js no-store 小异常时揪出**旗舰生产回归**：decoupled-geo-lb 闸2 全量切流(87da60ba)把 17.rip 切到 region pool origin(US `52.88.219.149`/EU `18.159.214.202`)，但 **region 前端 dist 停在 6/02**(Phase0 部署后没随 HK 后续部署更新)→ version.js 经 CF=**404+no-store**(源站直连 200/max-age=60)+ index.html 落后 2 天 → 全量 CN 用户版本检测/SW 更新链路断。铁证三独立信号：CF 404 body `server: openresty/1.29.2.5`(aws-web 是 1.29.2.3,证 tunnel 没到 web 双机)+ last-modified Jun02(web 是 Jun3-4)+ 源站直连健康。lead 自己 curl 复核坐实。

**止血(owner 批"同步dist到region",lead 主会话统筹 ops-senior 全程金标复核)**：aws-web-01 canonical dist tar→US/EU 原子翻转(纯静态零停机免 drain)→version.js 200/前端追平(我 curl 复核)。access=**EC2 Instance Connect profile nw-dev/ubuntu 用户**(非 aws-* 的 newworld)。

**★根因升一层=region origin 不是 HK 完整镜像**：只有 jar(Phase0 5c6988a8)+手动同步的静态文件,OpenResty 配置/dist 各自漂移。审计(`nginx -T` 三台 diff)出漂移清单(全已修/录):D1 version.js 短 TTL 缺(s-maxage 86400 vs 60→版本检测滞后1天,已补 map+location)/**D3 缺5条 legacy grace rewrite(`/api/v1/q|promotions/*`→`/api/v1/snack/*`)=region池老用户旧路径404广告零展示掉收入(已修,老路径经CF 404→200+`x-legacy-q-grace`头)**/D2 缺 proxy_next_upstream/D4 缺 grace log(均已修+双台 nginx-t+reload)/D5-D8 worker_connections/manifest/keepalive 低配(backlog)/guard.lua 仅4行死配置漂移(`/upload/ad-image` vs `snack-image`,admin接口region不承接,低,backlog);**速率限制/Strike/banned/vid/探针旁路/4xx no-store/安全头全一致,无安全暴露**。

**★方法论铁律(本次最大收获,金标层层揪)**：**「能用/调用在」≠「和 HK 一致」**。①ops 报"version.js 200 done"→lead 复核出 cache-control s-maxage=1天(只验200没验头);②ops 审计报"guard.lua 一致(require在)"→lead 坚持 `md5sum` diff 才揪出文件本体漂移。**验证必到「字节级一致」不是「功能可用」**。同 [[feedback_no_handwritten_numbers_from_tools]]。

**治本落地**：①preflight 补丁 `RUNBOOK §4 前置#0`(切流前每 pool origin 必验 version.js 200+hash==主;**金标"内容域SNI 200"拦不住 stale dist,旧origin对`/`也返200**)+ HK 每次前端部署必同步 region;②region 镜像治本 SPEC `docs/sprint/_archive/2026-06-06-region-origin-mirror/SPEC.md`(5开放决策待owner:config-as-code/扩展deploy脚本/镜像化)。docs 全在 `docs/sprint/_archive/2026-06-05-decoupled-geo-lb/agents/ops-*.md`,commit 46178885。

**关联**：geo-lb 切流见 [[reference_cf_lb_always_use_https_loop_universal_ssl]]；region 节点见 SESSION-STATE-multiregion;P0 iOS 白屏修复(bec8af53,待非峰窗部署+同步region)+ P1.5 index.html SWR(CF 2026-02-26 起支持边缘异步SWR纠偏6/03旧论,真blocker=index壳带set-cookie _vid需零cookie)见 [[project_cf_static_cache_versioning_2026_06_05]]。

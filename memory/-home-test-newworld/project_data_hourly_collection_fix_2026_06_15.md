---
name: project_data_hourly_collection_fix_2026_06_15
description: 2026-06-15 新CA服务器data每小时采集修复——Phase F迁移漏迁外部依赖三连(tinyproxy/FlareSolverr/buyvm-db)+5源全绿+代码加固
metadata: 
  node_type: memory
  type: project
  originSessionId: ce27c9bf-720e-4350-ba00-8892b604bf34
---

2026-06-15 排查修复"新服务器 data 模块每小时定时采集有问题"。**根因统一 = Phase F(2026-06-13)把 admin/data 迁加州 aws-ca-admin,3 个外部依赖/连接目标仍指向退役 HK 资源——env/配置迁了,依赖本体或可达性没对齐**(同 [[project_phase_f_admin_data_california_2026_06_13]] 同类延伸)。

**每小时定时采集 = 5 源**(cron `0 0 * * * *`):javxx / hanime1 / jable / beeg / cableav。rule34/pornhub/hanime.tv/xvgay 等都是每天定点非每小时。owner 澄清"3D 和动漫都从 hanime1 来"(hanime1 的 channel/genre),非 rule34。

**三个迁移断点(同一类)全闭合:**
1. **wowstream HLS 视频下载(javxx)**:buyvm-data tinyproxy(LA IP 绕 datacenter-ASN geo-block 的 403 兜底代理,209.141.48.177:3128)的**两层 ACL 只改了 UFW、漏了 tinyproxy 应用层 Allow**。UFW 已放行 CA 出口 IP `52.8.53.144`(**是 EIP,stop/start 不变**),但 tinyproxy.conf `Allow` 只剩退役 HK IP → `curl -x` 返 000。修=加 `Allow 52.8.53.144`+reload(行内注释会触发 syntax error 静默失败,注释须独立行)。ops 修,无需改代码。
2. **hanime1(动漫+3D)CF 挑战**:靠 **FlareSolverr** docker 容器(127.0.0.1:8191,5/12 上线,原跑 HK aws-data)解 Cloudflare Interactive Challenge。CA 上 `FLARESOLVERR_URL` env 迁了,但 **docker 没装、容器没起**。修=装 docker-ce(Ubuntu26.04 noble 源)+ `docker run -d --name flaresolverr --restart unless-stopped -p 127.0.0.1:8191:8191 ghcr.io/flaresolverr/flaresolverr`。修后 hanime1 successPages 0→1、真入库。ops 修,无需改代码。
3. **jable CF 挑战**(代码修):jable.tv 对 CA 数据中心 IP 上 CF 挑战,但 6 个 jable 爬虫+MovieDetail 用普通 `playwrightUtil.getPageHtml()`**不走 FlareSolverr 兜底**→ 403 拦成空页/"未找到电影列表容器"(18次/24h)。**selector 没坏**(FlareSolverr 取真页 section.pb-3+24片都在)。修=改走 `fetchHtmlBypassCloudflare` + cf-bypass 白名单从硬编码 hanime1.me 改可配置 `cf.bypass-hosts`(默认 `hanime1.me,jable.tv`)。修后"新增1+跳过9、容器错误归0"。

**代码加固(蓝军 F4/F5,已部署):** F4 加 Micrometer counter(`hls_download_total{source,result}`/`hls_proxy_fallback_total`)修"48h 静默无告警";F5 `GeoBlockedException` 类型化替代脆弱 `contains("403")`(只 geo-block 域名 403 才触发代理,非盲触);geo-block 默认根 token `wowstream,hanime1`。**lead 抓的部署级 BLOCKER:dev 初版默认 `wowstream.cc` ≠ 真实下载域 `wowstream2.cloud`(还有 wowstream.cloud),部署即回归——grep 实代码 + 钉真实生产 host 测试拦下。**

**commit/部署:** `acdb630d`(F4/F5 merge)+`5e4f579a`(jable merge);jar `newworld-data-20260615-042746.jar` 部署 aws-ca-admin(actuator :18080 UP、JAR 内含新类、无 OOM/ERROR)。**FlareSolverr 单实例 ~3 QPS,白名单只给确认被 CF 拦的源(hanime1.me/jable.tv),别灌无辜源。**

**安全清理(F3+F6):** 删 buyvm-data 上退役 HK IP(UFW 3128/443 + tinyproxy.conf Allow,16.162.253.75/18.167.41.192/18.166.209.100)——动态 IP 退役后可能被重分配,tinyproxy 无认证仅靠 IP ACL=开放代理滥用面。

**记录在案/暂不处理(owner):**
- **F2 buyvm 离线节点 DB 断裂**:application-buyvm-large/small.yml 写死退役 HK `18.166.209.100`;CA master `172.34.1.222` 是私有 VPC IP buyvm 够不到、公网 `13.57.1.70` SG 3306 未开、buyvm-db 本地 MySQL 未起 → 离线节点连不上任何库(仅跑 buyvm 批处理时咬)。详 `docs/sprint/2026-06-15-data-hls-proxy-acl/F2-buyvm-db-topology-KNOWN-ISSUE.md`,推荐方案=buyvm-db 本地库+定期同步。
- **CloakBrowser**(github.com/CloakHQ/CloakBrowser)评估:见 [[reference_cloakbrowser_cf_bypass]]。

**★二次修复(同日,观察上线运行数据后发现 F5 门控过窄回归):** 第一次部署(jar 042746)后观察 9.7h 运行数据,4 源健康但 **HLS 视频下载仍 607 失败(~200/小时)**。RCA:根因=该走代理的 403 没被路由到代理——① **201 轮换 CDN 域**(StreamSI 类 `随机词.store/.space/.site`,host 不在 `hls.geo-block-hosts` 白名单 → isGeoBlockedHost=false → 不抛 GeoBlockedException → 不走代理);② **406 wowstream** = `validateFirstFragmentIsMpegTs` 首段校验 handler 在 403 抛普通 IOException 非 GeoBlockedException → 不走代理。**这是 F5 改动自身引入的覆盖收窄**(F5 把"任何403切代理"收成"仅白名单host的GeoBlockedException切代理",漏了无法枚举的轮换 CDN + validate 步骤)。代理本身实证零问题(触发2418次0失败,单/突发/并发12/全header组合/连失败原URL全200)。诊断关键:F4 的"兜底也失败=0"指标直接证明"走到代理的都成功,失败的全是没走到代理的"。修=m3u8/fragment/key 三处 403 handler 去掉 `&& isGeoBlockedHost` 门控 + validate handler 403 改抛 GeoBlockedException(**任何 403 都切代理**;代理 0.13s/零失败,referer/token 类 403 顶多多一次廉价尝试)。isGeoBlockedHost 方法保留(现有测试在断言)。commit `c1912dc8`→merge `69839862`,jar `143609`;**实测最终失败 84/25min → 0,切proxy 475 次零失败**。教训:**isolated-test-pass ≠ production-scale-pass,修复上线后必观察真实运行数据**;诊断 agent 会看错 worktree(F5 前旧文件)把"类不存在"当前提→lead git grep master 实证仲裁、拿精确行锚自修。

方法论教训见 [[feedback_migration_external_dependency_audit]]。

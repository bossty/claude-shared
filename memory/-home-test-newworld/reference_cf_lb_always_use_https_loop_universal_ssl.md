---
name: reference_cf_lb_always_use_https_loop_universal_ssl
description: CF Load Balancer 在与其 pool origin 不同 zone 时对内容域路径 301 死循环;★治本=pool origin 建在 LB 同 zone(origin-{region}.dnsv106.com→tunnel);最终方案=独立基建域 dnsv106 上建同 zone-pool geo-LB(解耦 17.rip + 保留显式 region_pools);path B(CNAME→multi-region-tunnel 无 LB)是无显式控制的 fallback;最大教训=验 CF 边缘必用内容域 SNI 不能用 LB 直连(403 良性 artifact);CF LB plan 5-origin 硬限要升级
metadata:
  node_type: memory
  type: reference
  originSessionId: a71aa26f-69ff-4daa-8ee0-e32d79403b2e
---

2026-06-05 起一个"独立基建域做 LB CNAME 解耦 17.rip(防主站被封 SPOF)"的需求,排查出一个 CF 结构性坑 + 一个更优交付方案。nw-consensus 团队(lb-config-analyst/cf-edge-research/blue-team)crossfire + lead 金标仲裁。

## 现象
内容域(proxied,always_use_https=on)CNAME→**纯基建 zone(dnsv106.com)里的 CF Load Balancer hostname** → **CF 边缘 301 死循环**(301→同 HTTPS URL,server=cloudflare,无 origin 头,DYNAMIC)。`tcos.dnsv106.com`(LB)循环 vs `lblb.17.rip`(LB,同账号同 3 pool,LB 对象逐字段 byte-for-byte 完全相同)200 正常。

## ★ 最大教训(测路径)—— 全队反复误判的根源
**验 CF 边缘行为必须用真实用户路径的 SNI(内容域),不能用 LB hostname 直连测。** LB 直连(SNI=LB hostname)→ **403** 是无 Referer 的 WAF 良性拦截,**任何配置下都长这样**,会把"没修好"误读成"修好了"。本案多个"SSL Full→403""加同名 CNAME→403"全是 LB 直连 artifact;用内容域 standby(pondercalm.rest)SNI 实测,**那些"已修复"的 LB 仍 301**。lead 用内容域 SNI 一测就穿透了全部假修复。

## ★ 实验矩阵(硬证据,决定性)
| 测试 | LB 所在 zone vs origin zone | 内容域路径 |
|---|---|---|
| lblb.17.rip / lbtest2.17.rip | LB 与 pool origin 同 zone(17.rip) | **200** ✓ |
| tcos.dnsv106.com / lbtest.mistgarden.site | LB 跨 zone(非 origin zone) | **301 循环** ❌ |
| t2.dnsv106.com / tbtest.mistgarden.site | 无 LB,纯 proxied CNAME→tunnel | **200** ✓ |
→ **跨 zone LB=循环,同 zone LB=200,无 LB=200**。**根因 = LB 必须与其 pool origin 同 zone**:原 pool origin 是 `origin-hk.17.rip` 等(17.rip proxied),dnsv106 的 LB 路由到它=跨 zone 落进 17.rip context 的 always_use_https→循环;LB 在 17.rip 内同 zone 路由绕开→200。

## ★★ 最终交付方案 = 同 zone-pool geo-LB(owner insight 救活 LB,实证 GO)
**治本不是弃 LB,是把 pool origin 也建在 LB 所在 zone**(owner 一句"pool 也配在 dnsv106 是不是就行"切中矩阵):
- 在 dnsv106.com 建 `origin-{hk,us,eu}.dnsv106.com`(各 proxied CNAME→对应 region tunnel:hk=63594ad3/us=8af6ed58/eu=cde6d3f3.cfargotunnel.com)
- 3 个新 pool 用这些**同 zone** origin + 绑 lblb 同 monitor(GET /actuator/health Host=origin-hk.17.rip expect 200;**新绑 monitor 有 ~80s 探测周期才转 healthy,别误判 0/1**)
- LB `tcos.dnsv106.com` 复刻 lblb 的 region_pools(7)+country_pools(12)+geo+fallback(GET lblb→sed 重映射 3 个 pool id→POST,删 id/zone_id/zone_name)
- **金标实证**:mistgarden.site(内容域)→tcos.dnsv106.com→**200+geo(us-east→US origin)**。= lblb 精确复刻 + 解耦旗舰 17.rip + 同 zone 无循环 + **保留显式 country_pools[CN] 细调**(比 path B 强)。
- ⚠️ **CF LB plan 5-origin 硬限**:live lblb 锁 3,正式 geo-LB 需 3 个新,5 装不下 6 → 需升级 LB plan(owner 拍板升了)。pool 不能和 lblb 共用(共用得用 17.rip origin,tcos 又跨 zone)。
- ⚠️ **monitor 也要解耦(owner 揪出)**:图省事复用 lblb 的 monitor(Host=`origin-hk.17.rip`)→ geo-LB 健康检查残留 17.rip 引用,**CF 面板报"您的 URL 应引用域 17.rip"**,解耦不彻底(17.rip 真被封时 monitor 仍隐患)。治:建独立 monitor(复刻 type=https/path=/actuator/health/expect=200,Host 改 `origin-hk.dnsv106.com`)绑 3 新 pool。region web 的 /actuator/health 是 **host-agnostic**(任意 Host 返 200,实证),所以换 Host 不影响健康。**解耦铁律:LB 对象 + pool origin + monitor Host 三处都要扫 17.rip,缺一不彻底**。
- **落地(2026-06-05→06 全量收口)**:gate1 3 域 canary→半量 30/61→**✅全量(2026-06-06 峰内含旗舰):active A 63 域中 61 全迁 `tcos.dnsv106.com`,含旗舰 17.rip apex+wild**(原 63594ad3 HK 单区直连→tcos geo-LB);非 tcos 仅 2 实验臂(eduspace181 方案1/flowzone26 旧 lblb,有意排除防污染三臂)。owner sign-off=「10min 复测无问题就全量含旗舰」,gate 全绿才执行。**容量实证(全量+峰内单台 m5/region):US load 0.36→0.94(非旗舰批)→1.06(+旗舰)/EU 0.14→0.62→0.85,5xx=0 全程,利用率 26%/21% 留 74% 余量,HK master 179/500→单台 m5×region 扛全量含旗舰绰绰**。待办 backlog=region HA ×2(单 region 故障=CF LB fallback 降级非全断)。
- **★执行踩坑(CF DNS PATCH zone_id,已修零生产影响)**:批量 PATCH 切 CNAME 用快照 JSON 的 `.zone_id`→全 null(CF list `GET zones/{z}/dns_records` per-record 对象**不含 zone_id**)→60 条 7003 `zones/null/...` 全失败但**零记录改动(成功=0=生产未动无 5xx)**。修法=不信 list-record 抠的 zone_id,逐域实时 `GET zones?name=<domain>` re-derive zone_id+实时取 record id 再 PATCH→60/60 成功。铁律:CF DNS 改记录的 zone_id 必从 zones 接口实时取。
- **★回滚原值勘误**:active A 域切前 apex/wild 不是 lblb.17.rip,是直接 HK tunnel `63594ad3…cfargotunnel.com`(单区直连);回滚改回 63594ad3(非 lblb),快照 `aws-data:/tmp/lb-domain-snapshots/<d>.{apex,wild}.json` `.content` 存原值;lblb 是实验臂 flowzone26 在用全程未动。
- **坑:web.log 超高流量,验流量要 tail≥50000 否则采样窗口太小误读 req=0**;切后金标=内容域 SNI `curl -L -H Referer` 多打几次看稳定 200。
- ⚠️ **CN 拨测方差解读铁律(owner 用 aliyun 拨测发现两方案2域速度差很大)**:两个都解析到 CF Anycast 的方案2 域,CN 拨测速度可以差很多——**不是方案2/后端差异**(实证后端完全相同:同 region 源/同 us tunnel 8af6ed58,中立点 us-east 两域同 POP 同速 ~0.28s)。真因是 **CN→CF 边缘腿(#106)**:① **CF 给不同域名分不同 Anycast IP**(flowzone 104.21.21.248/172.67.201.117 vs digit-hub 104.21.68.55/172.67.187.189)→ 从 CN 路由到不同 POP/不同跨境路径;② **GFW 对不同域/IP 的 DNS 污染程度不同**(aliyun 200 节点:digit-hub 5 个节点被污染成 0.0.0.0 黑洞 vs flowzone 1 个)。**铁律:别用单域单点拨测判方案2,要用聚合 RUM(lb-cohort ≈ flowzone 才公允);CN 边缘腿是 CF Anycast+GFW 固有方差,LB/region 源砍不掉,要压平需 CF China Network(备案)或 Argo**。**工具**:itdog.cn 有点选文字 captcha 挡自动化;**aliyun boce(boce.aliyun.com/detect/http)无 captcha,playwright 可驱动**(输入框 fill→点 OK→等 40s→evaluate 抽 body.innerText 的 IP 计数,200 节点)。

## fallback 方案 = path B(无显式控制时用)
**内容域直接 CNAME → multi-region-tunnel(无 LB)**:
- `tcos2.dnsv106.com`(纯 proxied CNAME→`2063b532-…cfargotunnel.com`)→ 内容域过去 **200 + 13192 字节**;pondercalm.rest 实测同样 200。
- **geo 就近保留**:multi-region-tunnel 12 连接三区(HKG×4→aws-web-01 / SJC-PDX×4→US / FRA×4→EU);CF Anycast 路由用户到就近 colo→就近 tunnel 连接。HK 请求落 HKG、us-east 请求落 US origin(实测)。
- **更抗封**:CNAME 目标是 `…cfargotunnel.com`(Cloudflare 自有隧道 hostname,**不依赖会被封的 17.rip 旗舰域**),比原 LB 方案 SPOF 更小。
- 比 LB 简单(无 LB/无 cert-pack/无跨 zone 坑)。**架构**:内容域→`tcos.dnsv106.com`(纯 CNAME→tunnel,非 LB),dnsv106 当单点改向锚。
- ⚠️ geo 机制(CF Tunnel 就近 connector)与 gate1 验过的 LB region_pools 不同 → 切真实域前需 RUM 多地复验 TTFB。

## 机制:未定论(别再签任何 LB 根因)
- **cert-pack 条件被实证否掉**:owner 加 SSL:Read 后读到 `dnsv106.com` universal cert-pack **status=active, hosts=`dnsv106.com,*.dnsv106.com`**(覆盖 tcos)。openssl 也证 tcos 呈现该有效证书 verify=0。所以"LB hostname 无 active cert-pack 覆盖"不成立。
- **flexible 单因子否掉**:两 zone 都 flexible(17.rip 也是),17.rip 工作。
- **"SSL Full 修复"未在内容域路径验证**:团队"full→403"是 LB 直连 artifact;lead 内容域路径测 full 仍 301。**别信 Full 能修内容域路径**。
- 残留候选(未证):17.rip 可能有 per-hostname SSL Config Rule 让其实际走 Full(token 无 config-rule scope 读不到)。

## 已证伪死路(别重复)
cert issuer(LE/GTS=CF 轮换 CA 不通知)/ openssl 握手返 wildcard cert ≠ AUH 覆盖 / SSL mode 单独 / 加同名 proxied CNAME(tcos 带记录内容域路径仍 301,删记录复发)。

## 方法教训
(a) good+bad 两 zone 里**完全相同的属性**(cert/ssl-mode/origin-301)不可能是 discriminator,先排它再立论;(b) **测路径必须是真实用户 SNI**(本案最痛);(c) CF 边缘改动有 15s–2min 生效延迟,多采样到 ≥2min 再判;(d) 并行 agent 改共享 zone 状态(tcos 记录增删)致 false flapping,受控测试期冻结共享态 + 写操作署名(本案 tcos 一条 tunnel CNAME 归属丢失);(e) `9109`=token 缺 SSL scope,读不了 cert_packs/Config Rules;owner 可临时加 scope。

运维:dnsv106.com 已注册(NameSilo A,auto_renew=1,$17.29)+ 加 CF A zone + DNSSEC(DS 回填)+ CAA(digicert/letsencrypt issue+issuewild)+ Universal SSL active;排查后清回 CAA+DNSSEC 裸态待配 path B。真实 3 域(logicpipe26.cc/labwave488.top/digit-hub.top)全程 lblb.17.rip 200 零操作。
Related: [[reference_cf_cache_verify]] / [[project_phase0_redis_geo_deploy_2026_06_04]](gate1 方案2 + route-mode cohort)/ CLAUDE.md A/B/C/P/S 账号模型。

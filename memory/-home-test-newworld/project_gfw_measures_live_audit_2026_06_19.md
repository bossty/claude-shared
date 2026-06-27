---
name: project_gfw_measures_live_audit_2026_06_19
description: GFW突破全措施实测验证(2026-06-19)——哪些实打实工作/哪些名存实亡+GFW文档已严重失真
metadata: 
  node_type: memory
  type: project
  originSessionId: dc257175-09da-48ab-a79a-7e931baf5286
---

2026-06-19 对所有 GFW 突破措施做了**外部实测验证**（dig/curl/公共DoH + 用 WASM MASTER_KEY `NewWorld2024SecretKey@AES256!` 实际解密生产 /settings、np2 TXT、s.dat）。

**✅ 实测在工作**：CF橙云代理隐藏源站(17.rip+池全CF IP)；N_POOL 153域(解密settings得,抽样8/8 version=200)；**DoH np2 完美**(10个N_DOH carrier各8条np2 TXT经Google/AliDNS全解密,各自还原完整153域,union=153零缺失,印证[[project_doh_3layer_brokenness_np2_2026_06_18]]已落地)；HTTP Relay **已部署**(edu.rledumeta.com root=200返EduStream伪装页,/_relay无认证=401 HMAC门)；s.dat=152B解密出4个C类种子域；配置通道@EncryptResponse(/settings encrypted:true我成功解密=端到端工作,保护域名池不被DPI);HSTS preload header在;CAA在;探针门shouldBlockProbe lite版(main.js:154,commit 5b87d66d重加);静态伪装EduStream。

**🔴 实测坏/名存实亡（真窟窿）**：
1. **DNSSEC全线假的**:11个域(A/B/C全类:17.rip/byteatlas.top等/dhlearnpipe.com等/mindportal26.net)实测 DS全空+RRSIG全无=CF压根没签名/DS没推注册商。代码enableDnssec()调了但零生效。文档§5.4/§5.8"所有域名开启"不实。缓解:CF代理+HSTS+应用层AES还在,非裸奔但这层防线是假的。
2. **N_AG非CF兜底是死腿仍下发**:N_AG=https://d2qou1y0q9.execute-api.ap-east-1.amazonaws.com(**HK ap-east-1**),SW Happy Eyeballs 250ms第二顺位竞速腿;边缘答403但后端Lambda→EC2 origins 172.31.27.120/121 是HK VPC已2026-06-13退役→"CF被封时唯一非CF逃生通道实际不存在"却仍推给每客户端。应清N_AG或CA/EU重建非CF入口。

**📄 docs/GFW_AND_NETWORK.md 严重stale**勿当现状:拓扑还是退役HK/BuyVM(web-01 209.141.57.183)、CDN旧键CDN_CF_URLS_*、说探针已删(实有lite版)、说relay"不部署"(实在跑)。

**⛔ 按设计移除**:首屏内容接口(featured/recent/categories/tags)实测明文(e8135159撤AES换LCP);guard.lua白名单+Strike封禁2026-04-19起禁用只留限速。

**🟡 外部测不到**:SW降级链运行时故障注入(需DevTools)、WS握手、mTLS Authenticated Origin Pulls(代码无证据文档声称未证实)、Web Push投递、CT监控/注册商2FA(人工)。

验证法可复用:`curl -H "X-Timestamp:$(date +%s%3N)" .../api/v1/settings` → python AES-CBC key=SHA256(MK+str(ts//300000*300000)) iv=SHA256("IV"+MK+str(ts))[:16] 解密拿全config;np2解密 key/iv 用 version 当 ts 同式;seed key=SHA256(MK+"SEED_ENCRYPT") iv=SHA256("SEED_IV"+MK)[:16]。ca-admin SSH用户=ubuntu读不了/proc/environ也连不上DB(密码取不到),走解密settings拿池更省事。

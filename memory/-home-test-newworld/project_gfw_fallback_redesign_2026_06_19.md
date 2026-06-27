---
name: project_gfw_fallback_redesign_2026_06_19
description: GFW fallback 恢复链重设计基线(2026-06-19)+S/P/A三域降级链实测梳理+N_AG复活方案
metadata: 
  node_type: memory
  type: project
  originSessionId: dc257175-09da-48ab-a79a-7e931baf5286
---

2026-06-19 把 GFW"用户当前域被封→恢复访问"的 fallback 系统全面梳理+重设计。**★新会话先读 `docs/sprint/2026-06-19-gfw-fallback-redesign/SESSION-STATE.md`（handoff 锚点：当前确切状态+待办+坑）。** 基线档=`docs/sprint/2026-06-19-gfw-fallback-redesign/DESIGN.md`（已定稿，蓝军审过+Owner 全拍板）。P0 已上线（见 §16 部署日志）：①P0A 非CF腿 N_AG—改 Lambda nw-lambda-rl ORIGINS→CA web 172.34.1.x:7777 走已存在 peering pcx-0580d6e6d520aa3b4(ops 校验 peering/路由/SG 全就位零 infra 改),HMAC(N_AGS)鉴权撤 JWT,e2e 验过;②P0B S edge 探针壳(commit 6e58b6d7)—裸302改探针壳(GET /cdn-cgi/trace 探 CF 通则跳 qm001.<P>/不通跳 /__shell 吐生产 dist 壳),3 edge(usca-1/2/aws-s)全上线+4象限浏览器验过。③WS1 三 region 非CF端点全 LIVE(2026-06-20):HK(d2qou1y0q9→ca-web peering)+CA(66ajwu7jvd us-west-1→ca-web 本region)+EU(q7t4vo1nl2 eu-central-1→eu-web 本region),各打本region内网web,复用 IAM role nw-lambda-rl-role-fz9rw9oi,e2e 403/200 验过。**激活待P1**:N_AG 现仍单值=HK(SW单值读),CA/EU 是建好热备,P1 SW gateway 改多端点数组轮换才接入(现改N_AG为数组会破坏单值SW)。后续 P1 SW简化(删WS/navigate-API分流/wildcard并行波次/N_AG多端点) P2 reachHint。**

**★P1a-mech 已上线验证(2026-06-20,Owner 拍板把 P1 拆两批)**：本批=删 WS 隧道腿(frontend-only,后端 N_RW dormant 保留)+激活 CA/EU 多端点(活的非 CF 逃生腿 HK 单点→HK/CA/EU 三点)。实现:N_AGM 新 system_config 键(逗号分隔 base,HK 首,config_group=gfw/type=STRING)+PUBLIC_CONFIG_KEYS;app-config 优先 N_AGM 回退[N_AG]并发 apiGatewayUrl=首个给老 SW;sw.js tryApiGateway 单端点→Promise.any 多端点竞速(坏响应 401/403/5xx 转 reject 跳坏用好,全坏 reject 被 staggeredRace onFailure 接住)。代码 branch `gfw-fallback-p1a-mech`(commit 9976dcc9,push origin,**未并 master**——Owner「commit 分支」)。蓝军 CLOSE(0 BLOCKER)。部署:DB insert(ca-master→eu-slave)+deploy-web.sh 滚动 6 节点零停机(jar .bak-pre-9976dcc9)+deploy-frontend.sh(version 2347f1c5);验证 /settings 解密 CA+EU 含 N_AGM 3 端点 / deployed sw.js edu-stream-v1+WebSocket=0(WS 删净)/ SW E2E(17.rip)activated+console error=0。**P1b 后做(Owner 定增量非整体替换)**:navigate/API 分流(§4.1,staggeredRace 只在全失败分支加分流,保竞速)+wildcard 并行波次(§4.2)。详见 `docs/sprint/2026-06-19-gfw-fallback-redesign/DESIGN-P1a-mech.md`(§7.1 部署日志+回滚)。验 /settings 解密法:curl 不带 X-Timestamp→响应自带 timestamp,key=SHA256(MK+str(ts//300000*300000)) iv=SHA256("IV"+MK+str(ts))[:16] MK=NewWorld2024SecretKey@AES256!,configs 在 Result.data。**
⚠️坑:aws apigatewayv2 create-api --target 不自动加 Lambda invoke 权限(须手动 add-permission --principal apigateway.amazonaws.com --source-arn <execapi>/*/*,否则 API GW 500+无 log group);VPC Lambda create 后 Pending~60-90s(ENI);Lambda 复用全局 IAM role 跨 region OK。

⚠️部署踩坑(复用):pkill -f 'http.server' 自匹配杀 shell(老坑勿用);edge 壳必拉 ca-web-01 生产 dist(版本一致 a09c788f)非本地 build;部署序先 sync-edge-shell 后 deploy-openresty(MAJOR-3);AWS 用 AWS_PROFILE=nw-dev;sudo cat /proc 非 <重定向。蓝军连揪 lead 漏的 2 真 BLOCKER(探针壳子资源 edge 无 static location→404 / Lua gsub 含%崩)——独立蓝军+lead 二查双层把关救场。

**梳理实测的关键事实（live 验证）**：
- **CF 单一文化=最大短板**：所有存活恢复路径（A域153/P域131/Relay edu.rledumeta.com/WS/DoH发现域/wildcard 子域）**全 CF 代理**(104.21/172.67)。**唯一非 CF 逃生腿 N_AG 已死** → GFW 整段封 CF IP=零逃生（唯一真实"打不开"场景）。
- **N_AG 实测可复活**：API GW `d2qou1y0q9`(nw-ag-rl,ap-east-1)健在 ANY/{proxy+}→Lambda `nw-lambda-rl`(Active,nodejs24,1KB,2026-04-02后没动)；死因=代码硬编码 `ORIGINS=['http://172.31.27.120','172.31.27.121']`(退役HK VPC IP)+VPC锁 vpc-05e20575240422e94(HK)。AWS 访问:`AWS_PROFILE=nw-dev`(账号 748579767645)。
- **P 池=131 全局共享**(category=P purpose=promo active)：edge 落地池 shared:global:p_pool(syncGlobalPPoolRedis)=N_PP(promoDomains)=P_DOMAINS **三方完全一致 131,同源 DB 不漂移**(我曾误判"两池不同",错)。pick-p 按 ISP×省 penalty 加权选。
- **S/P/A 三层降级本质**：S=边缘 VPS(非CF)短链入口 pick-p 择优→302 到 `{渠道}.{P域}`；P/A=同一套客户端代码(sw.js/migrate.js/bootstrap.js)只是吃不同池(apiDomains vs promoDomains)+不同 geo-LB(tcos-canary vs p-lb)。**A/P 不可分开改(同代码同部署)，S 独立**。
- **SW 缓存壳是 returning 用户恢复的支点**：index.html 预缓存+navigate networkFirst 回退→域封时仍能加载壳跑 bootstrap。**冷启用户(无SW)首触被封域=前端彻底无解**(C2 边界)。
- **DoH 只发现不绕 SNI**(蓝军纠偏)：DoH 加密 TXT 只"发现域名",浏览器连接仍走 OS 解析+仍撞 SNI 过滤;防 UDP DNS 劫持+给新鲜域,不绕 SNI。发现≠可用。
- **客户端拿不到自己 ISP/省**→ISP×省可达性只能服务端(IP 解析)算+推 reachHint;DoH 是广播不能 per-client(塞可达性=组合爆炸+撞回 np2 83011/截断,故 np2 不动)。

**锁定决策**：①N_AG 复活=HK↔CA VPC Peering(源站80/443对公网关,Lambda 走内网到 CA web 172.34.x:7777)+us-west-1 第二端点 ②鉴权 HMAC(N_AGS)+rate-limit+s.dat 离线 token(撤 JWT——JWT 取自 CF 域,CF 封时取不到=循环依赖) ③S 探针壳:pick-p 不变+**GET /cdn-cgi/trace**(复用 cdn-failover.js PROBE_PATH,CF 边缘不回源绕 WAF 误判;非 CF 腿用/healthz;必 GET,HEAD 返404)探最优P,通则302/不通则边缘吐极简壳(冷启解) ④reachHint 完整版(服务端派生注入/settings+客户端上报扩 root@/wildcard 字段+本地记忆,只排序不硬跳) ⑤恢复链=RUM 优先并行波次(非串行) ⑥SW 删 WS(同CF Worker无独立价值)+删死N_AG+删per-request多腿竞速+加 navigate/API 分流(API-fail非纯伪命题:缓存壳+DPI专打加密/api+丢包偏大body)。

**分期**：P0A(N_AG复活)+P0B(S edge壳,并行,蓝军 M7 冷启不能等)→P1(SW简化)→P2(reachHint拆3PR灰度)。

**诚实边界**：CF+全AWS非CF IP+全根域+DoH 同时封=无解;冷启+唯一入口(非S)被封=纯Web无解(PWA天花板,真domain-fronting需原生App);AWS execute-api IP 比 CF anycast 更易精准封→非CF腿"概率性"非绝对。

**方法论**：设计 panel(2设计师+蓝军)+蓝军二审方案揪 2 BLOCKER(B1 Lambda 够不到关闭公网的源站 / B2 JWT 循环依赖)均 lead 二查确认成立。owner 直觉(API-fail伪命题/wildcard先试/场景C主力)经 fact-check 半对半需纠正。相关:[[project_gfw_measures_live_audit_2026_06_19]] [[reference_doh_txt_overlength_np1]] [[project_doh_3layer_brokenness_np2_2026_06_18]]

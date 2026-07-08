---
name: project_gfw_p3_n4_remigration_2026_07_01
description: GFW P3 N4 S边缘→NLB-direct 重迁移 — canary(ks001)翻后阿里云拨测CN慢+470ms(丢CN2 GIA)→回退edge→决定edge(CN2)主路+NLB仅failover,迁移暂停（2026-07-02）
metadata: 
  node_type: memory
  type: project
  originSessionId: 5633a1c0-6fb4-42eb-9222-62f1d9199e93
---

GFW reach 剩余 P3 = 重做 N4（S 短链入口 edge→NLB-direct 逃生层迁移）。**footgun 已修**（S 入口端点 InternalSRedirect/InternalPickP 2026-06-29 随 consolidation 合进 master `5ed76306`，工具实测 origin/master 含之 + 部署 web×6 health 200），NLB-direct 可安全重迁。**N4 曾 2026-06-27 全 10 域跑通→06-28 事故回退 edge（别会话从 GFW-free master 重部署抹端点）→06-29 consolidation 修 footgun**。故 P3=重做一次已验证过的迁移。

**★现状（2026-07-01，工具实测）**：
- **canary ks001/mintlab26.cc 已翻 NLB-direct LIVE 全绿**（15:30:38 UTC flip）。其余 9 域仍 edge（302 稳）。
- NLB-direct 基建存活：API `l671tmqge8`（endpoint l671tmqge8.execute-api.us-west-1.amazonaws.com）/ NLB `nw-s-entry-nlb` / TG `nw-s-entry-tg`（ca-web×4 :7777 **4/4 healthy**，TG 健康检查=s-redirect/health）/ VPC Link `25q0uh`。各域独立 custom domain `d-xxx`（mintlab26=`d-hkq2jht8k9`）。
- flip 原语：加显式 `<渠道>.<域>` CNAME→`d-xxx`（**DNS-only proxied=false**，非橙云=抗封 API GW IP）；**回退=删该记录→落回 wildcard→edge（秒）**。CF token=`CF_TOKEN_S`@ca-admin `/etc/newworld/secrets.env`；mintlab26.cc zone=`fe2e59c0db2e8d803d1123d337a8cf01`。

**★canary 重迁移全程（Owner 授权，Canary 先复验 + 现在就翻）**：
1. **dark 端到端复验**：`curl l671tmqge8/health`→200（NLB→web 通）；canary `--connect-to ks001.mintlab26.cc:443:d-hkq2jht8k9...:443`→302（真 Host/SNI，live DNS 未动）。
2. **pre-flip ISP 探针**（硬铁律，apexcorp26 教训：翻前必按 ISP 拨探端点防移动降级）：建 throwaway `probe-nlbchk.mintlab26.cc` CNAME→d-hkq2jht8k9（dark 非真渠道）→等 ~3min→aliyun runner(:3721 POST /probe)ISP cross-tab→**电信53/53 移动43/43 联通39/39=三网100% 首抽干净**→删 throwaway。
3. **flip**（Owner 改主意"现在就翻"不等低峰，因 canary 最低流量 2.8k+秒回退）：加 ks001.mintlab26.cc CNAME→d-hkq2jht8k9（record_id `587ad6e7e8873212c819a88598d02307`=回退 ref）。
4. **验**：ks001 resolves d-hkq2jht8k9 IP(off edge)；US 302 channel 保留；**post-flip aliyun 三网100%**（第一次返0节点=runner 瞬时忙 hiccup，重跑148节点全100%）；web s-redirect 0错误 health200；**API GW 5xx=0.0**。

**★★结论（2026-07-02，canary 观察 = 抓到延迟回归 → 回退 + 定架构）**：Owner 发现 canary 阿里云拨测明显慢，3-agent 团队排查（事实依据）：
- **NLB-direct CN 入口 302 比 edge 慢 +470ms 中位(+64%)，移动最惨 +886ms(+123%)**（aliyun boce 同 ~140 CN 节点 A/B，probe-edge vs probe-nlb 探针子域，取 302 redirectTime）。p90 尾 3.1-3.8s vs edge 0.95-1.2s（尾被 140 节点并发 burst 放大，中位稳健）。
- **根因=换端点丢 CN2 + 加后端往返**（两机制同向）：① edge=搬瓦工/IT7 AS25820 LA 在**中国电信 CN2 GIA 优质线**(CN RTT~130-160ms 高峰稳)；NLB=AWS us-west-1 AS16509 **无 CN2 通用 transit**(~200-280ms 高峰丢包)，每 RTT 差 60-120ms×多往返。② edge openresty 在 LA PoP 本地 lua 出 302；NLB 走 API GW→VPC Link→NLB→web pick-p(in-region ~20ms)+CN↔CA 请求往返。**非 TLS**(Agent 2 排除:两者 TLS1.3/1-RTT/无额外往返;次要尾险=API GW 证书链 2× RSA-2048 8KB vs edge ECDSA 4KB→丢包路径 RTO 尾)。
- **决定=选项3(a)**：**edge(CN2)保持主路、NLB-direct 仅作 edge 被 GFW 封时的 failover 逃生（非永久主路）**。**ks001 已回退 edge**（07:09 UTC 删 CNAME→wildcard→edge,验 67.230.x+302)。**NLB-direct 全量迁移暂停**(不翻其余 8 域,尤其 372k/日旗舰 jade-land)。NLB 基建留 dark 作逃生储备。
- ★教训：**首次 N4 pre-flip 探针只测可达性(success/三网%)不测延迟**→CN2-loss 延迟回归一直在只是没测→canary+观察窗才抓到（canary 正为此）。抗封韧性 vs CN2 延迟是真权衡；要抗封又不丢 CN2 需抗封端点放 CN2-provider(搬瓦工/其它)而非 AWS us-west-1。★旧 POC-FINDINGS "execute-api 比 edge 快" 是 Lambda-近-edge 变体,现 ks001=execapi→NLB→web-backend 反而慢,别混。

**（历史，已作废）★剩余（Owner 曾定 canary 先 bake 观察一窗再续）**：
- **观察点**（下窗/下会话评估）：ks001 的**留存（peer-controlled，admin 看板）/落点分布/持续 4xx-5xx**。技术指标全绿≠不伤漏斗，留存要几小时观察。**确认不伤推广漏斗再翻其余 8 域**（一口气翻完不观察=若伤漏斗全域中招才发现）。
- **剩 8 域待翻**（按流量低→高，jade-land 旗舰最后；每域走 provision检查→pre-flip三网≥95%探针→低峰翻CNAME→验→Owner gate）：lt001/quicktag26(6.2k) · hm001/swiftscope(6.9k) · df001/dawn-leaf(低) · p5mvc/gardensapling(37k) · oyaho/savorycellar(42k) · vupb9/turquoiseblaze(136k) · v6nki/opallode(139k) · pgeqd/jade-land(372k,旗舰末)。
- **gg001/apexcorp26 排除**：移动 SNI 烧 19%（主机名级链路封，换IP救不了，留 execute-api/edge，老书签认损）。
- 批4 edge 退役依赖全量验证，未开始。
- 出口门禁（每域）：CN可达≥老edge、302≥99%、5xx=0、自愈<~8min（删CNAME秒回）。

**运维坑**：aliyun runner :3721 偶返0节点=瞬时忙（3h聚合占）重跑即可，非域故障（0节点≠可达失败，可达失败会返节点带失败码）；rotate-s-entry.sh 缺 --no-wildcard-cname/dark 模式（rebuild 换IP需手动 delete+create-domain-name+mapping 不动 wildcard）。runbook=`docs/sprint/2026-06-21-reachhint-tri-probe/B3-NLB-DIRECT-PLAN.md`(N4跟踪表/pre-flip铁律)+`DEPLOY-RUNBOOK.md`+`agents/ops-nlb-infra.md`(基建ID)。相关 [[project_gfw_s_entry_nlb_handoff_2026_06_28]] [[project_gfw_groupA_dark_deploy_2026_06_26]] [[project_gfw_consolidation_2026_06_29]]。


---
**并入摘要（原 project_gfw_s_entry_nlb_handoff_2026_06_28.md，2026-07-07 memory 整理；全文在 git 历史 claude-shared）**
> ★★ 已闭环(2026-06-29):待决策选 **①** —— S 入口端点(InternalSRedirect/InternalPickP+依赖)已随 GFW **整合并入 master**(`5ed76306`),web 无论从哪部署都带着 → **footgun 根治,NLB-direct 可安全用于重做 N4**。S 当前仍留 edge(本次范围不含 N4 翻流)。详见 [[project_gfw_consolidation_2026_06_29]]。(下文为事故当时状态,保留作历史。)
## ★当前状态(最重要)
- **全部 10 个 S 推广短链已回退 edge,推广恢复中**(edge IP 直连验 10/10 都 302;真 DNS 有 ~5min 缓存尾,自愈)。**这是稳定态,别乱动。**
- **web×6 现 GFW-free**(别会话 06-29 01:59 从 master/fix 重部署),**无 InternalSRedirectController(s-redirect)+ 无 InternalPickPController(pick-p)端点**。
## ★事故根因 + 铁律(核心教训)
## ★待 Owner 拍板(下一步唯一决策)
- **选 ①**:算 → 把这两个 controller(+依赖:DomainPoolService/IspResolver/reach:grid 读等)摘成 GFW-free 子集合进 master → web 无论从哪部署都带着 → NLB-direct 可安全用 → 重新 N4 迁移。
- **选 ②**:不算/嫌麻烦 → S 永久留 edge,放弃 NLB-direct 迁移,清理 execute-api dark 资源。
- **端态 = NLB-direct**:user→API GW custom domain(抗封,DNS-only/dualstack)→VPC Link→内网 NLB(`nw-s-entry-nlb`)→web s-redirect→302。POC + 完整 live 验证全过(R1 真客户端IP经`$context.identity.sourceIp`注入`X-Real-Client-IP`;R2 wildcard Host 透传渠道;延迟≈Lambda 无冷启)。
- **N1**:`InternalSRedirectController`(GET `/api/v1/internal/s-redirect` 302 + `/s-redirect/health`),复用 InternalPickPController 的 pickWithReach;读 X-Real-Client-IP/X-Original-Host/X-Internal-Secret(EDGE_OPS_SECRET)。qa 969 PASS + 蓝军 8 条闭环。在 gfw 分支。
- **N2 基建**(dark,us-west-1):NLB `nw-s-entry-nlb`、VPC Link `25q0uh`、HTTP API **`l671tmqge8`**($default→VPC_LINK→NLB,overwrite:path 重写所有路径到 s-redirect 防暴露 web API 面 + 3 header 映射 + stage var edgeOpsSecret)。
- **pre-flip ISP 探针铁律**:翻任何 S 域前,provision 端点等 ~5min 传播 → aliyun 按 ISP cross-tab 探(全ISP均匀失败=传播未熟等;单ISP=IP被封 rebuild);三网≥95% 才翻。
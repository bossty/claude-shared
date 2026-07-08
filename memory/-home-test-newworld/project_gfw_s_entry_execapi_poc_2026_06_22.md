---
name: project_gfw_s_entry_execapi_poc_2026_06_22
description: "S入口execute-api架构POC全验证(CN v4 99%/v6 97%)+生产化wave1/2/3代码全落地+蓝军复核修3BLOCKER+region选址实测定稿us-west-1加州(S-Lambda→web本地0.2ms vs HK跨洋152.6ms;电信出口在加州;vs现役edge TTFB三网全胜;edge-optimized双输);★保持独立分支gfw-breakthrough-arch,禁合master(master须GFW-free,见[[feedback_feature_branch_deploy_test_then_merge]];我误合22fb37b2已被别会话revert 5b3e01d5),部署走自己runbook owner-gated"
metadata: 
  node_type: memory
  type: project
  originSessionId: 019a2513-f7cc-4759-ad55-7522771891e2
---

> **⚠️ 2026-07-07 状态标注**：「禁合master(master须GFW-free)」已废止：GFW 2026-06-29 已并 master 单基线(5ed76306)。

2026-06-22 GFW突破架构「S入口=execute-api/Lambda(非CF AWS IP)」活体POC全验证通过。实证全文 `docs/sprint/2026-06-21-reachhint-tri-probe/POC-FINDINGS.md`(分支 `gfw-breakthrough-arch`,未合master)。

**核心实证结论(已落档,直接采信勿重证)**:
- **CN可达**(aliyun真浏览器151节点):s-poc HK dualstack `https://.../health` = **IPv4 99% / IPv6 97%**(电信/移动~100,联通95),延迟中位685ms,DNS干净解析真AWS HK段。execute-api非CF AWS IP对CN高可达,架构前提成立。
- **wildcard custom domain**:`*.swiftscope.cc`(根域直属)一域覆盖所有`{渠道}.swiftscope.cc`,Lambda从Host取渠道码(`host.split('.')[0]`),无需每渠道一域。生产真形态已非破坏式验证(curl --resolve,custom domain `d-yz803n56yk`已预置)。
- **证书**:wildcard custom domain **必须ACM自签(import被拒)**;ACM自签对S域要**CAA加amazon**(否则CAA_ERROR);ACM公网证书**免费+13月+全自动续**(`RenewalEligibility:ELIGIBLE`,免acme.sh/cron,前提验证CNAME+amazon CAA长留DNS)。单域可用acme.sh LE import但需每渠道一域不推荐。
- **dualstack**:custom domain + API自身**两处都要设**`IpAddressType=dualstack`(默认ipv4)。
- **region 选址（★2026-06-24 实测定稿 = us-west-1 加州,推翻6-22"HK起步"）**:多源实测(POC-FINDINGS §13全程)——① S-Lambda→web pick-p **加州本地0.2ms vs HK跨洋152.6ms(peering ping实测)** ← 决定性 ② 电信跨太平洋出口本在加州SF/LA(boce.com 自有EC2 traceroute逐跳实锤,execute-api挡ICMP故改追自有EC2开SG ICMP) ③ CN入口腿HK vs 加州**平手**(电信HK240>US172但移动联通HK略优,中位184≈214)。→ **S-Lambda/execute-api 放 us-west-1 挂 ca-web 同VPC(pick-p本地、无需peering)**。逃生跨region用 rotate api-instance --new-region。三诊断坑:CF代理污染拨测(targetIp揭穿测的是CF非AWS)/跨洋RTT必ping实测不凭记忆(152.6ms)/tcptest guest追固定demo(HK==US识破)。edge-optimized(CloudFront)不测。
- **换API实例**=轮换单位(custom domain端点+execute-api+Lambda);半自动+人闸。
- **P0⑧ 换ID换IP逃生假设(2026-06-26实证通过,POC-FINDINGS §14)**:5×us-west-1+2×HK裸execute-api/4resolver dig→3层逃生坐实:①单ID DNS轮转6 IP②换ID几乎不重叠(封ID-A全6IP→换ID-B拿6全新未封,us-west-1跨13个/16段)③跨region段完全不相交。execute-api IP落AWS通用大段(52/54/13/18.x)GFW难无附损整段封=核心优势。rotate-s-entry.sh换ID即换IP自愈机制成立。

**Why**: owner逐项实证驱动,这套结论决定S入口生产形态。
**How to apply**: 生产化按 ARCHITECTURE-FINAL §9.5 + IMPLEMENTATION-ROADMAP批2;拨测用[[feedback_cn_probe_aliyun_realbrowser]];CF记录守[[feedback_cf_dns_ttl_auto]]。关联[[project_gfw_fallback_redesign_2026_06_19]]。

---

**2026-06-23 生产化全落地(wave1/2/3 + 蓝军复核,代码完,未部署)**:
- **wave1(5基础)**:probe富接口GfwProbeClient.probe()+ProbeNode/DomainHealth probe门控/CAA加amazon/s_entry_instance表/InternalApiAuth恒定时间。
- **wave2(5大件)**:web pick-p端点`/api/v1/internal/pick-p`(EDGE_OPS_SECRET守卫,读P池+reach:grid)/AliyunProbeClient+GfwProbeAggregator→reach:grid+headful runner(services/aliyun-probe-runner)/真S-Lambda(aws-lambda/s-entry)/provision+rotate脚本/admin三按钮页。
- **wave3(5消费层)**:IpDbBuilder省ISP多源融合/IspProvinceNormalizer三源归一/reachHint /settings注入(REACH_HINT_ENABLED门控)/A池penalty激活/MAJOR-4探针统一/cdn-cgi/trace。
- **★蓝军复核(wvxqghtbe)抓3 BLOCKER**(部署前未抓=功能上线即死):①**省份格式写读永不命中**(writer剥"省"后缀vs reader留"广东省"→reach:grid HGET永miss→penalty恒0)→修=新`IspProvinceNormalizer.reachGridProvince()`canonical,writer+3readers全过它②**AliyunProbeClient.probe单批60s timeout必超时**→reach:grid永不写→改逐域180s③**writeReachGrid从不写_ANY_**→reader Layer B回落死→补per-isp聚合。+10 MAJOR(checkSecret恒定时间/S-Lambda删503-detail+多URL+@sanitize/拨测扩S+P/runner systemd/rotate重试可重入/nginx限内网)。commit `8470fe02`,全量回归common+web+admin BUILD SUCCESS(admin1988)+Lambda 17/17。
- **关键教训**:见[[feedback_cross_component_key_format_align]]——隔离worktree agent互相看不见→跨件key格式/契约必漂(reachHint数组vs对象、省份带不带后缀),lead二查必逐件核对齐+蓝军专扫+真Redis端到端验penalty生效(防isolated-test假绿)。
- **部署**:`DEPLOY-RUNBOOK.md`组A暗部署(零流量)+组B灰度;剩MINOR/Phase2见`REVIEW-FIXES.md`。owner-gated未部署。

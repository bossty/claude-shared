---
name: project_gfw_s_entry_nlb_handoff_2026_06_28
description: "GFW组B S入口 NLB-direct 全量迁移 + 推广链全挂事故 + 回退edge + 待Owner拍板(S端点能否进master)。新会话 handoff,勿丢"
metadata: 
  node_type: memory
  type: project
  originSessionId: 24c91cd0-2cfc-4a82-a23a-f6d3529ba3bf
---

# GFW 组B S入口 NLB-direct + 推广链事故 handoff(2026-06-28)

> ★★ 已闭环(2026-06-29):待决策选 **①** —— S 入口端点(InternalSRedirect/InternalPickP+依赖)已随 GFW **整合并入 master**(`5ed76306`),web 无论从哪部署都带着 → **footgun 根治,NLB-direct 可安全用于重做 N4**。S 当前仍留 edge(本次范围不含 N4 翻流)。详见 [[project_gfw_consolidation_2026_06_29]]。(下文为事故当时状态,保留作历史。)

## ★当前状态(最重要)
- **全部 10 个 S 推广短链已回退 edge,推广恢复中**(edge IP 直连验 10/10 都 302;真 DNS 有 ~5min 缓存尾,自愈)。**这是稳定态,别乱动。**
- **web×6 现 GFW-free**(别会话 06-29 01:59 从 master/fix 重部署),**无 InternalSRedirectController(s-redirect)+ 无 InternalPickPController(pick-p)端点**。
- execute-api 那套(API `l671tmqge8` + 各域 custom domain `d-xxx` + `s_entry_instance` 表 10 行)**仍在但 dark 无流量**,无害,留着或后续清。
- 主工作树在别会话分支 `fix/latest-updates-snack-slots`;GFW 工作全在 `gfw-breakthrough-arch`(用 worktree 访问,别切主树)。master=GFW-free。

## ★事故根因 + 铁律(核心教训)
**推广链全挂 = 把生产 S 流量耦合到只存在于非-master 分支的依赖。** 昨天 N4 把 10 个 S 域全迁 NLB-direct(依赖 web 的 `InternalSRedirectController`/`InternalPickPController`,这两个是 GFW-W3 端点、只在 gfw 分支)。别会话从 GFW-free 的 master 重部署 web → 端点没了 → 所有 S 域 404 而非 302 = 打不开。Lambda 路径(mwzb77c47a→pick-p)同样死(pick-p 也没了)→ 只有 edge 独立可用。
→ **铁律:`InternalSRedirectController`+`InternalPickPController` 进 master 之前,S 域绝不能放 NLB-direct,必须留 edge。** 否则任何会话从 master 部署 web 就复发。这是 `newworld-dev-workflow` §1b 多会话风险的实例。

## ★待 Owner 拍板(下一步唯一决策)
S 入口端点(s-redirect + pick-p,本身只做 pick-p 选址 + 302,**不含抗封逃生逻辑**)算不算"GFW-free 可入 master 的基础设施"?
- **选 ①**:算 → 把这两个 controller(+依赖:DomainPoolService/IspResolver/reach:grid 读等)摘成 GFW-free 子集合进 master → web 无论从哪部署都带着 → NLB-direct 可安全用 → 重新 N4 迁移。
- **选 ②**:不算/嫌麻烦 → S 永久留 edge,放弃 NLB-direct 迁移,清理 execute-api dark 资源。
（我之前倾向先确认推广恢复,再定;Owner 未拍。）

## 已建成 + 验证过的(若选①复用)
- **端态 = NLB-direct**:user→API GW custom domain(抗封,DNS-only/dualstack)→VPC Link→内网 NLB(`nw-s-entry-nlb`)→web s-redirect→302。POC + 完整 live 验证全过(R1 真客户端IP经`$context.identity.sourceIp`注入`X-Real-Client-IP`;R2 wildcard Host 透传渠道;延迟≈Lambda 无冷启)。
- **N1**:`InternalSRedirectController`(GET `/api/v1/internal/s-redirect` 302 + `/s-redirect/health`),复用 InternalPickPController 的 pickWithReach;读 X-Real-Client-IP/X-Original-Host/X-Internal-Secret(EDGE_OPS_SECRET)。qa 969 PASS + 蓝军 8 条闭环。在 gfw 分支。
- **N2 基建**(dark,us-west-1):NLB `nw-s-entry-nlb`、VPC Link `25q0uh`、HTTP API **`l671tmqge8`**($default→VPC_LINK→NLB,overwrite:path 重写所有路径到 s-redirect 防暴露 web API 面 + 3 header 映射 + stage var edgeOpsSecret)。
- **pre-flip ISP 探针铁律**:翻任何 S 域前,provision 端点等 ~5min 传播 → aliyun 按 ISP cross-tab 探(全ISP均匀失败=传播未熟等;单ISP=IP被封 rebuild);三网≥95% 才翻。
- **AWS**:本地箱 `AWS_PROFILE=nw-dev`(acct 748579767645);CF token `CF_TOKEN_S` 在 ca-admin `/etc/newworld/secrets.env`;aliyun runner ca-admin :3721(常被 3h 聚合占)。

## S域 SNI 烧蚀图(实测,选①翻流量前必看)
仅 **gg001(apexcorp26)移动 SNI 烧 19%**(主机名被烧,换IP/换域都救不了,老书签认损);其余 9 个移动 90-100% 健康。SNI 烧=FQDN级链路封,与落点IP无关;IP抽签是另一回事(rebuild 可重抽干净IP)。

## S 冷启逃离(回访救援,backlog)
逃离载体=**Service Worker(免安装,CN 可用),非 PWA 安装(CN 装不了)**。durable 回访入口必须是**带 SW 的 P/A 落地域**,不是无 SW 的 S 短链(纯302无SW)。微信内置浏览器=无解尾部。SW 覆盖率埋点缺口(待补 `navigator.serviceWorker.controller` beacon)。详见 GFW-BACKLOG.md。

## 10 个 S 域 ↔ 渠道
dawn-leaf.com/df001 · apexcorp26.com/gg001(烧) · mintlab26.cc/ks001 · quicktag26.com/lt001 · swiftscope.cc/hm001 · gardensapling.com/p5mvc · savorycellar.com/oyaho · turquoiseblaze.com/vupb9 · opallode.com/v6nki · jade-land.com/pgeqd(旗舰)。回退法=删显式 `<渠道>.<域>` CNAME→落回 wildcard→edge(67.230.161.24/.182.105/95.40.168.207)。

## 文档(都在 gfw-breakthrough-arch 分支,用 worktree 看)
`docs/sprint/2026-06-21-reachhint-tri-probe/`:ARCHITECTURE-FINAL / DEPLOY-RUNBOOK / NLB-DIRECT-POC-PLAN / B1-PLAYBOOK-dawn-leaf / **B3-NLB-DIRECT-PLAN**(N4 跟踪表 + SNI烧蚀 + 回访救援) / GFW-BACKLOG。

## 本会话另一产出(已落 master,无关 S 事故)
`newworld-dev-workflow` skill 固化(home + plugin v0.1.7,master `a170f95f`)+ dev/qa agent 加 `isolation:worktree`。承 [[project_master_degfw_deploy_baseline_2026_06_26]]。

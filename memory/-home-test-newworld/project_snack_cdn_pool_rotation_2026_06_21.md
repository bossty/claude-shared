---
name: project_snack_cdn_pool_rotation_2026_06_21
description: per-bucket独立CDN域池通用一键轮换sprint(2026-06-21)—代码已写未执行;RCA=snack 95%CN fail根因CF单一文化(50域5apex全Cloudflare);CdnPoolRotationService零停机轮换;待Owner买5新域+执行
metadata: 
  node_type: memory
  type: project
  originSessionId: 85dc3fe1-5403-474d-941b-c0f0f36ee859
---

2026-06-21 sprint：**per-bucket 独立 CDN 域池「通用一键轮换」**。★**代码已写+蓝军过+测试绿,但今晚 Owner 明令只写不执行**——未调 CF、未注册域名、未改 R_SNACK、未部署。执行留 Owner 另令。

**RCA（触发）**：告警 `stats-v7-redirect-trace-cdn-fail` 长期 95-97%（7 天平，非回归）。根因=**snack(广告图)CDN CN 跨洋大面积失败**。深挖：R_SNACK = 50 域 = 5 apex（assetlibs/imgedustock/node-sync/previewedu/stream-lesson）× 10 sub，**5 apex 全在 Cloudflare**（NS=*.ns.cloudflare.com，IP=104.26.x/172.67.x 实证）。**名义 5 域实为 1 个 CDN（CF 单一文化）**——failover 在 5 apex 间切逃不出 CF，CN 够不到 CF 边缘就全垮。图本身正常（CA 实测 200+真实字节）。这是项目核心短板 [[project_gfw_fallback_redesign_2026_06_19]] 的具体落点。**假设：现 snack 域 SNI 被烧（A 类内容域走 tunnel/LB 对 CN 通，snack 走 direct-R2-via-CF 另一条路全垮）→ 换新 SNI 可绕（执行前可 CN 实证 SNI-vs-IP 级）。**

**新架构**：每 bucket（video/image/preview/asset）用**自己独立的 root 池**（隔离爆炸半径 + 可独立轮换）。现状是 4 bucket 共享同 5 root。

**已实现（分支 `gfw-entry-recovery-arch`，commit 521c927d + d374e344，⚠️非 master——工作目录被并发会话切到该分支）**：
- `sql/v41_domain_cdn_bucket.sql`：domain 加 `cdn_bucket` 列（标记 root 专属 bucket，幂等守卫）。
- `Domain.cdnBucket` 字段。
- `CloudflareApiService.unbindR2CustomDomain(bucket,host)`：R2 DELETE custom domain（复用 cfDelete，404 幂等返 true）。
- `CdnPoolRotationService.rotate(bucketInput,newRoots,subPerRoot,dryRun)`：通用 bucket 参数化轮换。**零停机顺序**=bind 新→retire 旧(active→retired)→swap R_X config(updateValue 自动 bump SYSTEM_VERSION)→unbind 旧。复用 cdn_prefix 表 SOT + CdnPrefixExpandService 随机 prefix。dryRun=true 默认安全。每 root 配 cache+CAA+DNSSEC。
- `CdnPoolRotationController` POST `/api/v1/internal/cdn-pool/rotate`（X-Internal-Secret，dryRun=true 默认）。
- 单测 9/9 + 全 admin 1864 绿。

**Owner 定参数**：每 root **5 sub**、每次 **5 root**（=25 新自定义域）。D1=加 cdn_bucket 列；D2=退役连 R2 unbind（**CF R2 上限实证 100/bucket** 非 50，bucket-asset 现 50 有 50 头寸→可 bind 新先于 unbind 旧零停机）；D3=HRW_K=10 保持（25≥10）。

**蓝军 Round-1**：6 条（lead 二查：F1 部分bind中止/F3 unbind404幂等/F4 InOrder含mapper/F5 CAA+DNSSEC/F6 防撞集含retired 都改；**F2 retire乐观锁混入=误报**，upd=0⟺非active⟺buildCsv本就排除）。详见 sprint DESIGN §7.1 + agents/reviewer.md。

**★Owner 加码"含购买的一键"已做（commit eb20d8a8 + 8cbc2ed0）**：买域+NS传播本质异步→job表+scheduler驱动。
- **方案1**：`DomainLifecycleService` onboarding 对 `cdn_bucket` 非空域**跳过旧 `bindCdnDomainToR2`(4-bucket固定前缀自动绑)**（否则新snack专属域被绑给全4bucket破坏隔离），只配zone/CAA/DNSSEC+active；R2-F3 修复=onNsActive selectById 重读 DB cdn_bucket 防 stale。**顺带**：旧 onboarding 调旧 4 固定前缀版≠生产 V7C1 10 随机版，方案1 已让专属域绕过它（共享老域路径不变，stale 仍独立 backlog）。
- `CdnPoolProvisionRotateService.start(bucket,count,subPerRoot,dryRun)`：dryRun默认；真跑=`purchaseCdnDomain(count)`买N个B-cdn→标cdn_bucket→建job(waiting_active)。**R2-F4 去重**：同bucket已有in-flight job则拒(防双买)。
- `CdnPoolRotateJobScheduler`(@Scheduled 5min+@ConditionalOnProperty)→`advanceWaitingJobs`：域全active→rotate→done；6h超时→failed；**R2-F2 detectStuckRotating**：rotating>30min→failed+Telegram(防admin中途崩卡死)。
- `CdnPoolProvisionRotateController` POST `/api/v1/internal/cdn-pool/provision-rotate`(dryRun=true默认)+GET`/status/{jobId}`；R2-F5：secret默认changeme启动WARN，prod须systemd设NW_INTERNAL_API_SECRET。
- v42 `cdn_pool_rotate_job` 表+实体/mapper。蓝军 Round-2 7条(F1并入F3/F7非问题,余5改)；CdnPool 18/18+全admin 1878绿。

**一键执行（Owner 另令，dryRun=false）**：`POST provision-rotate bucket=asset count=5 subPerRoot=5 dryRun=false` → 后台买5域→标snack→等active(NS传播)→自动rotate → GET status 看进度 → 观察 cdn-fail 率降。**无需 CF purge**(新自定义域front同R2 bucket)。执行前可 CN 实证 SNI-burn 假设。设计 `docs/sprint/_archive/2026-06-21-snack-cdn-domain-rotation/DESIGN.md`(§5.5 连买带轮换+§7.1/7.2 两轮蓝军)。

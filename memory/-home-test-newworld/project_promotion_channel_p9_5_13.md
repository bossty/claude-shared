---
name: project_promotion_channel_p9_5_13
description: 2026-05-13 P9 推广渠道全栈 audit + gg001 修真打通 sprint（Bug A/B/C/D 链 + 状态机修 + 架构去 SSH 依赖）
metadata: 
  node_type: memory
  type: project
  originSessionId: adb1f688-d97a-4e1e-864e-8c03115531ef
---

# 推广渠道 P9 sprint（5/13 完成）

## owner 触发问题（5/13）
1. admin 推广渠道页面各操作是否真跑通
2. 新增渠道是否自动购 S + 配 DNS + cert + 立即可用
3. 现有 8 渠道 S 域是否都配好（特别 gg001 owner 记得失败过）
4. 2 reserved 状态域名修法
5. owner 主张："gg001 已全部打通过"

## 5 P8 并行 audit（A/B/C/D/E）
- **A 前端**: ChannelList.vue 14 操作 12 ✅ + 2 ⚠️（**P0 文案"P 类"→"S 域" W13 hotfix 漏改前端**）
- **B 完整 a-g 链路**: 新建链路只 reserve standby + acme + reload + activate，**不重跑 a-c（NameSilo/DNS/DNSSEC）也无 g E2E smoke**——4.5/7 自动化
- **C 8 渠道 3 路 cross-check**: 6 production-ready 302 + 1 sentinel + **1 gg001 fail (TLS 000)**
- **D gg001 深挖**: domain 140 apexcorp26.com status=purchase_orphan / job 2 retry=4 卡 bad_pem
- **E 2 reserved 域实证**: dawn-leaf.com (ch_id=16 orphan) + apexcorp26.com (gg001 的 S 域)

## P0 修（3 项立即）
- ✅ dawn-leaf orphan 清理: domain.status=retired + binding.retired_at + job.failed
- ✅ ChannelList.vue:138 文案 "P 类"→"S 域推广链接"（commit 8424c5f4）
- ⏳ gg001 retry 暴露**4 个真 bug** ↓

## Bug 链（4 个串联真 bug）

**蓝军 a29599b 反证 owner 印象**：domain_provision_job 全表只 2 行（gg001 是**首个走新架构渠道**），6 prod 渠道是 pre-job 时代手动 grandfathered legacy（cert 在 disk → W14-S5 5/8 改名 `.bak.no-disk` 切到 cert_blob）。owner "全部打通过"印象来自 phase2 acme step once succeeded log 误记。

### Bug A — cert handoff 断（commit b8c346f3）
runReloadStep 调 pushDomainToEdge **传 null PEM**（cert 没从 cert_blob 取），admin L205-208 guard return `bad_pem httpStatus=0 attempts=0` edge 根本没被调用。
- 修: ChannelLifecycleService.runReloadStep 加 certBlobMapper.findByDomain + isNotBlank guard

### Bug B — 新建 flow 缺 DNS step（commit b8c346f3）
6 prod 域 wildcard A 是 grandfathered legacy（手动建），新 flow 不调 activateShortLinkDomain（只 rotate 链路调）。apexcorp26.com 无 DNS A/AAAA。
- 修: ChannelLifecycleService createChannelPhase2WithJob 加 runDnsStep 在 acme **之前** + DomainLifecycleService 提炼 public ensureWildcardDnsRecords（refactor reuse 新建+rotate 双链路）

### Bug C — runAcmeStep 不写 cert_blob（commit ea7783db）
runAcmeStep 调 acmeShService.issueCertOnAllEdges (SSH edge 签 cert) **不写 cert_blob**，Bug A guard 后续 findByDomain 必失败。
- 修: 改调 AcmeCentralService.signCentral(domain, [apex, "*."+apex]) 双 SAN 中央签 + UPSERT cert_blob + 保留 acmeShService 作 fallback

### Bug D — push io_err + 状态机（commit b9787ac6）
蓝军 ac46f86 反证：D-1 误判（cert_blob `uk_domain` 单行 PEM 内含双 SAN 是设计）；D-2 admin→edge hostname SNI 与 edge cert FQDN 失配 → TLS alert internal_error；D-3 retry exhausted pending 滞留。**cert_pull_agent.lua 5869 lines 实证真在跑** → W14-S5 设计本意 = cert_blob + edge poll。
- **owner 架构铁律：整体架构不依赖 SSH**
- 修 1: runReloadStep **删 pushDomainToEdge** 改 verify-only（cert_blob.findByDomain + isNotBlank + markStepDone）依赖 cert_pull_agent.lua 5min poll
- 修 2: runAcmeStep 强制 central（acmeCentralService==null → IllegalStateException，删 acmeShService fallback）
- 修 3: handleProvisioningExhaustion 状态机 writeDomainTerminalForPermanentFailure（namesilo_done=true → purchase_orphan / 否则 provisioning_failed）

### happy path 状态机修（commit ebb50596）
Bug D 只修 retry exhausted 路径，**happy path 4 flag 全 done 但 status pending 滞留** → OrphanChannelDetector 误 spam。
- 修: DomainProvisionJobMapper.markJobDone (SQL guard `WHERE status='pending' AND 4 flag 全=1`) + ChannelLifecycleService.finalize 调用

## gg001 真打通终验
- DNS test1.apexcorp26.com A: 67.230.161.24 / 95.40.168.207 / 67.230.182.105（3 edge IP）
- **TLS test1: 302 / 0.69s**（TLSv1.3 + subject CN=apexcorp26.com）
- job 2 status: done / 4 flag 全 1
- domain 140 status: active
- OrphanChannelDetector total=8 orphan=0（spam 止）

## 6 production-ready 渠道（grandfathered legacy）
hm001/qm001/jd001/ah001/hl001/yt001 全 302。pre-job 时代手动建 + W14-S5 (5/8) cert disk→blob 切换后 .bak.no-disk 保留 disk 副本。

## 教训 1-10

1. **架构铁律：不依赖 SSH**（owner 5/13 拍板）—— admin 与 edge 完全解耦，cert 走 cert_blob → cert_pull_agent.lua poll 模式。**How to apply**：未来 admin→edge 通信优先考虑 DB-as-message-bus / poll 模式，禁 SSH/HTTP push（除非 fallback）。
2. **owner 印象"已打通过"必 SQL 实证**：5/13 蓝军 ac46f86/a29599b 反证 domain_provision_job 全表只 2 行 + 6 prod 是 grandfathered legacy 路径。**How to apply**：用户主观"X 打通过"判断必 grep + SQL + history 实证；6 prod 渠道存活不等于"new flow 打通过"。
3. **sprint scope creep**：P8 a74df6f 顺手改 newworld-data 4 文件（xvideos/hanime1）不在 Bug D plan。**How to apply**：deploy P8 commit 必显式 add 文件名清单，禁 `git add -A`；P9 prompt 必明确 "WHERE 文件域"约束。
4. **commit message 误导**：owner 在另一会话顺手 commit b9787ac6 含 Bug D + hanime1-cron 双 sprint 改动，message 只描述 hanime1。**How to apply**：P9 接力会话先 `git log -1 --stat` 验真实改动文件清单，不信 commit message。
5. **happy path 状态机容易漏**：Bug D 改了 retry exhausted 转 purchase_orphan/provisioning_failed，但 happy path 4 flag 全 done → status='done' 没修，导致 OrphanChannelDetector spam。**How to apply**：状态机改动必 cover **happy + retry + exhausted + edge case** 四类路径，不能只测异常路径。
6. **cert_blob `uk_domain` 单行 PEM 含多 SAN 是设计**：openssl x509 -text 看 SAN 真含 `DNS:apex + DNS:*.apex` 双值。**P9 误判"缺 wildcard 行"被蓝军反证**。**How to apply**：DB schema "缺 row"判定前必 openssl/dig 解码 PEM/DNS 看真值。
7. **多 P8 串行修真 bug 比一次性方案稳**：本 sprint 修 4 个 bug（A→B→C→D）通过实际 retry gg001 逐个暴露。一次性"修所有可能 bug"不知道有 4 个串联。**How to apply**：复杂系统 phase2/job-driven 流程修复必"修 → 触发 → 暴露下个 → 修 → ..."迭代式。
8. **`cert_pull_agent.lua` 5869 log lines = 设计真在跑** + **W14-S5 5/8 cert disk→blob 切换是关键架构事件**。**How to apply**：grep edge log 看 N lines 数判设计组件是否真活在跑（≠ 配置里有 component 字段）。
9. **SNI 配错独立于 push 链路**：admin→edge hostname (`usca-1`) 做 SNI 与 edge cert FQDN 失配 → TLS alert internal_error。即使 push 路径恢复，也得修 SNI 或 skip SNI verify。**How to apply**：用 hostname 做 admin→edge 通信但 edge cert 签业务 FQDN 是常见反模式，预防：用 internal-secret HTTP header + 0.0.0.0 SNI / 显式 SslParameters.setServerNames。
10. **诊断 agent 中流断流 + verifier 接力 + P9 必 cross-check**：本 sprint 多次 P8 长任务 60+ tool uses 后断流，verifier 5 tool uses 真做完。**How to apply**：长任务派 P8 → 死后派轻量 verifier 接力（5 tool budget）专跑 mvn + 关键 grep + report。P9 必 cross-check P8 自报数字（git status + git log -1 --stat 实证）。

## 收尾 2 commit（5/13 闭环）

### avgPv 公式修（commit 094c8dd9）
owner 触发：admin "推广分析" gg001 显示 PV=7 UV=1 **avgPv=2**，数学不对（7/1=7 ≠ 2）。

P8 实证根因：旧公式 `avgPv = total_pages / uv`，**字段名误读**：
- `pv` = 每请求计 1（前端每 router 切换实时 fetch POST `recordPage`）
- `total_pages` = session 累计页（sendBeacon `recordSession` pagehide 上报，**经常被浏览器 ABORT 丢包**——5/12 P8-E E2E 实证 ERR_ABORTED）
- gg001 SDS: `pv=7 / total_pages=2 / uv=1 → avgPv=2/1=2`（公式对，但 total_pages 远低于 pv）

修：AnalyticsV4Service.java 3 处 (L171/196/217) `divFloat(totalPages, uv)` → `divFloat(pv, uv)` + javadoc L36 同步。owner "人均数据差"系统性 bias 根因（所有 channel `total_pages` 丢包导致 avgPv 偏小）一次性修。

**注意副作用**：dashboard 所有 channel 人均 PV 数字会**同时上升**（pv > total_pages bias 全栈修正）。

### MovieServiceImplTest dust 清理（commit 3fd4b67a）
pre-existing dust：`findByPage` 签名 9 → 12 args（新增 status / source / hasPreview），test 调用没跟，阻塞 newworld-admin mvn test 编译。

修：MovieServiceImplTest.java:275 补齐 3 个 `any()` 参数。

**mvn 全栈恢复**：common 432 + web 614 + admin 1791 = **2837 / 0F / 0E / 8 Skip** BUILD SUCCESS。

### 新教训 11-12

11. **session-level sendBeacon 上报字段普遍不可信**：pagehide/unload 时 sendBeacon 经常 ABORT（浏览器主动断），导致 `total_pages` / `total_watch_sec` / `total_browse_sec` 等 session 累加字段实际落库量 << 用户行为真实量。**How to apply**：dashboard 公式优先用 **request-level 实时 fetch** 字段（pv / 等），避免 session-level sendBeacon 字段。session 字段适合"行为深度"但需明示丢包 bias。
12. **dashboard 公式 javadoc 与字段名误导**：旧 javadoc L36 `avgPv = totalPages / uv` 看起来"对"——但 totalPages 是 session 累计页非 PV 总数。**How to apply**：公式 javadoc 必含字段语义说明（"totalPages = session 累计页，sendBeacon 上报可能丢包；pv = request 总数实时 fetch 准确"），让后人改公式前明白权衡。

## 待办 backlog（owner 拍板时机）

- **total_pages 字段死代码清理**（owner 拍板"不需要"）：4 层删（前端 sendBeacon pages + 后端 SessionDto.pages + Redis stats:pages INCR + SDS.total_pages column）— 独立 1-2h sprint
- **新建渠道 E2E smoke test**：DONE 判据应"真打 TLS 200"而非"4 flag 全 true"（蓝军 a29599b 提）
- **writeClusterRootKey flag flip 全量** + 删 raw 分支 grandfathered legacy 代码（V6 stats audit 待办）
- **ChannelList 死代码清理**：PromotionChannelController.addChannel dead path + handleAdd vue 死 UI（P8-A audit 发现）
- **删 EdgeSyncService.pushDomainToEdge 调用**链路彻底（架构铁律：不依赖 SSH，push 路径已不再被 ChannelLifecycle 用）
- **OrphanChannelDetector gg001 cosmetic 假告警**：gg001 真打通 (TLS 302 + cert + DNS) 但 detector 仍报"no active S domain"，判定字段错位待修

## 5/13 下半场 avgPv sprint（commits 094c8dd9 / 3fd4b67a / 9013c5ce）

owner 触发：admin 推广分析 gg001 显示 PV=7 UV=1 **avgPv=2**（数学不对，7/1 应=7）。

### 真根因链（多 P8 reverse engineer 才揭穿）
1. **公式语义错位**：旧公式 `avgPv = total_pages / uv`，字段名误读
   - `pv` = 每请求计 1（前端 router 切换实时 fetch POST）—— PV 真总数
   - `total_pages` = session 累计页（sendBeacon pagehide 上报，**经常 ABORT 丢包**——5/12 P8-E 实证 ERR_ABORTED）
   - gg001 SDS: pv=7 / total_pages=2 / uv=1 → 旧 avgPv=2/1=2（数学对，但 total_pages 远低于 pv）
2. **commit 094c8dd9** 改公式 `total_pages/uv → pv/uv`（5/13 owner 拍板）
3. **deploy 时序 bug**：commit 已 push，但 ae59b11 部署 P8 当时 mvn package 没含新改动（14:52 build jar 仍跑老公式 `divFloat(total_pages, uv)`）—— 直到 a09c9ed 1-shot debug + ad1b2d0 干净 redeploy `git reset --hard origin/master + mvn clean package` 才真上线
4. **全栈覆盖审计** (a1fd8e3 P8)：avgPv 后端 5 处 (V4Service ×3 + AnalyticsService L372 + retAvgPv L385) + 前端 5 个 Vue (Overview / Retention / Promotion / TrendChart) 全透传 metrics.avgPv，**新公式 100% 覆盖**
5. **avgPages dust** 残留：AnalyticsService L248/256 + ChannelAnalyticsService L222/L387 4 处算 `total_pages/uv`，前端 0 展示 → 后端 dust 字段可清债

### 教训 11-15（avgPv sprint）

11. **mvn package 与 git pull 时序问题**：`git pull origin master + mvn package` 这种 deploy 路径有 race 可能 — 如 git pull 时本地 `target/` 内已有旧 class 缓存，mvn 增量编译不识别新源码改动。**How to apply**：高敏感 fix 必用 `mvn clean package`（强制清 target/）+ `git reset --hard origin/master`（不接受本地 stale）。debug 时 `javap -p -c` 字节码直接对比 source 找 build-source 漂移。
12. **多 P8 audit 找不到真凶时 1-shot debug log 一锤定音**：本 sprint avgPv 排查派 10+ P8 (grep / javap / mapper / entity / resultMap / cache / endpoint curl) 都说"代码 OK"，但 endpoint 仍返旧值。最终 a09c9ed 加 1 行 `log.info` 在 metricsFromPromoRow L217 后 → 实证 method 内 avgPv=7 但 endpoint 返 2 → 锁定 deploy 漂移。**How to apply**：长 sprint 排查 ≥ 5 P8 无果时立即 1-shot debug log（加日志 + clean deploy + retry + journalctl），胜过 grep / javap 100 次推理。
13. **dashboard 字段名误读必须实证字段值数据流**：avgPv 看似简单 PV/UV 但实际后端字段 `total_pages` ≠ `pv` 语义。**How to apply**：dashboard 公式 javadoc 必含每字段语义说明（"pv = request 总数实时 fetch / total_pages = session 累计页 sendBeacon 丢包 bias"），让后人改公式前明白权衡。
14. **session-level sendBeacon 上报字段普遍不可信**：pagehide/unload 时 sendBeacon 经常 ABORT，`total_pages` / `total_watch_sec` / `total_browse_sec` 等 session 累加字段实际落库量 << 用户行为真实量。**How to apply**：dashboard 公式优先用 **request-level 实时 fetch** 字段（pv / 等），避免 session-level sendBeacon 字段做分子分母。
15. **后端 dust 字段独立清债**：本 sprint avgPages 4 处后端产出但前端 0 展示。owner 拍"不要"后可独立 sprint 删（前端 sendBeacon pages 字段 + 后端 SessionDto.pages + Redis stats:pages INCR + SDS.total_pages column）。**How to apply**：sprint 关注业务可见的指标，不动 dust 字段；专门排"清债 sprint"批量处理 dust，避免主线 sprint 范围漂移。

## 相关 memory
- [[project_v6_cluster_root_sprint_5_12.md]] — 上 sprint V6 cluster_root + audit 批次 A/B
- [[project_w14_wildcard_sprint.md]] — W14 wildcard 入口 + S 域 standby/active（5/9 #18 grandfathered legacy 36 历史域）+ W14-S5 (5/8) cert disk→blob 切换
- [[project_v6_d_track.md]] — V6 D 档 HD2 visitor_alias + HD8 acme 双签
- [[feedback_audit_methodology.md]] — 10 条蓝军/审计 agent 铁律

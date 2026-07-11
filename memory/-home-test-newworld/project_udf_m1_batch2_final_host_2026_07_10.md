---
name: project_udf_m1_batch2_final_host_2026_07_10
description: UDF 审计 Batch2（M1 SW 逃生 final-host 二次排除）已修复+真浏览器红绿双证+部署6节点+合master。含可复用的 e2e harness RED/GREEN 手法。
metadata: 
  node_type: memory
  type: project
  originSessionId: d6052243-445f-4625-8714-97495e73ff21
---

**UDF 统一域名失败转移 · 审计 AUDIT-2026-07-10 Batch2 = M1（SW 逃生 final-host 排除）** —— 2026-07-10 完成并合 master、部署 6 web 节点。

## 缺陷与修复
- **M1**：SW 逃生候选构造（`pool-redirect.js` `buildWave1bCandidates` / `sw.js` `buildPoolRedirectSiblings`）排除判据停在**裸 host**（`host===currentHostname`）。域池恒含当前 apex；裸 apex 被当前 channel 前缀注入后重构回当前死 host（`dead.example.com`+current `qm001.dead.example.com`→`qm001.dead.example.com`），channel-applied 后**无二次排除** → 死当前 host 当逃生候选，偷探测预算（根级封锁下死 host 排首位可致逃生完全失败）。
- **修复**：`applyChannelToSibling` 后加 `if(applied===currentHostname)continue`，两处逐字同步。**merge master `7cf09882`**（分支 `fix/udf-audit-batch2-m1`，部署产物 `eb1e93ae`）。3 commit：fix(+50/-2)、e2e harness、buyvm evidence。

## 验证（关键：证据链）
- 逻辑层：vitest 全量 **1309/1309** + `pool-redirect` 76/76 + parity（从真 `sw.js` 源码抽取执行，守两份漂移）。
- **真浏览器 e2e 红绿双证**：复用 `frontend-web/scripts/m1-probe-target-e2e.mjs`（P0 逃生同款 `--host-resolver-rules`+自签证书 https-origin+xvfb-headful 真 Chromium，无 iptables/sudo）。加 1 CASE + `SW_PATH` env 覆盖：
  - **RED/GREEN 同 harness 手法**：`SW_PATH=<master 未修复 sw.js>` 跑 RED、默认（修复版）跑 GREEN。
  - **核心断言 = `currentTraceHits===0`**：把「重构回的死 host」精确映射回 current 服务器，该服务器对 `/cdn-cgi/trace` 记数并 RST；修复后死 host 根本没被构造/探测 → current 服务器零命中。旧码探它 → currentTraceHits=1（deadHost LEAK）。比只看 302 落点更能坐实「根本没被探」（因两者最终都可能落到真 sibling，唯一区别是有没有偷探测槽位）。
  - **沙箱 + buyvm-data 干净机双环境结论逐字一致**（排除环境假象）。buyvm turnkey：`~/m1-probe/run-m1-buyvm.sh`（cert 已备、`NODE_PATH=/opt/javxx-m3u8/node_modules`、DISPLAY=:103、playwright 1.61.1）。
  - **WebKit ENV-LIMITED**：`--host-resolver-rules` 是 Chromium 专有 switch，harness 无等价 → Safari 覆盖靠单测 parity + 未来灰度 iOS 真机（同 P0「门①CDP+门②iOS 真机分工」）。**本修复无 UI 改动，不触发 4 象限视觉验证**（那是部署健康烟测、非逃生链证明）。
- 部署 6 节点：sw.js **SHA256 全等且==本地 build 产物**（obfuscator 变量重命名致源码级 grep 失效→改哈希比对更可靠）、version.js 一致 `a2a6477d`、种子同步、Chromium PC+Mobile 烟测 ok、19:06 HK 峰窗前收尾。证据 `docs/sprint/2026-07-06-unified-domain-failover/evidence/M1-BATCH2-E2E-RESULT.md` + 6 log。

## 审计三批状态
- Batch1（后端 M2/A-1/A-2+doc）已合 `2dd9e726`。**Batch2（M1 本条）已合 `7cf09882`+部署**。**Batch3（M3 pick-p 迁 web 后 N9E 108 监控失明，ops）仍 backlog**（改 N9E 108 盯 web http_server_requests 失败率 + edge categraf 增采 `:81/__pick_stats`，需 Owner+谨慎动监控）。C-2 ccTLD 护栏 / G-2 staggeredRace 降量待 Owner 拍板。

相关：[[reference_sw_lifecycle_escape_testing]]（SW 改动测试铁律，本条是其 harness 的一次成功复用）、[[reference_deadroots_sample_gate_implicit_contract]]、[[feedback_feature_branch_deploy_test_then_merge]]。审计台账 `docs/sprint/2026-07-06-unified-domain-failover/AUDIT-2026-07-10.md`。

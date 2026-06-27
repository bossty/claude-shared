---
name: project-region-readiness-gate-2026-06-08
description: "region 上线\"与 HK 行为对等\"就绪门禁脚本已建并接入 deploy runbook Step 2.6"
metadata: 
  node_type: memory
  type: project
  originSessionId: 64b5f5d1-9590-4971-9f5b-8d2e351a83eb
---

Sprint `nw-region-p1`（2026-06-08）产出 region 放量前"与 HK 行为对等"就绪门禁，防再发"切了才发现没准备好"元失败（fullcut-5xx upstream 写死 HK / 第二次 cache-miss 571ms 两次同根）。

**可执行物（已写码+测试，未部署/未切流）**：
- `scripts/region-readiness-gate.sh` — 运行时对等门禁 G0-G7（纯只读 SSH 断言，零 DNS-write）：G0 warm gate(exit2 防冷启误判) / G1 upstream 本地 primary / G2 读路径指本地 replica(读写分离:查 SPRING_DATASOURCE_SLAVE_URL 指本地+established→replica，**不是** DB_HOST!=HK——master 合法留 HK) / G3 cache-miss 冷端点 RTT≈HK(★关键探针,p50 配对实测,RED if region_p50>max(HK_p50×3,50ms)) / G4 serving 对等 / G5 容量(G5_ENFORCE_HA=0 终态前仅 WARN) / G7 origin 5xx 绝对数(结构正则 `" 5[0-9][0-9] [0-9]` 锚 status 列,非扫全行). 退出码 0/1/2.
- `scripts/check-region-read-routing.sh` — 合并读写路由静态闸：写规则委托复用 `check-no-sync-master-write.sh`(不复制 allowlist)，读规则=未标 readOnly/@Cacheable 且非 @Async/@Scheduled 的 GET 读 fail；pollution guard 检测假豁免文本→exit3 拒继承污染；`@RegionReadAllowed(理由)` 豁免。
- `scripts/tests/test_region_gate.sh` — 21 用例全绿，shellcheck clean。
- 接入 `newworld-deploy-runbook` skill **Step 2.6**（切 DNS 前必跑两脚本）。

**判据铁律**：看绝对数不看 rate（分母稀释陷阱）；回滚触发只认 origin 5xx + cache-miss RTT，不用被污染客户端 api_fail；G3 RTT 现象是权威 mechanism-agnostic 判据（[[feedback_verify_not_recall]] 锚现象不锚机制）。

真 region 节点：`aws-region-us`(replica 172.32.9.19)/`aws-region-eu`(172.33.8.248) ssh 别名；终态拓扑加 us-west-1×2(加州,172.34/16)见 FINAL-ARCHITECTURE-CONSENSUS。

设计全文 `docs/sprint/2026-06-08-region-final-migration/READINESS-GATE-DESIGN.md`。skill 候选 `newworld-region-cutover-readiness-gate`（待 lead 验收后沉淀）。关联 [[project_region_cutover_false_alarm_2026_06_08]] [[project_fullcut_5xx_rca_2026_06_06]]。

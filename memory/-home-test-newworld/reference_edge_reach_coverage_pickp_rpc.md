---
name: reference_edge_reach_coverage_pickp_rpc
description: edge nginx 如何用 reach 健康数据(pick-p RPC 5阶段) + ~4-9% RPC超时落非reach snapshot缺口 + 做到100%需GeoIP上edge(backlog)
metadata: 
  node_type: memory
  type: reference
  originSessionId: 5633a1c0-6fb4-42eb-9222-62f1d9199e93
---

**edge openresty S 短链入口（`short_redirect.lua` v3_check_and_redirect）如何用 reach:grid 健康数据选 P 落地域**（2026-07-02 工具实测）：

**5 阶段选址**：Step1 `/16` shared_dict 缓存(TTL 30s) → **Step2 调 admin `/api/v1/internal/ops/pick-p` RPC**(reach-aware,`OPS_PICKP_REACH_ENABLED=true`,读 reach:grid,`effective=base×reach`；成功后缓存结果 30s) → Step3 60s snapshot(`pool_snapshot_puller` HTTP pull admin /p-pool-snapshot；**base health×weight,不含 ISP×省 reach penalty**) → Step4 last-known-good → Step5 500。

**edge 确实用了 reach，但非 100%**：
- 主路 ~91-96% reach-aware（Step1 缓存命中之前的 reach RPC + Step2 RPC 成功）。terminate_500=0。
- **~4-9% 因 edge→admin RPC 超时落 Step3 snapshot(非 reach)**。实测各 edge `/__pick_stats`(127.0.0.1:**81**,localhost) 的 `nw_s_pick_cache_error/(hit+miss)`：usca-1 4.2% / usca-2 4.5% / **aws-s 9.4%(RPC尝试失败16%)**。aws-s=AWS 香港 ap-east-1(95.40.168.207)，HK→ca-admin(加州)RPC 链路长→更多超时。usca-1/2=搬瓦工 LA 离 admin 近。
- ★**admin 侧 `ops_pick_p_total` 100% success 看不到这缺口**——那些超时 RPC 根本没到达 admin(只 edge 侧计 error)。**只看 admin 会漏，必 edge 侧 /__pick_stats 交叉印证**。
- 实际"被导向被封 P"伤害 ≈ 4-9% × ~2%(封锁 cell 占比) ≈ **0.1-0.2%**，且前端 cdn-failover 兜(浏览器探到死 P 自动切)。

**要 edge reach 100%（backlog，Owner 定"后面再讨论"）**：
- **(a) 修 RPC 可靠性**（RPC 失败 retry 一次 / aws-s 就近 admin 端点 / 调 timeout）→ 4-9%→<1%，**ROI 高、无漂移风险**。先深挖 aws-s→admin RPC 超时根因(CF tunnel/admin 延迟/timeout)。
- **(b) 全量本地化**（100% 无 RPC 依赖）→ 需 reach:grid 同步 edge(~13k P池 cell,~0.3-1MB,扩 pool_snapshot_puller HTTP pull+新增 admin reach 快照导出端点,edge 禁直连 Redis) **+ ★GeoIP 上 edge**(IP→isp×省;edge 现在**完全无 GeoIP**,靠 admin RPC 解析;要搬几十MB IP库+lua解析器且与admin逐字一致否则漂移→取错reach cell→反向导向被封P)。=把 pick-p 整套搬 lua,GeoIP 是主体工作量+漂移风险,当正式项目。
- 建议：只补缺口先 (a)；要"admin 宕机也 100% reach + 零延迟"才做 (b)。

相关 [[project_gfw_p3_n4_remigration_2026_07_01]] [[project_gfw_3a_flag_activated_2026_06_30]]（pick-p reach 端点）。handoff §3 有同款 backlog 登记。

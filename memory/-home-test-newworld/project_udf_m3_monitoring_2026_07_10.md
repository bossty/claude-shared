---
name: project_udf_m3_monitoring_2026_07_10
description: UDF 审计 Batch3=M3 pick-p 迁 web 后监控失明修复，已合 master a6cf8028；含 aws-s 跨洋 RPC 2.9% 常态失败率新发现与两条 backlog
metadata: 
  node_type: memory
  type: project
  originSessionId: c551e640-7125-4301-b749-7c7b093aebba
---

UDF 全系统审计（`docs/sprint/2026-07-06-unified-domain-failover/AUDIT-2026-07-10.md`）三批修复的最后一批。
**Batch3 = M3 生产 ops，2026-07-10 完成，合 master `a6cf8028`**（Batch1 `2dd9e726` / Batch2 `7cf09882`）。

## 失明链条（三层叠加，全 nw-vm 实证）
pick-p 07-08 迁 web 后：① N9E 规则 108 仍盯 `ops_pick_p_total{service=admin}`，该指标在中心 VM **无任何 series**；② 分母 `clamp_min(...,1)` 使表达式恒 0，规则 `disabled=0` 却**永不触发**；③ edge 三台 `nw_s_*` 从未被 categraf 采集（`count({__name__=~"nw_s_.+"})` → no result），「盯 `:81/__pick_stats` 趋势」的收口动作**做不到**。
判据泛化见 [[reference_n9e_dashboard_alert_internals]]「`disabled=0` ≠ 会告警」。

## 落地
- edge×3 增采 `/etc/categraf/input.prometheus/s_pick_stats.toml` → `127.0.0.1:81/__pick_stats`（usca-1 灰度→推 usca-2/aws-s）。**只加 input 文件，不动线上 `config.toml`**（它与仓库 `ops/configs/categraf/edge-vps.toml` 已漂移）。
- 规则 108 改写 `PICKP-WEB-FAIL-RATIO`（web 非 2xx 占比）。失败信号有效性前置实证：`InternalPickPController` 失败返**真 HTTP 401/503**，非 200 包 error code。
- 新增 135 `PICKP-WEB-SILENT` / 136 `EDGE-S-TERMINATE-500` / 137 `EDGE-S-SNAPSHOT-STALE` / 138 `EDGE-S-PICK-METRICS-SILENT`。
- 红绿双验：401 注入（fail-closed，无业务副作用）→ 事件 6551 + Telegram 3508 → 停注入 → 20:01:58 恢复 + 通知 3509 + `his_event 6552 is_recovered=1`。存证 `evidence/m3-redgreen-verify.txt`；SQL/runbook 同目录。

## ★ 新发现（审计台账没有的）
**`aws-s` pick-p RPC 常态失败率 2.92%**（5.5min 实测速率；累计 865/33749=2.6% 同向），usca 两台 0%。香港 edge → 加州 web 跨洋 RPC，每 34 次 cache miss 有 1 次失败回落 snapshot。**用户无感（兜底生效）但 reach-aware 挑选已降级** —— 正是失明期间无人可见的东西。
计数语义：`incr_miss()` 在 /16 缓存未命中（`short_redirect.lua:259`），随后发 RPC；`incr_error()` 在 RPC 失败回落 snapshot（:275）→ **失败率分母是 `miss` 不是总请求**。

## backlog（未做）
1. **已立项**（`docs/sprint/2026-07-10-edge-pickp-rpc-timeout/BRIEF.md`，commit `b1472bea`，未开工）。★ 诊断推翻「跨洋 RTT 撑爆 500ms」朴素假设：失败 100% 是 timeout；真实 200 热连接 TTFB **aws-s 170ms / usca-1 370ms**（同一上游 base host，usca-1 稳态慢一倍却零失败）→ 打死 aws-s 的是**尾部抖动非均值**；冷连接首次 TTFB 547ms/1137ms 均撞 500ms READ 硬门（`short_redirect.lua:80-82`，keepalive_pool=50/timeout=60s）。**禁在 H1/H2 观测结论前调 timeout。**
2. `pick_cache_error/miss` 比率告警待 **≥72h**（非"一周"）per-ident 基线再建——72h 覆盖昼夜峰谷，一周才覆盖周末模式；指标 07-10 20:00 起才入 VM，此前无历史可回看。备选：改建「相对自身过去 1h 突增」型规则，对两数量级差异免疫、无需等基线，但抓不到稳态劣化（aws-s 的 2.9% 正是稳态劣化，应由立项 1 治理）。
3. **`B4-REACH-TCP-RESET-RATIO`(id=134) DB 里 `disabled=1`**，而 memory 曾记「B4 告警已启用」——声明与真值不符，Owner 定「只记 backlog 本会话不动」。b4 SQL 本就设计为先建 disabled=1、观测基线后再启用，阈值 0.5 仍是占位值。**该订正的是 memory 说法，不是 DB。**

## 顺带订正的 doc-drift
`S_ENTRY_LUA.md` 称「Categraf 抓取 /__pick_stats → 推 n9e」**从未成立**（失明被长期掩盖的原因之一）；三处排障命令 `curl 127.0.0.1/__pick_stats` 端口错（实返 301，正确 `:81`）；`MONITORING_SETUP.md` 写死「19 条规则」而 DB 真值 98 条 → 改为指向 DB 真值源；108 的 annotations 是从「S 域可达性」规则复制的残留（引用不存在的 `$labels.target`）。

## 过程教训
commit 时 pre-commit `gate0` (`git add -A claude-shared`) 夹带了别会话未提交的 memory/skill（实际 15 files 而 message 写 11 files=**message 说谎**）。用脚本自带正规 opt-out `SKIP_CLAUDE_SHARED_SYNC=1 git commit` 重提才对齐。见 [[feedback_memory_commit_discipline]]。
合并前 master 被别会话推进两次（`046e2739`→`c69164f3`），按 Not-Rocket-Science 铁律各重 merge 一次。

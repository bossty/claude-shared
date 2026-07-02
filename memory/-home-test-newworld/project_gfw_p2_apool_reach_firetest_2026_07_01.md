---
name: project_gfw_p2_apool_reach_firetest_2026_07_01
description: GFW P2 dark flag 激活事实核查 — REACH_HINT=no-op不激活 / A_POOL_PENALTY火测安全但零收益已回滚 / 观测指标合master（2026-07-01）
metadata: 
  node_type: memory
  type: project
  originSessionId: 5633a1c0-6fb4-42eb-9222-62f1d9199e93
---

GFW reach 剩余 P2「激活两个 dark 消费方 flag」——**事实核查后 = 非对称，且都不该盲翻**。handoff 把 P2 描述为"短价值路径"不准确，实测两 flag 的**前端/下游消费方状态**才是关键。

**★事实核查（工具实测 origin/master + 部署 jar + prod DB，非纸面）**：
- **`REACH_HINT_ENABLED` = 真·no-op，不激活**：后端 `ConfigController.buildReachHintJson` 注入 `reachHint` JSON；前端 `app-config.js` 解析进 `gfw.reachHint`+转发 SW，但决策函数 `_reachHintRank`/`_reachHintWildcardOk` **只被测试调用**，migrate.js/cdn-failover/sw.js 全忽略。激活=给 /settings(每用户)加 reach 读+没人读的字段=净负。要有价值须先做前端消费方（把 _reachHintRank 接进 migrate.js 恢复链）。
- **`A_POOL_PENALTY_ENABLED` = 真消费但火测证明当前零收益**：ON 时 `computeAnchorCandidates` 走 5-param reach-aware HRW(`combined=hash×poolScore×reach`)，其 `candidates.get(0)`=**`migrateTo`**，且 prod **`PROMO_MIGRATE_ENABLED=100`** → 所有回访 P 域用户被 migrate.js 重定向到 migrateTo(真消费)。理论上激活=migrateTo 变 reach-aware(避开被封 A 域)。

**★为使火测可观测先埋指标（观测优先，同 P1）**：`DomainPoolService.hrwPickTopReachAware` 加 2 Counter `gfw_anchor_reach_applied_total`(选址跑次数)+`gfw_anchor_reach_top_changed_total`(reach 改变 top1=migrateTo 次数；循环内同算 pure-HRW argmax 对比，零额外 Redis)。**Counter 保留 `_total` 后缀**(与 P1-B gauge 剥离 `_total` 相反，同 ops_pick_p_total；curl:18080 实测确认单 `_total` 非双)。纯观测 flag-off 即 no-op(hrwPickTopReachAware 仅 flag on 被调)。985 web 全绿。合 master `6af9bc23`(spec cc4676c1/plan f435caad/code 2095140e)。

**★★火测结论(2026-07-01 14:18:54→14:25:33 UTC, ~7min, Owner 监控)**：部署 web×6 滚动(逐节点 health gate)→翻 flag→密监。**安全 PASS**(全程 0 个 5xx；/settings P95 2.26ms→~3.3ms +1ms；reach fail-open 稳)。**价值=0**：7142 次 reach-aware 选址 `top_changed=0`——reach 从未改判 migrateTo。数学证：`top_changed=0 ⟺ pure-HRW top 域 reach 恒=1.0`，即 **A 内容域在实际回访-P 流量的 ISP×省几乎都可达**(reach ~93% 中性，~2% 封锁格没落在 A-pool anchor 候选×实际流量地区)。→ **Owner 决定回滚 flag**(config=false+republish，秒回滚；applied_total 冻结 7142、P95 回 1.7ms 基线确认)。**flag 保持 false dark**；观测代码留作休眠仪器(flag off 零开销，日后 A 域真被封需 re-flip 时立即有可观测性)。

**教训**：
- ★★**Explore 子代理再次读陈旧工作分支(第 3/4 次)**：A-pool agent 在 `fix/resize-observer-benign-monitor`+老 `gfw-breakthrough-arch` 报"A_POOL_PENALTY 不存在/GFW 已 revert(22fb37b2)"——全错(consolidation 5ed76306 已重合 GFW)。以 origin/master git grep+部署 jar python zipfile 实测纠正。**根因=主工作树停在无关旧分支**；对策：委派 Explore 必显式指定读 `origin/master`(或部署基线 ref)，且核代理给的"不存在"结论。reachHint agent 用 `git show master:` 就对了。
- ★**激活 dark flag 前必核端到端消费方真活**：flag 就绪≠端到端有效；reachHint 后端就绪但前端消费方 dead。owner/handoff "短价值路径"印象必 fact-check 实代码(此处前端 grep + migrateTo/PROMO_MIGRATE DB 实测)。
- ★**观测优先让"该不该开"用真实数据而非猜**：埋 metric+一次部署+7min 火测 就证明 A_POOL_PENALTY 当前零收益，避免盲开白背 5M DAU /settings 成本。
- web 后端 jar 部署路径=`/opt/newworld/newworld-web.jar`(非 admin deploys/symlink 模型)；web×6 滚动重启 EU 节点 boot 有 `LettuceConnectionFactory STOPPED` async-stats 瞬时报错(benign 重启 artifact，非代码问题，settle 到 0)。web 节点 mysql -p 命令行取 web /proc 凭证会因引号失败→用 ca-admin 路径查同一 DB(172.34.1.222)。

**GFW reach 剩余**：P1-B 熔断(待基线)、P2 已闭环(两 flag 决定不激活；reachHint 需前端消费方、A_POOL 需真被封 A 域场景才有值)、P3 N4 S 逃生层。master 本地合 `6af9bc23` 未 push。相关 [[project_gfw_probe_stale_observability_p1b_2026_07_01]] [[project_gfw_3a_flag_activated_2026_06_30]] [[project_gfw_pickp_reach_cutover_3a_2026_06_30]]。

---
name: project-region-p1-sprint-2026-06-08
description: region-p1 sprint 收口：571ms 真凶=搜索路径4处同步跨洋master-Redis写(@Async修,G3实测571ms→12ms);allowlist假豁免铁律;就绪门禁;BSP双barrier多agent方法论
metadata:
  type: project
  originSessionId: 64b5f5d1-9590-4971-9f5b-8d2e351a83eb
---

# region-p1 sprint（2026-06-08，承接 cutover-false-alarm）

**commit d5c71485**（36 files +3007/-104）。BSP 双 barrier + 蓝军 crossfire + lead 二查。team=nw-region-p1（arch-db/arch-fe-telemetry/arch-fe-robustness/arch-gate/blue-team-p1）。

## ★571ms 真凶最终定论（经 5 次机制反转才钉死，G3 实测验证）
**= region 搜索路径 4 处同步跨洋 master-Redis 写**（不是跨洋读/replica I/O/慢查询——前4版机制全错）：
- W1 recordSearchKeyword(MovieService:889) / W2 recordSearchMiss(968) / W3 getHotSearchKeywords 聚合写(setIfAbsent+executePipelined+ZUNIONSTORE 924/928/942) / W4 getRelatedMoviesById 回写(1060)
- 全部 `@Async("statsAsyncExecutor")` 离请求线程（W3/W4 用独立 @Component HotSearchAggregator/RelatedPoolWriteback 避 self-invocation 旁路=round5 教训）
- **G3 实测（drain aws-region-us 部署 d5c71485）：search 571ms→~12ms（47×，≈HK）**。page1≈page2≈12ms。一步确认根因+验证修复。
- **决定性诊断手法**：page=2 同 kw 对照(跳过 record 写) + tcpdump 拆端口(HK 6379 包数) + EXPLAIN ANALYZE(replica 0.02ms 排除慢查询) + lead baseline A/B。**包计数被背景 flush 污染过(idle baseline 52 HINCRBY)→归因必对照 idle baseline + scales-with-N**。

## 漏网根因 + 新铁律（最深刻）
防护闸 `check-no-sync-master-write.sh` allowlist **4 行假豁免**（line44-47，声称 @Async/@Scheduled/bloom-write-through 实为请求线程同步写）把真 bug 压下。**新铁律（已加进闸注释）：allowlist 豁免理由声称 @Async/@Scheduled/非请求线程的，必 grep 验证该注解真在方法上**。闸有效≠不被人工误豁免绕过。

## 其他交付
- **告警口径**（治"每次切换都像炸"，基线~16% artifact）：版本戳 git-sha 单源 + fetch.js failKind 三类(导航取消/adblock 不计分子) + console.error 去回声不灌 js-errors + cdn-failover-critical 桶(SNI 全阻断不再吞) + health 弱与门。
- **前端健壮性**：main.js beacon(degraded 命中率可观测) + cdn-failover.js 日志卫生(fire-and-forget 不阻塞 probe)；traceStartDetect=注入脚本证伪不修。
- **就绪门禁**（防第三次切换翻车）：scripts/region-readiness-gate.sh(G0-G7,**G3 cache-miss RTT≈HK 探针**抓打地鼠) + check-region-read-routing.sh(合并读写静态闸,@RegionReadAllowed/@MasterWriteAllowed) + ArchUnit 方法级 + deploy runbook Step2.6。

## BSP 多 agent 方法论沉淀（这次验证有效的）
- **superstep 放开吵+蓝军 crossfire → barrier 全员一致+lead 二查+CLOSED+禁抢跑**：5 次机制反转每次都是单方报捷被另一方/lead 实证纠（arch-db 测顺手端点报捷、lead 误判 replica 慢查询、blue-team flake 归因没切 baseline）。**谁都会错，靠互相实证兜底，lead 二查不豁免自己也不豁免蓝军。**
- **barrier 判据=本 sprint 0 新 regression（baseline A/B 证）非"预存套100%绿"**（否则有 flake 的库永远发不了版）。
- **避 rate-limit**：降并发(串行) + 砍冗余通信(收敛即封口,别 litigate 已定点) + **lead 兜底自跑决定性 ops(G3 部署我亲跑绕开限流 agent)** + 产物落工作树/commit 不靠 agent 内存。
- **收尾必逐个核实(owner 要求)**：串行唤醒每 agent 确认完工+commit 实证,防"以为做了其实没做"的进度同步坑。

## 状态 + 待办
- region-us 已带 d5c71485 运行+G3 验证(回滚 .bak-w1w4-202606081458)。**EU region 同部署 + 重新放量 A 域=待 owner 决策**(571ms 已根治+门禁已建=region 现在才真就绪)。
- backlog #15: cdn-failover-critical 告警文案带 reason(no_backup/sni_block/all_unreachable) fast-follow。
- 配套 skill 候选: region-cutover-readiness-gate + client-telemetry-artifact。详见 [[project-region-cutover-false-alarm-2026-06-08]](571ms 机制以本档为最终,那档跨洋读机制作废) + [[feedback-verify-not-recall]]。
锚点 docs/sprint/2026-06-08-region-final-migration/。

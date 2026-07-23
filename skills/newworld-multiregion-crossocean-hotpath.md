---
name: newworld-multiregion-crossocean-hotpath
description: 多 region 单 master 拓扑下，请求热路径上的同步跨洋 DB/Redis 操作是 5xx/慢的系统性根因。触发：multi-region / region 慢 / 跨洋 / cross-ocean / settings/snack/analytics 慢 / readOnly 路由 / @Cacheable 自调用 / region upstream / fullcut 5xx
---

> **执行机制**：靠判断力（跨洋同步热路径根因）

# newworld-multiregion-crossocean-hotpath SOP

**来源**：2026-06-06 fullcut-5xx-fix sprint（全量切 region 28% 5xx → upstream 根因 + round4/5/6 + 3val 全闭环；region p50 144ms→2-3ms）。

## 0. 核心心智模型（铁律）

**「in-HK 同机隐形 / region 跨洋放大」**：单 region 时代（app 与 MySQL master/Redis master 同机 ~3ms）写得没问题的代码，搬到 region（到 HK master 跨洋 US 142ms / EU 190ms）会被**放大成秒级慢 + 高负载 5xx**。这是一**整类** bug，不是单点。审 region 代码 / 排查 region 慢，先按此类排查。

**两条不可违反的路径规则**：
1. **请求热路径上的 DB/Redis 读 → 必须命中本地**：`@Cacheable`(Caffeine/TwoLevelCache) + `@Transactional(readOnly=true)`（路由本地 slave，`determineCurrentLookupKey()=readOnly?slave:master`）。cache hit 靠 `LazyConnectionDataSourceProxy` 不取连接，零开销。
2. **请求热路径上的写 → 必须离开请求线程**：`@Async`(fire-and-forget telemetry) / coalescing buffer(`StatsCoalescingBuffer` 内存累加 + @Scheduled 批量 flush) / bulkhead(`SyncGateBulkhead` RYW 决策闸，隔离池 + future.get 超时 + fail-open)。

## 1. 六个实战陷阱（每个都"in-HK 看不见"）

1. **OpenResty upstream 写死 HK 节点**（原始 28% 5xx 真因）：region `nginx.conf` `upstream nw_web` 从 HK 整段拷来、仍指 `172.31.27.120/121:7777`(HK web)，每请求跨洋到 HK tomcat 处理（region 本地 tomcat 零流量）。**修法=`server 127.0.0.1:7777` primary + HK 两台 `backup`**（保单机 HA 回退）。全量切时全球请求处理全压 HK 2 台 tomcat→线程池耗尽→5xx。

2. **Spring 自调用旁路 @Cacheable/@Transactional**（round5 snack/list、round6 settings）：同 bean 内 `getA()→this.getB()`（@Cacheable/@Transactional 在 getB）→ 代理旁路 → 缓存/readOnly 全失效 → 每请求跨洋。in-HK master 同机 3ms 隐形；region 跨洋秒级。**修法=抽独立 `@Component` 外部调用 / 自注入 `@Lazy self`**。

3. **readOnly 事务里有 Redis 写**（round6 B-1，违 CLAUDE.md 铁律，MovieService 已有移除先例）：给含 Redis 写的方法(如 getFullConfig→resolveFirstVisitDate)加 `@Transactional(readOnly=true)` = Redis 写落进 readOnly DB 事务。**修法=纯 DB 读抽进 readOnly `@Component`，Redis 写留在事务外**。

4. **DiscardOldestPolicy + 占位先于 dispatch**（3val F2）：主线程先 `seenCache.put(TRUE)` 再 `executor.execute()`，但执行器是 `DiscardOldestPolicy`（队列满静默丢最老任务、`execute()` **不抛 RejectedExecutionException** → catch 死代码）→ 被丢任务 key 已"已见"但实际没写。**修法=占位/标记移到操作成功之后**（被丢任务不留痕→重试；NX/幂等写多次无害）。

5. **冷启误判成稳态残留**：region tomcat 重启后 cache 冷 + JIT + 连接池 warmup，首批请求 100-200ms，warm 后 ms。排查时**必区分冷启窗口 vs 稳态**（看时间戳是否挤在重启时刻；warm 重放）。多次把冷启样本误判成跨洋残留。

6. **健康/就绪探针经 @Primary 路由池 ping 跨洋 master**（2026-06-25 EU `HIKARI_DB_PENDING` 真因）：`HealthController.health()` 用 `dataSource.getConnection()`（@Primary=Lazy→Routing，**无 readOnly 上下文 → `determineCurrentLookupKey` 返 master**）+ master Redis template，EU 上每次 /health 跨洋 ping CA master（`isValid`/`ping`，实测 **359ms ×~12/秒**，Little 定律占 **~4.3 条 master 连接**）→ HikariPool-1 pending 告警。`isValid()` 是驱动 ping 非 SELECT → **L2 跨洋读计数（CrossOceanReadListener）看不见**；多探针(OpenResty/categraf/CF/N9E)打 127.0.0.1 绕过 access.log（access.log /health=0 误导）。**修法=探针注入 `@Qualifier("slaveDataSource")`+`@Qualifier("replicaStringRedisTemplate")` ping 本地池**（EU→replica .248/.184、CA→本地，都 <1ms；commit `22c1ba08`，6 节点零停机 force-peak，/health 359ms→~2ms、pending 7-12→0）。**附带必修的 resilience bug**：原设计 region 节点存活绑死"跨洋 master 可达"，master/跨洋一抖 → 全 region 节点同时 /health 失败被 LB 摘除 → 全站掉；**写主可达性属异步可缓冲，不该作 LB 摘节点判据**。

## 2. 诊断方法论（铁律：运行时证据 > 代码 grep / OTel 归因猜测）

**代码 grep 喊"根因"反复错；OTel 抓到跨洋 span ≠ 它在请求热路径**（可能在 @Async 执行器/bulkhead/lettuce 事件循环线程，不卡请求）。必用运行时工具实证：
- **curl 直连对照**：`curl 127.0.0.1:7777`(本地 tomcat) vs `curl :80`(via OpenResty) vs `curl HK:7777` → 定位慢在哪层。
- **tcpdump 端口拆分 + 对照组**：`tcpdump host <HK> and port 3306/6379`，发 1 个请求看跨洋包；**必跑 0-op 对照端点**(如 settings/version) + idle baseline 区分背景(HikariCP master 池 keepalive/coalescing flush)。**5ms 请求不可能含 142ms 跨洋往返**——latency 本身就是铁证。
- **web.log uht 百分位分布** + 慢端点 top（`uht=` 字段，按端点聚合）。
- **scales-with-N 测试**：参数 N（slugs 数/errors 数）线性增长=每单位一次跨洋；flat=离请求线程。
- **同 key 重放**：连发同请求若全慢=零缓存命中（缓存失效铁证）。
- **ping HK** 得 RTT 基线，与 uht 比对（uht≈k×RTT → k 次跨洋）。
- **对自己的假设也 fact-check**：fvd"146ms"实测 4ms（冷启误判）；OTel 跨洋写实为 async/bulkhead 非热路径。下结论前先证伪。
- **jcmd Thread.print 多采样 + 按线程名分类谁占/等连接池**（2026-06-25 HIKARI 诊断）：定位"HikariPool pending 谁造成"——`sudo -u <owner> $JAVA_HOME/bin/jcmd <pid> Thread.print` 连采 ~20 次（覆盖突发），awk 抓栈含 `com.zaxxer.hikari.pool.HikariPool.getConnection`(WAIT=pending 等待者) 或 `com.mysql.cj`(HOLD=持连查询中) 的线程，**按线程名归类**：`http-nio-*-exec`=请求线程（**卡用户**）vs `stats-async`/`vid-metadata`/`feed-async` 等=异步（不卡用户）→ 再抽请求线程栈的 `org.earth.newworld` 帧定位具体端点。比 grep / VM 指标直给"是谁"。**判据**："**pending 但 total 没顶 max** = 跨洋建连延迟（每条 ~150ms）非容量瓶颈"——**扩 max 治不了**（还加 master 连接压力，6 web×max20=120），要么扩 EU `minimumIdle`（跨洋连接握更久需更多暖连接）要么消除跨洋调用本身。VM 查峰值：`max_over_time(hikaricp_connections_{active,pending,connections}{pool="HikariPool-1"}[24h])` 按 ident。

## 3. 闸门与验收
- `scripts/check-no-sync-master-write.sh`：grep 闸强制"无未豁免同步 master 写"，`@MasterWriteAllowed(理由)` 标注豁免（coalescing flush / bulkhead gate 是合法同步写点）。改 region 代码后必跑。闸门本身有 grep 盲区（insertIgnore 变体 / *Mapper 字段别名），扩代码时核查。
- 验收看 **uht 回 ms + tcpdump 跨洋包归零**，**不是看 5xx**（低负载假绿——5xx 只在高负载线程池耗尽才现）。
- 部署重启：region 本地 tomcat 重启窗口，OpenResty `proxy_next_upstream` **默认不重试非幂等(POST)** → POST 落 5xx（GET 被 HK backup 兜住）。全量推广 runbook 用 drain（先摘 LB 再重启）或评估 `non_idempotent`。

## 4. 方法论：本类 fix 走 SDLC 蓝军 crossfire
生产敏感热端点改缓存/事务/异步行为，必走 dev+qa+蓝军。**qa 测试绿 ≠ 正确**：round6 readOnly+Redis 写测试全绿却违铁律，靠蓝军独立 review 抓出。蓝军挑刺 lead 必逐条证据裁决（不盲采不盲驳：如"移除 @Transactional"修法被 `determineCurrentLookupKey` 路由证据驳回——移除会路由 master 跨洋）。

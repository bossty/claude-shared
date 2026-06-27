---
name: reference_redis_sharenativeconn_antipattern
description: CA web 持续 Redis 命令超时真根因=IP库34MB LRANGE 的 HOL；shareNativeConnection=false 是被A/B+官方文档双证的反模式(勿再试)；gfw分支残留地雷
metadata: 
  node_type: memory
  type: reference
  originSessionId: e154dcd7-4e73-48df-ae60-a425412b5fbf
---

2026-06-22-23 doc-backed RCA：CA web(主region)持续 `QueryTimeoutException: Redis command timed out`（白天100-300/30min、傍晚脉冲窗放大到8000-10000/25min）。

**真根因（强文档支撑，3组件互证）= 客户端/服务端 head-of-line blocking，非服务端慢**：
- `IpEntryRedisCacheLoader.loadEntries()` 每60min `opsForList().range(key,0,-1)` 一次拉 **182k元素/34MB** IP库list（走master `stringRedisTemplate`，.128）。
- 客户端：Lettuce 共享连接单 EventLoop 串行解码34MB（client-resources.md/pipelining.md "单线程/连接""等待越久"）；服务端：Dragonfly thread-per-shard 单分片线程不让出地遍历（df-share-nothing + flag `container_iteration_yield_interval_usec` 默认0）。双侧 HOL 把同 .128 上 MovieService/TwoLevelCache 热路径读顶到队尾撞5s commandTimeout。Dragonfly 官方延迟指南直接点名 "LRANGE on a 100,000-item list"。
- .128 实测全绿(--latency 0.14ms/slowlog无5s/bgsave未跑/connected_clients 368)**正是该机制的预期**，别被"服务端健康"误导成"非Redis问题"。
- **真修=IP loader 分批读**（range(0,-1)→每批2000元素小LRANGE循环），commit **615bb1c5**；测试 IpEntryRedisCacheLoaderTest +2，common 489绿。

**★反模式铁律（A/B+文档双证，勿再试）**：曾试"治本"=3个LettuceConnectionFactory `setShareNativeConnection(false)` 启用池想消除"单连接头阻塞"——**错**。
- A/B canary 单节点实测：超时未降(8040≈对照8522/10321)、反增 **911次** "Could not get a resource from the pool"(并发超max-active池满)，已运行时回滚+git revert(**57a7cf18**)。
- 文档证反模式：Lettuce作者wiki "Using multiple connections does **not** impact performance positively"；非阻塞读(get/mGet/lRange/hIncrBy)正是单连接多路复用最优场景。**HOL真因是大响应解码占满EventLoop，分池不缩短34MB解码、只搬到池里某条连接对它同样HOL**。治标都不对。
- commons-pool2 GenericObjectPoolConfig **maxWait默认-1=无限阻塞**（蓝军BLOCKER-1）：shareNativeConnection=true时池被旁路不暴露，改false才暴露→池满线程永久挂死。

**⚠️ gfw-breakthrough-arch 分支地雷**：该分支HEAD(35cb5e9b)在revert前merge过master，残留 setShareNativeConnection=false **3处**（master已0）。从gfw build/部署/反向merge会把证错池化带回线上放大超时。**修法：gfw重新merge master(57a7cf18+)自动吃掉revert**。

**H1 sync=true 条件放大器**：TwoLevelCache.get 把L2 Redis IO放进Caffeine per-key锁回调→Redis慢时持锁5s、同key全部线程排队5s。常态(0.14ms)有益、仅Redis慢时作恶；根因修后回归无害，暂不动（解耦要碰分布式语义风险更高）。

**★CPU spike（每10min :X1:40 java+cloudflared同飙、傍晚窗口、00:00峰流量时仍在、~00:02消）= 本轮06-22改动引入(未结案)**：数据铁证——06-22晚有精确10min周期(间隔[10,10,10...]×9)、06-21晚同样84%高流量却无此周期 → 不是傍晚脉冲/流量,是06-22部署引入。⚠️我曾连错三次假设(傍晚脉冲/17:45重启onset/午夜流量掉)全被Owner数据打脸 → **时间相关性不可靠,定性必抓:X1:40复发时的线程栈ground-truth(top -H)**。机制未钉死:缓存广播经web日志排除(all不规律/bloom-add每2min轻),非Pub/Sub触发。嫌疑=H4(getMoviesByIds逐片movie-card multiget,06-22唯一重写热路径)/H2。Owner暂放(明晚不复发就算)。⚠️实际只revert了治本(shareNativeConnection),H2/H4仍在master+全节点线上未回退→明晚同窗口可能复发,复发即抓线程定性。关联 [[project_beacon_cost_reduction_2026_06_15]]。

**诊断教训**：CA app日志写文件 `/var/log/newworld-web.log` 不进journald，用journalctl查CA定时任务/超时是**盲的**（绕一大圈把"warm偶发Redis超时"误判成"CA调度死")；查CA行为先确认日志去向、读文件日志。

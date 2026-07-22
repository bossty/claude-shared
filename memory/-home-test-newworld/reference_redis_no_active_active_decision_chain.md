---
name: reference_redis_no_active_active_decision_chain
description: 2026-06-02 Redis 异地多活调研的「拒绝 active-active」完整论证链:换引擎门槛0/3、唯一进用户路径的跨洋写=feed markSeen(正解改异步非写本地化)、多地写同key正解=region维key非CRDT、KeyDB LWW丢增量、replica白名单必到call-site粒度
metadata:
  type: reference
---

2026-06-02 Redis 异地多活调研 sprint（5 agent 三轮 barrier-crossfire + Owner 复盘重排）的决策论证链。**结论：newworld 不做 Redis active-active，任何阈值档都不触发换引擎**。未来再有人提「多 region 要不要 Redis 多活/换 CRDB/KeyDB/MemoryDB」，先按本条论证链走，不必重跑调研：

**1. 换引擎门槛 0/3**：同步跨洋写占 TTFB ≥15% **且** 切流后 ≥30% 用户离主 Redis 跨洋 **且** 存在亚秒强收敛需求——三条全绿才值得评估换引擎；当时 0/3，ROI 明确为负（换引擎 15~30 人日）。

**2. 无真多活需求（关键事实）**：
- **唯一进用户返回路径（urt）的跨洋 Redis 写 = feed markSeen**（`SessionFeedService` 每翻页同步 SETBIT）。正解=**改异步挪出返回路径**（它是请求最后一个 op、纯记录给下次用，客户端 IDB seenIds 兜底 race）——比「region-key 写本地化」更简单且不依赖 replica。**写要分同步/异步看是否进 urt**：fire-and-forget（stats/view 上报）本地化对用户零收益。
- **多地写同 key 的场景（stats pv 计数、view HINCRBY keyed by movieId）正解 = 加 region 维 key**，各 region 独立写、admin 聚合时求和/HLL merge——应用层消灭冲突，**不需要 CRDT 引擎**。**KeyDB 是 LWW（最后写赢），跑计数类会丢增量，「CRDT 友好」的措辞会误导**。
- 读才是大头：feed 每翻页 = 7 个串行跨洋 Redis RTT（5 读 + 2 写）≈ US 993ms / EU 1307ms，read-replica 读就近是单请求最大可省项，写就近是零头。

**3. replica 读写白名单必到 call-site/方法粒度（实施铁律）**：同一个类甚至同一请求里读写混合——`SidBloomService.filterNotSeen`（GETBIT，读）可迁 replica，`markSeen`（SETBIT+EXPIRE，写）必回 master。按「类级/连接级纯读」打包路由会把写打到 read-only replica 直接报错。前序「feed 整连接纯读」定稿即栽在这。

**4. pub/sub 跨 region 失效方案选型 = version-key 轮询（B），否决钉 master 订阅（A）**：A 的失败模式是「跨洋 idle 订阅静默断 → 失效广播永久丢且无告警 → L1 无限期脏数据」，属 newworld 反复踩的静默降级型坑；B（admin INCR 单调 seq → replicaof 复制 → web 1-5s 轮询本地 replica 比对）漏一拍下拍追平、replicaof 断有 lag 告警，fail-safe。**失败模式 > 实时性做选型**。

**5. 2-region pivot 陷阱**：只搬 DB/Redis master 不搬 admin ≈ 零净收益——admin 单实例的反向跨洋写（cohort 重建 340K zADD、stats SYNC、pub/sub 发布）会把 web 侧省下的延迟原数吃回去，只是换了谁跨洋。完整治本 = master + admin 双搬。

**6. 方法论：改名不是否决**——警惕把「active-active」改叫「region masters 分片」后照样推荐；同等复杂度必同等审视。

相关：skill `newworld-multiregion-crossocean-hotpath`（热路径跨洋是 5xx/慢根因）、[[project_dragonfly_selection_poc_2026_05_26]]、[[reference_redis_sharenativeconn_antipattern]]。

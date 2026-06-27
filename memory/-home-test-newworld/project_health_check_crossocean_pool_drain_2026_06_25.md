---
name: project_health_check_crossocean_pool_drain_2026_06_25
description: EU HIKARI_DB_PENDING 真因=HealthController每次/health跨洋ping master(359ms)抽干HikariPool-1;修=ping本地slave/replica;已部署6节点
metadata:
  node_type: memory
  type: project
  originSessionId: 6eecae1c-95e0-4231-a84e-4ccc79979b6c
---

跨洋读 epic 收口后 eu-web-01 又报 `HIKARI_DB_PENDING`(HikariPool-1=跨洋 master 写池)。**不是读泄漏复发**(L2 `nw_crossocean_read_total` 空=零跨洋读),真因是 **`HealthController.health()` 每次 /health 跨洋 ping CA master**。

**诊断链(运行时实证,非 grep)**：
1. 快照:pending 已归 0(momentary),L2 读计数空 → 排除读泄漏,定位写/连接侧。
2. VictoriaMetrics 24h 峰值:EU HikariPool-1 active 11-12 / pending 7-12 / total 14-15(**没顶 max=20** → 不是容量瓶颈,是跨洋建连慢);CA 全 0-2 pending=0。
3. **jcmd Thread.print ×22 采样 + awk 按线程名分类**谁占/等 master 连接:**42 HOLD + 6 WAIT(pending)= REQUEST 线程(http-nio-exec)**,仅 ~6 async(vid-metadata)。→ pending 在**请求线程**(卡用户),不是异步。
4. 抽请求线程栈的 `org.earth.newworld` 帧:**100% 是 `HealthController.health():33`**。
5. actuator `http_server_requests{uri=/health}`:count 152151、**mean 359ms/次**、~12 次/秒 → Little 定律 **~4.3 条 master 连接被健康检查长期占用**(对上 active 基线 4)。

**根因**：`health()` 用 `dataSource.getConnection()`(@Primary=LazyConnection→Routing,无 readOnly 上下文 → `determineCurrentLookupKey` 返 master)+ master `stringRedisTemplate`,EU 上每 poll 跨洋 ping CA master(MySQL `isValid` + Redis `ping`)。`isValid()` 是驱动 ping 非 SELECT → **L2 看不见**(解释 L2=0 却有 request 占 master)。多探针(OpenResty 主动健康检查+categraf+CF/N9E)打 127.0.0.1 绕过 OpenResty access.log(所以 access.log /health=0 误导)。

**修(commit `22c1ba08`,已部署 6 节点 d1766b93)**：HealthController 注入 `@Qualifier("slaveDataSource")` + `@Qualifier("replicaStringRedisTemplate")` ping **本地池**(EU→replica .248/.184、CA→本地)。实测 **/health 359ms→~2ms(EU)/~1ms(CA)**,HikariPool-1 active 11→1-2、pending 7-12→0,body 仍 `{mysql:UP,redis:UP}`。**附带修 resilience bug**:原设计 EU 节点存活绑死"跨洋 master 可达",master/跨洋一抖 6 节点同时 /health 失败被 LB 摘除→全站掉;写主可达性属异步可缓冲,不该作 LB 摘节点判据。

**可复用铁律**：① region 节点健康/就绪探针必 ping **本地池**,禁经 @Primary 路由池(无事务→路由跨洋 master);② "HikariPool pending 但 total 没顶 max" = **跨洋建连延迟**非容量,**扩 max 治不了(还加 master 连接压力),要么扩 minIdle 要么消除跨洋调用**;③ 诊断"谁占/等连接池"= jcmd Thread.print 多采样 + 按线程名(http-nio-exec=请求 vs *-async=异步)分类,比 grep 直给答案;④ `isValid()`/驱动 ping 不走 datasource-proxy QueryExecutionListener,L2 读计数不覆盖。属 [[newworld-multiregion-crossocean-hotpath]] 同类(候选入 skill)。承 [[project_crossocean_read_guardrail_2026_06_25]]。

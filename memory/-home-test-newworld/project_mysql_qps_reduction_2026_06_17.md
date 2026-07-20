---
name: project_mysql_qps_reduction_2026_06_17
description: MySQL业务库QPS减压专项(接手会话9532d6aa遗留)；真凶=snack缓存bypass真bug+71%事务塞子；P0上线snack_slot 77.5→0.5/s(-99.4%)，P1因master load仅12%退backlog；8条durable教训
metadata: 
  node_type: memory
  type: project
  originSessionId: 51e46e5d-f553-4c24-a728-303df35fe4b0
---

# MySQL QPS 减压专项（2026-06-17，接手会话 9532d6aa perf-rca 遗留 owner-gated 项）

**结局**：P0 snack 缓存 bypass 修复上线（master `c9a6bf9d`，6 节点滚动），业务库 `SELECT snack_slot WHERE slug` **77.5/s → 0.5/s（-99.4%）**；P1（JDBC 会话态消冗）实测 master load 均值 0.12/CPU 空 76% **退 backlog**；服务器不升级。全程 SDLC（pm-helper PRD + 蓝军 + dev/qa + lead 仲裁/接管）。

## 真凶链（实证不臆测）
- 6-14 旧诊断两杠杆（readOnly 补标 + vid_metadata 缓冲）**双重证伪**＝早已实现（web 46 个 @Transactional 全 readOnly；VidMetadataService 已 Caffeine+异步 DiscardOldest）。
- lead prod `performance_schema` digest 增量实测：业务库 71% QPS = 事务管理塞子（SET autocommit/COMMIT/SET TXN RO·RW），服务端近零成本。
- 真杠杆：① snack_slot bypass 真 bug（`SnackService.getSnacksBySlotWithUa` 非 @Cacheable，每请求直打 findBySlug 取 slot 做 UA clientFilter 判定，才委托内层 @Cacheable）② JDBC 会话态消冗(P1)。修法=新增 @Cacheable `getSlotMeta`(snack:slotmeta，UA 无关 slot 元数据)，clientFilter 内存判定，UA 定向语义零改。

## 蓝军真功 vs lead 仲裁（多 agent 价值）
- 蓝军揪出：snack bypass（pm-helper 只看内层 @Cacheable 漏外层）+ **C5（lead 自己复核漏了）**：P1 只改 master URL，高频读走 slave URL(systemd drop-in)不继承参数→P1 半残。
- lead 仲裁推翻蓝军：BLOCKER-2(cache-hit 塞子)降级——LazyConnectionDataSourceProxy 已启用 cache-hit 零连接；MAJOR-3(categraf)机制错——15s≠67/s 且池稳定(processlist 全 Sleep)。
- lead 接管修 3 个 dev bug：测试 String→List<String> 编译错(WARN-11 没跑 test-compile)/漏 snack:slotmeta 缓存失效(SnackCacheRefreshListener)/times(1) 断言基于错误缓存心智(单测无 @Cacheable 代理→2 次)。

## 8 条 durable 教训（Owner 2026-06-17 采纳全部）
1. **QPS 高 ≠ 负载高**：3590 q/s 看着吓人，master load 0.12/CPU 空 76%；71% 是廉价事务塞子计数。**扩容/优化前先量真实 load 不看 query 计数**，别为不存在的容量问题买单。
2. **读写分离配置必覆盖两处 URL**：master 写池=jar 内 `application-prod.yml spring.datasource.url`；slave 读池=systemd drop-in `/etc/systemd/system/newworld-web.service.d/slave-datasource.conf` 的 `SPRING_DATASOURCE_SLAVE_URL`（region 迁移时建，**不在仓库**；CA 读连接打 master 本机 .222、EU 打 replica .248）。改 datasource URL 参数只改 jar 内 master URL → 高频读路径全不生效。（已补 [[newworld-web CLAUDE.md]]）
3. **`READ WRITE ≈ READ ONLY` 是 HikariCP 连接复位成对，非缺 readOnly**（纠 6-14 误诊）；digest `COUNT_STAR` 累计值会骗人，必跑增量 delta 看当前速率（两次快照 COUNT_STAR 差/秒）。
4. **snack getSnacksBySlotWithUa cache bypass**：UA 定向(clientFilter 白名单，源自 anti-adblock 反拦截)使外层不能按 slug 缓存，但 slot 元数据 UA 无关→单独 @Cacheable；**新增缓存 key 必同步进 SnackCacheRefreshListener evict 清单**否则 admin 改 slot 后陈旧。
5. **anti-adblock baseline 27 天没分析**：埋点 `nw_diag_visibility_total{ua,metric}` 一直在收，**夸克 90%/小米 76% honeypot 拦截率**远超 PRD 20% 触发线，但 B-2 触发判定/B-7 dashboard import 全 Owner backlog 没做。**埋点交付 ≠ 分析交付**；触发判定应 @Scheduled 自动告警非人工 backlog；`snacks_hidden` 混入视口外/lazy 不能直接当拦截率，honeypot(bait) 才是干净信号。baseline 全表见 `docs/sprint/_archive/2026-05-20-anti-adblock/baseline-FINALLY-analyzed-2026-06-17.md`。
6. **prod web 节点无 unzip**，验 jar 内类用 `python3 zipfile`(z.read 搜字节) 或 `javap`，别假设 unzip 在。
7. **`set -e` + 启动期 curl 健康轮询会误 abort**：app 启动期 curl 拒连返非零→set -e abort 整脚本（输出空但 cp/restart 已执行，险误判部署失败）。健康轮询循环勿配 set -e。
8. **EU 重启瞬态错误判别**：restart 期 `LettuceConnectionFactory STOPPED` + snack 曝光写失败是预期瞬态(~30-60s 随启动完成停)；判 P0 回归看「同 jar CA 是否也错」+「错误是否持续」两条（本次 EU 1392/639 错、CA 0 错、60s 内归零=纯瞬态非回归）。

## 部署/取证
- canary ca-web-01 先验(actuator UP/snack·home 200/jar 含 getSlotMeta/snack_slot 降)→滚动 5 节点；jar 5 版备份 `.bak-pre-c9a6bf9d` 秒级回滚。
- auth-backstop：所有 prod SSH/部署/digest 采样 lead 代跑。
- 安全：查 env 时明文 DB 密码被带出（已知项 owner 暂不轮换，见 [[reference_terminal_ca_infra_eip_nat_n9e]]），未写入任何文件。
- 峰窗 digest 复采 host PID 253838 今晚 23:35 HKT 自动跑(`/tmp/qps_peak_2026-06-17.txt`)，坐实脉冲态构成。

## 未尽 backlog
- P1 JDBC 会话态消冗（方法存 `docs/sprint/_archive/2026-06-17-mysql-qps-reduction/DEPLOY-PLAN-canary.md §P1`，QPS 涨到真高负载再启）。
- anti-adblock Phase 2（夸克/小米反拦截）+ snacks_hidden 拆分 + B-2 @Scheduled 告警（待 Owner 拍）。
- snack getSnacksBySlot `@Cacheable(unless="#result==null")`（C2 MINOR，missing/disabled slug 仍打库）。

关联：[[project_perf_rca_zerodowntime_2026_06_16]]、[[feedback_perf_rca_deploy_gotchas_2026_06_16]]、[[reference_terminal_ca_infra_eip_nat_n9e]]

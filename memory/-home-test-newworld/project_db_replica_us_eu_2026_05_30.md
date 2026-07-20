---
name: project_db_replica_us_eu_2026_05_30
description: US+EU MySQL read replica 上线 sprint（5/30-31）—— web 读写分离激活 + 12 条跨机复制血教训 + 公平基线
metadata: 
  node_type: memory
  type: project
  originSessionId: a71aa26f-69ff-4daa-8ee0-e32d79403b2e
---

# US/EU read replica 上线 sprint（2026-05-30~31 通宵）

**目标（owner）**：US/EU region 各拉 MySQL read replica（HK master 不变），US/EU web 读走本地 replica、写走 HK master，消跨洋 DB N+1；**记录 web 切换时间点对比 replica 前后真实数据**。2-region(US master) pivot 仍 DEFERRED（见 `2REGION-US-PRIMARY-DESIGN.md`）。

## 最终态（🟢 全闭环 2026-05-31 ~04:37 HK）

- **HK master** aws-db-poc：内网 172.31.19.174 / 公网 43.198.91.111 / `ssh aws-db-poc`，MySQL 8.4.8 server_id=2，GTID ON，库 ~10GB。
- **US replica** i-08514c82940691701：172.32.9.19 / EIP 52.33.86.37，**m5.xlarge**，server_id=3，lag 0。US web 44.249.182.197 切 20:27:33Z。
- **EU replica** i-0246036769dcc62d1：172.33.8.248 / 3.65.1.28，**m5.xlarge**，server_id=4，lag 0-2s。EU web 172.33.6.211 切 20:36:37Z（覆盖旧 t3.large 期 16:51:05Z）。
- 复制走 **VPC peering 私网**（SOURCE_HOST=172.31.19.174，US-HK pcx-0a3290b438c3a6995 + EU-HK）。复制账号 `replicator@172.32.%`+`@172.33.%`（mysql_native_password，pw `Repl!c@t0r_nw2026`）。app 用户 `newworld`。
- **具体 infra 真值 + SOP 全在 `docs/sprint/2026-05-29-peak-perf-debate/REPLICA-BUILD-STATE.md`**（fresh agent 接手必先读，禁再问已确认项）。
- 读写分离 infra 早就绪：`ReadWriteDataSourceConfig`(newworld-web) 完整 AbstractRoutingDataSource，`@Transactional(readOnly=true)→slave`，激活=配 `spring.datasource.slave.url`（systemd drop-in 注入，零代码）。web MySQL 写仅 4 类遥测/维护、无 read-after-write（见 `CONSISTENCY-REPLICA-DESIGN.md`）。

## 12 条血教训（跨机 MySQL 8.4 复制 + 多 agent 协作）

1. **DB replica 不该用 t3 突发型**：稳态要持续追 master 写入，2 vCPU apply 追不上 master 8vCPU 写（lag +27s/min 增长）；IOPS/workers 调优无效，**升 m5.xlarge(4vCPU) 后 1min 追平 lag=0**。replica 实例按各 region 读负载配比（US 服 66% CN 读 > EU 30%，本该更大）。
2. **对照实验基础设施必同配公平**：两 region replica 必须同实例类型（m5.xlarge），否则 US-vs-EU 性能比较被规格混淆。owner 揪"都升来保证公平"。
3. **传输必走 VPC peering 私网、禁公网 EIP**：scp 到公网 EIP（52.33.86.37）走 HK→US 跨洋公网 → TCP 卡死 522KB 不动；改私网 172.32.9.19（peering 骨干）→ 10MB/s 秒通。peering 配了不用=没配。owner 揪"peering 不是打通了吗"。
4. **load 禁 `--force`（吞真错）**：44/63 卡了 4.5h 不知道为什么——`--force` 把真错吞了。去掉才发现真根因 = **dump 本身截断**（157MB 残包 vs 完整 760MB），不是表报错。
5. **mysqldump clean 用 `--set-gtid-purged=OFF`**：避免 dump 含 `SET @@GLOBAL.GTID_PURGED` 多行语句，grep/sed 剥离地狱（剥单行→跨行语法错、剥块→还失败）；用 `--source-data=2` file/pos 起点 + `SOURCE_AUTO_POSITION=0`。
6. **MySQL 8.4 默认禁 mysql_native_password**：master 的 `CREATE USER ... mysql_native_password` binlog 重放到 replica 报 Error 1524。replica cnf 加 `mysql_native_password=ON` + 重启（START REPLICA 前做，比 skip 干净）。
7. **app 用户不在 `--databases newworld` dump 里**（mysql.user 没复制）：切 web 前必在 replica 建 app 用户(`newworld` SELECT) + 测连通（`mysql -h <replica> -u newworld` 返数），否则 web 连不上 replica。
8. **web 切 replica 前必追平 lag<60s**：replica falling behind 时切 = 真用户读越来越旧的内容。门控在 lag<60s（IO bound 时先提 gp3 IOPS / CPU bound 时升实例）。
9. **大表 load IO bound 在线救**：gp3 IOPS 在线 `modify-volume --iops 15000`（30G 上限，500:1 比例限制 16000 报错）+ t3 `modify-instance-credit-specification unlimited`（解 credit 限速）。但稳态 apply 瓶颈是 vCPU、IOPS 救不了 → 升实例。
10. **多 agent 协作铁律（撞车血教训）**：① 长 load/dump 任务 idle ≠ 卡死（30min dump、1h load 都正常），先问"在等什么"再决定换人；② **禁为同一 mutating 任务并发 spawn 第二 agent**（误判 idle spawn ops-takeover 与 ops-2 撞车 DROP/CREATE 同库 + 双 dump 打 master）；③ 一 region 一 ops owner 严格只碰自己 region；④ AWS 层加速（IOPS/instance）vs MySQL 层（load/replica）可分层让两 agent 不撞。
11. **fresh spawn agent 必先读状态档**：新 agent 不继承上下文，会重问 profile（`--profile nw-dev`）/region(eu-central-1)/VPC/peering/复制账号/dump 位置——全固化进 REPLICA-BUILD-STATE.md，禁再问。owner 揪"compact 之后全忘了"。
12. **systemd drop-in 切 slave.url**（不动 application-prod.yml）：`/etc/systemd/system/newworld-web.service.d/slave-datasource.conf` 注入 SLAVE_URL/USERNAME/PASSWORD，可回滚（删 drop-in 重启回 master）。EU 升级时先回退 master 保用户再升 replica。

## owner mindset 破局（本 sprint 多次）

VPC peering 没用上（传公网卡死）/ EU 快 US 慢（credit 耗尽）/ 公平性（两区同型）/ "compact 全忘了"（状态没固化）—— **每个都是 owner 一句话揪出 agent 执行盲区**。execution 这趟极不顺（spawn 撞车 + 截断 dump + GTID + 公网传输 + IO 瓶颈 + 实例太弱，逐个剥），EU 一气呵成证明 SOP 对、US 被那台累瘫实例拖一整天。

## ★ ROI 验证结论（5/31，双源实证，详见 `docs/sprint/2026-05-29-peak-perf-debate/REPLICA-ROI-FINDINGS.md`）

**MySQL replica 建好但对现流量零受益**（双源：US/EU replica Com_select **0.03 q/s**=空转 vs HK master 465 q/s；nginx urt 三段持平 145/191ms 没变快）。**真瓶颈 = 跨洋 Dragonfly(Redis) 读**：urt p50 US 145ms ≈ US→HK Dragonfly RTT **141.7ms**、EU 191ms ≈ 188.7ms，**1:1**——每请求 ~100% 是跨洋读 HK Dragonfly 这一跳（feed/cohort ZSET/cache 全在 HK）。根因：**重缓存系统跨洋成本在缓存层(Dragonfly)、不在被缓存吸收的 DB 层(MySQL)**。

**决策**：① MySQL replica 保留作 readiness/failover/未来地基（不回滚）；② **真正的多 region 延迟优化 = Dragonfly read-replica**（df-v1.38.1 原生 replicaof，0 slave，可行；难点=app 层 Redis 读写分离自定义路由，写/锁/ZSET写留 HK master）独立 sprint；③ settings 996ms 走缓存优化非 replica（慢在未缓存 ad/domain/vid，p99 少数）。

**6 条血教训**：① **replica 要 replica 对的存储层**（重缓存系统选缓存层 Dragonfly 不选 DB）② **上 replica 前先 profiling 定位真瓶颈+量化占比**（我从"DB N+1 996ms"顺手做 MySQL replica，没看占比=p99 少数 + 缓存多重）③ **urt≈RTT 是跨洋-bound 金标** ④ 多源交叉(Com_select+nginx urt)才拍真相 ⑤ **sub-agent 报"X 不存在"必独立二查**（ops 两次错：EU web 错认 replica IP / "ReadWriteDataSourceConfig 类不存在"实际主仓+28worktree 全有，差点重写已存在类；派 sub-agent 纯采数禁下结论）⑥ 部署目标必对齐测试范围（误部署 HK 生产被 owner 揪回）。owner 一句"需要为 dragonfly 也做 replica 吗"把主矛盾从 MySQL 拨正到 Dragonfly。

## ★ RUM 欠采样纠错 + 三臂测试真相（6/01-02，owner fact-check 推翻）

**owner 从 admin 后台揪出"flowzone 流量不止 RUM 的 9 条"→ 三源对账推翻我"flowzone n=9 真用户没走方案2"的错判**：
- **三源**：admin DB(权威 PV/UV) flowzone 5/30 PV784/UV108、今 UV53；US+EU origin cf.log ~2170 req(CN 2107，真路由 LAX/SEA/AMS/LHR 欧美主 POP)；**RUM 仅 n=9**。
- **根因 = flowzone 子域专属 beacon bug**(🟢实证)：eduspace beacon/PV=66%(RUM 正常)，**flowzone beacon/PV=0.5%**(1742 页面加载只 9 beacon)；`/api/v1/analytics/*`+`/q/tally` 几乎没被调用 = beacon 没发出(非归并 bug 非探针旁路非全局欠采样)，疑 LB-geo 路径 CSP/CORS/某 API 失败，待真机抓 console/network 定位。
- **admin DB 权威重核全平台分布**(近 3 天 PV 14.1M/UV 1.93M/100 域)：生产域 96.95%PV→HK / 17.rip 2.75% / eduspace 0.30% / flowzone 0.011%；多 region 测试臂合计 0.31%PV、单 HK 99.7%。旧"97.67% CN→HK"方向对但来自被污染 RUM(蒙对)，现 admin 权威钉死。
- **★ 三臂测试真相**：测试本就拿 3 专属域做对照、**与全局流量份额无关**；3 域样本基数都够(17.rip 387k/eduspace 42k/flowzone 1.58k PV)，**唯一 blocker = flowzone beacon 坏**(修了三臂 RUM 对比立即成立，不需引生产流量)。
- **教训(沉淀)**：① **RUM 是采样信号、有 per-domain beacon 覆盖盲区**，流量量级类结论必须 admin DB(服务端 PV/UV)兜底、RUM 只作性能辅证；② 单一信号源下结论是反复犯的错(CLAUDE.md 多源 cross-check 铁律)；③ owner 后台/印象 fact-check 两次碾压 agent 单源 RUM。**所有 REPLICA-ROI-FINDINGS 的 RUM 数字需带此 caveat**。

## ★ us/eu region 曾 backend-only 大坑 + flowzone beacon RCA（6/02，治本闭环）

**owner 让 RCA "flowzone 子域 beacon 不上报(0.5% vs eduspace 66%)"→ 真机 chrome-devtools 挖出真因严重得多**（原 CSP/CORS 假设证伪）：
- **真因 = us/eu region origin 当初只部了 newworld-web 后端、漏部 frontend-web/dist + OpenResty 前端静态层**。打 `gg001.flowzone26.top/`(设 __e2e=7rip 跳探针) document 返**后端 JSON 404**(`content-type:application/json`,`x-poc-origin:us-west-2`)，`/`/`index.html`/`sw.js`/`assets` 全 JSON 404 但 `/api/*` 正常 → cloudflared catch-all 直怼"只有后端没前端"的 web → 浏览器拿 JSON 404 当页面、`#app` 不存在、零 `<script>` → SPA 永不挂载 → web-vitals/analytics JS 没机会跑 → beacon 不发(console 零报错，因为没 JS)。
- **0.5% vs 66% = 落 HK(有前端) origin 份额差**：flowzone `country_pools[CN]=[us,eu,hk]` 取首位钉 us-pool(无前端)，只 ~0.5% 漏到 hk 才发 beacon；eduspace 单 tunnel 100% 落 HK 故 66%。
- **💣 这是方案2 rollout 的功能性 P0**：方案2=生产 CN 切流目标架构，**当前 us/eu 不发前端 → 若切生产 CN 落 us/eu 真用户整页 404**，不止 RUM 瞎。**多 region 节点必须前后端整套同构(OpenResty :80 root dist + SPA fallback + /api→本机:7777 + guard.lua)，不能只部后端**。
- **治本闭环(6/02)**：① us/eu 补前端层(scripts 同步 dist + OpenResty :80) ② 核 upstream 指本机 127.0.0.1:7777(owner 揪，确认对、无 HK 硬编码) ③ 版本对齐三处全 `2b7d5d4e`(ops 图快用本地 b73947e2→纠正同步 HK 生产版，防三臂版本分裂混淆变量) ④ 验收 HK/US/EU `/`=text/html+version.txt 一致、flowzone 外网 text/html。**REPLICA-BUILD-STATE「US/EU web」实为 backend-only，已纠**。
- **教训**：① RCA 顺藤摸瓜"一个问题进一类问题出"(beacon→多 region 地基缺前端 P0) ② 多 region 节点 full-stack 同构铁律 ③ 补 N9E 告警(region origin `/` 返非 text/html 即告警) ④ ops 图快用本地 build 违"必同步生产 dist"铁律、owner-mindset 主动揪。详 `ACTION-flowzone-beacon-fix.md`。

## ★ 缺陷②：us/eu 漏装 categraf → RUM 进不了 VM（6/02 夜，第二个同源 region-parity 缺陷）

补完前端层后 flowzone RUM 仍 n≈0。对账揪出**第二个断点**：
- **断点链**：beacon→us/eu web :7777 后端(写本地 Micrometer `nw_vitals_*{rum_host=flowzone26.top}`)→:18080 actuator(数据在)→**❌ categraf 缺(us/eu 从未装)**→VM。origin 收 2400+ beacon 但 VM 只有 HK 漏量 ~3。
- **修复**：us/eu 各装 categraf，scrape `127.0.0.1:18080/actuator/prometheus`，writer→`https://n9e.17.rip/prometheus/v1/write`，global.labels `dc=aws-us/aws-eu`+hostname `nw-us/eu-web-01`（抄 HK aws-web-01 基线，HK 零改动）。**VM 闭环实证**：三臂 `host`+`dc` label 可区分 us(flowzone fcp=50)/eu(15)/hk 漏量(2)，eduspace 同样分离。
- **★闸门标尺教训**：flowzone 低流量测试域(admin DB ~784PV/天≈0.5次/min)→ 拿 "30s :18080 count 在涨" 当装 categraf 闸门是**错标尺**，致 ops 误判"实验已结束、不装"(越界结论)。**真闸门 = ":18080 有无 flowzone nw_vitals series"(count=84 即 PASS) + routing 活(live curl 拿真 SPA)**。低流量域禁用短窗口"涨没涨"判存活；grep beacon 必用真端点 `/api/v1/analytics`(非 `/q/`)。多 agent 数据冲突(deploy 报 2400+ vs ops 报 ~0)按铁律不选边、main session live curl 自查仲裁(21:20 峰窗拿真 SPA→实验在跑、ops 错)。
- **★顶层教训 = region 节点 parity checklist**：缺陷①(前端层)②(categraf)同源——**建 replica region 无"与 HK 同构清单"做闸门→漏一层补一层**。**方案2 rollout 前必落 parity checklist**：后端+cloudflared + 前端 OpenResty:80+dist + categraf scrape:18080→VM + 日志路径(OpenResty web.log 非旧 nginx cf.log) + N9E 告警(region origin 非 text/html / region 无 categraf 上报)。
- **最终硬验收 = 今晚峰窗累积**(VM 三臂 count 涨 + 真 TTFB/LCP 差值，cron 785dea33 @6/03 10:00)。当前=管道全通，非对比结论已出。详 `ACTION-flowzone-beacon-fix.md`。

## 待办

- **N9E 告警两条**（owner 待排期）：region origin `/` 返非 text/html + region 节点无 categraf 上报。
- **★ Redis 异地多活 sprint 已收口（2026-06-02 夜，`docs/sprint/_archive/2026-06-02-redis-geo-ha/SPRINT-FINAL.md`）**：5 方 barrier-crossfire 结论=**现在不该做 active-active**（无真多活需求：唯一多地写同 key=stats，app 层加 region 维 key 消灭即可，不需 CRDT 引擎；换引擎 0/3 门槛 ROI 负）。**唯一用户可见跨洋写=feed markSeen**（`SessionFeedService:249-251` 每翻页同步 SETBIT，非 beacon）；stats=客户端 fire-and-forget 不进 urt；锁/cohort指针/pub-sub=admin 单写者无冲突。**硬 gate=先 prod 实测 markSeen 占翻页 TTFB %（必 us/eu 采）**：<15ms 不做/15-50ms 点解/>50ms 升级，三档都不换引擎。**🔴 必修 latent bug**：前序 read-replica 定稿误判"feed 整连接纯读卸 replica"，但 markSeen 是写、必留 master → replica 白名单必到 **call-site 粒度**（getBit→replica/markSeen→master）。pub/sub 跨 region 裁定=**version-key 轮询**（避静默断连坑）。**2-region pivot 真相**：97.5%→30% 漏算 admin（仍在 HK），完整治本=DB master+admin 双搬。
- settings 计算缓存优化（独立、正交、立即可做）。
- replica lag N9E 告警（US+EU Seconds_Behind_Source >300s + IO/SQL≠Yes，进行中）。
- 明早 10:00 cron：replica 前后 origin_db 对比（切换时刻 US 20:27:33Z/EU 20:36:37Z 切 before/after）+ 三臂网络腿。**真正公平的峰窗 before/after 要等下次峰窗**（今晚切换都在 post-peak 04:27/04:36 HK）。
- 关联：[[project_db_migration_2026_05_27]]（同 master aws-db-poc）+ [[project_peak_perf_debate_2026_05_29]]（三臂测试 + replica 前置结论）。

## ★ 6/03 10:00 三臂峰窗复跑（前端+categraf 修复后首跑，THREE-ARM-REAL-DATA-VERDICT §9）

> 6/02 峰窗(20-03 HKT=12-19Z) us/eu 前端层+categraf 修复后首次重跑。多源对账：VM RUM(by rum_host) + admin DB site_daily_stats(PV/UV 权威) + us/eu origin 只读。

- **① beacon 🟢 恢复(真)**：三独立信号一致——flowzone HK by_pop n **9(72h)→67(单峰窗)**；by_pop 1h 时序 **14:00Z(22:00HKT)阶跃**(45→184→1420→3844→1716)=修复落地点；us/eu plain 桶 0(14Z前)→数百/h。admin DB flowzone PV **6/01=293→6/02=1379→6/03=40579/UV3629**(本夜注入真流量，与 eduspace 21386 同量级)。**但精确 beacon/PV % 算不出**——`_by_pop_*`(带 rum_host)series **只在 dc=aws-hk**，us/eu categraf 发 **plain bucket 无 rum_host**→flowzone 落 us/eu 的 beacon 与 eduspace 混桶不可按臂拆。
- **② 三臂对比 🟡 部分成立**：同 build(`DK1rgbO7.js`)+真 SPA+flowzone 有真流量=可比前提满足；HK by_pop 切片(就近小样本)17.rip ttfb504/lcp2278 n15820、eduspace 566/2887 n1392、flowzone 402/1749 n67(最低但仅 HKG/SIN 就近、不外推方案2)。**网络腿/成功率/按臂 region 落点三项本窗全无源**。
- **③ 路由裁决 🔴 本峰窗判不了**：决定性证据(网络腿/成功率/按臂POP)全断，方案2 推荐仍只能靠合成+历史 cf.log origin 落点(§3)。
- **★★ BLOCKER(与 §8.4 同根、持续~15h 未恢复)**：US+EU origin nginx 仍 systemctl **inactive**(journal 实证 18:59:21 6/02=10:59Z 干净 stop 非 crash)；logrotate 00:00 把 cf.log→cf.log.1(末写 18:59HKT)，新 cf.log **整峰窗 0 字节零行**。但 **pre-stop openresty master(PID97817)+4worker 残留 LISTEN:80** 仍服务→真用户拿 SPA、web:18080 actuator 有 29381 vitals、categraf 直 scrape→VM 有 us/eu RUM(**这就是 RUM 通 cf.log 盲的原因**)。残留 worker 跑 stop 前旧配置=unmanaged ops 隐患。
- **教训**：① **RUM 通 ≠ cf.log 通**：categraf 直 scrape actuator 与 systemd-nginx 访问日志是两条独立链，nginx 停了 RUM 照样有、但网络腿/成功率(靠 cf.log)断。② **by_pop(rum_host) vs plain bucket 不对称**：HK 配了 rum_host、us/eu 没配→多 region 臂的 RUM 按臂不可拆，是下次峰窗前必补的 label。③ **counter-reset 坑**：categraf 14Z 重启使 `increase([7h])` 在窗末 instant 查 us/eu plain 桶返"-"(单样本/staleness)，query_range 时序才可信。
- **backlog(让下峰窗可拆)**：① us/eu `systemctl restart nginx` 恢复 cf.log(P0) ② us/eu categraf `nw_vitals_*` 加 `rum_host` label ③ us/eu cloudflared tunnel 指标纳入 VM(VM 现只有 dc=aws-hk tunnel)。

## ★★★ 上条三处误读纠正（6/03 owner push 只读复核，THREE-ARM §10，推翻上条处置）

> owner 反诘「别下 restart 结论先验」→ 逐项 SSH us/eu 只读核实，上条 §8.4/§9.4「nginx 停摆需 restart」+ §9.1「us/eu RUM 无 rum_host」**全是误读，根因不同**。

- **① OpenResty 真健康、不需 restart**：systemd 管的是 **`openresty.service`(active running)** 非 `nginx.service`(独立空 unit、一直 inactive)。openresty MainPID 97817(US)/76653(EU)=ps master ✅ 健康非 zombie；18:59 是 **(re)start 时刻非 stop**。上条「nginx 停摆、worker zombie、需处置」=**盯错 unit 名**。
- **② 网络腿/成功率/region 从 live web.log 就能算、免 restart**：US/EU :80 写 **`/usr/local/openresty/nginx/logs/web.log`**(US 383MB/EU 323MB、**实时写 mtime 10:19**)；`/var/log/nginx/cf.log`(上条读的)是**死 legacy 路径 OpenResty 从不写**——「cf.log 整峰窗 0 行」是读错文件幻觉。web.log `log_format main` **含 `urt=$upstream_response_time`+cf_ray(POP)+cf_country**(nginx.conf:17-20)→ 网络腿/按臂成功率/POP 落点全可 parse、覆盖整峰窗。**§9.4「cf.log 盲需 restart」作废**。
- **③ rum_host gap 真根因=categraf prometheus input 被禁用**(非 label 缺/非旧 build)：us/eu jar `/opt/newworld/newworld-web.jar`(5/31 13:01)，actuator **已输出富 label** `nw_vitals_*_by_pop{cfCountry,cfPop,rum_host=eduspace/flowzone}`(rum_host 出现 28179/24273 次)→**后端含 rum_host patch、label 齐**。断点=categraf：`journalctl -u categraf` 实证 **`prometheus scraping disabled!`**——进程 active 但 prometheus input 没生效、**从不 scrape :18080**→us/eu `nw_vitals` **零条进 VM**(VM 查任何 `dc=aws-us/aws-eu` nw_vitals=0 钉死)。§9 引的「aws-us n=924/eu622」是 VM 查询 artifact(不带 dc 标)、**作废**。flowzone 在 VM 唯一可见=HK by_pop n=67(就近小片)，真大头(落 us/eu)RUM 全缺。
- **修正 backlog**：① **修 us/eu categraf**(查 `prometheus scraping disabled` 根因→修好富 label 自动进 VM) ② 下轮网络腿/成功率/region **优先 us/eu web.log parse**(字段已全、免依赖 categraf) ③ **无需 restart**。
- **教训**：① 盯对 unit(`openresty.service`≠`nginx.service`、MainPID 对 ps master 才是健康判据、启动时间戳别当 stop) ② 读对 log 路径(`/usr/local/openresty/nginx/logs/web.log` 真路径、cf.log 死 legacy——与 feedback_frontend_deploy「真日志在 openresty logs」铁律同、第二次踩) ③ owner「别下结论先验」连救多轮 cf.log 误读。

## ★★★★ 再纠正：categraf RUM 确实进 VM（上条③「scraping disabled→VM 零条」也是误读，THREE-ARM §11.A）+ web.log 服务端三臂裁决（§11.B）

> owner 要 VM 原始 JSON 自己仲裁。重查带正确 label：us/eu series 齐全 fresh。**上条「VM 零条、categraf disabled 是根因」错。**

- **A 仲裁（categraf 进 VM=真）**：VM 查 `nw_vitals_lcp_ms_by_pop_count{dc=~"aws-us|aws-eu"}` **有数据**，每条含 `{cfCountry=CN,cfPop=AMS,dc=aws-eu,rum_host=flowzone26.top}` value=[1780453654=02:27:34Z 当下,"2392"]——**rum_host+cfPop+dc 全在、fresh 非 stale**。query_range 实证 us/eu lcp_count **13:30Z 起单调增贯穿整峰窗**(aws-us 14Z=207→19Z=4771→02Z=9451)。上条「VM 零条」错因=我那条 `{dc="aws-us"}`/`region=~` 查询用错过滤返 `[]`，不是数据没有。**`prometheus scraping disabled!` 是红鲱鱼**——来自 `prometheus_agent.go`(内建 remote-scrape agent，无关、确实关)，与 `input.prometheus/[[instances]]` scrape:18080(正常工作)是两套机制。**昨晚「VM 收到 us/eu fcp/lcp by_pop」=真，今晨「零条」=我误读**。→ **§9/§10 反复说的「us/eu 按臂不可拆」全错**：us/eu by_pop 带 rum_host、可按臂拆；cron 汇总应改查 `by_pop{dc=~"aws-us|aws-eu",rum_host=...}`(之前只查 dc=aws-hk 漏 us/eu)。
- **B web.log 服务端三臂(峰窗 12-19Z，按 referer 分臂，🟢)**：US flowzone **130346 req/96.5% ok/0 5xx**，POP=SEA70565+LAX53273(美西就近)；EU flowzone **74250/95.0%**，POP=AMS59725+LHR14167(欧就近)；HK 17.rip 340805/99.9%。origin urt：**HK p50=10ms(本地 Dragonfly)/US 150ms/EU 210ms**——us/eu 高的 140/200ms=跨洋 Dragonfly RTT(REPLICA-ROI 142/189ms 吻合)、与路由无关、单列。**减掉跨洋 Redis 后同 region origin 三臂 urt 持平(US 都150/EU 都210)→origin 处理无差异**。
- **B 裁决**：① **region 落点 方案2(flowzone)优**：LB geo 把 CN→欧美 POP 干净按地理分流到对应 region origin(美西→US/欧→EU)无混落；方案1(eduspace)单 tunnel 同臂 POP 跨 region 乱落(mesh 不可控)；单HK 全回 HK。② **成功率三臂同 region 持平、全 0 5xx**(US flowzone/eduspace 96.5/96.9%、HK 99.9%)，4xx 3-5% 是 beacon/探针非路由故障，方案2 无额外失败。③ **综合服务端维度 方案2>方案1>单HK**(落点最优+成功率不输)。但端到端快慢仍需 RUM(含 CF Anycast 接入腿)，HK origin urt 10ms 最快只因不跨洋、不代表对 CN 端到端更优(CN→HK Anycast 接入腿仍绕欧美 POP、那段在 RUM 不在 origin urt)。
- **真 backlog**：① cron 汇总加查 us/eu by_pop rum_host(数据本就在 VM，只是没查) ② Dragonfly replica 消除 us/eu origin urt 跨洋成本(D2 另一线) ③ **无需 restart、无需「修 categraf」**(上条作废)。

## ★★★★★ 端到端三臂落锤(6/03，THREE-ARM §12) — 方案2 真用户 RUM 终于背书

> owner 要每数字原始证据+交叉印证。解 §11.B 两尾巴：4xx 是否真无害 + us/eu RUM 端到端。

- **① 4xx 钉死=499 客户端中断、真 4xx≈0**：web.log 拆 status×path 后「3.5-5% 4xx」**全是 499(client closed connection，nginx 专属码，客户端自己断连非服务端失败)**。真 4xx(400/405)=**0.00-0.07%**，全是 BEACON(畸形 beacon 400)/SCANNER(405 扫描器 `/instatll`等)/个位数 APP-API，**零用户可见失败、零 5xx**。499 us/eu(3-5%)>HK(0.05%)是「跨洋慢→用户切页断连」二阶现象。**→ §11.B「成功率 96.5/95%」是被 499 污染的伪值，剔 499 后三臂真成功率全≈100%，多 region 零成功率代价。**
- **② us/eu RUM by dc(VM 实证)**：flowzone us TTFB p50=**372**/eu=**345**；eduspace us=**500**/eu=**532**(n=2582-9375)。**取数 caveat**：us/eu by_pop **VM instant histogram_quantile 可算，但 `increase([7h])`/window-range 返空**(VM 高基数 series window 评估限制，本轮多次踩)→us/eu 用 instant 累计(series 生于 6/02 13:30Z 至今≈测试期，非严格 12-19Z 峰窗)，HK 用严格 increase[7h]，口径不齐。
- **★网络腿=RUM TTFB−origin urt(web.log:HK10/US150/EU210ms)**：flowzone us 372-150=**222ms**/eu 345-210=**135ms**；eduspace us 500-150=**350ms**/eu 532-210=**322ms**。**同 dc flowzone 网络腿<eduspace**(us 222<350/eu 135<322)——与 §11.B「flowzone LB geo 干净就近 vs eduspace mesh 跨 region 混落多绕路」**两源互证**。
- **③ 端到端落锤：方案2(flowzone LB geo) > 方案1(eduspace 单 tunnel mesh) ≥ 单HK(17.rip)**。TTFB/网络腿 flowzone 全面最低、LCP 略优、成功率无代价、服务端落点最干净。**LB-geo「干净地理落点」真转化成真用户更低 TTFB+更短网络腿 → CN 切流推荐架构，真用户 RUM 这次终于背书(非仅合成)。** vs 单HK 方向≥但口径不齐(us/eu 累计 vs HK 峰窗)待下窗同口径复核。
- **单列项**：us/eu origin urt 150/210ms 含跨洋 Dragonfly(HK 仅 10ms)=Dragonfly replica 另一线，修了端到端再降~140/200ms。
- **待下窗(不硬下)**：① us/eu 严格峰窗 increase[7h] per-arm(series 满 24h+ 后 window-range 才work) ② cron 加查 us/eu by_pop instant histogram_quantile。
- **本轮方法论教训**：VM 同一 series **instant 查能出、window-bounded `increase([7h])`/range 返空**是 VM 高基数 series 真实坑——别因 window-range 返 NA 就误判「数据不存在」(今晨已因此误判一次)；`query_range` 宽扫 vs 窄窗 vs instant 三种取数对同 series 结果不同，关键数字必三法交叉。连环误读后 owner「每数字要原始证据+交叉印证」是对的。

## ★ 实施计划对齐（6/03，`IMPLEMENTATION-PLAN-cutover-replica.md`）— 三件捆绑

三臂裁决（方案2 赢）+ Redis sprint（replica + markSeen 异步）合并落地。**核心：三件一个捆绑、时序耦合，缺一切流更慢。**
- **耦合**：方案2 切流值得做（真用户网络腿 flowzone<eduspace<单HK），但**单做反更慢**（落 us/eu 真用户被跨洋 Redis ~993ms 拖死吃光路由收益）→ 必须 + Dragonfly read-replica（读就近 ~700ms）+ markSeen 异步（写挪出路径 ~283/373ms）。replica/markSeen 单做零收益（今 us/eu 无流量）。
- **时序**：Phase0 前置（replica+markSeen+pipeline 部署 us/eu，HK 不动，零收益）→闸门0（lag<60s+读路由 grep gate+markSeen 无 dedup 回归+failover dry-run）→Phase1 canary（删 country_pools[CN]+切 1 wildcard 渠道域→us/eu replica 已就位）→闸门1 金标（canary us/eu origin urt 150/210→个位 ms）→Phase2 灰度全量→闸门2（方案2 vs 单HK 同口径复核）。每步秒级可逆。
- **workstream**：A Dragonfly replica ~5-8 人日（replicaof+app 层 per-call-site 读路由白名单+pub/sub version-key 轮询 B+failover 联合单元）/ B markSeen 异步+串行读 pipeline ~1-2 人日 / C 切流 ~2-3 人日+观察。总 ~8-13 人日。
- **★ 待 owner 拍 4 决策**：① cohort 指针+ZCARD 读要不要下沉 replica（ZCARD v{seq}校验+lag fallback 就近多省 ~280/400ms vs 保守钉 master 仍跨洋，一致性 vs 延迟）② 2-region pivot 关系（本盘子按 HK-master 做、pivot-aware；US-master pivot DEFERRED；真 pivot 需 DB+admin 双搬）③ canary 选哪个 wildcard 渠道域+时间窗 ④ engine 确认 Dragonfly（不换 KeyDB/CRDB/MemoryDB，0/3 门槛）。
- markSeen 异步实证可行：`SessionFeedService:249-251` 是请求最后一个 op、当前请求不依赖其完成、客户端 IDB seenIds 兜底 dedup race（替代 sprint 选项 E 写本地化，更简单不依赖 replica）。

## ★ us/eu 生产化排查 + replica lag 监控迁声明式（6/03，owner 反诘拨正）

owner 让"核实 replica RAM 余量(为 Dragonfly 同机)"起,一路揪修 4 个 us/eu 同源生产隐患 + 把 lag 监控迁声明式：
- **DB replica 磁盘 100% 满**：binlog 30d 占 9G + 盘满 relay log 写不下会断复制。修：EBS 在线扩 29→58G + `SET PERSIST binlog_expire_logs_seconds=604800`(7d,别禁 log_bin,failover 要 promote 需 binlog)。**别因 Dragonfly 升 m5.2xlarge——瓶颈是磁盘不是 RAM**(US avail 13Gi/EU 9.5Gi 富余,Dragonfly 2.3G 同机够,前置只是扩盘)。坑:磁盘满时 `growpart` 需 `/tmp`,用 `TMPDIR=/dev/shm`。
- **replica lag 42h/33h**：磁盘满期间 SQL apply 积压所致(非复制断,IO/SQL=Yes);盘释放后追赶 US~9.5h/EU~5.5h。**切流硬闸门 lag<60s 现不满足,等追平。**
- **us/eu WEB logrotate 没生效**：logrotate.d/nginx 指 `/var/log/nginx/*.log` 但 OpenResty 日志在 `/usr/local/openresty/nginx/logs/`——路径对不上从没 rotate(web.log 548M,8G 盘 11/16 天撑满)。修：同步 HK `/etc/logrotate.d/openresty`(含 `kill -USR1` postrotate)+ 强制 rotate 一次降盘。**又一个 region-parity 漏项(前端层/categraf/logrotate 同根)。**
- **★ replica lag 监控迁声明式(owner 反诘"有 categraf MySQL 插件+N9E 还要 bash 脚本吗")**：原 `replica-lag-watchdog.sh`(过程式 + 手写 state escalation + "首次告警后静音"盲区致 42h lag 只推一条 Telegram)→ **退役**,换 **categraf + N9E**：
  - **根因**:categraf v0.5.6 默认发废弃的 `SHOW SLAVE STATUS`(MySQL 8.4 Error 1064)→ slave 指标采不到。修 = input.mysql 加 `gather_replica_status = true`(纯配置、没换 binary、既有 89 个 mysql_global_status_* 零回归)。aws-monitor 加 input.mysql 指 172.32.9.19+172.33.8.248(newworld 账号有 REPLICATION CLIENT,peering 可达)→ `mysql_slave_seconds_behind_source` 进 VM。
  - **N9E 规则坑(踩了一串才成)**:① yaml UI 导入失败"input yaml is empty"(我猜的 version/group/rules 格式不对)② DB 直写 rule_config 的 prom_ql 引号未转义→引擎 `invalid character` 静默跳过 ③ 正解=**N9E API**(root 登录拿 token,GET 现有 working 规则拿真格式:prom_ql 在 `rule_config` 里非顶层)④ POST 漏写 `datasource_ids`/`notify_rule_ids`→引擎不评估+无通知(对齐 working rule=`[1]`/`[1]`)⑤ VM 双层转义→PromQL 用 bracket `172[.]3[23][.].*` 绕开。**真 fire 实证 alert_cur_event id=2508 rule_id=101 trigger_value=72132**。bash watchdog `systemctl disable --now timer` 退役(脚本+备份留痕)。
  - **规范沉淀**:① **监控先用 categraf 插件+N9E,别自己写脚本造监控大脑**(N9E `repeat_interval` 原生复报,手写 state escalation 是重复造轮子)② **N9E 规则导入用最小增量文件别导全量 SOT**(全量 UI 导入会重建/覆盖其余 55 条)③ **程序化创规则走 N9E API 不走 DB 直写**(DB 直写 rule_config JSON 引号转义坑)④ N9E rules SOT=`ops/n9e-alert-rules.yaml`,API rule_id 101/102。
- **N9E root 凭证**：在 **aws-monitor `/etc/newworld/secrets.env` `N9E_ROOT_PASSWORD`**(按 secrets 铁律不落 git 明文);端点本地 :17000 / https://n9e.17.rip,busi-group newworld=2,datasource_id=1,notify ops-telegram=[1]。
- **产出**:`REGION-NODE-PRODUCTION-CHECKLIST.md`(方案2 切流前置闸门,A web/B DB/C Dragonfly/D 监控/E 清理,标 ✅已修/🔴待)。owner-mindset:一个问题进(RAM 余量)揪出一类(磁盘/日志/监控全是"新 region 按测试标准建非生产同构 HK"同根)。

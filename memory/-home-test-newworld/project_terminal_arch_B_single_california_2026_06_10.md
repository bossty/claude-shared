---
name: project-terminal-arch-b-single-california-2026-06-10
description: "终态多region架构owner定稿=B单加州+EU(砍俄勒冈),推翻FINAL-A 3区;master落加州"
metadata: 
  node_type: memory
  type: project
  originSessionId: 64b5f5d1-9590-4971-9f5b-8d2e351a83eb
---

2026-06-10 终态多 region 架构 **owner 定稿 = B：单加州 + 法兰克福，砍俄勒冈，HK 退役**。**推翻 [[project_arch_lock_california_2026_06_08]] 的 FINAL-A（3 区 + master usw2）**——FINAL-A 的"master 留 usw2 零搬运"是幽灵论据（实测 master 仍在 HK，从未迁出，5 源坐实：region-us/eu web `DB_HOST=172.31.19.174` + `@@hostname=aws-db-poc` + REPLICA STATUS 空 + AZ-STRATEGY 把 HK→usw2 列为未做 workstream）。

**终态拓扑**：加州 us-west-1（master + web×3，全 1a 单 AZ）+ 法兰克福 eu（web×2 + replica）。砍俄勒冈整 region。

**为什么 B 不是 A（3区）**：专家 team（routing/db-ha/cost-ops/history + 蓝军 7 条）证据驱动结论 = **俄勒冈 perf 优势仅 SEA −7.6ms（PDX 钉桩软值）、edge 优势实测 ≈0（tunnel-edge 落点独立贡献 ≈0，cf-tunnel-edge 铁律实证）** → 撑不起一个 region 的 ~$280/月 + 运维。A vs B 真实是 judgment call：A 多花 $280/月买"运维型故障(坏deploy/IO饱和)不同时端掉 web+master"的故障域隔离；**owner 选择不为这层隔离付费**（写仅 4.2%/~41TPS、master 死断写不断读、~8min runbook 切回），取简洁 + master 在主力区。**owner 接受加州全 1a 单 AZ 集中风险（B2 裸奔版）。**

**POC 为什么当初是俄勒冈不是加州（owner 深查结论）**：当初**没做 CA-vs-OR 对决**，US 当一个 66.6% 桶定主区；俄勒冈赢在 phase11 碰巧用的 $30 探针惯性 + 贴最大单峰 SEA + 便宜 + 误以为零搬运。加州对 LAX 47% 的 +46.8ms 优势直到 6-08 prod-tunnel 才量化。历史巧合非路由优选。非对称：砍加州罚 LAX +46.8ms(重)、砍俄勒冈罚 SEA ~7.6ms(轻) ⟹ 单 US 区应是加州。

**落地计划**：`docs/sprint/_archive/2026-06-10-terminal-B-migration/SPRINT-PLAN.md`（WS0 清三 replica errant GTID[CA b03992d8:1-5/EU 3b33fb1f:1-6326/OR 退役不清] → WS1 HK→加州 master cutover[PONR,owner签字+演练] → WS3 DB_HOST/REDIS_HOST 切加州 → WS5 俄勒冈退役 / WS6 CF geo 收 ca+eu / WS7 HK 退役）。failover = 手工+半自动 runbook ~8min（owner 6-09 §FINAL.2 已否决自动框架，不重开）。前置：EU+1节点、max_conn 500→600、SG-fence runbook 第0步。

决策全文 `docs/sprint/_archive/2026-06-10-terminal-arch-decision/VERDICT.md` + 4 臂 agents/*.md + 蓝军 reviewer.md。配套 [[project_california_region_build_2026_06_09]]、[[reference_cf_tunnel_lb_topology]]（拓扑需随俄勒冈退役更新）。

**★执行状态（2026-06-10，commit a8f7caea + dev 改动 887fd566..d7bef3cd）= 可逆准备全完成、PONR 待 owner go**：
- **已做完(可逆,已commit)**：repo 配置/代码/文档 staged 终态B（region-nodes俄勒冈注释/watchdog/ReplicaRedisConfig注释/CLAUDE.md标注/region-readiness-gate重写ca+eu）；WS1 runbook v2（演练D1-D6折入）；cutover-ws1.sh（隔离dry-run过）；prod脚本ready未apply（prod-ws6-cf-converge/prod-ws2-eu-provision）；mvn全绿。详见 `docs/sprint/_archive/2026-06-10-terminal-B-migration/EXEC-CLOSEOUT.md`。
- **二查裁掉WS4**：master只承写池(Hikari写池max20硬上限,读池80走replica不连master)→~160≤max_conn500余量340,无需抬;gate MASTER_MAX_CONN_HEADROOM=160。
- **真RTO(隔离演练)**：cutover写中断~3min(7节点JVM串行瓶颈)、读不中断、回滚~35s。EU errant 6326不阻塞START REPLICA(AUTO_POSITION),处置=rebuild(8.5s)>inject(44s)。WS0清errant方向=在HK master inject CA errant。repl账号需mysql_native_password。
- **owner决策**：亚洲country_pools→ca / EU web-02=m5.xlarge / **cutover低峰窗口待owner定** / Redis持久键(session token/push_subscription/visitor_fingerprint)cutover前定迁移策略+补S5演练。
- **待执行(owner-gated,人在环)**：WS0清errant→WS1 cutover(PONR)→WS3 DB_HOST切→WS2 EU+1→WS6 CF收ca+eu→WS5砍俄勒冈(不可逆)→WS7退HK(≥7天后不可逆)。cutover后172.31.19.174→CA master 172.34.1.239全96处文档批量更新。

**★cutover-prep 实战硬事实(2026-06-10 prod 实证,改脚本/runbook 必用)**：
- 特权访问:prod 无 root 密码,secrets.env 只有 app DB_PASSWORD+REDIS_PASSWORD。已把三台 DB root 配 **auth_socket**(HK 原生;CA/EU 经 `--init-file`+MYSQLD_OPTS 重启配,owner 授权)→cutover 特权 SQL 走 `ssh <db> sudo mysql`,非 `mysql -u root -p`。
- DB 主机:HK=`aws-db-poc`、CA=`aws-region-usw1-db`(172.34.1.239,MySQL8.4)、EU DB=172.33.8.248 **无固定别名**(i-0246036769dcc62d1,KeyName=None)走 **EC2 Instance Connect**(ubuntu@3.65.1.28,nw-dev 有权限;SSM 无)。`aws-region-eu/us` 是 web 非 DB。
- 复制账号=**`replicator`**(非 repl),re-point 省 SOURCE_PASSWORD 复用。Redis:CA(172.34.1.128)是 HK 全量 replica,S5 零丢失。
- **事故+铁律**:EU 重启撞满盘(58G FS 100%,21G binlog;EBS 早扩120G 但 FS 没 grow)→down,growpart+resize2fs 扩116G 恢复。根因 binlog 默认留 30 天(全 fleet),已改 3 天+purge;HK master 当时也 67%。**动 prod DB 重启前必 `df -h` 闸门**(加 cutover pre-flight)。
- cutover-ws1.sh/runbook 待改:`mysql -u root -p`→`ssh <db> sudo mysql`、`repl`→`replicator`、加 df 闸、EU 走 Instance Connect。EU+1+窗口待 owner。脚本已改 commit ac425d94(auth_socket/真DB主机aws-region-usw1-db+aws-region-eu-db/PF0 df闸/S4b 标注 HK 转replica 需 replicator 明文密码缺口)。

**★容量/拓扑右-sizing(2026-06-10 实测,纠正之前 over-size;详 docs/sprint/_archive/2026-06-10-terminal-B-migration/CAPACITY-TOPOLOGY-ASSESSMENT.md)**:
- 规格:CA DB=r6i.xlarge(4/32G,bufpool24G,数据27.6G,命中99.1%)+CA Redis 172.34.1.128=r6i.large(独立机,Redis master);EU DB=m5.xlarge(4/16G,bufpool**4G**,数据28.4G,命中**98.8%**)+EU Redis 同机(used3.89G/max4G)。HK r6i.2xlarge 退役。
- **核心洞察:working set≈4-8G 不是28G**(EU 4G池就98.8%命中→冷数据为主)→DB **不需要大内存全缓存**。之前"升r6i.2xlarge/≥32G"是 cache-everything+对齐HK 偷懒锚,**已纠**。
- **EU iowait93%事故真根因=盘满+IOPS节流(非内存饿)**,已修(盘39%/binlog3天/EBS16000IOPS)。
- **右-sizing结论(数据驱动不预升)**:CA r6i.xlarge 作 master 大概率够(写41TPS极轻/working set缓存/连接宽松),放量后看峰值CPU再定;EU m5.xlarge 盘修后够;DB/Redis分开=故障隔离偏好非容量刚需。**暂不花钱resize,钱留到峰值数据显压力/DAU涨大**。
  - **已做**:EU bufpool 4G→**6G**(在线SET PERSIST,非8G——实测mysqld暖满8G+dragonfly4.2G+OS≈13.2G/15.4G无swap太薄,6G留~4G余量更稳;working set 4-8G,6G够)。**EU DB+Redis 同机**(172.33.8.248,16GB),Redis maxmem硬cap 4G不会被挤,风险是箱级OOM非Redis;同机所以bufpool上限~8G,要更大须拆Redis离箱/换机但working set小不必。
  - **S4b replicator 密码缺口=方案①(commit 92c35cb3)**:HK本是master无已存复制凭证+无replicator明文→脚本PF4在HK master建专用账号`repl_cutover`(GRANT REPLICATION SLAVE)传播到CA,S4b用它+HK_REPL_PWD(运行时openssl生成不入chat/git);未设则回落方案③(S4b跳过HK留停机老master回滚源)。EU(S4a)不动复用已存replicator。
  - cutover脚本commit:ac425d94(真实模型)+92c35cb3(repl_cutover)。

**★★★compact 后接手入口 = `docs/sprint/_archive/2026-06-11-migration-sequence-redesign/SESSION-HANDOFF.md`**（整轮会话所有结论/方案/进度/决策/原因/教训/prod硬事实/全commit链/Phase C执行清单的单一权威记录，无需重新对齐）。

**★★迁移序列重大重设计(2026-06-11,commit 97015922,docs/sprint/_archive/2026-06-11-migration-sequence-redesign/MIGRATION-SEQUENCE.md)——之前的"WS1 搬master"是窄化错误,已废,改 traffic-first 完整序列**：
- **根因教训**:把"终态迁移"窄化成"搬master+3 region节点",**漏了承载全部真实流量的 HK 层**(aws-web-01/02 主流量web + admin/data 全 DB_HOST=REDIS_HOST=HK 无读写分离;region web CA×3+EU 的写池也指 HK)。owner 亲揪 2 showstopper(G1 HK web写断/G2 admin跨洋),lead 补 G3(Redis同理)。10:00 HKT 自主 cutover **已取消**(单搬 master 会把主流量写打只读replica)。
- **verdict=traffic-first**(三方+蓝军一致):先排空 HK 用户流量→再搬 master,使"流量节点写错库"结构上不可能(非靠原子切N host)。相位 0→[A opt,排空后省略]→B(就绪门)→C(流量灰度迁CA/EU+admin scheduling.enabled=false静默)→C.5(写吞吐预算门:峰值写TPS<134/region×0.5,现41TPS<<134)→D(PONR cutover-ws1.sh **必扩成四重补强**:executor队列归零+Redis单点切+多节点原子repoint含admin/data最先切+graceful drain)→E验收→F admin/data落点→G OR/HK退役。
- **完备性铁律生效**:blue-team completeness-critic loop两轮(Round1揪11条含团队全漏的G4/G5/G6,Round2=0新BLOCKER=dry)→共18破坏点全归位。关键:BREAK-12 EU写池drop-in空回落80(G5解耦只在CA做漏了EU)→补20;BREAK-13 data池=10跨洋吞吐塌→补20;CA max_conn=300(非500)汇聚修后160/300无需抬;data池实测=10(非50,node-routing自纠+蓝军复核交叉验证起作用)。
- **去险**(stateful-deps实测纠CHARTER陈旧前提):DNS自动摘除已不存在(Tunnel模式只Telegram);切Redis master不登出全站(JWT无状态/secret在DB/push_sub在MySQL)。
- **cutover-ws1.sh 待扩**(现仅promote master,远不够)。方法论沉淀:迁移设计必从全节点×{DB读写,Redis读写}矩阵入手、揪头发看"流量在哪层";owner反诘=严肃缺口信号(两次都对)。

**★执行前置进展(2026-06-11夜)**:
- **Phase 0 已做**:EU web(aws-region-eu)写池 drop-in `SPRING_DATASOURCE_HIKARI_MAXIMUM_POOL_SIZE=20`(修BREAK-12,在线重启验证 /api/config /均200健康)→CA汇聚280→**160/300 headroom47% 无需抬max_conn**。
- **cutover-ws1.sh 扩(commit 570405dc)**:①★真bug修 S6健康检查 curl:7777/actuator/health 返404(actuator未在:7777暴露,:80经OpenResty SPA才200)→改 systemctl is-active+端口响应非000;②G4 APP_NODES重排 aws-data最先切(admin:8888+data:9999双unit);③BREAK-13 data切DB_HOST同份drop-in加池=20。
- **待扩(下一焦点pass)**:executor-zero(I4)**需先解决metrics端点**(actuator:7777不可用,执行器队列指标取不到);EU Redis maxmem(G7)pre-S5运行时;ss-verify(S7连接实证);EU+1节点(Phase0,重/影响CF,单独provision)。
- 真健康信号=`/api/config`或`/`返200(非:7777/actuator/health 返404)。
- **★actuator/metrics 端点实测(commit 10f7da46)**:web actuator 在**独立管理端口 :18080**(bind127.0.0.1,application.yml:33-41 exposure 只开 prometheus,health;:7777 无 actuator)。健康=`:18080/actuator/health`{status:UP};指标=`:18080/actuator/prometheus`(/actuator/metrics 没暴露)。I4 执行器队列信号=`executor_queued_tasks{name=...}`。**statsAsyncExecutor=queueCapacity50000+DiscardOldestPolicy 有损缓冲(WebStatsAsyncConfig.java:83-84),实测稳态queued~49999**→I4"等队列==0"对它是错的,只 gate must-not-lose(syncGateBulkhead等AbortPolicy fail-open/feedAsync,现全0),statsAsyncExecutor 尾巴 super_read_only 后丢=可接受stats缺口(owner认)。脚本S0.5 I4门已加。
- 脚本commit链:ac425d94+92c35cb3+570405dc+10f7da46+c430997d(四重补强余项)。
- **EU+1 已 provision(commit 8b05553a)**:第2台EU web=i-0bb6939092aac3cb5/172.33.10.241/35.159.128.77/m5.xlarge/eu-1a,从现EU web克隆AMI(ami-0729994f24d74ac34)起,web+cloudflared active serving,写池20+DB_HOST=HK继承,cloudflared同A-EU-tunnel token=第2connector隧道HA。EU现×2满足每区≥2。ssh别名aws-region-eu-web-02(本地,克隆已含aws_region key,公网IP动态cutover前复核);已接线 cutover-ws1.sh APP_NODES+I4_WEB_NODES + region-nodes.conf EU2。
- Phase B/C灰度runbook=docs/sprint/_archive/2026-06-11-migration-sequence-redesign/PHASE-B-C-RUNBOOK.md(41346f62)。
- 方法论:right-sizing 看 working set(命中率)不看总数据量;别按"对齐现有大机"锚定;iowait 先查盘/IOPS 别默认内存;owner反诘"配置要这么大吗"=右-sizing信号,实测后确 over-size。
</content>

---
name: project-phase-c-execution-2026-06-11
description: 2026-06-11/12 Phase C 完成(A66+P62+C4全迁CA/EU region 5xx=0)；★Phase D(master cutover HK→CA)2026-06-12 失败+已回滚事故(S5 redis-cli卡死→fence漏回滚SG→502/503)。compact后必读 docs/sprint/_archive/2026-06-11-migration-sequence-redesign/MASTER-HANDOFF-2026-06-12.md
metadata: 
  node_type: memory
  type: project
  originSessionId: 64b5f5d1-9590-4971-9f5b-8d2e351a83eb
---

2026-06-11 **真执行了 live 生产流量迁移**（不只是设计）。compact/新会话接手必读 `docs/sprint/_archive/2026-06-11-migration-sequence-redesign/SESSION-HANDOFF.md`（★★★ 段）+ `terminal-tasks/PHASE-C-EXEC-LOG.md`（live prod 状态权威）。

**已对 live 生效**：
- **Phase C A 域批灰度 66/66 = 100%**：C0→C1(2)→C2(7)→C3(20)→C4(20)→C5a(15)→C5b(17.rip 主站)，6 批全程 5xx=0，A 域 CNAME tcos→tcos-canary、用户流量迁 CA/EU。CA/EU 实时承接正常(5 节点 200/5xx=0/CPU 9 成空闲)。
- **admin+data `app.scheduling.enabled=false`**（aws-data systemd drop-in `scheduling-off.conf`，relaxed binding env var）——恢复=删 drop-in+restart（Phase F 联动）。
- **全局回滚 durable**：已迁 A 域回滚=apex+wildcard CNAME 改回 `tcos.dnsv106.com`（唯一例外 techplatform447.top→HK tunnel 63594ad3）；即 /tmp 快照丢也可重构。

**HK 未排空（关键，Phase D 前提未达成）**：A 迁完后 ssh HK 实测 **62 active P + 10 active S 域仍在 HK**（P=4×A 主流量 3.98M UV/7d，cf_ray 实测 US-west 65%/EU 27%/Asia 6%=CN 经海外 colo 进 CF）。

**⚠️ 路径 A 已死（2026-06-11 C-P0 真切推翻）**：原 C-P 设计"P 域跨账号 CNAME→tcos-canary"**生产真切=CF 1014 Cross-User Banned 硬失败**（apex+子域均中，秒回滚，旧"xtestca 探针实证"纠为误报）。根因=tcos-canary 在账号 A、P 在账号 9a1d6632，跨账号 CNAME 指 proxied 记录被 ban。

**B1（单 tunnel 多 region connector）也死**：CF 全文档扫官方否定——replica 无 traffic steering、就近+仅失败 failover、无控制杆。

**★终方案=方案①（已冻结 barrier CLOSED）**：在 P 账号 9a1d6632 内建 per-region tunnel(P-CA/P-EU connector 跑 region 节点)+CF geo Load Balancer(region_pools NA/Asia→CA、EU→EU,[主,备]failover)+origin proxied 间接层(p-ca-o/p-eu-o CNAME proxied=True→UUID,镜像 A 的 origin-ca proven 模型)；P 域 apex+wildcard CNAME→P-LB(同账号无 1014)，逐域 flip 复用 CP1-5。runbook=`terminal-tasks/PHASE-C-P-OPTION1-RUNBOOK.md`(2轮蓝军+lead终核冻结)。机制依据=A 域 tcos-canary 已 live 同款(steering=geo,lead 实测 LEAD-PROD-FACTS-PS ★★LPRO-B)。S=不动(edge VPS 层,归 Phase F)。
**★2026-06-11 夜已执行完成**：owner 确认方案①、买 lbedge.org(NameSilo P)加 CF P 账号(zone 配置镜像 A:SSL/CAA/DNSSEC)、开 LB add-on+加 token LB:Edit 权限。lead 主会话建 P-CA/P-EU tunnel(connector 跑 region CA×3/EU×2)+origin-ca/eu/hk 间接 CNAME(proxied)+geo LB `p-lb.lbedge.org`(2 monitor /actuator/health + 2 pool,region_pools 镜像 A)+standby `p-lb-bak`(含 HK fallback)。命名全对齐 A。**62 P 域夜间 cron 心跳自主 6 批(2+6+15+15+15+9)切 CNAME→p-lb.lbedge.org，每批观察后推进、全程 5xx=0**。终验全 62 P+66 A region 正常、A 域 17.rip 200。详 `terminal-tasks/PHASE-C-P-OPTION1-EXECLOG.md`。
- **执行中纠 runbook 4 假设**(实读 A LB 实配)：monitor=/actuator/health 非 settings/version；pool 不 override Host(用户原始 P 域 Host 透传)；monitor Host=origin 自身名(匹配 SNI 否则 403)；region_pools 只 A 的 7 region(SAM 非法)。
- **新铁律**：guard.lua GAP-9=lbedge.org 内 infra-host 首段必 ≤10 字符(p-lb-standby 12 字符被 444 丢弃,改 p-lb-bak;用户内容域不限)。

**剩余(owner-gated,非今夜)**：admin/data scheduling 恢复(Phase F)；HK 真排空终确认；Phase D(master cutover HK→CA cutover-ws1.sh)→E→F(admin/data 迁 CA)→G(HK 退役+删旧 P-tunnel 1af743b6+代码硬编码清理)；S 域(10)走 LA edge 归 Phase F。

## ★2026-06-12 后续(全详情见 docs/sprint/_archive/2026-06-11-migration-sequence-redesign/MASTER-HANDOFF-2026-06-12.md)
- **C 类4域(账号0672a94a,tunnel a92dcc44)也迁完**(方案①连接器,region cloudflared-c metrics:20254,停HK)。admin/data scheduling **已恢复**。所有服务器本机直连(EU DB=ubuntu@3.65.1.28 Instance Connect装常驻key+别名;删死别名aws-db/nw-us-db-replica)。AWS凭证=`AWS_PROFILE=nw-dev`(命令必带--region,SG在ap-east-1/EU实例eu-central-1)。
- **★Phase D失败事故(2026-06-12)**：DRY_RUN=0跑cutover-ws1.sh→pre-flight全过→**卡死S5**(redis-cli主机没装+脚本本地跑够不到内网Redis IP)→S6从没跑→**fence已revoke HK SG 0.0.0.0/0:3306**→region web(172.34 CA)被挡在HK DB外→**接口批量502/503+图片挂**。lead两失误:RCA先错怪DB只读(实测region web 0只读错/reads全200,只admin调度写撞只读)、回滚漏re-authorize SG。**恢复**=解冻HK super_read_only OFF+`aws ec2 authorize-security-group-ingress --region ap-east-1 sg-0f78086b48f545846 tcp 3306 0.0.0.0/0`+重启HK web→站点恢复。
- **残留待清**:CA孤儿master(revert时replicator密码`Repl!c@t0r_nw2026`被拒疑轮换)/EU binlog purged需重建/CA Redis孤儿master(REPLICAOF NO ONE)。
- **★2026-06-12 残留已全清(都验证过)**:① CA MySQL=改密码(doc值本就错非轮换)+注入空事务跳过1524(CA缺mysql_native_password插件)→健康追平;② CA Redis=python raw-socket(无redis-cli) REPLICAOF回HK;③ EU MySQL=**MySQL CLONE物理重建**(errant 3b33fb1f:1-6326+1236 purged双问题,改密码/skip修不了必须整盘);④ EU Redis本就是HK slave。剩俄勒冈Redis孤儿172.32.9.19归Phase G。
- **★region replica跨洋重建SOP(将复用)**:别用`mysqldump|mysql`逻辑(逐行重放+建索引=随机I/O单流,实测0.7MB/s,fsync首瓶颈)→用**MySQL原生CLONE INSTANCE物理页拷贝**(实测395MB/s/560×,32GB~3min)。要点:版本+OS+arch必一致;两端`INSTALL PLUGIN clone`在线免重启;donor建BACKUP_ADMIN账号;recipient`SET GLOBAL clone_valid_donor_list`+`CLONE INSTANCE FROM`;自动重启需systemctl兜底;保留recipient自身server_uuid不撞;GTID自动对齐后直接`CHANGE SOURCE AUTO_POSITION=1`。脚本范本docs MASTER-HANDOFF §C。
- **★私网+编排教训**:跨region有私网直连(EU172.33→HK172.31:3306 OPEN via TGW路由`172.33.0.1`),传输走私网别走公网;**`ssh A "...|gzip"|ssh B "gunzip|mysql"`=拿本机当中继=双跨洋公网**(owner"是走私网吧"点破);**pkill -f用char-class(`[g]unzip`)防误杀自身shell致管道孤儿化**(本次孤儿v1+v2两写入器撞同一EU库,中途发现止血)。诊断顺序:吞吐慢先`iostat`看iowait+`aws ec2 describe-volumes`看盘规格,别凭单次网络采样下"盘限速"结论(我误判过一次,实为flush空窗)。
- **Phase D重试5洞**:①S5改ssh到redis主机python raw-socket发REPLICAOF(已验可行) ②回滚必re-authorize fence的SG ③dry-run测不出S5先单独真测 ④502/503先查SG/network非DB只读 ⑤replicator真密码待查。
- **★2026-06-12 Phase D 9洞已补(commit 453b64b2,cutover-ws1.sh)**:蓝军crossfire后,owner定**砍掉SG fence**(三-CIDR只撤0.0.0.0/0=切CA读漏EU写=事故根因;super_read_only才是真停写,SG fence冗余只带blast radius)→trap改纯解冻HK。洞7 CA启用mysql_native_password(实测ACTIVE)+PF5.5门禁;洞8 S3 promote加SET PERSIST durability 1/1(CA replica期2/0当master崩溃丢数据);redis全改ssh python raw-socket。详见 docs MASTER-HANDOFF §G + agents/reviewer-phase-d-retry.md。
- **★OS异构铁律(2026-06-12实测,动region DB级ops前必看)**:**US加州(db/redis/web×3)=Amazon Linux 2023(user=ec2-user/svc=mysqld/cfg=/etc/my.cnf)**;EU+HK=Ubuntu(user=ubuntu或web节点newworld/svc=mysql/cfg=/etc/mysql/)。app web服务名三OS统一=newworld-web.service。教训:按单一OS路径改配置会绕大圈(CA加mysql_native_password误加/etc/mysql白折腾,实际读/etc/my.cnf);owner定不为洁癖滚动重建live节点(CA/EU web承接全部流量),异构保持+脚本ops做OS-aware。region建时没统一环境是欠账。
- **新铁律**:[[feedback_verify_not_recall]]——region web批量502=被挡在DB外(SG/network层),非DB只读;DB只读只挂同步写/admin调度,region读纯SELECT照常。

**方法论**：owner 三次反诘全救场(scope/HK排空/跨账号)→prod 实测>doc(aws-s/容量/cross-account 多次纠 doc)；BSP 多 agent+lead 二查；traffic-first 逐批可秒回滚。专家团队(arch-f/ramp-c/accept-de/bluearmy) **未解散**待命。见 [[project-terminal-arch-B-single-california-2026-06-10]]。

## ★2026-06-12 OS 统一工程 + Phase D 就绪（compact 后必读 `docs/sprint/_archive/2026-06-12-os-alignment/SESSION-HANDOFF.md`）
- **owner 令**：所有 aws 服务器 OS **版本统一 Ubuntu 26.04** + 时区全 **HKT**。team `osalign`(arch/webops/bluearmy) 出 OS-ALIGN-PROGRAM.md FINAL。owner 拍 D1-D6 全准。
- **已完成**：D1 replica_skip_errors 统一 OFF(CA 生效/HK 待 Phase D 重启/EU 本就 OFF)；**新 CA DB 172.34.1.222 Ubuntu 26.04 建好**(从 HK CLONE+全配置对齐,取代旧 AL2023 .239,别名 aws-region-usw1-db 已 repoint .222)；**D3 web 全 Ubuntu 26.04**(CA×3+EU×2 新节点,外部 hammer 200,旧 5 台 D6 退役 stopped+AMI delete-after 2026-06-19);IP swap .239→.222 全仓。
- **★Phase D master cutover HK→CA = 全员签字 GO-ready 但未执行**(owner compact 前不跑,compact 后拍 GO+窗口)。脚本 cutover-ws1.sh commit **0b200053**,0-BLOCKER。上次 4 根因全闭合(砍SG fence/S5 python raw-socket+settimeout/abort-trap解冻HK/durability flip)+新护栏(S2.5 PONR人工门/HK_REPL_PWD强制热备)。执行=export HK_REPL_PWD+5个IP+REDIS_PWD,DRY_RUN=0,S2.5暂停lead实测放行S3。CA .222/EU/HK/CA Redis 就绪二查全绿。
- **剩余**(Phase D 后):D5 CA redis(AL2023→Ubuntu)/Phase F admin-data 迁 CA/D2 aws-monitor(22.04)/旧.239+HK 退役。
- **★web 重建事故教训**:建节点 tar 漏 nginx/lua/(guard.lua)→/api 404 只首页默认页;**假绿盲点**=测:7777直连+外部命中旧节点+/healthz 骗过;**铁律**:验 web 必测经 OpenResty:80 的 /api 真业务接口本地验绿才接回(G19/G20/G21)。EU 区 SSH key=nw_poc(非aws_region)。
- **OS 异构矩阵**:web+db 已 Ubuntu 26.04;CA redis/aws-data(admin/data)/aws-monitor(n9e) 仍旧 OS 待办。详 SESSION-HANDOFF 全表。

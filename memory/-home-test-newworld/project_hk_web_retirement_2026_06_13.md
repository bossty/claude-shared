---
name: project_hk_web_retirement_2026_06_13
description: 终态B收尾——HK web层退役全程(流量灰度迁CA/EU+fake-green健康检查根治+实例terminate)+一串可复用CF/迁移坑(2026-06-13)
metadata:
  node_type: memory
  type: project
  originSessionId: 64b5f5d1-9590-4971-9f5b-8d2e351a83eb
---

2026-06-13 终态B收尾：HK web 层（aws-web-01/02）流量灰度迁 CA/EU → fake-green 健康检查根治 → AMI + terminate 实例。owner-gated 逐步，全程零 502、CA/EU 0 错。

**1. 流量灰度迁（A域为主，P/S/C 已天然在 CA/EU）**：
- A 域 tcos-canary geo-LB：12 亚洲国 country_pools=[hk主,ca,eu] → **清空 country_pools** 让其继承 region_pools(NEAS/SEAS=ca主)/default(IN落SAS→default[0]=ca)。owner 洞察"country_pools 是历史 HK-override 没保留必要"=最简路径。
- **CF PATCH `country_pools={}` 是 no-op（合并语义不清除），必须 `null` 才清空**（或 PUT 全量替换）。fallback_pool hk→ca。
- **★监控指标陷阱**：连接数/请求总数被 **CF Traffic-Manager 健康检查探针**淹没（探 origin-hk /actuator/health，占 ~87%），误判"没排空"。真实排空看**排除 /actuator/health 的用户请求** + **tcpdump 抓 :80 Host 头**（cloudflared→OpenResty 本地明文 HTTP，不用 reload nginx）。
- **★P域直钉 A-HK-tunnel 根因**：3 个 retiring A 类域(byteatlas.top/digit-stream.top/digitportal.top + *.通配)的 CNAME **直指 `63594ad3..cfargotunnel.com`(A-HK-tunnel)绕过 tcos-canary LB** → 清 country_pools 对它们无效、永远钉 HK。修=CNAME 重指 `tcos-canary.dnsv106.com`(获 ca主+geo-steering+HA)。靠 tcpdump Host(=P域名)+DNS CNAME 排查到根。CN(中国)不在 CF 任何 region→走 default[0]=ca。
- **★CF monitor/pool ID 是 32 字符**，显示 `[:8]` 截断后拿去 PATCH=`Object not found`(code 1001)。必用完整 ID。

**2. fake-green 健康检查根治（退役前置）**：
- 病根：所有 monitor path=/actuator/health,port=443,expected_body=""(空)；:443→OpenResty SPA catch-all 永返 200(HTML 非 health) → CF 永不 failover、永不摘死 origin。真健康在 :18080。
- 修：OpenResty 已有 **`:80/health`=`proxy_pass nw_web`→`{"status":"UP","mysql":"UP","redis":"UP"}`真后端健康**（vs `/healthz`=静态'ok'假绿）。monitor 改 path=**/health** + expected_body=**`"status":"UP"`**（精确区分 UP/DOWN/SPA）。tcos-canary(ca/eu/hk)+p-lb(ca/eu)全改；or pool+p-lb/p-lb-bak 共享的 hk pool disable。
- **★真场景验证**：HK cloudflared 停后，hk pool 经 /health 探不到 down tunnel → **正确判红 0/280**（修前假绿会显 healthy），ca/eu 主力 healthy 用户零影响。证明假绿真修好。
- 硬前置铁律：**先 OpenResty 暴露真探针端点(/health)，再改 monitor**；若反序(monitor 先改但 origin 仍假绿)→全 pool 假红自残。

**3. 实例 terminate**：AMI 留回滚位(回滚位先就位铁律)→terminate aws-web-01/02(ami-0ef0c0a8/ami-029900196,delete-after 2026-06-20)。HK ap-east-1 **100G 卷快照长尾慢**(85% 卡 10min+)。裁决：无状态可重建节点(app 在 git、流量已迁、永久退役)给 AMI **有界窗口**，到点无论 AMI 是否好都 terminate(跳 AMI 授权——rollback 靠重建不靠 AMI)。AMI 最终 deadline 前 111s 到位=拿到回滚位。

**3b. OR(俄勒冈)节点退役(同日，同模式)**：aws-region-us(52.88.219.149,us-west-2,A-OR-tunnel 8af6ed58)。OR 本就是 region_pools 末位 fallback(ca/eu 主、fake-green 下永不命中)，**disable nw-dnsv106-or pool 即排空**(无需灰度迁，不像 HK 有 country_pools+直钉依赖)。实证排空：纯 web 节点(无 admin/data)、真实流量 0、cloudflared-a 出站 0、tcpdump :80 空、无用户域直钉 A-OR-tunnel→可直接退役。同 AMI 有界窗口+terminate(instance i-0b647009df3ed40b6;AMI ami-0f04c617903cf898b 10min 窗口到点仍 pending→按授权跳 AMI 终止,快照后台续跑仍成回滚备份)。**终态 B web 层定局=加州 CA×3+法兰克福 EU×2，HK+OR 两 fallback pool 均 disabled+实例 terminate。**

**4. ★detached background poll 反复死**：awsexpert-f 的后台 AMI 轮询 until-loop 连死 3 个(bqe7cms90 等无输出)。**lead 必须用自己的 ScheduleWakeup 兜底 + 主动 prompt 驱动**关键完成，不能单靠 teammate 的后台 poll(完工≠它启的 detached 工作完工，[[feedback_long_task_no_stall_sop]])。

**5. Phase F 二进制漏装补漏**：admin/data 迁 CA 新机(Ubuntu26.04)漏装外部程序——gif2webp/cwebp(管理后台图片上传 `can not run program gif2webp`)、node、/opt/javxx-m3u8.js、acme.sh(此前只补了 ffmpeg/Playwright)。**迁服务到新 OS 必 grep 全部 ProcessBuilder/Runtime.exec 审外部二进制依赖**，逐一确认装齐。[[project_phase_f_admin_data_california_2026_06_13]]

**6. ★HK 最后两台退役 = aws-data(admin/data 主机 t3.xlarge i-049711348d6849ced) + aws-db-poc(老 master/现 CA replica+HK Redis r6i.2xlarge i-07fa2fe8cfd21e3dd)(2026-06-13 owner gate"确认 data 持续入库后退役两台")**：
- 退役前 lead 二查 pre-flight(DB 退役不可逆,admin .239 事故教训)：①扫 5 web+CA admin 到 .174 实际连接全 0 ②system_config 无 .174/.16.161 残留引用 ③EU replica(终态保留)IO=ON/SQL=ON 健康 ④aws-data 真 idle(cloudflared-admin inactive、5min 真实 HTTP=0、newworld-data 已 failed,仅 3 idle Redis 连接到 .174)。
- 优雅停服顺序：先停 aws-data(admin+openresty,释放到 HK Redis 连接)→再 aws-db-poc(STOP REPLICA→stop mysql→stop dragonfly)。停后即验"不破坏"：CA master 掉到只剩 EU .248 一个 replica=终态形态、5 web+admin :18080=200、CA data 仍入库(+14)。
- **凭证机制**：主会话/节点 IMDS 均无 EC2 role,AWS CLI 凭证在 `~/.aws/credentials` 的 `[nw-dev]` profile(IAM user nw-dev,account 748579767645)→`AWS_PROFILE=nw-dev aws ec2 ...` lead 直驱,绕开 teammate 后台 poll 死的坑。
- AMI 留回滚位：aws-db-poc→ami-032ee6b226b4a6aae(available 快)、aws-data→ami-01e87be97c01ac53c(HK 100G 快照慢,deadline 仍 pending 29%)。**EBS 快照一旦 pending+有进度即与源卷解耦,terminate 删卷不中断快照→照终止(OR 先例+本次二查确认)**。两台 terminate(--no-reboot AMI)。
- **★终态 B 收口里程碑：HK 彻底退场。DB 层定局=加州 CA master(.222)+法兰克福 EU replica(.248)；web 层=CA×3+EU×2；admin/data=CA(aws-ca-admin)。**

**7. ★就近读终态验证(2026-06-13 owner"确认 CA/EU 都就近读")**：CA web=DB 读 .222+Redis 读 .128 全 CA 本地；EU web=DB 读 .248(SLAVE_URL,EU 本地 replica)+**Redis 读 .248(REDIS_REPLICA_HOST,EU 本地 Dragonfly slave)**,只写跨洋到 CA 单 master(.222 DB+.128 Redis,@Async 离热路径)。**坑:先看 ss 到 .128 有 50 连接差点误判 EU 跨洋读→查到 web 进程有 REDIS_REPLICA_HOST 读写分离 env 才明白 50 是写池+主工厂、读走本地 .248(7 连接少因 L1 Caffeine 吸大部分读)**。.248 Redis 实证=role:slave/master_link:up,往 CA .128 写 probe key→1s 后 EU .248 读到=跨区复制近实时。EU DB+Redis 同机 .248 跑 MySQL replica+Dragonfly replica。

**How to apply**：①流量是否真排空看排除健康检查探针的用户请求+tcpdump Host,非连接数 ②迁移前 grep 所有 DNS CNAME/LB steering 找绕过 LB 直钉退役 tunnel 的域 ③CF PATCH 清 map 用 null 非 {}、用完整 32 字符 ID ④改 LB 健康监控必先暴露真探针再改 monitor、改完验"模拟某 pool down 是否正确判红" ⑤迁服务到新 OS 审全部外部二进制 ⑥关键完成 lead 自兜底不靠 teammate 后台 poll ⑦DB/有状态节点退役前 lead 二查 pre-flight(无活连接+无 config 残留+保留 replica 健康+优雅停服后验不破坏)、AMI 留回滚位、EBS 快照 pending 有进度即可 terminate ⑧判就近读看实际连接(IPv6-mapped 容忍)+读写分离 env(REDIS_REPLICA_HOST/SLAVE_URL),别被写池连接数误导。**8. ★收口扫描发现的孤儿(2026-06-13 terminate 后扫两退役 region)**：①**OR 漏网孤儿 DB replica `nw-us-db-replica`(i-08514c82940691701,m5.xlarge,172.32.9.19,公网52.33.86.37,2026-05-30 建=FINAL-A 三区时代)**——终态 B"砍俄勒冈"只退了 OR web(aws-region-us)、这台 DB replica 漏掉。实证孤儿:不在 CA master(.222)的 dump 线程(只 EU .248)、终态活节点零连接、CPU 2.27% idle、名字即 replica(无独有数据)。但 **disableApiTermination=True(而 CA master=False,非标准做法→刻意保护)** + SSH key 不匹配(newworld/ubuntu@ 均 denied,无法验复制源)→**lead 暂停自主 terminate,AMI 留保险(ami-029ede9f46ec11b56,available)后上报 owner**(删 DB+被保护+不可 SSH 验=该停手确认,非盲删)→**owner 确认"关保护+terminate"→已关 disableApiTermination+terminate(shutting-down),零读者终止零影响,CA master 仍只 EU replica/站点 200/data 入库 71799**。②HK 孤儿卷 vol-0b4818b82a80cf356(100G,5/28 DB 灾难重建日建,脱离2周)。③HK 仍 running:n9e(监控,留)+**302-01(c5.large,95.40.168.207=openresty edge 重定向节点,:80→301/:443→302,owner 确认 edge nginx,功能节点保留非孤儿)**。④**CA 漏网孤儿旧 master `ca-db-master-old`(.239,i-0e9acb6e0f3948b9f,r6i.xlarge ~$300/月,2026-06-08 建)**——OS 统一时被 Ubuntu .222 取代后实例没退(owner"ca区是不是还多了一台db"点出)。完整 SSH 二查(这台能连,验得彻底):无复制源/IO线程OFF/read_only=1/零客户端/终态6节点零连接=完全断连死库。无终止保护→AMI(ami-0dded74e80c0f1a3a)+terminate,零影响。**退役后 CA region 干净=6台(master.222+redis.128+web×3+admin.34)正好终态拓扑**。
**9. ★收口清理执行完(2026-06-13)**：①HK 孤儿卷 vol-0b48 快照(snap-01ebf72a33afc4653,delete-after 2026-07-13)后删卷。②CF or/hk pool 清理:account A(token A,zone dnsv106.com)tcos-canary 移 or+hk 留 ca+eu(default+7个region_pools EEU/ENAM/NEAS/OC/SEAS/WEU/WNAM 全改[ca,eu])、**tcos.dnsv106.com(enabled 但只挂 disabled hk pool=已非功能态)重指 ca**;account P(token P,zone lbedge.org)p-lb-bak 移 hk 留 ca+eu(p-lb 本就干净);删 3 disabled pool(nw-dnsv106-hk/or+nw-lbedge-hk,CF 未拒=确认无 LB 引用)。**两账号现各只剩 ca+eu pool=终态对齐**,全程 17.rip 200。**坑:删 pool 前必查所有 LB 引用面(region/country/default/fallback),tcos.dnsv106.com 只挂 hk=漏改会留死 LB;CF 拒删被引用 pool 是天然安全校验**。
剩余 owner-gated：**仅 2026-06-20 AMI delete-after 清理**(6个退役 AMI:nw-hk-web×2/data/dbpoc-retire + nw-or-web/dbreplica-retire + nw-ca-dbmaster-old-retire,及关联快照)。HK 孤儿卷已清、302-01(edge nginx)+n9e(监控)有意保留、CF pool 已对齐。**终态 B 核心架构已达成:CA(master .222+web×3+admin/data)+EU(web×2+replica .248),HK app/DB 层彻底退场(仅余监控 n9e),就近读实证成立。**

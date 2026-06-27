---
name: project_phase_f_admin_data_california_2026_06_13
description: Phase F admin/data 物理迁加州根治 admin 跨洋 Redis 热路径假死 + 一串迁移期运维坑（2026-06-13）
metadata:
  node_type: memory
  type: project
  originSessionId: 64b5f5d1-9590-4971-9f5b-8d2e351a83eb
---

2026-06-13 master cutover（[[project_phase_d_incident_and_checkpointed_runbook_2026_06_13]]）后，owner 报 **admin 无法登录**（超时 30s）。lead 兜底诊断→根因→owner 选"Phase F 迁 CA 根治"→执行 F0-F3+F-data 全闭环。

**★admin 假死真根因 = 跨洋 Redis 热路径（multiregion-crossocean-hotpath 反模式，admin 后端版）**：
- cutover 的 S6 把 admin `REDIS_HOST` 切到跨洋 CA Redis（172.34.1.128）。admin 物理在 HK（aws-data），到 CA Redis 实测 **466ms/次**（vs HK 本地 5ms，慢 90×）。
- `OpsController.pickP`（边缘 S 域选 P 域热 API，S-entry 高频调，每次循环多个 Redis hGet）每个 hGet 跨洋 466ms → **173/200 Tomcat 线程卡在 Lettuce CompletableFuture await** → 线程池耗尽 → admin :8888 **所有请求**（含登录/GET /）hang，但 :18080 管理端口 health 仍 200（独立线程池）+ 定时任务仍跑（独立 scheduling 线程拿得到连接，误导）。
- **诊断法**：主端口全 hang + 管理端口 OK = Tomcat 池耗尽；`jstack` 看线程栈→Lettuce `AsyncCommand.await`→追到热 endpoint；`redis-cli` 测 CA-vs-HK Redis 往返延迟坐实跨洋（用 REDISCLI_AUTH 免 -a 警告）；**连接真伪权威源=DB/Redis master 侧 processlist，非 client 侧 ss grep**。
- **临时止血**：admin `REDIS_HOST` 指回 HK 本地（DB 留 CA，HK DB 已只读必须）。但导致 admin(HK Redis) vs web(CA Redis) 的 **stats 同步管道分裂**（web 写 CA Redis，admin 读 HK Redis 漏算）——软缺口。
- **根治 = Phase F：admin/data 物理迁 CA**，本地直连 CA DB+Redis，pickP 466ms→**7.8ms**，stats 一致性恢复（CA admin 读 CA Redis=web 同源）。

**Phase F 落地（F0 provision→F1 deploy→F2 验→F3 cutover→F-data）**：
- F0：CA us-west-1a m5.xlarge Ubuntu26.04（aws-ca-admin，i-05a9c5d3，内网 172.34.1.34，复用 CA web SG）。
- F1：JDK25+OpenResty+cloudflared；JAR/前端从 aws-data 拷生产二进制；scheduling 先禁（防双 admin）。
- **F3 cutover 机制**：①scheduling handoff——HK admin ExecStart 追加 `--app.scheduling.enabled=false`（在最终生效的 drop-in，多 drop-in 按字母序最后赢，HK 是 l1-oom.conf）+ CA 主 unit 移除该 flag，**全程仅一个 scheduler**（HK 关→空窗→CA 开，防双 DNS 摘除/双 stats 同步）②**域切**——CA/HK cloudflared-admin **同一 tunnel token**（831edb84，remotely-managed catch-all→localhost:80），启 CA cloudflared+停 HK cloudflared，tunnel 自动路由到 CA，干净可逆。
- F-data：HK data 停→CA data 启（单爬虫，防双爬）。
- HK admin 留 active 做**回滚备用**（不服务域/不调度），aws-data soak 后退役。

**★迁移期一串运维坑（全已修，部分是新铁律）**：
1. **IPv6-mapped ss 断言坑**：`ss -tnp` 对 Java/Netty 的 IPv4 连接显示 `[::ffff:172.34.1.222]:3306`，`grep 'IP:3306'` 被中间 `]` 卡住匹配=0 假故障。修 `grep -Ec 'IP[]:]+3306'`。s6-repoint commit e38b5f56。
2. **HKT 时区 date 解析坑**：OS 统一为 HKT 后 `systemctl ActiveEnterTimestamp` 值带 "HKT" 缩写，`date -d` 解析失败→region-readiness-gate G0 warm 检测回退 0 误判未 warm 永 exit 2。改用 `ps -o etimes`（进程存活秒免时区解析）。commit 750223ea。
3. **CA web 读退役陈旧 .239**：CA web SLAVE_URL 指向 OS 统一时被 .222 取代的退役旧 CA DB .239（复制源 HK、SQL 线程 OFF、陈旧扩大）→加州用户读陈旧。修 SLAVE_URL→.222 本地 master（max_conn=600 头寸足，加州 master 本地读无跨洋代价）。EU 不受影响（读本地 .248）。
4. **node-03 异常 8G 小盘 + OpenResty web.log 无轮转**：web.log 涨 3.1G 撑爆→health 503（OpenResty :80 经 HK backup upstream 仍 200，用户影响有限）。truncate+装 logrotate（其他节点 48G）+EBS 在线扩 8G→48G。
5. **Playwright + Ubuntu26.04**：Playwright 1.57 不支持 ubuntu26.04，systemd 加 `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1`+`HOME=/home/newworld`+从 aws-data rsync 拷 ~/.cache/ms-playwright（2.4G）。

**★Phase F soak 期 CRITICAL 事故（2026-06-13 06:59，soak 监控抓出）**：CA master .222 的 MySQL 被 **unattended-upgrades**（自动升级 openssl/libssl3 等）在 06:59 触发服务重启（实例没重启，uptime 15h，仅 `systemctl` 干净 stop+start ~13s）→ mysql 从 **replica 时代的 config（`/etc/mysql/mysql.conf.d/99-newworld.cnf` 有 `read_only=ON`/`super_read_only=ON`）** 起来变只读 → **全站 MySQL 写失败 15min**（admin stats scheduler 3339 错 `--read-only option`；analytics/hit 返 200 因 @Async 缓冲 Redis 但不落 MySQL；用户直写失败；读/登录正常）。soak 第 5 轮（07:11）抓出 30min ERROR 0→3339 异常。**根因 = cutover C6 promote 时 read_only=0 只 `SET GLOBAL` 未持久化到 config**（durability 用了 SET PERSIST 故 1/1 存活，唯独 read_only 没）。**修复**：改 config `read_only=OFF`+`super_read_only=OFF`+durability 对齐 1/1（持久化防再次重启回退）+ `SET GLOBAL read_only=0/super_read_only=0`（即时），Com_insert 9→1850/6s 写恢复、EU/HK 复制 ON/ON lag=0 无 split-brain（EU/HK 仍正确 read_only=ON 是 replica）。**遗留风险**：unattended-upgrades 在生产 DB master 自动重启 mysql（needrestart 默认 auto），每次安全升级 ~13s 写抖动——read_only 已持久化故无数据事故，但建议 needrestart 改 list-only(`$nrconf{restart}='l'`) 把 master 重启挪到维护窗口（owner-gated 补丁策略）。**新铁律：master promote 后必把 read_only=0 + durability 写进 config 文件（不只 SET GLOBAL/SET PERSIST），并验证"模拟重启后仍可写"；生产 DB 禁 unattended-upgrades 自动重启服务**。

**★Phase F 第三方依赖白名单遗漏（2026-06-13 owner 问"data 采集了吗"挖出）**：CA data 启动+爬虫跑，但**电影 13.5h 不入库**(最后 04:11)。根因=data 调 LLM 内容分析(OPENAI_ENDPOINT=`https://209.141.48.177/v1/chat/completions` buyvm-data relay)超时 30s×5→分析失败→不存库。实测 **CA data 出口 52.8.53.144 → buyvm-data :443(OpenAI relay)+:3128(tinyproxy HLS 下载) TCP 全不通**——buyvm-data UFW 只 allow 老 HK aws-data IP(18.167.41.192)，迁 CA 后没加新 IP。修=`ufw allow from 52.8.53.144 to any port 443/3128`，LLM 恢复、电影入库恢复(+2/10min)。**铁律：迁服务到新 region/IP 必同步更新所有外部依赖(relay/proxy/API/对端防火墙)的源 IP 白名单**——不止本机装二进制，还有对端 allowlist。aws-data 退役时清 buyvm UFW 旧 HK IP 规则。

**How to apply**：①任何"在 region-X 物理机的服务"的 Redis/DB host 改跨洋前，先评估它有无高频热路径（pickP 类循环小读）——后端 admin 同样适用 crossocean-hotpath 铁律，不止 web ②admin 假死/超时先 jstack 看池是否耗尽 + 测目标 Redis/DB 往返延迟，别只看 health ③单实例服务（admin/data）cutover 铁律=任一时刻仅一个跑 scheduling/爬虫 ④同 tunnel token 多机=切域只需 swap 哪台跑 cloudflared。关联 skill newworld-multiregion-crossocean-hotpath。

---
name: project-db-migration-2026-05-27
description: newworld DB 真生产迁移 sprint — prod aws-db (t3.xlarge MySQL+Redis 共机) → aws-db-poc (r6i.2xlarge MySQL 8.4+Dragonfly 共机)，9 round cross-fire + 蓝军 8 次 + 5 cutover 实战 + 16 anti-pattern 真生产沉淀
metadata: 
  node_type: memory
  type: project
  originSessionId: 8fa5c97f-60bf-4150-a436-5133cef6a028
---

# newworld DB 真生产迁移（2026-05-27）

**Sprint commit**: `55dd26ad` master HEAD push origin（+2913/-0 lines, 12 files docs/sprint/_archive/2026-05-27-prod-migration/）
**前置**: `a19c2046` cacheEvictAll endpoint / `975cca58` sample-keys-stratified.sh / `5/26` dragonfly-research POC sprint

## 迁移结果

- ✅ prod aws-db (t3.xlarge MySQL 8.0 + Redis 共机) → aws-db-poc (r6i.2xlarge MySQL 8.4 + Dragonfly v1.38.1)
- ✅ 4 节点应用 DB+REDIS_HOST 全切 172.31.16.161（4 unit Environment + secrets.env REDIS_PASSWORD）
- ✅ MySQL 90 unique hosts 业务流量 / Dragonfly 5946 ops/s / total 104M commands
- ✅ 60min cutover 后 monitor 76/76 全 PASS（biz5xx=0 / health_fail=0）
- ✅ 业务感知 ~75s（owner Gate 7 "1min 可接受" 范围内）
- ✅ **Final data verify 零丢失 (5/27 23:21)**: 18 表 poc≥prod 单向 / GTID 完全覆盖 (177106/177106) / binlog 17:02:43 冻结
- ✅ **Prod 真 stop 真终极验证 (5/28 00:01)**: aws-db MySQL + Redis 真 inactive 后 30s+ 真业务 200 / 4 节点 health 200 / 0 ERROR — **应用真 100% 不依赖 prod 真铁证**
- ❌ **5/28 17:30 灾难 — Owner 真误 terminate aws-db-poc**：EBS DeleteOnTermination=true 默认 → EBS 真删 → poc 数据真彻底丢
- ✅ **5/28 17:38 真业务切回 prod**：业务 200 / 4 节点 health 200 — 17:25 不可达 → 13min 真急救闭环
- ✅ **5/28 19:30 真重建新 poc (43.198.91.111 / 172.31.19.174)**: r6i.2xlarge / 100GB EBS gp3 IOPS 16000 / Ubuntu 26.04 / tune-kernel + Dragonfly :6379 + MySQL 8.4 + termination protection
- ❌ **真 cutover#2 真假乐观 — replica_skip_errors 真跳过 stats race 真 trx**：visitor_fp -1471 / site_daily_stats -18 / ad_daily_stats -2 真数据 diff（GTID 真 357 trx 污染 + 真 data drift）
- ✅ **5/28 20:48 RESET 重建真治本**：STOP REPLICA + RESET REPLICA ALL + DROP DATABASE + 新 mysqldump (--source-data=2) + apply with `--force` + `file/pos + AUTO_POSITION=0` replica (mysql-bin.000002:59446035) → 4 表 diff=0 + lag=0
- ✅ **5/28 21:05 cutover#3 真 PASS**：T+240s 业务切到新 poc / 4 节点真连 172.31.19.174 (140 连接) / 真零旧 prod 连接 / 真业务 200 0.71s
- ✅ **5/28 21:30-21:50 cleanup**: s_channel_agent.lua 死代码 (52b7e470 -200 lines) + admin nginx 5 grace rewrite (086f86eb -75 lines, 5 天 0 命中证据) + sw.js 前向兼容 q/tally (384b20fe)
- ✅ **5/30 14:53 Owner 真提前 stop 旧 prod aws-db**（原 plan T+7d 6/4，提前 5 天）— T+~48h 真证据齐：4 节点 → 旧 prod 0 连接 / 旧 prod 业务连接 0（仅 monitoring）/ 新 poc Threads=151 master 真活 / categraf 真无 stale 旧 prod IP / N9E aws-db metric down 真无业务影响
- ✅ **5/30 stop 后真业务零回归实证**：业务 17.rip 200 / 4 节点 health 200 / 4 节点 ERROR 真零 connection-related（仅 HlsDownloadService 真爬虫源站 SocketTimeout 真历史业务异常 与 stop 真无关）/ 旧 prod TCP :3306 真 timed out 真证 stop 真生效
- ⏳ T+30d (6/29) terminate-instance + EBS 释放 真彻底退役

## 5/28 真灾难 → 重建 → cutover#3 → cleanup 真完整 timeline

| 时刻 | 真事件 |
|------|------|
| 5/28 14:10 | Owner 真 commit `3bd0202b` retiring→retired 状态机 |
| 5/28 ~17:00 | Owner 真验证 prod stop 后真业务 OK (灾难前) |
| **5/28 17:25** | **Owner 真在 AWS console "stop instance" 真不慎选错点了 aws-db-poc** |
| 5/28 17:25-17:30 | aws-db-poc 真不可达（业务真 502 / 4 节点 health 000）|
| 5/28 17:30 | aws-db (旧 prod) 真起 MySQL + Redis 急救 |
| 5/28 17:38 | 4 节点 unit 真切回 prod IP + secrets.env 真切回 prod password + 业务 200 ✅ |
| 5/28 17:50 | Owner 真核 EC2 — instance 真 **terminated**，**EBS 默认 DeleteOnTermination=true 真删** |
| 5/28 18:00 | Owner 真创新 instance 43.198.91.111 (r6i.2xlarge / 100GB EBS / IOPS 16000 / termination protection) |
| 5/28 18:10 | ssh 免密 + scp scripts + hostname rename aws-db-poc |
| 5/28 18:20 | tune-kernel + Dragonfly install (6379/proactor=6/32G) + MySQL 8.4 install |
| 5/28 18:30 | mysql_native_password 真插件 + newworld/repl user 创建 |
| 5/28 19:00 | 首次 mysqldump prod (542M) + import — fail at `promotion_channel`（procedure 依赖顺序）|
| 5/28 19:30 | DROP + 重 apply with `--force` + replica with GTID auto_position=1 |
| 5/28 19:45 | replica fail `replica_skip_errors` 设 + 跳过 GTID 192330 → replica 真起 + 数据 diff -1471/-18/-2 |
| 5/28 20:30 | Owner 拍 B RESET 重建真治本 |
| 5/28 20:48 | DROP DATABASE + 重 mysqldump + `file/pos + AUTO_POSITION=0` 真起点 mysql-bin.000002:59446035 → 4 表 diff=0 |
| **5/28 21:05-21:09** | **cutover#3 真 PASS T+240s + 真业务 200 + 4 节点真切 poc** ✅ |
| 5/28 21:30 | 60min monitor 启 (background bprrq6aln) |
| 5/28 21:35-21:55 | 真 cleanup 3 commit: s_channel_agent + admin nginx grace + sw.js fix |

## 5/28 真新 anti-pattern (A20-A29) — 10 真新生产教训

| # | 真 anti-pattern | 真证据 / 修法 |
|---|---------------|-------------|
| A20 | **EBS DeleteOnTermination=false + termination protection 真双重防呆** | Owner 真直接教训 - 单 termination protection 真不够（owner 真主动 terminate 时仍可触发）。**修法**: `aws ec2 modify-volume-attribute --volume-id <vol> --delete-on-termination false` + termination protection |
| A21 | **data systemd 真假 active + JVM 真 fail loop 真不暴露** | systemd Restart=always + ActiveState=active 真 5/27 17:05 cutover 后 data 真一直没真启动起来 24h+ 真无人发现。**修法**: health check 必须**本地 curl 127.0.0.1:$port/actuator/health 真业务 200**，不接受 `systemctl is-active`；N9E 真加业务 metric (爬虫真入库率 / actuator/health 持续 200) |
| A22 | **systemd drop-in 真覆盖 ExecStart 真路径** | 真主 unit ExecStart 真被 `/etc/systemd/system/<svc>.service.d/*.conf` 真覆盖 → `sed -i` 改主 unit 真不生效。**修法**: `systemctl show -p ExecStart --value` 真找真生效行 → `grep -l '<pattern>' /etc/systemd/system/<svc>.service.d/*.conf` 找真覆盖文件 → 真改对路径 |
| A23 | **mysqldump 真 file/pos vs GTID 真起点** | `--source-data=2 --set-gtid-purged=OFF` 真写 file/position 注释 (mysql-bin.000002:59446035)。SET gtid_purged 真不能用 apply 完成后真 GTID (中间 9159 trx 真丢) → 必须用 dump snapshot 真起点 GTID 或 **file/pos + AUTO_POSITION=0 真模式** |
| A24 | **replica_skip_errors 真有数据 drift 副作用** | replica_skip_errors=1032,1062 真跳过 stats race trx → 真数据 diff (visitor_fp -1471 等)。**修法**: 真治本路径是 RESET 重建 + 真精确 file/pos replica，不靠 skip_errors 真"忽略"（真 skip 真有累积副作用）|
| A25 | **drop-in 真 ExecStart= 空赋值真清主 unit** | drop-in 真用 `ExecStart=` (空) 真清主 unit 之前所有 ExecStart 然后真新 ExecStart 真覆盖。**修法**: 改 ExecStart 真**先 systemctl show -p ExecStart** 找真生效行 → 改真 drop-in 文件 |
| A26 | **RESET 重建真完整 SOP** | STOP REPLICA + RESET REPLICA ALL + RESET BINARY LOGS AND GTIDS + DROP DATABASE + 重新 mysqldump prod (--source-data=2) + apply with `--force` + 真核 table_count=63 + `file/pos + AUTO_POSITION=0` replica → 真数据 100% 一致 |
| A27 | **旧 ServiceWorker cache 真长期 lag → grace rewrite 真不能立即删** | aws-web legacy_grace.log 真 2033 hit/24h 真活流量 = 用户旧 SW (5/24 前装) 真 cache 真 5/24 前 dist 真 chunk → 真发 `/promotions/track`。**修法**: nginx grace rewrite 真保留 ≥30d 真 ServiceWorker 自然更新期；删除前必看 legacy_grace.log 真 hit 真下降趋势 |
| A28 | **死代码 cleanup 前必扫 sw.js + dist + frontend src + access log 真 4 维度证据** | admin nginx 75 行删除真证据: ① admin.log 5 天 0 hit ② frontend-admin dist 真 0 旧 + 4 新 path ③ categraf 真未 install legacy toml ④ legacy_grace.log 0 bytes。**Owner 真挑刺真核心** = lead 真必出**4+ 维度真硬证据**才删 |
| A29 | **sw.js 真 forward-compatible 真识别多路径** | isAnalyticsRequest() 真同时识别新 (`/v1/q/tally`) + 旧 (`/v1/promotions/track`) → 真新版 SW 真识别新路径，旧 SW cache 真识别旧路径，nginx grace 真兼容期内真无 cache 策略 drift |

## 真完整 commit chain (本 sprint 5/27-5/28 共 15+ commit)

| commit | 真 scope | 时间 |
|--------|---------|------|
| `a19c2046` | cacheEvictAll endpoint | 5/27 13:31 |
| `55dd26ad` | sprint 12 files +2913 | 5/27 19:46 |
| `d1651e17` | scripts IP 切换 | 5/27 21:18 |
| `4e8ba96c` | CLAUDE.md A1~A16 | 5/27 21:26 |
| `0c98d601` | SOT yaml N9E rules | 5/27 22:52 |
| `5df2443d` | N9E dashboard + SQL SOT | 5/27 23:18 |
| `8a22e3ca` | CLAUDE.md A17~A19 | 5/27 23:20 |
| `c0287e7c` | HikariCP leak-detection | 5/28 11:59 |
| `39a82d06` | cohort dev-C 状态档 | 5/28 11:59 |
| `7761a52d` ~ `3bd0202b` | Owner 真业务 commit (5 件) | 5/28 13:13 - 14:10 |
| **`52b7e470`** | **clean s_channel_agent 死代码** | **5/28 ~21:30** |
| **`086f86eb`** | **clean admin nginx 5 grace** | **5/28 ~21:45** |
| **`384b20fe`** | **sw.js 前向兼容 q/tally** | **5/28 ~21:55** |

## 本 sprint 真完整 commit chain（9 commit）

| commit | 真 scope |
|--------|---------|
| `a19c2046` | feat(cache-evict-all) dev-senior 真落 endpoint (anti-pattern #4/#5 真治本) |
| `55dd26ad` | docs(sprint) 12 files +2913 lines (SOT + 蓝军 8 版 + sprint-report) |
| `d1651e17` | chore(scripts) 业务运维脚本 DB/Redis IP 172.31.27.200 → 172.31.16.161 |
| `4e8ba96c` | docs(claude) sink A1~A16 (16 真生产 anti-pattern) |
| `0c98d601` | ops(n9e) +5 USE method alert rules (anti-pattern #16 闭环) |
| `5df2443d` | ops(n9e) N9E host USE method dashboard + SQL patch SOT |
| `8a22e3ca` | docs(claude) sink A17~A19 (dashboard 闭环延伸 3 教训) |
| `c0287e7c` | fix(web) HikariCP leak-detection-threshold 20s (5/22 P0 复盘配置补强) |
| `39a82d06` | docs(sprint) cohort sprint dev-C 状态档收尾 |

## 16 真生产 Anti-pattern（按出现顺序）

### Sprint cross-fire 揪 10 个（v1-v7 9 round）
1. lettuce auto-reconnect 5s = 0 downtime 假乐观（v1 蓝军揪）
2. MySQL 8.0→8.4 跨版本 mysqldump `--master-data` 已废弃用 `--source-data`
3. systemd drop-in 真路径覆盖主 unit
4. Caffeine 真 TTL 30min ≠ 60s（dev grep 实证 SystemConfigService L78-93）
5. cacheEvictAll endpoint 真路径 `/admin/api/v1/ops/cache/evict-all` + X-Internal-Secret
6. sed pattern 跨节点 silently no-op
7. `--set-gtid-purged=ON`(replica) vs `=OFF`(rescue.sql apply) 临场易混淆
8. cloudflared SIGTERM grace period 真值 30s（不是 15s）
9. nginx F-1 教训 max_fails=2 天然 rolling restart（v3 简化删 nginx sed）
10. **CLAUDE.md 写了 ≠ sprint 真验过** — DB_HOST 真位置在主 unit Environment

### Cutover 实战暴露 4 个（5 次 cutover 失败/成功）
11. **MySQL bind=127.0.0.1 默认 + 多 conf 文件 ordering bug**（Ubuntu mysqld.cnf 覆盖 99-newworld-prod.cnf）
12. **systemctl is-active + 外部 curl = false positive** — 必本地 `curl 127.0.0.1:$PORT/actuator/health`（cutover #1 真坑：systemd 进程已起 + nginx upstream 路由 PEER healthy 节点接管造成假 200）
13. **application-prod.yml hardcode `port: 6379`，systemd Environment=REDIS_PORT 不被读** — 修法：Dragonfly listen 6379（不用 6381）零应用改动
14. **mysqldump --databases newworld 不导 mysql 库 → aws-db-poc 缺 newworld user → Access denied** — 必先 CREATE USER + GRANT（dry-run 一次性揪出，sprint 8 round 全漏）

### Cutover 后暴露 2 个（owner 业务直觉揪）
15. **配置文件 ≠ 服务真运行** — sprint cleanup-tune 落盘 `categraf/*.toml` 是 POC 范本，**没真在 aws-db-poc 装 categraf binary + systemd start + 上报 N9E**。owner 一句"新 db 没装 n9e 是吗"揪。修法：tar pipe 中转 prod /opt/categraf + /etc/categraf + 改 hostname/redis-pwd + systemd start
16. **N9E `cpu_usage_percent = 100 - idle` 含 iowait 误报** — 多线程 KV `--proactor_threads=N` 触发 N 个 vCPU 持续 io_uring wait → kernel 算 iowait（即便磁盘 %util=6% 真不忙）→ N9E 显示 75%「CPU」假警。owner 一句"poc CPU 75% 跟旧机差这么大"揪 + lead `mpstat -P ALL` 实证 6 个 proactor vCPU 各 96-99% iowait + CPU 6-7 idle ≈ 98%。修法：N9E dashboard 4 panel（cpu_busy=user+sys 告警70% / cpu_iowait 仅参考 / disk_util 告警 80% / disk_await 告警 100ms），告警阈值用 cpu_busy 不含 iowait

### Anti-pattern #16 真闭环延伸 — N9E dashboard patch 3 新教训（5/27 evening）

commit `5df2443d` (ops/n9e-board-id5-host-use-method.json + n9e-host-use-method-patch.sql)
+ commit `0c98d601` (ops/n9e-alert-rules.yaml +5 USE method rules)
+ commit `4e8ba96c` (CLAUDE.md sink 16 anti-pattern)

**真闭环 5 层一致禁 `100-idle`**：
1. SOT yaml +5 rule (HOST-CPU-BUSY/LOAD/DISK-AWAIT-SSD/AQU/UTIL-HDD)
2. N9E mysql alert_rule id=90~94 INSERT + id=69 DELETE
3. N9E mysql board_payload id=5 panel 4 PromQL 改 user+sys + threshold 80→70
4. 新增 4 panel: iowait 参考 / Load /core / SSD await / IO queue
5. 5 row 分组折叠 (CPU/内存/磁盘 IO/网络详情/其他指标) 真一致

**新教训 A17**: **N9E row panel 折叠需 4 字段齐：`collapsed:true` + `id: uuid` + `panels: []` + `isResizable:false`** — 缺一行为不一致。我首版仅写 `type/name/layout` 4 字段，owner 反馈"CPU/内存/磁盘 IO 折叠点两次才生效"。diff 原"网络详情" row 真 schema 揪 4 字段缺。**规则**：UI 字段语义不能凭直觉推断，必 fact-check working 实例真完整字段集；reference_n9e_v8_dashboard_schema.md 真说"唯一权威是 board_payload 现存 working dashboard"，本次实证 owner 1 句反馈胜过我 2 轮凭印象补字段

**新教训 A18**: **dashboard panel + alert rule + 内置 SOT yaml 必四源一致禁 `100-idle`** — owner "5号 dashboard CPU 使用率历史趋势计算方式是不是也要改一下" 1 句揪我之前只改 alert rule + 内置 DELETE 但忘 dashboard panel #4 仍用 `100-cpu_usage_idle`。**规则**：anti-pattern 闭环必扫全栈所有显示/告警点（alert rule / N9E 内置 rule / dashboard PromQL / SOT yaml），用 grep 真核每一处公式是否对齐；本次实证 1 个 anti-pattern 真闭环 = N+1 个修法点（不只 1 处）

**新教训 A19**: **dashboard / N9E 改动必落 ops/*.json + *.sql 可重建** — 不能仅活在 mysql 数据库。本次 commit `5df2443d` 把 board 5 真 payload (29 panel) + SQL patch (5 INSERT + 1 DELETE) 落 ops/ 目录。**规则**：N9E DB 丢了能 git 一行命令重建；未来 board 改动有 audit trail；sprint 真完成 ≠ 数据库改完，是 git 真落地

**Owner mindset 真直觉揪 dashboard 闭环 3/3 = 100%**：
- "5号 dashboard CPU 趋势是不是也要改一下" → 揪 panel #4 真凶
- "━━━ 都去掉吧" → 真 UI 风格一致性
- "CPU/内存/磁盘 IO 折叠点两次" → 揪 4 字段 schema 真缺

## SOP 9 round 演化

| Round | NEW BLOCKER | 累计修法 | 真大事 |
|-------|------------|---------|--------|
| v1 + 蓝军 v1 | 5 | 21 | 推翻 0 downtime 假乐观 |
| v2 + 蓝军 v2 | 4 | 29 | mysql 8.0→8.4 跨版本 + rescue.sql GTID |
| v3 + 蓝军 v3 | 3 | 37 | nginx 简化 + sample-keys |
| v4 + 蓝军 v4 | 1 | 44 | Caffeine 真 TTL 30min 大错（owner 拍板方案 B dev endpoint）|
| v5 + 蓝军 v5 | 2 | 50 | endpoint 真路径 + systemd drop-in sed |
| v6 + 蓝军 v6 | 0 | 50 | 真接近 cutover-ready |
| **v7 + 蓝军 v7** | **CRIT+3** | **54** | **DB_HOST 真路径 / sed 路径错 / IOPS 16000 / rescue secrets.env** |
| v7.1 + 蓝军 v7.1 | 0+0 | 58 | REDIS_PORT + secrets.env rollback |
| **v7.2** | health gate | 59 | **anti-pattern #12 本地 curl gate** |
| **cutover 实战 5 次** | **+4 真坑** | **63 + 4 真生产** | #11~#14 + dry-run 治本 |

## Owner mindset 真业务直觉揪 6/16（37.5%）

| Owner 真业务问 | sprint 漏的真坑 |
|---------------|---------------|
| "cutover 第一台怎么判断成功" | #12（systemctl is-active false positive）|
| "现在就 dry-run" | #14（mysql.user 缺）|
| "删除多余的干扰配置文件" | mysqld.cnf 默认 ordering bug |
| "配置文件地址更换考虑好了没有" | #10（DB_HOST 真路径）|
| "新 db 没装 n9e 是吗" | #15（配置 ≠ 真运行）|
| "poc CPU 75% 跟旧机差这么大" | #16（cpu_usage iowait 误报）|

## 关键修法实证

- **awk 替代 sed**（v7 vs cutover #2）: `awk '/^Environment=DB_HOST=172.31.27.200/{print "Environment=DB_HOST=" new; next} {print}'` 比 sed 跨节点更可控
- **pipe 中转大文件**（cutover #1）: `ssh aws-db 'cat /tmp/file.gz' | ssh aws-db-poc 'cat > /tmp/file.gz'` 无需中转机 ssh key
- **debian-sys-maint 兜底**: prod aws-db root@localhost 无密码时 `mysql -udebian-sys-maint -p<pwd from /etc/mysql/debian.cnf>` 是真 root 兜底入口
- **GTID `caching_sha2_password` 需 SSL**: replication user 用 `mysql_native_password` 避 SSL 限制
- **MySQL 8.4 SOURCE_PASSWORD 32 char 硬限**: `openssl rand -hex 16` 生成
- **Dragonfly listen 6379 不是 6381**: 与 prod 应用 yml 默认一致 = 零代码改动

## 真生产 cutover SOP 模板（v7.2 + 实战修正）

```
T-2h    prod Redis CONFIG SET save ""（防 BGSAVE COW）
T-30min preflight: nc 三方节点 → aws-db-poc:3306 + :6379 全 OK
         + lag<5s 持续 60min verify
         + dry-run 真业务连一次 newworld user
T-5min  4 节点 awk 预改 unit Environment + secrets.env（不 restart）
        daemon-reload + systemctl show verify 真生效
T+0    prod MySQL SET GLOBAL read_only=1
T+5s   PROD_GTID=$(SELECT @@global.gtid_executed)
       WAIT_FOR_EXECUTED_GTID_SET(PROD_GTID, 60)
T+30s  promote: STOP REPLICA + RESET REPLICA ALL + read_only=0
       Dragonfly REPLICAOF NO ONE
T+45s  ROLL_NODE 严格顺序（data → admin → web-01 → web-02）
        每节点 restart + 本地 curl 127.0.0.1:$port/actuator/health × 8 retry × 4s
        任一 fail → 立即 rollback 本节点 + STOP cutover
T+3min cluster verify curl https://17.rip × 3
T+5min /actuator/health + N9E metric verify
T+30min rollback 窗口关闭（超过此点不可回滚 = 丢业务数据）
T+7d   旧 aws-db 真退役 stop instance
```

## 后续待办

- N9E dashboard 4 panel patch（cpu_busy / cpu_iowait / disk_util / disk_await）
- T+7d 4 节点临时 backup `.bak.cutover*` 清理（web-01:2 / web-02:2 / data:4）
- T+7d 旧 aws-db stop instance（保 EBS）
- T+30d 旧 aws-db terminate（释放 EBS）

详见 `docs/sprint/_archive/2026-05-27-prod-migration/sprint-report.md`

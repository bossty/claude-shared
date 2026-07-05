---
name: project_alert_triage_rule42_disk_n9e_2026_07_05
description: 07-05 凌晨三线告警triage(慢查询/CPU/CDN失败率)→规则42重校准25%/30min+新建规则119 HOST-DISK-USED+删SystemMonitorTask磁盘巡检部署验证
metadata: 
  node_type: memory
  type: project
  originSessionId: c3b90f0f-03f9-4ef3-b601-36203b947891
---

# 07-05 凌晨告警 triage + 规则42/119 + SystemMonitorTask 磁盘巡检收编 N9E

**三线告警全根因（无急性事故）**：
1. MYSQL-SLOW-QUERY(23@00:33)=ca-admin(172.34.1.34) 夜间统计任务：channel cohort 查询连发23条(各~1.7s/扫49.5万行) + VidAliasMergeTask 01:00 vid_metadata 7天聚合 **65s/扫2340万行**。慢性效率问题，优化候选（预聚合/挪出峰窗），未处理。
2. ca-admin CPU 74%@01:11 = 三股叠加：admin 01:04 被另一会话 `sudo systemctl restart`（A池RUM恢复部署 apoolrum-2bbdeb01 包）+ 爬虫活跃(35个playwright chrome+ffmpeg瞬时220%) + 统计任务同窗。瞬态自愈。
3. stats-v7-redirect-trace-cdn-fail 19%/4h = **慢性昼夜节律非事故**：VM offset 实测夜间15-19%/白天8-11%，redirect_trace 表逐根域失败量昨==今；50个R_VID域全活(404=链路通)；与 RUM-LCP-RCA(06-29起CN→CF段劣化)互证。**告警备注"saga倒备桶"过时——saga 04-28 已永久取消**(wave_stats_v7_sprint_closure.md C-1)。

**已执行（Owner 拍板做1+4）**：
- 规则42：10%/1h→**25%/30min**（急性线：单根域全灭≈+20pt/单桶≈+25pt 昼夜可穿透）+note更新。N9E DB(n9e_v8.alert_rule id=42)真值+ops/n9e-alert-rules.yaml 回镜 `d865af5b`。
- 新建规则 **119 HOST-DISK-USED**：`max by (ident,path)(disk_used_percent) > 85` /15min，全fleet 15台（此前 N9E 只有 diskio 性能规则、无容量规则，磁盘快满信号全押自建巡检）。
- 删 SystemMonitorTask checkDisk/checkLocalDisk/checkRemoteDisk+SystemMonitorDiskTest（远程侧对 ca-master 公钥拒/eu-replica 22端口不通早已盲，同 JvmHealthMonitorTask 教训）。分支 fix/systemmonitor-disk-to-n9e，2131测试0败，合master `037ad472`。checkMysql/checkRedis/checkFrontendMonitor 保留（仍是 N9E 外自建，后续可评估逐项收编）。

**★ca-admin 部署 jar symlink 真值 = `deploys/current.jar`（deploys 目录内）**，systemd ExecStart 指它；`/newworld/newworld-admin/current.jar`（上一层）不存在——`ln -sfn` 到上层路径会静默新建无人用的链接、重启的还是旧包。判错证据：重启后 journal 里旧行为仍在（本次靠"阴性验证等2个巡检周期"逮住）。备份链约定：`deploys/current.jar.bak-pre-<tag>`。
**★阴性验证必须锚定新 MainPID**（`journalctl _PID=<新pid>`）且等满被删任务的 initialDelay+周期，否则旧进程日志混淆判断。
**★N9E 规则操作路径**：ssh ca-monitor `sudo mysql n9e_v8`（socket 认证），改 alert_rule 后必回镜 ops/n9e-alert-rules.yaml（规则113教训）。新建规则用 INSERT..SELECT 全列复制同类规则（如115）防 v8 schema 列缺漏。
**★pre-push 闸门跑全量 ci-local（~10min）**，push 必 run_in_background；pgrep 查僵尸时自身命令行会自匹配（用 `-fa "xxx.sh$"` 锚定）。
SSH "Permanently added" 每连必打噪音 = UserKnownHostsFile /dev/null 的必然产物，已在 ~/.ssh/config 尾部加 `Host * LogLevel ERROR` 压掉（不改连接行为）。

**续（同会话，Owner 升级为全项目监控统一 N9E）**：
- 批1：新建规则 **120 MYSQL-CONN-HIGH/121 MYSQL-REPLICA-LAG/122 MYSQL-DOWN/123 REDIS-DOWN/124 REDIS-CONN-HIGH**（promql 全 VM 实测+absent 阳性对照）；★REDIS-MEM-HIGH 漂移方向反转=**yaml 陈旧 DB 真值是活的**（抄 yaml 前必核 DB）。回镜 `3a309bca`。
- 批2：删 checkMysql/checkRedis（★主从延迟检查连 master 查 SHOW REPLICA STATUS 恒空=上线起即死），SystemMonitorTask 仅剩前端监控。合 master `1a86b38f`，部署 ca-admin（jar dbredisn9e-bfddaa5e，7min 观察 0 ERROR+consumer 17 次消费）。
- **全项目盘点+批3-5 计划落档 `docs/sprint/2026-07-05-monitoring-unification/PLAN.md`**：批3=web RUM 告警收编（MonitorService 补 Counter，弱与门拆两条正交规则 http_response 探:7777）；批4=**data 爬虫零告警盲区**（盘点最大发现，断流无信号）；批5=replica-lag-watchdog.sh 与规则121双轨退役/WebHealthCheckTask 删除(需 Owner 推翻 06-14 保 bean 决定)/双 telegram 桥核实/C 类保留项照 CfZoneAuditService 标杆（gauge→VM 留历史）逐步镜像。BaiduTokenAlertTask 实际已停用(@Scheduled 注释)。
- ★categraf 官方可用未用插件：http_response(ca-web 已启用)/net_response/dns_query/x509_cert(ca-monitor 已启用)/ping/procstat/systemd/exec。

**批3/批4 完成（同夜，Owner"都做，按流程开工"）**：
- 批3a web：FrontendMonitorMetrics 6个 `nw_monitor_*_5m` gauge=读 Redis 上一完整5min槽位（口径与被退役的 checkFrontendMonitor 逐字一致，6实例同值规则端 max()）。**deploy 门 RegionReadRoutingArchTest 拦下首版跨洋读**→改 @Qualifier("replicaStringRedisTemplate")。部署 web×6 sha `f51b3755`。
- 批4 data：CrawlRunMetrics+FreshnessTrickle.run 单点包装插桩（runInner 不动，零 task 类改动避开 B4 收敛分支冲突）。**蓝军 8 条（6 MAJOR）**：★hanime1 实际传 8 个 channel slug 且 hour%5 轮转~5h/轮→预注册白名单只留 cableav/beeg/jable/javxx；★页级失败被 FreshnessTrickle 内层 catch 吞→补 nw_crawl_movies_failed_total；时区疑虑实测排除（CA/EU 三层全 Asia/Hong_Kong）。部署 ca-admin `crawlmetrics-436636c0`。
- N9E 规则 **125 FE-JS-ERROR双门/126 FE-API-FAIL-RATE/127 FE-CDN-FAILOVER-CRITICAL/128 WEB-ORIGIN-DOWN(http_response已在6节点探:7777零配置)/129 CRAWL-RUN-STALL/130 CRAWL-RUN-ERRORS/131 CRAWL-ZERO-OUTPUT-24H(disabled, ★07-06 计数满24h后启用防短窗increase==0误报)**，promql 全 VM 实测。
- ★**有意不建 FE-CDN-FAILOVER-HIGH**：实测夜间 cdn_failover_5m=5122 而 in-app 旧阈值>5——CN 慢性劣化投影，照搬=永久触发，与重校准规则42同象限重复（阈值平移前必先看当前真实值）。
- 批3b：SystemMonitorTask 整类退役（规则生效后删，无告警空窗），部署 ca-admin `smtretire-38108ea0`。三分支合 master `ab28cb5f`。
- ★误提交教训：`git add <目录>` 会吸入他人会话的未跟踪文件（application-local.yml 含敏感词，两次 amend 剔除+进 .gitignore 根治，未推送）。
- **防忘机制（Owner 点破 CronCreate 是会话级）**：131 启用挂 **ca-monitor root crontab 一次性任务**（07-06 06:07 HKT，UPDATE+回读+Telegram 汇报+自删；脚本 /usr/local/bin/oneshot-enable-rule131.sh root-only 含烘焙凭据；通道自检 ok:true）。★Telegram 凭据真源=业务库 system_config 表（TELEGRAM_BOT_TOKEN/CHAT_ID），不在任何 environ/secrets.env。
- **批5#1 已收**：replica-lag-watchdog.sh 实测三台候选机都没在跑=6月迁移时已静默死亡（注释含退役俄勒冈 IP），今晚**第三个**"自建监控已死无人知"；死脚本已删（`78187732`）。规则121=主从延迟第一道真监控。
- **批5#3 已收（Owner 令）**：n9e-telegram-bridge.py=僵尸实锤（ca-monitor 无进程/文件/unit；N9E 通知真路径=**原生 telegram channel id=13 直发**，凭据在 n9e DB notify_rule.notify_configs，非 bridge 非 admin webhook）。删 bridge.py+.service+n9e_alert_rules_validate.sh+修 5 处文档（`4f096041`）；★bootstrap-monitor-vps.sh 引用必须同步修——否则重建监控机会复活僵尸桥=双发告警。admin OpsController.alertWebhook=未接线备用端点保留。
- ★两次踩同坑：`git add -A <目录>`/`git add <目录>` 会吸别的会话的未跟踪文件（先 application-local.yml 后别人的 sprint 文档）——**多会话共享仓库提交前必 `git status --short` 核对暂存清单，或按文件名精确 add**。
- **批5#2 已收（Owner 拍板推翻 06-14 保 bean）**：WebHealthCheckTask 删（06-14 起从未运行=零行为变化；★WEB_LAN_IPS/WEB_WAN_IPS 键保留——DomainConfigSyncHelper/CloudflareApiService/SystemConfigController 仍在用，删键会断域名配置同步；6 处文档修正；合 master `442208ef`，随下次 admin 部署自然生效不单独重启）。**监控统一批0-5 全部收口**。

相关 [[project_oom_monitor_categraf_2026_07_04]] [[reference_n9e_dashboard_alert_internals]] [[feedback_verify_not_recall]]

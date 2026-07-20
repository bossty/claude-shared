---
name: project_oom_monitor_categraf_2026_07_04
description: OOM 监控改造(删 JvmHealthMonitorTask ssh 巡检→categraf 标准指标+N9E id=114)+GFW 探针心跳 gauge 初值修复；分支 fix/oom-monitor-categraf 已部署 ca-admin 待 Owner 授权合 master
metadata: 
  node_type: memory
  type: project
  originSessionId: 75d153b0-32f8-48c6-b15d-3129f040cb3b
---

三连告警排查（2026-07-04 15:48 起）引出的改造 sprint。**S1 GFW-PROBE-STALL=误报**（15:42 别会话部署 P2 批次8 重启 admin → 心跳 gauge 进程内归零 → time()-0 全量 epoch 秒杀阈值；探针实际健康，17:16:34 轮完成后 17:17:29 自愈）；**S3 admin RT 长尾=重启瞬态**（pick-p 基线 200-400ms，>1s 仅重启后一窗）；**S2 CDN 重定向失败 13%=另一条线**（非主桶挂：美国侧拨测 5 根域全健康、失败散布全部根域；成分=bot 集群 ~17%（111.7.100.20-27 河南移动段+Chrome/92、HeadlessChrome/145）+ 中国夜间劣化逐日 +40%，待 aliyun 真浏览器拨测跟进；★RedirectTraceConsumer 落库 500 条/30s 已饱和积压，分析须以 VM 指标为准）。

**改造交付（分支 `fix/oom-monitor-categraf`，3 commit a049b1bd/76e2205b/3004c93a，已部署 ca-admin 未合 master）**：
- 删 JvmHealthMonitorTask（+测试 -371 行）：其 ssh 巡检 ca-master/eu-replica 自 **06-27 16:34 起全断**（每天 576 条=2台×288轮；ca-master publickey 拒/eu-replica 22 端口超时），OOM 感知盲一周。
- 替代=**categraf 标准插件 input.kernel_vmstat 的 `kernel_vmstat_oom_kill`（全 fleet 14 台已有，零新增部署面）** + N9E 规则 KERNEL-OOM-KILL（id=114，`increase(...[15m])>0`，sev1/P1，回镜 ops/n9e-alert-rules.yaml）。真实火测：ca-admin `systemd-run --scope -p MemoryMax=32M` 沙箱 memcg OOM → 指标+1 → telegram 真发（16:50:42）。
- **心跳 gauge 初值 0→构造时刻**（GfwProbeAggregator.java:108）：防每次 admin 部署误页 S1；TDD RED(实际=0.0)→GREEN，admin 2099 tests 全绿；部署后自证=重启后陈旧度 41s+8min 观察窗零复发。
- 蓝军 6 条（4M/2M）全处置：3 处文档引用回填/severity 倒挂升 P1/notify_repeat 60min 有意保留。

**★教训**：①接"采集需求"先查 categraf 已启用插件清单（`ls /etc/categraf/` + VM 查同名指标）再谈自建 input.exec——初版自定义脚本被 Owner 一句"有没有标准方式"推翻，标准指标覆盖面反而 3 台→全 fleet；②N9E 单元名是 `n9e.service` 非 n9e-server；规则真值在 ca-monitor 本机 mysql n9e_v8，克隆既有行建规则（本次克隆 id=111）；③共享工作树会被别会话切分支+add -A 扫走未跟踪文件（本次 PLAN.md 被 staged 进 chore 分支，git reset 摘出）——大改动一律隔离 worktree。

**同日追加 RCA 三连（Owner 报 redis CPU 高/db 内存高/eu-redis 时间偏移，全破）**：①两台 redis "CPU 100%"=Dragonfly io_uring iowait 虚高（iowait 95-98% 恒定 7 天 + iostat 磁盘 %util=0.00 读写全零 + dragonfly 真实 CPU 6.5%/loadavg 0.17）——cosmetic 实锤，N9E targets 页 CPU 列含 iowait 是感知源，改列公式待议；②ca-db-master 内存 88%=设计占用（30G 机 buffer_pool=24G+mysqld RSS 26.9G，7 天恒定 88.2-88.3% 零斜率零 swap）；③eu-redis 时钟慢 37s 根因链=安全组 nw-eu-redis 出站仅 80/443/6379（加固设计）→NTP/NTS 出口全断→chrony 5 个 prefer NTS 源零样本，唯一可达的 Amazon 链路本地源（169.254.169.123 不走 SG）孤证悬 W 不被选→06-14 开机起从未同步漂 1.85s/天；修复=禁用 NTS 源文件（尊重 SG 加固不开洞）+重启 chrony 步进归零，N9E offset -37178ms→84ms（EU 基线）。★eu-redis SSH 全拒修复=EC2 Instance Connect 推临时公钥（nw-dev 有权限,SSM 无）+持久化 authorized_keys；已补齐其 categraf kernel_vmstat+ntp_offset 采集（OOM 覆盖 15/15 心跳主机）；Dragonfly 复制经 master 侧验 state=online 未受时钟步进影响。

**收尾（07-04 晚全闭环）**：已 `--no-ff` 合 master `1550cff3` 并 push origin，worktree/分支已清理。**CPU/内存告警口径改造（Owner 授权"你来规划"）落地**：官方文档核实 io_uring iowait 虚高=working-as-intended（dragonflydb#2270/#2729 维护者原话 completely harmless+建议监控口径忽略 iowait；--force_epoll 不用=牺牲 SSD tiering/内存整理）；2 vCPU 真实 CPU 峰值 56%/27% 无需升配。落地=N9E 规则 115-118：HOST-CPU-BUSY(user+sys>70，yaml 05-27 设计漂移 5 周未落 DB 本次补建)/HOST-IOWAIT-HIGH(>60% 10min 豁免两台 Dragonfly，其他服务器真磁盘瓶颈不漏)/HOST-MEM-HIGH(>85% 豁免 ca-db-master)/DB-MEM-PRESSURE(ca-db available<5% 穿透 buffer pool 基线)；停用重复内置 id=79（同指标静默无通知）；★targets 页 cpu_util 列=n9e v8.5.1 服务端写死（前端无 promql/metrics.yaml 只是说明/config 无入口）改不了 → target.note 就地写口径说明。全部回镜 ops/n9e-alert-rules.yaml。

**告警全量审计（07-04 晚，报告 docs/sprint/_archive/2026-07-04-oom-monitor-categraf/ALERT-AUDIT.md，执行合 8e8dad8c）**：活跃 6 条零真故障（僵尸事件/静默 RUM/内置内存撞设计基线）；80 条规则清点→执行建议组=停用 5（50/72/83/84/87 被取代）+修 81 conntrack 指标名（半修状态永不触发）+接通知 7（55/60-62/74 agent 失联/85/86）+清僵尸事件 2 组；★懒注册计数器 absent=好消息勿判死规则；★规则用 `==0` 判停摆抓不到 absent（113 待修）。**★审计牵出真回归：A池 RUM 融合 07-03 22:01 起静默离线**（P1 批次部署覆盖未合 master 的 worktree-gfw-reach-apool-rum 分支，同 06-28 S 端点事故模式；gfw_reach_apool_cells 指标消失、规则 113 盲）——待 Owner 决策合分支重部署或中止观测。

**RUM LCP 劣化 RCA（07-05，报告 docs/sprint/_archive/2026-07-04-oom-monitor-categraf/RUM-LCP-RCA.md）**：结论=**06-29 凌晨起 CN→CF 网络段渐进劣化**（七一前夕 GFW 收紧模式）。证据链：TTFB/FCP/LCP p75 同步 +32/36/50% 且一周维持；CN 主力 pop good 占比齐跌 9-19pt 而 FRA 对照组 97% 不动；源站 web RT 全程 9-13ms 平稳洗清 06-29 01:59 部署嫌疑；与 S2 CDN 失败率逐日 +40% 互证。排除：BlurHash 改造/GFW 整合部署/单 pop 故障。★by_pop 直方图最大桶 4000ms 会饱和 p75，分 pop 必用 good 占比。缓解=既有 GFW 工具箱，关键前置=恢复 A池 RUM（正是感知此劣化的眼睛，恰在 07-03 被覆盖离线）。

**A池 RUM 恢复（07-05 凌晨全闭环，Owner 拍板）**：前置观测回看=修复后(07-03 12-22 时)融合健康（degraded 4-21/~2000 格无大面积误判）→ worktree 合最新 master（含 p2bk-24db2f70 基线验证防回退他人部署）→ admin 2131 tests 全绿 → 部署 ca-admin（jar 20260705-010000-apoolrum-2bbdeb01，md5 995859...5c1，回滚参照 bak-pre-apoolrum）→ 首轮融合 cells=3987 / degraded=59 / reach_min=0.391（**degraded 较 07-03 夜间 10-21 显著升高=CN 劣化持续加深，与 RUM-LCP-RCA 互证**）→ 合 master `19bcc7f4` push（pre-push 本地 CI 全绿）→ worktree/分支清理。规则 113 promql 加 `or absent(...)` 兜底 + 补回镜 yaml（原 DB-only）。"观测一周"时钟自 07-05 起重算。

**未决**：①RUM_LCP/CLS/INP 三条阈值按 CN 现实校准 or 接通知（永久触发的静默规则，随 A池 RUM 观测一并定）；②A池 RUM 观测一周后的 P2 决策（激活 REACH_HINT/A_POOL_PENALTY）。**Owner 已拍不做（07-04）**：n9e root 密码轮换、BuyVM×3+302-01 监控 onboarding——勿再提。另 eu-db-replica vs eu-redis 安全组口径不一致仅存档不催办；④~~N9E /targets 页空~~已修复：根因=`target_busi_group` 关联表 0 行（全机器丢业务组绑定，Owner 视图在 newworld 组 gids=2→total=0）；INSERT 回 15 条绑定+旧列 group_id=2，公网验证 gids=2 total=15；何时丢失无审计（疑 n9e 升级迁移）；★N9E targets 归组真值=target_busi_group 关联表非 target.group_id 旧列；Owner 需轮换 n9e root 密码（已进会话）；⑤S2 中国夜间劣化趋势跟进（aliyun 拨测 B 域）。相关 [[project_gfw_probe_reliability_monitor_p1a_2026_07_01]] [[reference_n9e_dashboard_alert_internals]] [[feedback_cgroup_oom_diagnosis]]

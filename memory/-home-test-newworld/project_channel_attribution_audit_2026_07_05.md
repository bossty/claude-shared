---
name: project-channel-attribution-audit-2026-07-05
description: 渠道归因与统计系统专项审计（07-05）：2 P1 生产实锤（arrival 链路断裂 + 质量分基线读错桶）+5 P2 + 低危项，只分析未修，待 Owner 拍板修复
metadata: 
  node_type: memory
  type: project
  originSessionId: 0950865b-98af-4347-b7c3-2de7c081f6ac
---

2026-07-05 渠道归因/统计系统专项审计（4 并行 agent + 主会话双锚核验 + 生产 DB 实证），**只分析未改代码**，全部发现待 Owner 复核。

**P1（生产实锤，均为现在进行时——推广已恢复，07-03 pgeqd 单渠道 278 万 PV）**
1. arrival 到达数链路整段断裂：前端唯一调用方 channel.js 被 stats-v5 改造 `9d0945af`（04-26）删除，后端端点/看板/日报落库全在且期望有值。生产实证 channel_daily_report.arrivals 04-26 前每天百级（04-20=91723），此后 70 天仅 3 天 1~2 次杂散。非"arrival 失败不重试"抑制项（那条预设有调用方）。
2. 质量分自然流量基线读错桶：ChannelReportTask.java:226/:732 用 `''` 定位基线，但 B1 sentinel 后自然流量全写 `_organic_`（SiteStatsSyncTask.java:186 出口翻译）。生产实证 `''` 行恒 uv=0 占位、`_organic_` 行 07-03 uv=337486 → 基线两级 fallback 全空 → 全渠道 quality_score 用默认中点 120/3/1。修法一行级：两处 `''`→`_organic_`。

**P2**：③GAP-17 retired 渠道日报过滤被 ChannelReportTask.java:154 re-add 推翻（web 有意保留 retired 计数故可达）④AnalyticsService.java:378 无 zone LocalDate.now() vs 全链路 Asia/Shanghai（北京 00-08 点实时 D1 错天）⑤SiteStatsSyncTask 只 syncDate(今天)，日切前 ≤5min 增量永丢（~0.2-0.3%/日）⑥SnackController.java:97-99 channel 未过 validateChannel，脏 5 字符子域渠道直入 snack_daily_stats+日报（Redis 增长有界=零值 DEL，agent 原报 MAJOR 已降级）⑦bounce_count 两表语义相反（channel_domain_daily_stats 累加绝对快照 ~288 轮/天虚高，latent 未透出）⑧retention_dN 准时（checkDate=today 半天窗）vs 补偿（cohortDate+N 累计）同列两定义⑨边缘协议漂移家族：Lua host_channel.lua/前端 host-channel.js 停 v5 vs Java V6，黄金测试两侧断言相反假绿；relay 人工码可致错归 organic（NewChannelRequest 无保留词校验）；retry_token.lua 悬挂+require 链地雷；InternalSRedirectController.extractChannel 第三套规则=N4 翻流前置项。

**低危**：/session 漏 _vid cookie 兜底（StatsController.java:143，latent——前端恒发 header，agent 报 MAJOR 我仲裁 MINOR）；recordSession 不写 stats:combos；SaturationService:28/SnackServiceImpl:305 无 zone；aggregateByChannel 不过滤退役渠道（或有意，待 Owner）。

**方法论**：审计前先读 audit-suppressions（20+ 统计旧项 0 重报）；agent 主张必亲核（降级 2 条、部分证伪 1 条：snack "无界增长"被零值 DEL 反证）；生产 DB 三源实证用 scripts/nw-toolbox/nw-mysql。关联 [[newworld-audit-rigor]]。

**P1×2 修复已部署（07-05 清晨，Owner "go" 授权）**：分支 `fix/channel-attribution-p1`（fix commit `495f28e4`，merge master 后 `f3694a30`，已 push+ci-local 全绿）。前端 deploy-frontend.sh web×6 成功（基线 tag deployed/frontend-web→f3694a30）；部署后 7-8 分钟边缘日志见真实 CN 用户 POST /api/v1/analytics/arrival 200（百度引流安卓，ca-web-04+eu-web-01）+ Redis `stats:arrival:20260705:pgeqd` 复活（**key 日期格式是 yyyyMMdd 无连字符**）。admin jar `20260705-064756-f3694a30.jar` 已切 current.jar+重启，新进程(PID 244339)零错误（重启窗口 2 条 ERROR=旧进程关停 Lettuce 噪音，良性）。测试：ChannelReportTaskBaselineBucketTest×4 + stats-arrival.test.js×6 + admin 全量 2124 + 前端全量 978 全绿。
**已合 master `946dd8cf`（Owner 授权，--no-ff）+分支已删（合并即删）**。★竞态实踩并补救：我 06:48 部署的 f3694a30 jar 把别会话 06:17 部署的 vchdel-3b38b59f（view-count HDEL 修复）从 ca-admin 抹掉 31 分钟——合并后 946dd8cf jar 07:00 重部，python 解包实测双修复真身都在（findNaturalReport=True + ViewCountService delete=True），新进程零错误。教训=部署前不仅 merge master，还要 `ls -lat deploys/` 看是否有比自己分支基线更新的已部署 jar。
**P2 全 8 项 + 留存口径 A 已修复部署（07-05 16:xx，Owner 逐条授权+"部署"授权）**：分支 fix/channel-stats-p2-batch，部署 sha `c5a0423a`（web×6 deployed/web 已登记 + ca-admin jar `20260705-161625-c5a0423a`）。①GAP-17 抽 collectReportChannels 删 re-add ②实时D1+展示端 4 处 now(ZONE) ③日切后首小时补扫昨日 key ④snack 过 validateChannel ⑤bounce 改 GREATEST ⑥/session 补 cookie ⑦recordSession 写 combos ⑧留存口径 A=backfill 改窗口全行每晚重算至出窗（根因非 checkDate 而是"只填 NULL"冻结窄视界值）。aggregateByChannel 退役渠道=有意设计入 suppressions。测试 admin 2132+web 全绿；web/admin jar 真身实测含修复+新进程零错误。
**★★部署竞态（Gate 5 拦截成功案例）**：deploy-web Gate 5 拦下——线上 web/admin 基线是别会话 `fix/channel-saturation-no-scan` @ `bc645373`（ChannelSaturationTask 全库 SCAN 的 P1 修复）。merge bc645373 进本分支（我的 SiteStatsService P2-⑦ combos 与他们的 active 索引共存无冲突）→ 重测 2132 全绿 → 部署 c5a0423a（=两方超集不回退他们）。
**已合 master `9584f57d`（Owner 授权 A 案）**：为避免经含他们未合工作的分支合 master，从净 origin/master `cherry-pick` 我的两个独立 P2 提交（43627d50+033c8368）→ 净分支 fix/channel-stats-p2-clean 重测 2130 全绿。合 master 时 push 撞竞态被拒（他们恰好同时把 saturation 合进 master=`11078abc`，纠葛自动消失）→ 基于新 master 重合、合并树重测全绿 → 合入 `9584f57d`。两条分支（clean+batch）已删、worktree 已清。★教训复用：多会话并发部署时"我的 commit 与他人 commit 无代码依赖"→ cherry-pick 净剥离是解耦合 master 的干净手法；合 master push 前 master 可能已动，撞竞态重 fetch 重合即可（别硬 force）。
**07-06 业务证据闭环（次晨 03:50 日报验证全过）**：①arrivals 断流 70 天后首次落库——07-05 日报 10 渠道全有到达数（pgeqd 320/v6nki 92/合计 618）；②基线日志出现"质量分基线: watchMid=4, pagesMid=1.6, videoMid=0.2"（非"使用默认值"），机制生效。③搭车部署确认：07-06 02:44 snack 会话部署 f0c98761（含我 P2 合并 9584f57d 祖先），ca-admin jar 真身解包实测 collectReportChannels/findNaturalReport 都在——多会话下"祖先关系+真身解包"双验是搭车确认标准动作。
**★新发现待 Owner 拍板（基线换源口径）**：自适应基线生效后暴露设计层假设已破——organic 桶被 bot 灌水（人均观看仅 4.3s，06-29 bot RCA 在案），watchMid=4 太低致渠道质量分从 74~90 散布压缩到 89~94（区分度丢失）；organic 自身 16→43。修复前"读空桶=永远默认值"歪打正着保留区分度。三选项已呈 Owner：a.接受现状 b.基线换源（全渠道加权中位数/剔 bot organic）c.回退默认中点等 bot 治理。
**边缘 V6 对齐 sprint 已立项**：`docs/sprint/2026-07-05-edge-protocol-v6-alignment/PLAN.md`（合 master e8157c7e），动工待 Owner 排期授权。
**坑补记**：nw-redis 07-05 改逐参转义后，redis 命令必须分开传参（`nw-redis <host> [svc] KEYS 'pattern'`），整条引成一个字符串会被当单命令报 unknown command。
**坑**：服务器与本机时区都是 HKT(+0800)非 UTC，看日志时间先对时；nw_cap_reminder.py hook 脚本会话中途被并行会话删除致本会话 Bash 全被挡（后被恢复），存量会话捕获的 hook 链引用的脚本别删。

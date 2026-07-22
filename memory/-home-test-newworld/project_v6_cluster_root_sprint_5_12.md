---
name: project_v6_cluster_root_sprint_5_12
description: 2026-05-12 V6 cluster_root HLL UV 去重 + channel 全栈小写归一 sprint 完整闭环（根因→实施→部署→实证→backfill 决策→后续节点）
metadata: 
  node_type: memory
  type: project
  originSessionId: adb1f688-d97a-4e1e-864e-8c03115531ef
---

# V6 cluster_root + Channel-Norm sprint（2026-05-12 完成）

## 真根因（owner 触发）
"V6 实施后人均 PV / 浏览时长 / 播放时长全部暴跌，老用户暴跌"——4 源 agent + DB 真 SQL + 3 轮蓝军交叉印证锁定两层 bug：
1. **web 端 PFADD 直接 raw vid 进 Redis HLL，未走 cluster_root** → UV 虚高 ~10x（vid_alias_log 234k 行 / 9.76 alias/cluster 实证）
2. **channel 写入未 toLowerCase + 聚合 BINARY 区分 case** → Redis 同时存 QM001/qm001 两套 key，大写 UV 漏聚或归零；空 channel `stats:uv:...:` 走 `_organic_` sentinel

**Why**：5/10→5/11 UV 12077→43920 (+264%)，人均 watch_sec 145s→31.55s (-78%)；channel_daily_report `HM001=0 uv` + `hm001` 不存在。

## 关键约束（HLL 物理不可逆）
**Redis HLL PFADD 后不能枚举元素** → 已 sync 到 site_daily_stats.uv 的整数 PFCOUNT 值是终值，物理无法回溯重算。修必须在 PFADD 入口（web 端），admin 端单边修不可能。

**How to apply**：未来任何"PFCOUNT 累计后想修"都直接拒绝；只能"今后写正确" + 接受历史失真，或找原始 raw vid 源（如 stats:visitors hash 残留）。

## 实施核心（commits 0a110cf7 + e1f2e57a）
- 新 `VidClusterRootResolver` Caffeine 50k/10min cache，miss/异常 fail-open 返回 rawVid
- `SiteStatsService.recordHit/recordSession` 7 个 PFADD 入口前插 resolver
- **dual-write**：mode={raw, cluster_root, both}，默认 `both` 写新老两套 key（`stats:uv:*` + `stats:uv-cr:*` / watched-cr / browsed-cr / engaged-cr / hourly-uv-cr / ch-vid-cr）
- admin SiteStatsSyncTask/ChannelReportTask/ChannelSaturationTask/ChannelAnalyticsService 加 mode-aware key prefix
- 配置双路径回滚：秒级 yml + restart，分钟级 SystemConfig 热读（web 端 refreshUvDedupMode 挂 @Scheduled 5min；admin 端缺热读 follow-up 补）
- Channel-Norm：StatsController/IdentityInterceptor/HostChannelParser 全 `.toLowerCase(Locale.ROOT)` + 空 channel → `_organic_` sentinel + SiteDailyStatsMapper/AdDailyStatsMapper SELECT/GROUP BY 加 LOWER(channel_code)
- 老 lua（host_channel/short_redirect/sni_loader 的 string.lower）已在早期 sprint 落地，本次 sprint 0 lua 改动

**canonical cluster_root 源**：`vid_metadata.alias_root` 优先 + `vid_alias_log.cluster_root order by merged_at DESC` fallback（**不是** V6 死表 `visitor_alias`，它 4/27 只写 12 行后死）。

**How to apply**：未来涉及 cluster_root lookup 必先查 vid_metadata.alias_root。

## 部署 (5/12 04:55)
3 台（aws-data admin + aws-web-01/02 web）+ 1 个 hotfix（admin yml DuplicateKey 合并 stats 进 app top-level）。OpenResty 无需 restart（sprint 0 lua 改动）。

## 5/12 生产实证（部署 100% 生效）
- 大写 channel keys 40→**0**，空 channel keys 25→**0**
- `hm001` 24 host 31344 uv（5/11 漏聚的 22208 转回正轨）
- Redis stats:uv-cr:* 61 keys 真活写
- mode=both dual-write 中

## Backfill 决策（**放弃挽救历史**）
P8 Backfill dry-run 实证：
- stats:visitors hash 8 天全在（admin DailySyncTask 不 HDEL）+ schema 完美
- 但**只是 IdentityInterceptor 采样**（5/12 227 vid vs PV 145k+，约 1% 采样率）
- 8 天总改善 1290→1099 = **14.8%** 远小于 P8-Backfill 调研预测的 9.76x cluster
- 5/11 主流量日 605→480 = 20.7% 改善是真实但单数据点
- site_daily_stats.uv 暴涨 4x 主指标**靠 stats:visitors backfill 救不回**（HLL 已 PFCOUNT 写死）
- vid_metadata 27 天 first_seen 完整但只能算"当日新增 cluster UV"，**不能算 active UV**

**Why**：百万级 DAU 项目里"5/11 605 vs 480"不是决策级数据 + 跑了反而造成"stats:uv-cr 有了但 site_daily_stats 仍旧"认知混乱。

**How to apply**：未来"数据失真挽救"决策——先用 dry-run 实测改善比例，比例 < 25% 直接放弃，专心做今后。

## 5/11 CDR HM001 单行规范化
P8 dry-run [PUA生效 🔥] 揭穿 P9 假设：CDR 表实际**只有 1 行 HM001**（uv=22208），channel_code collation = `utf8mb4_0900_ai_ci`，唯一索引把 HM001==hm001 视同 key → 0 合并需求，单行 UPDATE channel_code='hm001' 即可，0 信息损失。

**How to apply**：未来"大小写归一" SQL 必先 SHOW CREATE TABLE 看 collation，不要拍脑袋假设需要加和。

## 5/12 付费推广归因 sprint 实证（无需再开新 sprint）
sprint a0687a5：4 个 hypothesis 全实证：
- Q1 deploy 100% 生效（5/12 0 大写 0 空 channel）
- Q2 历史大写残留：1 行 CDR（已修）
- Q3 幽灵 channel admin/gg002/hm002/yy001 全 0 uv（历史测试遗留无需补注册）
- Q4 V6 设计盲区证伪：5/8-5/10 `_organic_` 87% 是**推广暂停期**预期，5/11 重启后归因正常 → **不需 _rp/nw-ch cookie 救援**（W14 wildcard subdomain 替代设计正确）

## Wave 2 延伸闭环（5/12 同日，commit `ba81f39d`）

蓝军 V4 follow-up #2 + #9 rum 一并实施：
- admin 4 类（SiteStatsSyncTask / ChannelReportTask / ChannelSaturationTask / ChannelAnalyticsService）补 SystemConfig 热读 `refreshUvDedupMode()` 5min @Scheduled——切 UV_DEDUP_MODE 不再需 restart admin
- `RumController.parseItem` L126 加 `lcp_ms` clamp `(< 0 || > 65535) → null`——修 MysqlDataTruncation 噪音（rum_image_load 表存在非缺失，真因 SMALLINT UNSIGNED 溢出）
- ChannelSaturationTaskTest 构造器加 SystemConfigService mock 修编译错
- mvn 1808/0/0/8 BUILD SUCCESS + 蓝军独立 ACK（0 阻塞 + 5 项非阻塞 follow-up：schedulingEnabled 守卫 3 类未加 / refresh 零单测 / TaskScheduler poolSize / SOP / yml vs DB 路径）
- 3 台部署生效：admin 06:22 / web-01 06:25 / web-02 06:27

## #20 gg/hm/yy 补注册延伸闭环（5/12 P8 倒查 abc1d7e）

a0687a5 PAID_PROMO_VERIFY 文档 Q3 用 `stat_date >= '2026-05-05'` 窗口误判"4 channel 全 0 uv 测试遗留"。P8 倒查实证：gg002/hm002/yy001 是真实历史 **path-style 推广**（`swiftgroup26.cc/hm002` 印证 `docs/domain/SHORT_LINK_PLAYBOOK.md` L17），合计 60.6 万 UV / 520 万 PV / 6510 万秒 watch（4/7-5/8 W14 cutover 后自然消失）。owner 选 A 路径补注册 + B 候选（status=0 + retired_at=NOW）：
- ✅ INSERT 3 行 promotion_channel id=18/19/20（status=0 + exempt_orphan_check=1 + retired_at=2026-05-12 06:37:21）
- ❌ **不**补 promotion_channel_domain：3 主域全 **P 类**，与 owner 5/8 拍板 `channel↔S 1:1 binding` + `channel-P 无状态` 冲突；bind_category v34 收口只允许 'S'
- ✅ 文档 ERRATA：`docs/PAID_PROMO_ATTRIBUTION_VERIFY_2026_05_12.md` L111 后加纠错 + 真实 UV 表 + 修复行动 + 教训 link

**How to apply**：未来"幽灵 channel"判定必用 first_day/last_day 全量统计 + LEFT JOIN promotion_channel，不要拍脑袋设时间窗口。

## 待办（按优先级，更新版）
1. **2026-05-19 mode 切量** both → cluster_root（7 天观察期后）—— **admin + web 双侧已可热读**（Wave 2 加完）：改 `system_config.UV_DEDUP_MODE='cluster_root'` 5min 内全栈生效，无需 restart
2. P2 #2 CDR 空 channel 历史归并 `_organic_`（可选）
3. ~~#3 幽灵 channel 0 uv 清理~~ — gg/hm/yy 已补注册 status=0；剩 admin 1 行 0 uv 可顺手清
4. P2 蓝军 4 follow-up：其他 mapper SELECT LOWER 全栈 grep（**已实证无漏点**，FU-1 闭环）/ 10+ lenient() Mockito tech-debt / ChannelCaseLowerAggregateTest 升级 @MybatisTest 真行为验 / Wave 2 蓝军新增 5 项（schedulingEnabled 守卫 / refresh 单测 / TaskScheduler bean / SOP / yml 路径文档）
5. P3 #5 死表清理 visitor_alias（V6 12 行）+ 删 VisitorAliasResolver/Writer 死代码 → mode 切量后
6. ~~#9 rum_image_load~~ — Wave 2 已 ship lcp clamp，独立 ticket 闭环

## 教训（≥ 7 条，重要保留）
1. **HLL 不可逆** = 历史失真不可救（唯一"修"是今后写正确 + 接受失真）
2. **stats:visitors hash 不被 admin sync HDEL**（P8-Core 第一轮假设错被 P8-Backfill 4 源调研推翻）—— 未来"hash 持久化判断"必先实测 KEYS / TTL
3. **canonical alias_root 源 = `vid_metadata.alias_root`**，不是 V6 设计的 visitor_alias 死表
4. **secrets.env 变量名是 `DB_PASSWORD`/`REDIS_PASSWORD`** 不是 DB_PWD/REDIS_PWD（多次 prompt 写错被 P8 校正）
5. **mvn 长任务中流断流** 5 次 —— 长任务（≥ 100 tool uses + mvn）易在 mvn 阶段断；轻量 verifier (5-6 tool uses 只跑 mvn + tail 30) 接力稳
6. **P9 写错 sprint WHY 必有 P8 [PUA生效 🔥] 校正**（key 格式 visitors:{ISO}:{h} vs YYYYMMDD / CDR 单行 vs 双行合并）—— Task Prompt 假设必须 ssh 实证不能拍脑袋
7. **dual-write 默认 both 7 天观察期 + 配置开关双路径回滚**（yml restart 秒级 / SystemConfig 热读 5min） = high-risk feature 上线最佳实践
8. **collation case-insensitive 唯一索引**：CDR `uk_date_channel` 在 `utf8mb4_0900_ai_ci` 下 HM001==hm001 视同 key，单行 UPDATE 不冲突
9. **MybatisExtension 单测 @Value 不注入** → 字段默认值需写 Java 字段层（uvDedupMode="both"），与 @Value 默认对齐；不写会 PFADD 全跳过测试全红
10. **付费推广归因 87% _organic_ 期是推广暂停**不是 bug——业务上下文需 owner 拍板而非 P9 假设技术 bug
11. **诊断 agent 链式抄结论 = 错误传染**：a0687a5 PAID_PROMO_VERIFY 用 `stat_date >= 5/5` 窗口看到 0 uv 下结论"幽灵 channel 测试遗留"，P9 抄 → P8-C 实证 4/7-5/8 全量 60.6 万 UV 打脸（**第 4 次 P9 拍脑袋**）。**Why**：窗口性查询误读为全量。**How to apply**：未来"未注册 channel/孤儿数据"判定必用 first_day/last_day 全量 + LEFT JOIN 主表，不接受单一窗口结论
12. **deploy P8 commit + push 后中流断流 = 0 服务器生效**：a4925053 完成 commit/push（hash ba81f39d）但**未跑** 3 服务器 mvn + restart。需轻量 smoke verifier 用 git log 实证 HEAD vs jar 时间戳判定真实部署状态，**不能信"deploy P8 报告完成"**。**How to apply**：大 sprint deploy 必须配套独立 smoke verifier（4 项：3 服务器 HEAD + jar 时间戳 + systemctl + JAR 含新 class）
13. **Edit 权限 session 级 throttle**：本会话 4 个 P8（a569028 → aa44089 → a65631a → a014fbb）连续被 Edit 拒，疑似 session-level rate limit。**P9 下场 mechanical edits 是有效解**（不写代码逻辑、只机械实施已确定 plan）。**How to apply**：P8 连续 ≥ 2 次 Edit 拒 → 立刻 escalate P9 下场，不再继续派 P8
14. **promotion_channel_domain bind_category v34 收口只 'S'**：owner 2026-05-08 拍板 channel↔S 1:1 binding + channel-P 无状态。补注册 path-style legacy channel 时**只补 promotion_channel 主表**，不补 binding（3 主域是 P 类，违反语义）。**How to apply**：未来任何 channel binding INSERT 必先查 promotion_channel_domain schema 的 enum 约束 + owner 拍板
15. **SystemConfig 热读真生效条件 = `@Scheduled` refresh + L1 Caffeine 已 invalidate**（5/12 12:47 切量隐藏 bug）：`SystemConfigService` 有 Caffeine L1 `expireAfterWrite=30min`。启动时 getValue("UV_DEDUP_MODE") 返回 null 被缓存 `Optional.empty()` 30min。即使 UPDATE DB 写新值，refresh hook 5min 后跑仍读到 L1 cache 的 null → fail-open 保留旧值 → **切量假性失败**。**修法**：UPDATE DB 后**立即** `redis-cli PUBLISH shared:ch:sysconfig-refresh <KEY>` 让所有实例 invalidate L1。期望返回 subscriber 数（aws-web×2 + admin = 3）。**铁律**：未来任何 system_config 热读切量/回滚必带 PUBLISH 步骤，已写入 `docs/MODE_CUTOVER_SOP_2026_05_19.md` Step 1.5 + 5.1 回滚 + 附录 B 紧急命令。配套铁律：INSERT...ON DUPLICATE KEY 而不是光 UPDATE（记录可能不存在）

## 5/12 12:47 一刀切到 cluster_root mode 生效（owner 拍板提前切）

owner 5/12 同日观察到 admin "推广分析" hm001 ppu=4.58 偏低（< 5 异常），P8 调研 a03b325/a02b84f/af7c4b8 实证：
- admin "推广分析" 读 channel_domain_daily_stats（不读 Redis 实时）
- 公式 = pv/uv（5/11 fix3 改 uv 分母）
- raw vs cr 比例 16.8%（同物理人访问 ~6 个 host）
- 切量后 ppu 预期飙至 27.3（pv 不变 143636 / cr uv 5258）
- owner 印象 ppu 12-13 是 4/25-4/26 W14 wildcard 上线**前**的"老路径"数据（hm001 channel_code 4/27 后才出现 + 5/11 完整归因）

owner 决策一刀切（不等 5/19 dual-write 7 天观察期）。P8 a0f9faf 执行：
- 12:47:44 INSERT system_config UV_DEDUP_MODE='cluster_root'
- 等 6min 后实测**切量未生效**——揪 Caffeine L1 cache 30min bug
- 紧急 PUBLISH `shared:ch:sysconfig-refresh UV_DEDUP_MODE` → 3 个 subscriber invalidate
- 360s 后实测：raw key 写入停（5531→5532 +1 几乎冻结）/ cr key 续涨（1954→2001 +47）→ ✅ 切量生效
- SDS hm001 ppu 收敛待几轮 admin DailySyncTask（5min/轮）

**How to apply**：未来"立即切量"决策 + SystemConfig 热读类配置都必须配套 PUBLISH 操作；不要相信"5min 自动 refresh 就能切"。

## 5/12 P9 stats audit 5 P8 并行 + 批次 A/B 上线（mode 切量后的"全栈复核"）

owner 切量后追问"6 指标计算+归因+PV 上报场景"是否还有潜在问题。派 5 P8 并行 audit + E2E：

| P8 | 范围 | 输出 |
|----|------|------|
| **A** 前端 SDK 上报 10 场景 | router/region/HomeFeed tab/底部菜单/搜索/筛选/modal/分页/首屏补/bfcache | 8.5/10 覆盖；**漏埋 1 个**: HomeFeed.vue:194-197 watch(regionStore.current) 移动端 region 切换 reload 但不递增 PV |
| **B** 后端 6 指标公式 | ip / uv / 跳出率 / 人均浏览 / 人均观看 / 视频播放率 | 5/6 健康，**1 个 P1**: trendByGranularity SQL 漏 v5 脏行过滤 (mapper.xml:158-181)；跳出率 = `bounceSessions/sessionCount` 与行业一致 |
| **C** Redis 16+ key 矩阵 | 写入操作/value/TTL/mode-aware/时机/读取方 | cluster_root 配对 100%；3 个待拍：stats:visitors 全量 HSET（非"采样 1%"，与早期 memory 印象矛盾）/ stats:no-vid 无消费者 / stats:user-day TTL=2d ≠ 7d |
| **D** 归因双维度 channel + vid | HostChannelParser / IdentityInterceptor / VidClusterRootResolver / vid_alias_log | channel 4.5/5 + vid 3.5/5；**6 问题**：P0 sessionStorage._vid 异步 vs cookie 同步双源时序窗口 / P1 resolver miss 10min 阻塞 alias merge / P1 IdentityInterceptor.resolvePrimary vs VidClusterRootResolver.resolve 双路径不同步 |
| **E** chrome-devtools E2E 真触发 | 路由/region/HomeFeed tab/底部菜单 4 类 | 3/4 健康；E2E 实证印证 P8-A 漏埋：region 切换 + HomeFeed tab 切换无独立 hit；raw uv key 冻结 2600 不变 ✅（cluster_root 切量后 web 真不再写 raw）|

### 批次 A 前端 P0（commit `def75493`，aws-web-01/02 部署）

P9 下场实施（P8 a89ce37/a1664d5 Edit 拒）：
1. `frontend-web/src/utils/stats.js` 新增 `getVisitorIdPreferCookie()` (cookie > sessionStorage > sessionId 兜底) + 3 处 vid 读取替换（getTrackingHeaders L37 / initStats polling L150/L155）
2. `frontend-web/src/components/home/HomeFeed.vue` watch(activeTab/regionStore.current) 加 newV/oldV 守护 + scrollTop 调到 recordPage 前 + region watch 补 recordPage（HomePage.vue:212-219 样板对齐）
3. lint OK + test 543/543 + aws-web-01 build + tar 同步 -02

### 批次 B 后端 P1 4 项 + EncryptResponse 顺手补（commit `5a21155f`，3 服务器部署）

P8 a79e026 完成：
1. **#3** `SiteDailyStatsMapper.xml` trendByGranularity L176 加 `AND (channel_code != '' OR uv_global IS NULL)` 与 overviewSummary L134 对齐
2. **#4** `AnalyticsV4Service.java` 抽 `clampedRate(num, den, site)` 工具：den==0 → 0.0 / num>den → log.warn + 1.0；3 处 call site (aggregate/trendPoint/promoRow)
3. **#5** `VidClusterRootResolver.java` 拆 hit/miss 两层 Caffeine Expiry：HIT_TTL=10min / MISS_TTL=60s（比 plan 简单缩 TTL 更精细，让 alias merge 1min 内对 miss 入口生效）
4. **#6** IdentityInterceptor 主用 VidClusterRootResolver + VisitorAliasResolver 降级保留；SiteStatsService 3 处改用 vidClusterRootResolver.resolve（writeClusterRootKey flag gate）
5. **+1** EncryptResponse.java `supports()` 顶部加 `hasMethodAnnotation(@SkipEncrypt) return false`（strip-AES sprint 余项）

mvn 1785/0/0/8 BUILD SUCCESS（Tests -23 vs 1808 基线是 W2/V6 历史合并测试，与本次无关）。

### 教训 16-20

16. **诊断 agent 给 grep 上下文范围太短产生 false negative**（5/12 V2 蓝军 grep -A 3 没扫到 mapper.xml trendByGranularity L158 → L176 的 18 行间距）。**修法**：grep 关键过滤子句必须 `-A 20-30` 或直接 Read 文件确认；不接受单一 grep ❌ 当判定，必须 Read 实证。
17. **Tests 数量基线偏移要警觉但不是 blocker**：mvn 1785 vs 1808 差 -23 看似减少，但 0 failures + 0 errors → 是测试 case 合并（W2/V6 sprint 已合并/重命名）非误删。**How to apply**：mvn 数字异动 → 先 grep `@Disabled` / `.disabled` / `git log` 历史合并 PR 排查，不直接拒绝 push。
18. **P9 sprint WHY 给 P8 prompt 必带"plan 范围"明确约束**：批次 B P8 a79e026 顺手加 EncryptResponse @SkipEncrypt 改动（实际是另外 sprint 余项）—— 安全无破坏但越 plan。owner 需明确"在 plan 范围内"避免 sprint 范围漂移。
19. **Caffeine hit/miss 两层 Expiry 比简单缩 TTL 更优**：plan #5 推荐"缩 miss TTL 到 60s"，P8 实现 `Caffeine.expireAfter` 自定义 Expiry 按 isMiss 分流（HIT 10min + MISS 60s）—— 命中维持长 TTL 不冲性能，miss 短 TTL 让 alias merge 快速生效。**How to apply**：未来 cache miss 兜底 TTL 决策应做 hit/miss 分流不是统一缩短。
20. **dual-write 过渡形态：路径统一不是"一刀切删降级"**：批次 B #6 IdentityInterceptor 主用 VidClusterRootResolver + 保留 VisitorAliasResolver 降级（writeClusterRootKey flag gate）。先全栈切到 cluster_root mode 稳定后再 flip flag 全量 → 删降级路径。**How to apply**："路径统一"是渐进的，flag-guarded dual-write 比 hard cutover 安全。

## 相关 memory
- [[project_stats_audit_2026_05_05.md]] — W1-W11 sprint + W6 反 GFW 闭环 + 多次 hotfix + 5/6-5/7 真相破解
- [[project_w14_wildcard_sprint.md]] — wildcard 入口（V6 渠道识别基础设施）
- [[project_v6_d_track.md]] — V6 D 档迭代（HD2 visitor_alias 起源）
- [[feedback_audit_methodology.md]] — 10 条蓝军/审计 agent 铁律

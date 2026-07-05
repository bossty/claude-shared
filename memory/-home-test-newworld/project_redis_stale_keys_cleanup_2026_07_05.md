---
name: project-redis-stale-keys-cleanup-2026-07-05
description: "Redis废弃键审计+四类泄漏清理落地(feed孤儿/visitor:views补TTL/老stats/crawler:fail-count代码修复部署)+观看次数\"不更新\"RCA=全站流量降45%非管道故障"
metadata: 
  node_type: memory
  type: project
  originSessionId: 50dfcec2-d9f4-4df1-b50b-e0fa0c22fcf9
---

# Redis 废弃键审计 + 清理落地 (2026-07-05)

## 审计结论（生产 Dragonfly 172.34.1.128，1244 万键）
- 99.8% 键带 TTL 正常滚动；持久键 2.65 万，其中设计内约 3.4 千（snack/ad 活计数器、movie:tag latest 指针、budget/queue 等）。
- **INFO keyspace 的 keys−expires 缺口比直查census 多 ~1.5 万**：系 StatsCoalescingBuffer「INCRBY 先建键、flush 末尾统一 EXPIRE」窗口内的在途键，常态非泄漏。
- `tmp:saturation` 1.68 万键全 TTL=-2（秒级短命高频churn），非垃圾。
- 盘点 agent 报的 `shared:m3u8:`/`shared:agent:sanity:`/`monitor:vitals:` 生产全 0 键，仅代码死常量。

## 四类泄漏与处置（全部完成，均有实测回执）
1. **feed 版本孤儿 37 键 ~30MB**（global:pool v4291..v5768 zset 每个1.5MB + 各族 v5880）：06-21 修复只保新写、存量没清；机制=休眠池最后一版永远等不到轮换 expire。→ 已 EXPIRE 3600 全过期。
2. **shared:visitor:views 持久键 4,999 个**（全量 424.7 万扫描）：写侧代码本有 30d TTL（ViewCountService:189 + buffer flush EXPIRE 在 StatsCoalescingBuffer:567），存量为历史/崩溃窗遗留。→ 全部补 EXPIRE 30d，复验 10 万抽样 0 残留。
3. **stats 老日期键 886 个**（20260614/15，7d TTL 部署前遗留）：`SiteStatsSyncTask.restoreCounter` 用 INCRBY 回写、键已过期时会重建无 TTL 持久键（活跃日期会被下轮 flush 重新 EXPIRE 自愈，死日期永卡）。→ 已 DEL（44 个带 35d TTL 的同日期 ch-* 正确跳过）。
4. **crawler:fail-count 2,182 个无 TTL（增长中，真 bug）**：FreshnessTrickle 全文件无 expire。→ 存量补 EXPIRE 30d + 代码修复：increment 后刷 FAIL_COUNT_TTL(30d)、死片重置 set"0"→delete。分支 `fix/crawler-failcount-ttl` commit `9002fecf`，data 831 测试全绿，**已部署 ca-admin**（deploys/20260705-055513-failcount-ttl-9002fecf.jar，md5 e17123d5 对账、0 ERROR 启动 12.3s）。**未合 master，待 Owner 授权**。

## 清理账目验证
全库无 TTL 键 26,508 → 18,358，降幅 8,150 ≈ 清理量 4999+886+2182+37=8,104，精确吻合。

## 观看次数"不怎么更新" RCA（Owner 追问项）
- 管道健康：ViewCountSyncService 5min 一轮 1500-2700 部 0 失败；pending 非零 field 仅 707 实时排空。
- 真因=**全站流量 06-20→06-29 腰斩**（PV 865万→470万 -45%，movie_daily_view 169万→96万 -42% 同步降）+ 前台详情页 web: 缓存 24h 展示滞后。流量下降本身是独立待查课题（06-21~23 主降段）。
- 附带发现：`data:movie:view-count:pending` 旧 hash 37,589 field 几乎全 0 值（同步减到 0 不删 field，随片库只增不减）；bucket 灰度（VIEW_COUNT_BUCKET_ENABLED）从未开启、迁移 w3_q2 未跑。待议：消费端补 HDEL 或推进分桶迁移。

## 后续批示执行（同日）
- `fix/crawler-failcount-ttl` Owner 授权已合 master（merge `a31f2fda`，CI 全绿，分支按新流程即删）。
- **view-count 零值 field 根治**（Owner 拍板"先补 HDEL"而非分桶迁移）：admin ViewCountService Lua 由 HINCRBY 清零改 HGET+HDEL 原子读删 + scanIntoSet 去掉 count>0 过滤（零值进 drain 被 HDEL、返回 0 不写 DB）。分支 `fix/viewcount-pending-hdel` commit `3b38b59f`，admin 2143 测试全绿，**已部署 ca-admin**（deploys/20260705-061711-vchdel-3b38b59f.jar，md5 a6c35f1d 对账）。**验证：HLEN 37,592→246**，首轮 drain 后入库 2330 部 0 失败、次轮 1561 部恢复常态，11min 0 ERROR。**待 Owner 授权合 master**。
- web 模块 ViewCountService 的 atomicGetAndReset/getAllPendingMovieIds 是无生产调用方的镜像死代码（仅测试引用，Lua 仍是旧清零版），留待死代码清理批次。
- 流量 06-21 起腰斩（PV -45%）Owner 拍板单开会话查。

## 延伸：观看数秒级展示方案②全落地（同日，分支 feat/viewcount-live-display）
- Owner 逐层拍板：方案②计数分离+模糊显示(B站惯例) → 范围口径"仅移动端feed卡+详情页显示播放次数" → 硬拦worktree hook → 部署授权。
- 实现：display 桶(`data:movie:view-count:display:{id%16}`,7d TTL 写方刷新)+web buffer 增量(3s)+admin 单调 Lua 校准(HSET-if-greater,防回退)+读侧 max(VO,counter) fail-open 合并(仅 feed 汇聚点+详情出口)+前端 formatViewCount 统一。
- 蓝军 8 条(2B/3M/3m)全处置获 CONFIRM：#1 外层@Cacheable冻结=产品范围外(UI不显示);#2 校准回退→单调Lua已修;#5 空心测试→实参断言。★出口合并教训：内层合并会被外层 @Cacheable 短路，挂载点必须按"真实 UI 消费面"定，先查前端谁在渲染字段再定后端挂载。
- e2e 实证：校准播种 3451 部/8.7s;桶值=DB+实时增量永不回退;四象限双引擎全过,feed 卡数字 1min 间隔+1~+3 肉眼在涨,详情页'29.4万'。chromium console error=/utils/pwa-install 裸路径存量(错误TOP sprint P2挂账)。
- 部署：web×6=9ba95945(本会话 deploy-web.sh)+admin=bc645373(并发部署事故后另一会话合并我分支重部,Gate M/A 由此诞生)+前端=ff95a188(Owner授权 Gate A)。
- 事故联动：07-05 两会话 27 秒并发 deploy-web 互相覆盖 → 五道门新增 Gate M(flock)+Gate A(OWNER_DEPLOY_APPROVED=1 所有部署,不分峰谷)。
- ~~待 Owner~~ 已授权合 master：merge `913e4f9f`（CI 全绿），分支/worktree 按流程已删（stash 带入 worktree 的共享区未跟踪杂物已先搬回原处防丢）。全案闭环。

## 未决（待 Owner）
- ~~`fix/viewcount-pending-hdel` 合 master~~ 已授权合入：merge `1ad237f3`，推送竞态收敛 merge `da529b99`（远端 CI 窗口前进 4 提交，冲突仅 claude-shared 记忆文件取远端侧），分支两侧已删。
- **feed 卡片观看数时效方案待拍板**：Owner 反诘钉出第二半根因——06-22 H4 逐片卡缓存(`dacbb024`)把卡片 viewCount 从"每渲染直读 DB(5min 级新鲜)"冻成 24h TTL 快照，与流量降 45% 同日叠加=体感"不更新"。候选：①movie-card TTL 24h→1h(一行) ②计数分离+渲染时 HMGET 合并(业界标准,秒级,中等改动:展示计数器+写侧 Lua 守卫+同步任务权威 SET 校准+getMoviesByIds 合并点) ③前端模糊显示叠加。已建议②一步到位或①先行渐进。
- monitor:* 键第6项：错误类有 MonitorErrorController+MonitorErrors.vue 活跃消费**必须保留**（盘点 agent"无消费者"判断错误）；仅 api-fails/api-clientfail/api-total/net-echo/cdn-failover(-critical) 6 类真无读方，30min 自过期不堆积，建议下次 web 部署搭便车停写。

## 方法论（可复用）
- nw-redis 的 `$*` 拼接可直接远端接管道做 SCAN 聚合，只回传汇总；大规模 TTL 普查用「scan 落文件 + sed 'TTL ' 前缀 + redis-cli stdin 批量 + paste 配对」，425 万键 ~8min。
- 判"废弃"三步：前缀聚合定家族 → TTL 抽样定持久 → 代码 grep 定读写方；盘点 agent 结论必生产实测复核（本次其 2 处判断被推翻）。
- 清理用 EXPIRE 短倒计时代替直接 DEL（复刻系统自身过期机制，留反悔窗）。
- 相关：[[project-alert-triage-rule42-disk-n9e-2026-07-05]]（SystemMonitorTask 退役背景）、[[reference-deadcode-audit-sop]]。

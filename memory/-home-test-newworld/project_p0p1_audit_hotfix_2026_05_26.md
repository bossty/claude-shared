---
name: project-p0p1-audit-hotfix-2026-05-26
description: P0+P1 慢 SQL 全栈审计 + 雪崩止血 hotfix sprint (2026-05-26) — cursor-feed 部署后 owner /pua:p9 派 4 P8 senior 并行排查 + 3 senior 并行 hotfix 10 项修法 + 5 P2 backlog；9 条新铁律全栈雪崩审计 SOP / PageHelper LIMIT 兜底 / @PostConstruct 长跑 / ApplicationReadyEvent / executePipelined 多 key 原子 / 增量 bloom-add write-through
metadata: 
  node_type: memory
  type: project
  originSessionId: 388bb599-5c9a-4a23-a102-9bed7b944583
---

# P0+P1 慢 SQL 全栈审计 + 雪崩止血 Hotfix Sprint（2026-05-26）

## 触发

cursor-feed 3 tab 重构 sprint（2026-05-24~05-26）部署后稳定，owner /pua:p9 派 4 P8 senior 全栈排查最近 24h 慢 SQL + 雪崩风险代码。

## P9 派工 → 4 P8 senior 并行

| Senior | 角色 | 输出 |
|---|---|---|
| P8-α | SQL 真凶归因 | `docs/RESEARCH/2026-05-26-slow-sql-audit/sql-attribution.md` (304 行) |
| P8-β | @Scheduled / @PostConstruct 雪崩 | `scheduled-tasks-audit.md` (177 行) |
| P8-γ | 缓存失效 / 写池 | `cache-write-pool-audit.md` |
| P8-δ | latent hack / 死代码 / Deferred | `latent-hack-deadcode.md` |

## 修法分级

### P0（4 项 即刻可修）

- **P0-1** AdStatsSyncTask 加 `initialDelay=300_000` — 启动 t=0 抢 HikariPool
- **P0-2** GlobalFeedPoolService 删 `@Transactional(readOnly=true)` — CLAUDE.md 铁律违反
- **P0-3** SessionFeedService 删 dead branch + KEY_LATEST_POOL_LATEST/PREFIX 常量 — 自注释"实际不会再走到"
- **P0-4** TwoLevelCache.evictByPattern 加 `@Deprecated` + Javadoc — 5/22 B-1 后 0 生产调用

### P1（6 项 本 sprint）

- **P1-1** DiverseHighQualityComputeTask @PostConstruct → @EventListener(ApplicationReadyEvent.class) — 87s 不阻塞启动链
- **P1-2** DomainPoolMaintenanceTask.checkPendingNs fixedRate→fixedDelay + initialDelay=60s — CF API 抢/重叠
- **P1-3** findMoviesByActor/Category/Tag XML 加 LIMIT 1000 — PageHelper 失效兜底
- **P1-4** findEnabledMoviesWithFilters XML 加 LIMIT 1000 — 同上
- **P1-5** 爬虫 publish `bloom-add:<movieId>` 增量 + findAllEnabledIds LIMIT 500000 + 删 listener 全量 SELECT — 双 web 30 万行雪崩消除
- **P1-6** GlobalFeedPoolService 18 次单 SET 改 executePipelined 原子 — 极短混版本窗口

### P2（5 项 排队独立 sprint）

- DiverseHighQualityComputeTask cohort 池化退役
- ActorService DB fallback 路径仍存活（cold-start 隐患）
- 双 web 并发回源首页加 singleFlight（500 万 DAU 准备）
- 4 爬虫整点 `:00` 错峰到 `:00/:15/:30/:45`
- OrphanChannelDetectorTask N+1 查询

## 关键 commits

| sha | 内容 | 改动 |
|---|---|---|
| `62f1503f` | Δ1 admin 5 项 P0+P1 | 4 files +40/-22 |
| `570b5219` | Δ2 web 4 项 P0+P1 | 3 files +22/-28 |
| `6fdf15cc` | Δ3 bloom 方案 B+A P1-5 | 8 files +51/-16 |
| `4a34c14d` | test fix DiverseHighQualityComputeTaskTest initOnBoot(null) 签名同步 | 1 file +1/-1 |
| `cd57f108` | merge 3 worktree → master | — |

## 部署 verify

- mvn 全 module BUILD SUCCESS（test fix 后 testCompile PASS）
- 9 组 e2e (3 tab × 3 region) 全 11000+ bytes 真数据
- DB long query (Time>5s) = 0
- 双 web ready 24-28s

## 9 条铁律（已合入 root CLAUDE.md Lessons Learned）

1. **全栈雪崩审计 4 角色 SOP**（α SQL / β @Scheduled / γ 缓存 / δ dead code 并行）
2. **PageHelper 失效兜底铁律** — mapper XML 必加 LIMIT N
3. **@PostConstruct 长跑（>5s）必改 ApplicationReadyEvent**
4. **@Scheduled fixedRate 改 fixedDelay + initialDelay 分级**
5. **爬虫高频 publish "all" 绑全量 SELECT 是雪崩根因** — 增量 bloom-add write-through
6. **Redis 多 key 指针原子切换用 executePipelined**
7. **dead code + 废弃常量必在功能 sprint 收尾清**（"待清理"注释是 delta debt）
8. **已知危险方法必加 @Deprecated** — evictByPattern 0 生产调用仍需标注
9. **@EventListener 改签必同步 mock**（5/21 铁律二次实证 — testCompile FAIL 是编译器检测网）

## owner 拍板决策

1. **优先级 C**：P0+P1 立即跑 + P2 排独立 sprint（不接受 A 只修 P0 / 不接受 B 只 P0+P1 不立 P2）
2. **方案 B+A 双保险**（P1-5 bloom）：增量 bloom-add write-through 治本 + LIMIT 500000 兜底
3. **delete TwoLevelCache.evictByPattern 暂不删**：加 @Deprecated 等 6 个月观察期再删

## 后续 P2 排队

memory `project_p2_backlog_2026_05_26.md`（待 owner 拍板时开）含 5 项独立 sprint 候选。

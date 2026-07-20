---
name: project-cursor-feed-sprint-2026-05-24
description: cursor /feed 三 tab 重构 sprint（2026-05-24~05-26）—— 7 轮 PRD + 4 worktree + Phase3 4 MAJOR + P4-P11 11 轮部署后 hotfix；架构 = 3 tab × (global + 5 region cohort 分桶) = 18 ZSET + sid-Bloom + client IDB + Base64url cursor；ActorPool cohort 池模式止血演员列表 DB 雪崩；22 条铁律
metadata: 
  node_type: memory
  type: project
  originSessionId: 388bb599-5c9a-4a23-a102-9bed7b944583
---

# cursor feed 三 tab 重构 sprint（2026-05-24~05-26）

## Sprint 概要

首页三 tab（feed / hot / latest）从 page 参数翻页重构为 cursor 协议 + 全局优质池 + cohort 分桶架构。

**三目的**：
1. 真无限滑（cursor 协议，翻页 0 次 MySQL）
2. 首页 DB 读压力归零（500 万次/天 DB 翻页读 → 0）
3. cohort 千人千面（region 分桶 + seed 决定顺序）

**PRD 演化**：v3→v4→v5→v6→v7→v7.1，共 7 轮（v5、v6 两次 BLOCKER 全推翻顶层设计；v7 Owner 二度揪头发后拍板新架构）

**总时线**：单日（2026-05-26）完成，4 worktree 并行 + 3 轮 Phase 3 hotfix + P4-P11 共 8 轮部署后 hotfix

**最终 HEAD**：`d7391725`（P11 LinkedHashMap byId 按 pageIds 重排修 hot/latest tab 显示乱序）

---

## 架构核心（最终上线 v26 实证）

### 全局优质池（Layer 1）
- `GlobalFeedPoolService`（admin 模块）@Scheduled fixedDelay=300_000 initialDelay=300_000 + @PostConstruct 首次冷写
- 质量分：`view_count * 0.6 + recency * 0.4 * 1e6`（不含 completion_rate，全库 grep 零结果）
- SQL：`FORCE INDEX(idx_movie_feed_cursor)` + `ORDER BY view_count DESC, id DESC` + Java 层二次 sort
- 指针 key 模式：先 ZADD `feed:global:pool:v{seq}` → 再 SET `feed:global:pool:latest = "v{seq}"` → catch 不切 pointer → EXPIRE 老版本 10min

### 3 tab 独立池（P10 业务语义对齐）
- `feed:cohort:{region}:v{seq}` ZSET（score=quality 综合分，feed tab，shuffle 千人千面）
- `feed:hot:{region}:v{seq}` ZSET（score=view_count，hot tab 按播放量降序，不 shuffle）
- `feed:latest:{region}:v{seq}` ZSET（score=create_ts UNIX 秒，latest tab 按入库时间降序，不 shuffle）
- 各自独立 latest 指针 key
- 总池数：3 tab × (1 global + 5 region) = **18 ZSET**
- admin 写池耗时实测 1389ms（含 18 ZSET 写入）

### session-Bloom（Layer 5，server 兜底）
- `SidBloomService`：10K bit/sid，TTL 30min，3-hash funcs（CRC32 + FNV1a + djb2）
- FPR：n=4800（200 页）时 ~43%（client IDB 是主防线）
- pipeline executePipelined 批量 GETBIT / SETBIT

### client IDB seenIds（主防线）
- `feedCursor.js`：SEEN_MAX_SIZE=50000，key = `list_feed_v2_seen_{tab}_{visitorHash}`
- reset() 同时清内存 + 不恢复 IDB（P5 `1a21701e` 教训：删 loadSeen/saveSeen）

### cursor 协议
- Base64url（RFC 4648），`opaque = Base64url(JSON.stringify(payload))`
- payload = `{sid, seed, idx, tab, ver, v: 1}`
- CursorTokenCodec.decode 非空 token 失败 throw IllegalArgumentException → Controller HTTP 400（P3-R3 `d409de2b`）

### SHUFFLE_WINDOW
- `Math.min(poolSize, 5000)` — 业界 99% 用户翻页深度 ≤208 页（5000÷24）；小池子（cn=996）全打乱无 hack

### ActorPool（独立 sprint，止血演员列表 DB 雪崩）
- `ActorPoolService`（admin 模块）@Scheduled 5min + @PostConstruct
- `actor:global:pool:v{seq}` ZSET（score=movie_count，3363 演员）+ 指针 key
- 仅 global，不分 region（演员前端无 region 筛选）
- web `ActorService.getActorsWithPagination` 改读 ZSET，0 DB 翻页

---

## 关键 commit 链（按时序）

| sha | 描述 |
|-----|------|
| `885c0648` | 前置：hourKey 13min 偏移消除整点雪崩 |
| `650ad53a` / `1c912240` / `ca22b5c9` | MovieQualityScore VO + Mapper SQL + GlobalFeedPoolService 指针 key |
| `af7ac200` | dev-A: SessionFeedService+SidBloomService+CursorTokenCodec 三件套 (+832/-0) |
| `8261c545` | dev-C: /feed/v2 endpoint |
| `1d01e26e` | dev-D: cursor 前端 + IDB seenIds (+207/-32) |
| `33feaed9` | MAJOR-3: idx_movie_feed_cursor migration + FORCE INDEX + Java sort |
| `43473e9e` | MAJOR-4: executePipelined 替代 72 次串行 ZRANGE |
| `85d14453` / `469cf48b` | MAJOR-1/2: cursor validation + Controller @Pattern @Size |
| `d409de2b` | **MAJOR-1-R2 真闭环**（dev 虚报后蓝军 R2 揪出，throw + HTTP 400） |
| `18fd9db6` | **P4**: FeedPageResponse items List<Long>→List<MovieListVO>（前后端 contract 真凶） |
| `1a21701e` | P5: 删 loadSeen/saveSeen（reset 后 IDB 恢复 seenIds 全过滤） |
| `4d8fb691` | P6: filterIdsByRegion 临时兜底（被 P9 替代） |
| `d2211ba3` | P7: 跳 shuffle hack（owner 揪 over-engineered） |
| `c2a5c35e` | P8: 扩 window=poolSize（owner 再揪） |
| `3a254060` | **P9 一步到位**: cohort 池实施 + SHUFFLE_WINDOW 5000 |
| `6cc89e0f` | **P10**: 3 tab 业务语义独立池 hot=view_count latest=create_ts |
| `c31ed084` | P10: 前端 region 切换重置 activeTab=latest |
| `9c5265b3` | **ActorPool**: cohort 池模式止血演员列表 DB 雪崩 |
| `abf09033` | ActorPool: 删 region 分桶死代码（owner 揪 over-engineered） |
| `d7391725` | **P11**: LinkedHashMap byId 按 pageIds 重排修 hot/latest tab 显示乱序 |

---

## Owner 拍板决策链

1. **v6 全推翻 → v7 新架构**：personalized ZSET 路径取消（Bloom 167GB 算数错 1000 倍 + 候选上限 ~600 vs 声称 2000）；改全局优质池 + sid-Bloom 125MB + client IDB 主防线
2. **SHUFFLE_WINDOW=5000**：业界 99% 用户翻页深度 ≤208 页（5000÷24）；不为凑性能拍大数
3. **tab 顺序**：热门 / 最新 / 推荐，default 最新（P4 部署时拍板）
4. **cohort 池一步到位**：Owner P9 拍板"未来 cn 增长 自动适应"，不接受 P7/P8 临时 hack
5. **首屏数据取消加密**：Owner 业务直觉（performance 考量，5/26 推回时 fact-check 验证 hot/latest 仍加密 = 不矛盾）
6. **3 tab 独立池**：hot=view_count / latest=create_ts / feed=综合质量，不共享 ZSET
7. **region 分桶前 verify 前端**：演员无 region → 只建 global 池（actor 教训）
8. **region 切换重置 activeTab=latest**：3 tab 不跨 region 共享状态
9. **真浏览器渲染 verify**：chrome devtools mcp 是 score 排序语义的唯一可靠验证层（P11 真凶）

---

## 蓝军统计

- PRD 轮次：7 轮（v3-v7）
- 真 BLOCKER：4（v5 ×2 + v6 ×2）
- 真 MAJOR：11（v7 ×3 + Phase3 R1 ×4 + Phase3 R2 MAJOR-1-R2 ×1 + v5 ×2 + v6 ×1）
- **dev 虚报事件**：Phase 3 R1 dev 声称"throw + 400"实为全 return null；蓝军 R2 揪出，R3 真闭环（`d409de2b`）
- **蓝军/qa 未 catch 的 P0 bug**：FeedPageResponse.items 类型断裂（7 轮蓝军 + 1805 mvn + 549 npm 全 PASS，部署后 owner 才发现 P4 `18fd9db6`）
- **蓝军/qa 未 catch 的 P11 bug**：MyBatis IN 不保顺序（mvn/npm/curl 全 PASS，chrome devtools 真浏览器才暴露 `d7391725`）

---

## 生产部署验证

- idx_movie_feed_cursor：EXPLAIN key=idx_movie_feed_cursor，type=ref，Extra=NULL（无 filesort）
- admin @PostConstruct：34032 ids v1，738ms（原始）/ 1389ms（P10 18 池写入）
- cohort 池 v13：jp=25605 / cn=996 / anime=2362 / 3d=1137 / western=3941（5 region）
- 9 组 e2e（3 tab × 3 region）全返 11000+ bytes 真数据
- DB long query（Time>10s）=0
- P11 三方对账：latest:jp:v26 ZREVRANGE 0-2 = [69517,69511,69509] = SQL ORDER BY create_time DESC = 浏览器渲染首条

---

## 22 条铁律候选（详见 `docs/sprint/_archive/2026-05-24-cursor-feed/CLAUDE-MD-LESSONS-CANDIDATE.md`）

主体 L1-L15（P0-P9）：前后端 contract e2e 渲染验证 / dev 状态档虚报 grep 实代码 / cohort 池各层独立 AC / SHUFFLE_WINDOW 业务语义 / PRD SQL 幻象字段 / IDB seenIds reset 陷阱 / for 循环 Redis pipeline / VO 三方校验 / 3 次 owner 反诘即停手 / Fisher-Yates 算数验证 / DB 读压力归零实证 / OQ 合并前拍板 / cohort 池模式标准模板 / mvn PASS 必要不充分 / tab 顺序业务决策

增量 L16-L22（P10/ActorPool/P11）：MyBatis IN 不保顺序 LinkedHashMap 重排 / chrome devtools mcp 真浏览器三方实证 / 多 score 3 独立 ZSET / region 分桶前 verify 前端 / DB CPU SHOW PROCESSLIST 真凶定位 / cohort 池模式通用模板 / SHUFFLE_WINDOW Math.min 自适应

精炼 10 条已合入 root CLAUDE.md Lessons Learned 段。

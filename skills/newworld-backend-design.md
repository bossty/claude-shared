---
name: newworld-backend-design
description: Newworld 后端设计核心 — Result<T> 包装 + EncryptResponse + Web 教育主题伪装路径；TwoLevelCache (Caffeine L1 + Redis L2) + @Cacheable/@CacheEvict + 6 版本号驱动 (contentVersion 等)；推荐系统 3 层硬同步 (data/web/frontend)；配置三层判定 (代码常量 / application.yml / system_config DB)；Bloom Filter write-through + rebuild 兜底，禁 miss-then-DB；Web 模块只读查询标 @Transactional(readOnly=true) 但禁包 Redis 写。Triggers on controller, result wrapper, Result<T>, encryptresponse, cacheable, cacheevict, twolevelcache, contentversion, settings/version, 推荐三层, related, MovieLimit, VideoPlayer, system_config, application.yml, bloomfilter, write-through, miss-then-db, readOnly 事务, 缓存穿透, MovieRecommendationService, CacheConstants, MovieCacheRefreshListener.
---

# Newworld 后端设计核心铁律

## 触发场景
- 新增 Controller / Service / Mapper
- 改 `@Cacheable` / `@CacheEvict` / 新增缓存键
- 改推荐数量 / `MovieLimit` 常量 / `VideoPlayer.vue` 推荐拉取
- 决定配置存哪儿（代码常量 vs yml vs DB）
- Bloom Filter 相关代码（refresh / write-through / Listener）

## 1. API 设计
- 所有响应包装为 `Result<T>`（code=0 成功，code=1 失败）
- Web 端 API 用教育主题伪装路径（movie→course, actor→instructor）；admin 端不伪装
- `@EncryptResponse` 注解启用 AES 加密，前端 WASM 解密
- 关联关系用 ID 数组：`categoryIds`（必填）、`actorIds`、`tagIds`（可选）

## 2. 缓存策略

**两级缓存**：`TwoLevelCache`（Caffeine L1 + Redis L2），`@Cacheable` 透明使用。
- L1 Caffeine：20K 条，24h TTL，JVM 内
- L2 Redis：24h TTL，JSON 序列化
- 键格式：`{模块前缀}:{实体}:{类型}:{ID}`（如 `web:movie:id:123` / `admin:category:list:all`）；`CacheConstants.java` Web/Admin 两套常量
- Admin CRUD → `@CacheEvict`；Web 读取 → `@Cacheable` + 定时刷新；Data 采集 → Pub/Sub
- 跨模块通过 Redis Pub/Sub 同步

**6 版本号驱动**（`/api/v1/settings/version`）：
- `systemVersion` / `adVersion` / `metadataVersion` / `contentVersion` / `weeklyHotVersion` / `dailyHotVersion`

**缓存刷新链路**（Data 采集 → 前端更新）：
1. Data 模块每 10 部成功 → `CONTENT_VERSION +1` + Pub/Sub `"all"`
2. Web 模块 `MovieCacheRefreshListener` 收到 → 清首页 section / 分页列表 (×3 页 ×5 region) / 刷 bloom
3. 前端 `app-config.js` 轮询版本号（默认 12 min）→ contentVersion 变 → 清 localStorage 重请

## 3. 推荐系统 3 层硬同步
修改推荐数量必须同步：
1. **data**：`MovieRecommendationService.computeRecommendationsForMovie()` 硬编码 limit；写 Redis `shared:movie:related:{movieId}`
2. **web**：`MovieLimit.related` 常量
3. **前端**：`VideoPlayer.vue` 的 `getRelatedMovies(id, N)` 和阈值

当前值：24（底部"猜你喜歡" slice(0,12) + 侧栏/移动端追加 slice(12,24)）

## 4. 配置三层判定

| 层级 | 适用 | 存储 | 示例 |
|------|------|------|------|
| 代码常量 | 永不变（改了重新部署） | Java 常量 | R2 bucket、HLS 密钥、AES MASTER_KEY |
| 启动配置 | 部署时定，运行时不变 | application.yml | DB/Redis 连接、R2 凭证、JWT secret |
| 动态配置 | 运行时改，不重启生效 | DB system_config | CDN 域名、第三方 API Key、签名密钥 |

判断标准：**这个值改了之后，需不需要重启服务？** 重启 → yml；不重启 → DB；永不改 → 代码常量。

视频常量统一放 `VideoConstants`（common 模块）三模块共享。

## 5. Bloom Filter Write-Through

1. **必须 write-through 增量更新**：入库 → Pub/Sub `bloom-add:<id1>,<id2>` → Listener 调 `BloomFilter.put(id)`（Guava 23.0+ lock-free CAS）
2. **保留周期 rebuild 作兜底**：Pub/Sub at-most-once，10 min 定时 rebuild 自愈
3. **禁止 "miss 查 DB 兜底"**：违反防穿透本意；miss 直接返 404
4. **Listener 内部顺序**：先 `refreshBloomFilter()` → 再 `evictByPattern(列表缓存)`。反转 = 列表清完回源拿新片但 bloom 未刷 → miss 404 窗口

## 6. Web 模块 readOnly 事务（演进路径）

- Web 模块只读查询标 `@Transactional(readOnly = true)`，便于未来路由到只读副本
- login 等涉及写操作的方法**不要**标 `readOnly = true`
- **不要在 readOnly 事务中执行 Redis 写操作**

## 检查清单
- [ ] 新 Controller 返 `Result<T>`，Web 路径用教育主题伪装
- [ ] `@Cacheable` key 含模块前缀，`@CacheEvict` 写时同步
- [ ] 改推荐 limit 三处同步 commit（data + web + frontend）
- [ ] 新配置先问"改了要不要重启" 决定层级
- [ ] BloomFilter 入库链路有 write-through + rebuild 兜底
- [ ] Web readOnly 方法体内无 redis write

## 违反后果
- 推荐 limit 三层不同步 → 前端展示 24 但 web 切片 12 → 侧栏空 / 重复
- 配置错放 yml（应放 DB）→ 改 CDN 域名要重启服务，停机窗口扩大
- Bloom miss 查 DB 兜底 → 防穿透失效，恶意大量不存在 ID 直接打 MySQL → 雪崩
- readOnly 包 Redis 写 → 未来路由只读副本时数据不一致
- 上述任一项被用户发现 = **3.25 级别**复盘

## 源
- CLAUDE.md L399-L477（API/缓存/推荐/配置）
- CLAUDE.md L753-L774（Bloom Filter）
- CLAUDE.md L116-L120（readOnly 事务）

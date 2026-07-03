---
name: project-cache-unification-2026-07-03
description: C组缓存统一全流程完结：poller L2大锤(KEYS+DEL×6实例)修复+seq事件精准失效+CORS双缓合一；部署web×6+5钩子实测；含部署门捕获的@Autowired双构造器crashloop教训
metadata: 
  node_type: memory
  type: project
  originSessionId: 8c1fcb79-0cfc-4ab7-83a2-3dc3a94850e3
---

# C 组缓存统一（2026-07-03/04 完结，spec+计划+蓝军+终审+部署验证全链路）

**核心发现（比 backlog 描述更实质）**：`ConfigCacheRefreshPoller` javadoc 自述"只清 L1"，实现却调 `TwoLevelCache.clear()` 连 L2 master 一起清；`RedisCacheManager.builder` 未配 BatchStrategy → 默认 `BatchStrategies.keys()` = **`KEYS web:*` 全 keyspace 阻塞扫描 + DEL，×6 实例**，每次 SYSTEM_VERSION bump（改配置/域名/CDN 轮换）触发一次——5/22 SCAN 雪崩 P0 同款模式藏在 poller 里。grep 实证 `web` 区约 25 处 @Cacheable 零消费 system_config，纯误伤。

**方案 A（小步）**：poller 改发进程内 `SystemVersionBumpEvent`（移除 CacheManager 依赖=结构性防回归；挂独立单线程 `configPollScheduler`）；`SettingsReadCache` 三缓存 + `ConfigController.promoPoolRef` 监听事件精准失效（TTL 60s/5min 保留兜底）；CORS 白名单归口 `SettingsReadCache.getActiveApHostSet()`（loader 直调 mapper 防 self-invocation 旁路 @Transactional——蓝军 BLOCKER#1）。staleness 120s→**实测 1.1s(EU)/1.3s(CA)**。

**事实纠偏**：BACKLOG"双缓曾造 6h 陈旧"实为 **6min** 且 2026-06-25 已修（现状 120s）；"失效 4 路径"实为 5 条；"收敛单一路径"按字面执行会推翻 CACHE_ARCHITECTURE.md §5.2 有事故背书的设计——验收改写为"消除重叠与自相矛盾"获 Owner 批准。

**部署实录（Owner 授权 --force-peak）**：首次部署 sha 19c2b6a8 在 ca-web-01 被 readiness 门拦下自动回滚零损伤（见下教训①）；热修 `a314aca2` 后 6/6 零停机全绿；5 钩子实录落 `docs/superpowers/plans/2026-07-03-cache-unification-DEPLOY-CHECKLIST.md`。合 master merge commit `6356f6cd`（--no-ff，Owner 授权）。

## ★教训①：Spring 多构造器 bean 必标 @Autowired（部署门捕获，四道评审全漏）

给 `SettingsReadCache` 加 Ticker 测试构造器后成双构造器且均无 @Autowired → Spring 回落找无参构造器 → `NoSuchMethodException` 启动 crashloop。**mock 单测不走容器逮不住**（设计/实施/蓝军/终审全漏，deploy readiness 门捕获）。根因细节："照搬 DynamicCors 的 Ticker 构造器模式"时漏看其 public 构造器是**无参**的（依赖走字段注入）——照搬模式必看齐构造全貌。回归钉写法：真实 `DefaultListableBeanFactory` + `AutowiredAnnotationBeanPostProcessor` 走构造器解析路径（先复现同异常再转绿），见 `SettingsReadCacheTest.SpringConstructorResolution`。

## ★教训②：pre-push 门禁运行期间禁一切并行 maven/改源码（同 worktree）

push 后台跑 ci-local 全量测试期间，我并行 merge master + `mvn test` + `mvn clean package` 同一 worktree → clean 把 `newworld-common/target` 从门禁测试的 classpath 底下抽掉 → admin 测试大片 `NoClassDefFoundError` 误判失败、push 被拦。**判别特征**：失败全是 NoClassDefFound/资源缺失且时间戳与自己的 mvn 重叠。另外首个部署 jar 也是并行期间产物（虽验证含类，仍重建了才部署）。

## 其他要点

- 触发 seq bump 验证用直接 `INCR shared:system-version`（我方改动面从 poller 起，admin afterCommit INCR 是未动存量）——忠实且不碰业务配置。
- web 节点无 mysql 客户端；`nw-mysql` 对 web/admin 服务均报 "could not read DB_USERNAME"（工具 line 30 疑有 bug，待修）；取真实 A 域改走 Redis `ZRANGE shared:global:a_pool`。
- EU 重启窗口 SnackService 数百条瞬态 ERROR：近 60s 归零 + 同 jar CA 零错 → 非回归（2026-06-17 教训复用成功）。
- 遗留（不阻塞，登记后续清理）：DynamicCors 死 `log` 字段 + `pathMatcher`/`CORS_PATH_PATTERN` 既存死代码；promoPool 写回竞态=既存特性上限 5min 不破承诺不修。
- 相关：[[reference-safe-branch-worktree-cleanup-protocol]]、[[feedback-feature-branch-deploy-test-then-merge]]

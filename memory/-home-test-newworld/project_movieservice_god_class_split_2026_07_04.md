---
name: project_movieservice_god_class_split_2026_07_04
description: MovieService 上帝类拆分（代码精简 B5）——facade 委托抽 3 协作者，行为保持，合 master 172bd4d0 + web×6 部署验证
metadata: 
  node_type: memory
  type: project
  originSessionId: 293fba68-3676-40ca-9c18-59b8e428181f
---

代码精简审查 **B 组 · MovieService 上帝类拆分**完成，合 master `172bd4d0`（2026-07-04），web×6 零停机部署验证（sha=`00553eef`）。

**做法（Scope A，facade 委托，行为保持）**：MovieService 1280→1037 行(−243)，抽 3 个单一职责协作者：
- `MovieVoConverter`(@Component,零依赖纯转换):convertToListVO/convertToPageInfoVO/buildPageInfo
- `MovieBloomFilterService`(@Service):bloom 生命周期 + mightContain(三态:filter=null→true fail-open);@PostConstruct 归此
- `MovieSearchService`(@Service):record×2(@Async statsAsyncExecutor)/getHotSearch(@Cacheable)/searchEnabledMovies(@Cacheable+@Transactional)
- MovieService 保留全部 public 方法作 **facade 委托** → controller/scheduler/listener 零改;跨 bean 委托反而让 AOP 代理正确生效(与旧 self-invocation 坑同理);连带移除抽取后死依赖 stringRedisTemplate+hotSearchAggregator。

**★关键 fact-check（否决 backlog 项）**：backlog 原写"HeaderPageVO<T> 消 3 个包装 VO"（MovieCategoryVO/MovieActorVO/MovieTagVO）——经查 **3 VO 非同构**（header 字段名各异 categoryName/actorName+actorAvatar/tagName）且 **前端页面 + api/*.js 直接消费这些字段名**，换泛型会把 JSON 从 `{categoryName,pageInfo}` 变 `{header:{...}}` **破坏前端契约**，负价值 → 否决。见"包装决策而非算法决策"。

**★关键设计约束（纠葛点决定范围）**：`getMoviesByIds`(卡片水合读原语)被"相关"组共享，`getPersonalizedFeed` 回调分页 → 整个相关组强拆会造 MovieService⇄RelatedService 循环依赖，无环解需级联抽 MovieCardReader(5 类)。故 Scope A 只抽 3 个真·干净件(Bloom/Search/转换器)，相关/个性化留 MovieService——避免过度设计。

**★行为保持验收范式**：现有 `MovieServiceTest`(908 行,全走 public API)=安全网。facade 保留 public 方法 → 现有测试继续有效。抽走逻辑的测试迁到 3 个新测试类;MovieServiceTest 用 `@Spy` 真实 converter(纯,断言原样过)+ mock bloom/search。`mvn clean test -pl newworld-web -am` 1019 全绿(基线 1009)。

**★蓝军两队交叉验证真值**：1 BLOCKER(分支落后 master 9 commit 未 merge)+3 MAJOR(PAGE_QUERY_LIMIT 两副本破单一事实源→归一包可见常量;@Async 缺反射断言守卫→补 AsyncAnnotationGuard;搜索测试单 mock 喂 master+replica 双参丧失读写路由可测→改 2 独立 mock 手动构造)+4 MINOR，全修。@Cacheable/@Async 迁移后代理生效、cacheNames/key 逐字不漂、qualifier 未接反、mightContain 代数等价、无循环依赖——均经核实。

**★部署验证坑**：API 响应全加密(`{"encrypted":true,"data":"<AES>"}`)→ 无法从响应取 movieId;节点 **mysql 客户端缺失 + DB_USERNAME 不在 environ**（app 配置默认）→ nw-mysql 取 id 失败;/proc/environ 需 `sudo cat`(不能 `sudo tr <redirect`，重定向在 sudo 前由 ssh 用户执行)。验证靠:搜索/热搜/featured/popular 200+加密真数据(覆盖 MovieSearchService+MovieVoConverter 路径)+ 启动 @PostConstruct OK(bloom)+ deploy-web.sh 内建 warm business-gate。

设计+评审全档 `docs/sprint/2026-07-04-movieservice-split/DESIGN.md`。关联 [[feedback_shared_master_race_push_reject]]（本次 push 又遇 ci-local hook 已推、显式 push 报 no-op 拒绝）、[[project_cache_unification_2026_07_03]]（同为 web load-bearing 重构范式）。代码精简审查现 A/C/D/B5 完成，剩 B4 爬虫收敛 13 家。

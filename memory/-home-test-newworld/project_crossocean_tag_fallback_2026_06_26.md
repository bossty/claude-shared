---
name: project_crossocean_tag_fallback_2026_06_26
description: L2 WEB-CROSSOCEAN-READ抓到tag/category/latest分页DB fallback跨洋(PageHelper COUNT丢replica路由);修=reader+fix/*分支流程首跑;tcpdump cache-bust金标
metadata:
  node_type: memory
  type: project
  originSessionId: 6eecae1c-95e0-4231-a84e-4ccc79979b6c
---

L2 检测器(本会话建的"保证"系统)告警 **WEB-CROSSOCEAN-READ**(digest=`SELECT count(*) FROM movie JOIN movie_tag_relation WHERE tag_id=? AND status`)——EU region 跨洋读 CA master。承 [[project_crossocean_read_guardrail_2026_06_25]]。

**根因(L1 ArchUnit 盲区,只 L2 抓得到)**：`MovieService.getMoviesByTagID/getMoviesByCategoryID/getLatestMoviesWithPaginationByRegion` 三个 @Cacheable 方法**移除了 @Transactional(readOnly=true)**(Redis 主路径无需 DB 事务,注释"readOnly 已移除")。但其 **DB fallback**(Redis 池未就绪/0关联tag/Redis故障时走)的 `PageHelper.startPage` 自动 COUNT + SELECT 因此丢 replica 路由 → EU 跨洋打 master。低频(冷tag/空池才触发,3/10h)。**L1 ArchUnit 看不到**:方法有 @Cacheable 被判"已本地化",看不进 cache-miss 里的 DB fallback。**范围实证完整**:'readOnly已移除'签名全文件正好3处=这3方法(getDiverse 有readOnly不漏,蓝军F2误报)。

**修(本sprint既定reader模式)**：`MovieDbFallbackReader`(@Component) 加 `pageMoviesByTag/pageMoviesByCategory/pageLatestMoviesByRegion` 三个 @Transactional(readOnly=true) 方法(各 `PageHelper.startPage; new PageInfo<>(mapper.findX())`,COUNT+SELECT 同方法体/同事务/同 replica 连接,PageInfo 在 tx 内构造);3处 fallback 改调 reader。返回类型镜像 mapper(tag/category→PageInfo<MovieListVO>、latest→PageInfo<Movie> 调用方转VO)。master `70f494fc`,部署 jar `b3fd30e9`。

**tcpdump 金标实证(诊断踩坑→换法)**：① L2 A/B(eu-01修 vs eu-02旧)**失败**——@Cacheable 缓存结果 + 两 EU 节点共读同一 replica(.184)池状态对称,触发不了"看旧节点涨"。② 换 **tcpdump + cache-bust**:取0关联tag(movie_tag无movie_tag_relation→池指针null→必fallback)× 全新region参数(避@Cacheable,key含region)→ eu-web-01 抓到 **35 次 count-by-tag 全落 REPLICA(.248)零落 MASTER(.222)**=修复实锤。教训:**@Cacheable+共享replica 让指标A/B失效时,tcpdump+缓存绕过(fresh cache key)才是金标**。

**首次跑通 Owner 定的 fix/* 分支流程**(2026-06-26 新铁律,根CLAUDE.md):新功能/修复走 `fix/*`(或 feature)分支开发 → build 前先 merge 最新 master → 从该分支打包部署+测试 → 蓝军 → **Owner 授权才 --no-ff 合 master**(master 永远=已测可部署基线,禁未测合master)。多会话防漂移:合并/push 前必 `git fetch` 看 origin/master 真值(本次 origin 被别会话推到 cb9e66c7,FF 本地 master 再 --no-ff 合 fix 再 push)。配 [[project_master_degfw_deploy_baseline_2026_06_26]](master GFW-free 可直接部署=本流程前提)。

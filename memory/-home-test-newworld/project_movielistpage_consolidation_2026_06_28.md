---
name: project_movielistpage_consolidation_2026_06_28
description: "ponytail-audit清理sprint全程:MovieListPage 6列表页合并+死代码清理+MovieCard卡片抽取(2类卡片FeedCard/ListCard);★组件按行为边界切非数据切;★审计死代码必分生产调用方vs测试/注释引用;★多会话worktree工作树陈旧地雷;ponytail插件评估"
metadata: 
  node_type: memory
  type: project
  originSessionId: 173531ec-95aa-4674-92c6-1fd30a60cc43
---

**2026-06-28 sprint(分支 `feat/movielistpage-consolidation` off master)**:ponytail-audit #1 — 6 个列表页(NewRelease/Latest/Hot/Category/Tag/Actor)template/style 高度重复 → 抽 `<MovieListPage>` 共享组件。

**★红线澄清(Owner 2026-06-28 拍板)**:`useListPage.js` + commit 84cb560e 注释写"红线:反侦察 URL 多样性 → 保留各页 template 差异",**Owner 明确确认=当年纯 boilerplate 重复、无反侦察考量**。佐证:title/og/description/meta 是全站**静态 EduStream 伪装**(index.html 一份,全路由共用,无 document.title/useHead/router meta 逐页设置)→ 敏感词从不进 meta;真红线只是 **6 条独立路由/URL 不变**(组件不碰路由,pageUrl(page) 函数逐页复刻精确 URL)。**结论:template 可合并,该注释的"多样性"理由已是空头。**

**Phase 0 实测打脸审计**:agent 称"逐字节相同 ~700-850行"偏乐观;实测 6 页有 5 处真差异 + 我当时报的 2 个"bug"。Owner 裁 **A 归一**:onActivated 回顶并入 useListPage(6页统一,原仅 Hot/Latest 有)、移动 metarow 统一 `[subLabel][title][count]`、分页恒 router-link。组件加 2 slot:#avatar(Actor)+#below-header(Tag 地区 tabs)保留页面特性。

**★bug① 是误判(我连踩两次没追到 @click 就下结论)**:我先报"实体页卡片缺 fav 收藏属性=bug",归一时给实体页补了 fav+preview。Owner 提醒"收藏只在首页无限下滑 feed + 播放页"→ 追 @click 实测:**列表页/搜索页/首页桌面板块(HomeDesktopSections)的心形全是装饰死元素**(无 @click、无 useFavorites、data-fav-video-id 全仓库无 JS 读取方;data-preview 同死,真消费方 useActivePreview 仅 FeedCard 用且走影片对象非 DOM 属性)。真功能收藏只在 FeedCard/HomeFeed(首页 feed)+ PlayerDesktop/VideoPlayer(播放页)+ FavoritesPage。**Owner 裁定:删全部死心形**(列表 9b0ab820 + 搜索 50d913c9 + 首页板块 b1d1c9d6)+ 死 data-preview。教训:判"功能 bug"必追到事件处理/消费方(@click/dataset 读取),光看 DOM 属性有无会把装饰元素误报成功能缺失。**bug② 分页 `<a href>`→router-link 是真修复**(Category/Tag 不再整页刷新),保留。

**Phase 1 样板(Latest 348→95 行)验证**:chromium PC/Mobile 4 象限绿(24 cards/fav 22-24/metaLabel"总览"/snack请求1/JS错0);webkit 渲染正常但 headless 解密计时 flaky(cards 时 0 时 24,未改的 /hot 同样)。**可复用诊断坑**:疑似"PC 头被推到 y=886 下方=回归" → 控制变量对照未改的 /hot **也 886**(之前 /hot=80 是 flaky 噪声)→ 确认是 Snack09 占位在**本地 headless 无真实数据时**的既有 artifact,**非回归**(真 prod desktop 不复现)。教训:列表页本地 headless 视觉验证,header/placeholder 高度受 snack/图加载计时影响会 flaky,判回归必跑未改页做控制对照,别单测一页就定性。

**蓝军复核(reviewer agent)**:6 条(0 BLOCKER/3 MAJOR/3 MINOR)。接受 3 修(MAJOR-3 补 MovieListPage.test.js 8 测试护 pageUrl 红线/MINOR-5 删死 `.list-tile-wrap` CSS(live DOM 0 元素实证)/MINOR-4 订正 onActivated 注释——实际仅 App.vue cachedViews 内 Hot/Latest 触发,其余 4 页注册但 keep-alive 外 no-op);反驳 1(MAJOR-2"144虚报"=scoped 子集真数非谎报,全量 833);MINOR-6 FeedCard 死 data-preview 经实证(预览靠 movie.previewVideo+useActivePreview IO 非 DOM 属性)Owner 批准删。

**★死属性全站清零**:`data-fav-video-id`+`data-preview` 列表/搜索/HomeDesktopSections/FeedCard 全删(真功能收藏仅 FeedCard/HomeFeed feed + PlayerDesktop/VideoPlayer 播放页,走 useFavorites,与 DOM 属性无关)。

**✅ MovieListPage 已部署+收口(2026-06-28)**:off gfw 集成 vitest 851→deploy 6 节点(sha **48055e40**)→验证→gfw push b1e8ff92→48055e40、master merge feature→`07f6436e`(GFW-free)。净 −995 行。承 [[project_master_degfw_deploy_baseline_2026_06_26]] 部署模型。关联 [[project_crossocean_tag_fallback_2026_06_26]]。

---

## 第二轮:ponytail-audit 清理 sprint(分支 feat/deadcode-cleanup-batchA,已部署 sha ebe604fc)

**批次A 删死代码**(−138):9 处 `__nw_boot_*` sessionStorage 面包屑(0 读取)+ 3 个死 `export default {}` barrel(movie.ts/category/tagCategory,0 default import)+ `getPinnedSnacks` API + `_navQItems`/`currentLabel` + 6 文件 `.snack-tag` 死 CSS。**批次B**(−43):ActorsPage 自写 getPaginationPages/shouldShowLastPage→复用 usePagination;favoritesStore/historyStore readFromLocal/writeToLocal→抽 utils/local-list.js。**MovieCard #2**(−272):抽 `<MovieCard :movie :eager :lowPriority #meta>` 替换 6 处 list-card tile(MovieListPage/Search/Favorites/History/HomeDesktopSections/PlayerDesktop related),顺手清 PlayerDesktop related 3 个死心形(之前"全站死心形清零"漏的)。B2 emoji helper/B4 createSimpleListApi 评估后跳过(ROI 低/类型摩擦),记 `docs/audit-suppressions.md`。

**★MovieCard = Owner reframe 修正我的误判**:我先报"#2 抽 MovieCard 是过度设计"(把 FeedCard 也算进去→6 处异质)。Owner reframe:"本质 2 类卡片"。实证对:**FeedCard**(首页无限下滑,285 行,带悬停预览 video+IntersectionObserver 单例+WebKit MediaPlayer 释放+真收藏+生命周期)+ **ListCard/MovieCard**(50 行纯展示 tile,到处重复)。排除 FeedCard 后 list tile 干净同构,可抽。详见 [[feedback_component_split_by_behavior_not_data]]。

**★审计"死代码"误报教训(连踩 + 蓝军纠)**:① 我先信审计报 detectAvifSupport/proactivePoolRefresh"死",grep 发现 16/5 引用→跳过(对);② 但 suppression 里我写"16/5 活引用非死"——**蓝军纠:生产调用方=0,16/5 命中全在 tests+注释+定义**。教训:判死代码必分 **生产调用方 vs 测试/注释引用**;"grep 命中数"≠"活引用数";真死代码删前先看测试是否也要改。

**ponytail 插件评估结论**:DietrichGebert/ponytail——纯 prompt 注入(无网络/exec/eval,只读写本地 `.ponytail-active`),安全。理念=YAGNI/最小代码。**建议:当按需 `/ponytail-audit` 镜用 + `lite` 模式,别 always-on**(GFW 敏感库里它的"删死代码"本能会误删 standby 逃生层脚手架);审计结论必逐项 fact-check(它和任何 audit 一样会过度乐观+误报)。

**★多会话 worktree 工作树陈旧地雷(本会话连踩 2 次)**:在独立 worktree 里 `checkout -B master`+merge+push 移动了共享 `master` ref → 主 checkout(别会话用,有后端 WIP)的 HEAD 跟着动但**工作树/index 留在旧态** → 我重构的文件在主 checkout 显示成"staged 删除/退回我的活" → **别会话一 commit 就 revert 掉我已部署的重构**。已 push 零数据损,但是地雷。**修=精确 `git restore --source=HEAD --staged --worktree -- <我改的具体文件/目录>`**(只动我的 frontend 文件,不碰别会话后端 Java WIP)。承 [[feedback_feature_branch_deploy_test_then_merge]] §1b。

**✅ 第二轮已部署(2026-06-28 20:46 HKT)**:集成 sha **ebe604fc**,**FORCE_PEAK=1 峰窗内部署**(Owner"现在就部署",纯清理零用户可见变化、lint0+vitest851+蓝军6条全修+集成0冲突预验证+dist.backup秒回滚,6 节点零事故,落复盘)。gfw 48055e40→ebe604fc、master 07f6436e→`7c1b82e1`(GFW-free)。净 −453 行。蓝军 F1(MovieCard 补 lowPriority prop 保真 HomeDesktopSections 原 fetchpriority=low 让路信号)。

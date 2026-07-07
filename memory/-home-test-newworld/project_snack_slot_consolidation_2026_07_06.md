---
name: project_snack_slot_consolidation_2026_07_06
description: "广告位收敛19→13(PC/mobile共用一套)+yml单尺寸+纯图卡+命名v45+多轮间距对称精修,终态master 3467e0c5全部署;含前端间距踩坑reference(app-mobile覆盖/Tab清位挂滚动容器/min-height塌缩/注入CSS预览法)"
metadata: 
  node_type: memory
  type: project
  originSessionId: db5768b1-6308-46eb-845a-adea5ee5851e
---

# 广告位(Snack)收敛 19→13 + 单尺寸 + 电影卡/纯图改版（2026-07-06）

**已合 master `8fe65073` + 五步部署验证全过**（fix/snack-slot-consolidation，SQL补丁另commit）。Owner多轮brainstorm拍板。

## 终态结构（13 活跃槽 + 6 退役）
- **全站公共件挂 MainLayout 一层**（非首页）：z02 方格图标=公共头部(首排吸顶)、l03 横幅=公共底部(含播放页)、z06 文字广告=全站(含播放页)。各页零散挂载已删防重复。
- **★首页保留原布局**（Owner「mobile首页布局不动」）：图标条在轮播图下方由 HomePage 自渲染(top-spacer=false sticky=false)，公共 Snack09 用 `v-if=!isHomeRoute`(route.name home/region-home)排除首页。其他页(列表/搜索/播放/收藏/历史)用顶部公共头部。
- **6 槽退役**(z01/z03/z04/z05/p02/l01 status=0留档)，PC位置改挂共用槽:首页穿插→l02、首页图片卡→p01；p02侧栏删Snack02.vue。
- **命名v45**:z02方格图标/l03底部横幅/z06底部文字/g03选片页文字链接(手机底部Tab选片面板内)/l02列表穿插/p01视频下方图片/p07推荐上半穿插/p08推荐中部横幅/p03推荐下半穿插/p05贴片/p06暂停/g01打开网站弹窗/g02右下角悬浮。
- **p01/z05 纯图片形式**:Snack08委托Snack04(imageOnly),16:9可点击图无文字。

## ★yml 单尺寸简化(Owner「只传一份图为何定义两尺寸」)
pc/mob/rec 三组collapse为单组 rec_w/rec_h(运营看到=存储=校验同一个数)。SnackSlotSpec record 10→6字段。软校验纯rec:过小=rec×0.6阻止、比例偏离rec×[0.75,1.25]确认框(横幅位按3:1传CSS cover裁5:1)。设计doc docs/superpowers/specs/2026-07-06-snack-slot-single-size-design.md。

## 后端
SnackSlotSpecService.validate() 加 status=1 过滤(退役槽从yml删条目不启动失败;null视为启用=测试fixture需要)。yml收敛11图片槽。

## 部署(2026-07-06 06:02-06:08 HKT)
五步:v45 SQL(断言active13/retired6/strand0)→yml→admin jar `20260706-060543-8fe65073`→fe-web×6→fe-admin。
**★步0断言正确拦停strand=1**:l01有1条已下线广告id=34(status=0)滞留,首版迁移漏l01源(误判空:pre-flight按status=1统计)。手工补迁id=34→l03,strand=0续跑。SQL已补l01→l03(commit待推)。
验证:admin 0 ERROR+11槽加载OK;jar record recW在/pcW无;双引擎四象限(chromium+webkit×PC/mobile)逐页截图:首页图标在轮播下方✓/列表页顶部公共图标头部✓/播放页底部p08+l03间距32px不叠✓/收藏页新增图标头部✓。deployed/frontend-web+admin tag=8fe65073。

## 教训
- ★迁移pre-flight统计"槽是否空"必须含**所有status**广告,只按status=1会漏下线广告致退役后滞留(断言救了)。
- ★合并撞F11安全批(Snack08同文件),取safeClickUrl委托继承;共享checkout本地master被别会话docs commit占用→用detached worktree在origin/master做--no-ff合并不碰本地master。

## 07-06 收尾批(间距精修+下拉过滤+数据清理)已合master`7c95cc09`部署
- **间距精修**(合`7c95cc09`,fe-web+fe-admin已部署验证):Owner反馈公共图标头部到内容+底部横幅间距太大。根因=`.title-with-avatar.center min-height:100px`预留高度(无头像页白留空白带)→改auto(有头像页头像自撑,截图验完整);+content-header padding 4.5rem→1.5rem+sorting-nav:empty归零(空nav 8rem幽灵间距)+snack-tile-row下距16→6+global-bottom-banner 32→16/12px。列表页gap 129→106px,标题上移~60px空白带消失。★注入CSS到实时页面截图=不部署预览法。
- **退役槽不入下拉**:管理端顶部筛选下拉改activeSlotList(status=1),formSlotList复用。
- **数据清理**(直接改生产库,非部署):p01/l02/p03/l03迁移堆超max_count,删10条(9无图占位+id34离线ms重复),每槽留到撑满显示,有图真广告(l03 id37/p03 id27)不动。备份scratchpad/deleted-snacks-backup-*.tsv。★迁移把广告堆超展示容量=运营看到"8条"但只显4;清理原则=优先留有图+补占位到max_count。

## 07-06 间距精修多轮(Owner逐条反馈,全fe-web已部署)
共4批,均feature分支→注入实时页面预览→合master→fe-web×6→四象限验收→清理:
- `7c95cc09` 首轮:title-with-avatar.center min-height 100→auto(根因)+content-header 4.5→1.5rem+sorting-nav:empty归零+tile-row 16→6+底部横幅32→16。
- `0471b0e8` 移动列表+PC播放页对称:①图标↔播放器 0→18px(#site-content.player-page padding-top)②p01↔猜你喜欢:Snack08 .snack-cards-wrap min-height 200→0(卡片aspect-ratio自带高度)③p08中部横幅PC隐藏(d-lg-none,移动端保留)底部靠l03横幅收口=对称④meta头像↔高清原片 0→10px(.models margin-right:meta-badge的margin-left:auto行满塌缩致贴住)⑤底部横幅16→8/12→6。
- `3467e0c5` content-header页(分类/演员索引/收藏/历史)+MovieListPage:①图标↔标题 64→12px ②内容↔底部横幅(分类85→45/列表页码72→32)③MovieListPage标题行list-meta-row恢复12/12。

## ★前端间距踩坑(load-bearing,下次改移动端间距必看)
- **app-mobile.css 覆盖压过 app.css**:`.content-header`在app.css改padding无用,移动端`app-mobile.css:19 .content-header{padding:4rem...}`(media query)会盖掉。改移动端content-header间距必改app-mobile.css。
- **底部Tab清位挂错层**:`.site-content{padding-bottom:50px}`(main-layout.css,移动端)本为底部Tab留位,但全站底部横幅/文字链/footer在#site-content之后,这50px反成"内容↔横幅"大空隙。正确=清位挂`.scroll-wrapper`(滚动容器)底部,site-content只留小padding。移动端footer本身display:none(Tab替代)。
- **min-height塌缩当空隙**:`.title-with-avatar.center min-height:100px`(给头像预留)/`.snack-cards-wrap min-height:200px`(给卡片预留)在内容矮于预留值时=垂直居中留白/底部空,视觉是"间距太大"。有aspect-ratio/自撑内容的可直接min-height:auto/0。
- **margin-left:auto行满塌缩成0**:meta-badge(高清原片)用margin-left:auto右推,行内容填满时auto=0致贴住前元素。要保最小间距给前元素加margin-right,别改auto。
- **注入CSS到实时页面截图=不部署预览法**:playwright goto线上→addStyleTag(候选CSS)→截图/量gap,真数据下看效果,避免build+起服务;验证型改动神器(本会话全程用)。

## 前序批(同日已部署)
project_snack_slot_size_hints_2026_07_06(尺寸提示单真相源/rec/电影卡)是本批前身;本批是最终收敛态。

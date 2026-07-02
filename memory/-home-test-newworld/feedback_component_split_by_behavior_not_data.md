---
name: feedback_component_split_by_behavior_not_data
description: "前端组件按\"行为/成本边界\"切,不按数据切;同数据但行为不同(交互/生命周期/成本)= 正确两个组件,硬合=过度设计。Owner 2026-06-28 reframe 修正\"填全字段一个组件\"的直觉"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 173531ec-95aa-4674-92c6-1fd30a60cc43
---

**铁律(Owner 2026-06-28 reframe)**:前端**组件按"行为/成本边界"切分,不按"数据"切分**。两个东西渲染同样的数据、但**行为/成本不同**(交互性、生命周期、渲染量),是**正确的两个组件**,不该合并。

**Why**:Owner 当时的直觉是"card 本质是承载 movie 数据的实体,填全字段、各页按需取,两类 card 能合一个"。这句对的是**数据层**(movie 实体确实统一,各取所需);但漏了——**组件 = 数据 + 结构 + 行为 + 成本**,不只是数据。
- 实例:**FeedCard**(首页无限下滑卡,285 行)= 悬停预览 `<video>` 懒挂载 + IntersectionObserver 单例(全页只挂 ≤1 video)+ WebKit MediaPlayer 泄漏释放 + 真收藏 + onMounted/onUnmounted/watch 一堆生命周期。**MovieCard**(list-card tile,50 行)= 纯 props→模板,零行为零生命周期。
- 硬合两路:① 每个便宜图块都背上 FeedCard 的机器(一页 24-100 个卡 → 24-100 个 IO + video 潜在挂载)= 性能崩;② 或一个巨型组件 + 一堆开关 prop(showPreview/enableFav/eager/...)= 过度设计(反 DRY/ponytail 初衷,比复制更难读)。两条都更糟。

**How to apply**:想合并组件 / 抽共享组件前,先问 **"它们共享的是 结构+行为,还是只共享 数据?"**
- 只共享数据 → 统一**数据模型**(实体对象 + 各页按需取字段),组件**保持分开**。
- 共享结构+行为 → 才抽一个组件(如 6 处 list-card tile 同构 → 抽 MovieCard)。
- 顶多把**最小的纯展示共用件**(如缩略图 `<picture>`)抽子组件给行为不同的两边复用;但收益小时别抽。

**判据口诀**:数据可统一,组件按行为切。"card"不是规格、是 UI 模式;granularity 永远看 结构+行为是否重复,不看数据是否相同。承 ponytail 反过度设计(`[[project_movielistpage_consolidation_2026_06_28]]` 的 MovieCard #2,我先误判"抽 MovieCard 是过度设计"因把 FeedCard 也算进去 → Owner reframe 修正)。关联 [[feedback_declarative_over_procedural]]。

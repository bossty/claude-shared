---
name: 分类页路由是 /subjects 不是 /categories
description: 前端 SPA 路由命名陷阱，用户看到 /categories 会 404
type: reference
originSessionId: a1281538-3ef1-45f9-abfb-2b6348aec877
---
`router/index.js:20` 把 CategoriesPage.vue 挂载在 `/subjects`。
- 列表页：`/subjects`
- 详情页：`/subjects/:categoryId/:page?`
- 标签详情：`/topics/:tagId/:page?`
- 演员详情：`/instructors/:actorId/:page`

**Why:** 教育主题伪装（movie→course/lessons, actor→instructor, category→subject, tag→topic）。
**How to apply:** 任何"打开分类页/演员页"测试都用伪装路径，不要用业务命名。

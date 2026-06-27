---
name: 部署前必查三项（2026-04-14 事故硬化）
description: 三个真实事故教训：SQL migration 必执行 / PageHelper 禁手写 LIMIT / 新函数必须在启动链路真调用
type: feedback
originSessionId: f41fc13a-9772-4519-93e4-19914facf340
---
## 背景

2026-04-14 01:15 两生产 bug 同时爆发 + 12:00 发现 Sprint 1 TP-02 从未生效。单日内 P9 错过三次事前 verify 机会。

## 规则

**部署前必查三项，少一项 = 3.25：**

### 1. sql/ 新 migration 已在生产 DB 执行

- 任何含 `sql/*.sql` 新文件的 commit，**部署后端代码之前**必须先在 aws-db 跑 SQL
- 漏了 → 新代码访问不存在表 → 生产 500 雪崩
- **Why**：TP-01 `promotion_channel_domain` 表漏建 → web 每秒 500 爆炸 1h

### 2. PageHelper 场景下 Mapper XML 不能手写 LIMIT

- PageHelper 在 Spring AOP 层自动在 SQL 前注入 `LIMIT ? OFFSET ?`
- MyBatis Mapper 再写 `LIMIT #{limit}` → `LIMIT ? LIMIT ?` MySQL 语法错
- **Why**：P1-3 的 `findAllLatestMovies` 加 LIMIT → 双 LIMIT 所有首页接口爆炸
- 本地 dev profile 可能绕过这个场景，**必须 prod profile + 本地 mysql prod 镜像真跑**

### 3. 新启动期函数必须在启动链路 import + 调用

- 定义 `export function initXxx()` 不等于会执行
- 必须在 `main.js`（前端）或 `@PostConstruct`/Spring Bean（后端）真调用
- **Why**：Sprint 1 TP-02 `initFirstVisitDate()` 定义了 25h 从未被调 → 灰度 0 数据
- **How to apply**：grep 新函数名在 main.js/启动链路文件命中 import + call，才算完成

## 元 SOP：E2E 验证真实性红线

- E2E 验证**绝不能用 curl 手塞 cookie 绕过前端流程**
- curl `Cookie: _fvd=...` 走通后端路径，但从来不会暴露"前端写 cookie" 的缺失
- **必须用真实浏览器**（Chrome DevTools MCP）：首访 → F12 看 localStorage/cookie 是否写入 → 刷新看请求是否带
- 不能只测 API，必须测"前端 → 后端 → 前端反馈"完整闭环

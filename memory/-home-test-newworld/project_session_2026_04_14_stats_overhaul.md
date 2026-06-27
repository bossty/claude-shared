---
name: 2026-04-14 统计与分类页全栈整治
description: 统计 SPA PV bug 全套修复 + 5 分类主题 SVG + 清理无切片视频 + 全链路缓存清除的会话状态
type: project
originSessionId: a1281538-3ef1-45f9-abfb-2b6348aec877
---
## 已完成（已部署生产）

### 核心 commit 链
- `0f1dd85` 后端：HLL UV 拒绝 sessionId 兜底 + `stats:no-vid:{date}:{channel}` 监控
- `6f3215f` 前端：38 处 `<a :href>` → `<router-link :to>` + stats.js 加 pagehide/pageshow + HomePage tab/region/feed PV 漏点
- `935a4d4`/`1005c03`/`eddbb0c`/`1c01ac3` 5 分类主题 SVG（cn-drama/amateur/webcam/3d-animation/hentai）+ 500x500 viewBox + ?v=__BUILD_HASH__ 破 CF 缓存 + light 主题白字阴影
- `da262c4` revert 误带的 Rule34 WIP
- `c10819e` `docs/上线影片过滤设计.md` 144 行 SSOT

### 数据/运维操作
- DB 软下线 6 部 7mm 失败影片 (id: 48478, 48489, 48509, 48513, 48519, 48521)
- status=1 movie 总数 23952 → 23946
- movie_count 重算（CategoryStatisticsTask + ActorStatisticsTask 等价 SQL）
- Redis Pub/Sub `shared:ch:movie-refresh "all"` + 6 个具体 ID
- `shared:content-version` 913 → 914
- L2 精准 DEL 8 个 home/list 键

**Why:** P9 战略拆解 + 4 路 P7 并行 + 真实浏览器 E2E 验收，整套 SPA 流量统计 bug 闭环。
**How to apply:** 这套修复是基础设施级，未来"渠道饱和度"等业务指标依赖此基础。

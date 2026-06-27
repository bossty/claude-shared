---
name: newworld-cf-cache-verify
description: CF cache 验证铁律 — curl -I (HEAD) 永远返 cf-cache-status DYNAMIC + no age，会误判没缓存；用 curl -s -o /dev/null -D - (GET) 才看真实 cache 状态。triggers: cf-cache-status DYNAMIC, CF cache verify, 验证 CF 缓存, cache HIT/MISS 调试
---

# newworld CF cache 验证铁律

## 核心 lesson（2026-05-22 ad-image-encrypt sprint 实证）

**`curl -I` (HEAD) 永远 DYNAMIC，不代表 CF 没缓存。**

CF 默认对 HEAD 请求不命中 cache（且不存 cache），所以即便 GET 已经在边缘 HIT 4319s，HEAD 还是返 `cf-cache-status: DYNAMIC` + 缺 `age` header。曾误判 CF 配置坏了 → 折腾 Cache Rule / Origin headers / Cache Reserve 三个错方向。

## 正确验证方法

```bash
# ❌ 错的（永远 DYNAMIC，会误判）
curl -sI "https://cdn.example.com/path/file.js" | grep -i cf-cache-status

# ✅ 对的（GET 看真实 cache 状态）
curl -s -o /dev/null -D - "https://cdn.example.com/path/file.js" \
  | grep -iE 'cf-cache-status|^age:'
```

期望输出：
```
cf-cache-status: HIT
age: 4319
```

## 触发场景

任何下面对话 → 立即用 GET 验证，禁用 HEAD：

- "为什么 CF 没缓存"
- "cf-cache-status 是 DYNAMIC"
- "Cache Rule 配了但不命中"
- "明明 cache-control immutable 还是回源"

## 边界

- `purge` 验证 / DNS 存在性验证（见 `newworld-cf-purge-multi-zone` skill）用 HEAD 没问题
- 单纯调 cache 状态必须用 GET
- 浏览器 Network panel 看到的 cf-cache-status 是首次 GET 响应里的，**disk cache replay 时也会复用同 header**，所以浏览器看 HIT 不代表当前服务器 HIT — 强刷 Cmd+Shift+R 才能拿真实当前状态

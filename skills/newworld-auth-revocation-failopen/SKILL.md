---
name: newworld-auth-revocation-failopen
description: JWT/会话校验里黑名单/吊销类 Redis 查询必须 fail-open（基础设施抖动 ≠ 凭证无效）；吞一切的 catch-all 会把 Redis 超时静默变成 401 → 前端清 token 误踢登录。本地校验(签名/过期)与远程吊销(Redis)分层 try。triggers: parseToken, isTokenBlacklisted, 黑名单, JWT 校验, 登录几分钟掉线, fail-open, 401 误踢, RedisCommandTimeout 踢登录, token 失效, 吊销列表
---

> **执行机制**：靠判断力（fail-open 分层设计判断）

# newworld 鉴权吊销检查 fail-open 铁律

## 核心 lesson（2026-06-18 admin 几分钟掉线 RCA 实证）

**鉴权路径上的"黑名单 / 吊销 / 撤销列表"查询依赖 Redis，必须 fail-open——基础设施抖动 ≠ 凭证无效，绝不能因 Redis 超时把在线用户踢成 401。**

实战：admin 后台"几分钟掉线"，owner 以为是登录过期（token 真有效期 2h）。真因是 `AdminUserServiceImpl.parseToken` 有个**吞一切异常的 catch**，里面调 `isTokenBlacklisted`（Redis `hasKey`）。当 Dragonfly 每 5min 快照 spike 击穿 Lettuce 3s 超时，`hasKey` 抛 `RedisCommandTimeoutException` → 被静默 catch → 返 `Optional.empty()` → 拦截器出 **401** → 前端 `request.js` 对**任何** 401 都 `localStorage.removeItem(token)` + 跳登录。**Redis 抖动被翻译成"登录失效"**。且静默 catch **不留日志**，极难排查。

## 反模式（禁）

```java
public Optional<Identity> parseToken(String token) {
    try {
        if (!jwtUtil.validateToken(token)) return Optional.empty();
        if (isTokenBlacklisted(token)) return Optional.empty();   // ← Redis 抖动在此抛异常
        ...
    } catch (Exception e) {
        return Optional.empty();   // ← 把 Redis 超时也当成"token 无效"→ 401 误踢
    }
}
```

## 正确模式：本地校验 vs 远程吊销，分层 try

```java
// 第一道：JWT 签名+过期，纯本地、不依赖 Redis。失败=token 真无效 → 401。
Claims claims;
try {
    if (!jwtUtil.validateToken(token)) return Optional.empty();
    claims = jwtUtil.parseToken(token);
} catch (Exception e) {
    return Optional.empty();
}
// 第二道：黑名单=尽力而为的吊销，依赖 Redis。抖动时 fail-open + WARN，不踢人。
try {
    if (isTokenBlacklisted(token)) return Optional.empty();
} catch (Exception e) {
    log.warn("[auth] 黑名单查询失败(Redis 不可达?)，按未吊销放行，避免误踢登录: {}", e.toString());
}
return Optional.of(new Identity(...));
```

## 触发场景（出现立即套用本铁律）

- "管理后台 / 用户登录 几分钟就掉线 / 频繁重登"（先排除真过期：查运行时 `jwt.expiration` + 前端 401 处理）
- 任何 `parseToken` / `isTokenBlacklisted` / 吊销列表 / 撤销检查里 catch 吞 Redis 异常
- `RedisCommandTimeoutException` 与登录掉线同时出现

## 边界

- **只对"吊销/黑名单"这类尽力而为的撤销检查 fail-open**；JWT 签名/过期校验失败仍必须 fail-closed（返 empty → 401），那是真无效。
- fail-open 的代价是"已登出但仍在黑名单 TTL 内的 token 在 Redis 抖动窗口可能短暂可用"——对内部 admin 可接受；高敏场景可改为短重试再放行，但**不可**直接踢人。
- 这是"应用层不踢人"；根上的 Redis 抖动要另治（如 Dragonfly 快照降频，见 [[newworld-multiregion-crossocean-hotpath]] 同源的跨洋/抖动思路）。
- 静默 catch 必须补日志（同 `newworld-vite-dynamic-import` 的 silent catch 反模式：吞异常不留诊断 = 排查黑洞）。

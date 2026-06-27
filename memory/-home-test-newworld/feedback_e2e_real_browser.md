---
name: E2E 验证必须用真实浏览器，不用 curl 塞 cookie
description: 2026-04-14 两个隐藏 bug 的教训：curl 手塞 cookie 会绕过前端流程，掩盖"前端没写 cookie / 没注入 header"类 bug
type: feedback
originSessionId: f41fc13a-9772-4519-93e4-19914facf340
---
## 规则

**E2E 验证绝不能用 `curl -H 'Cookie: xxx'` 或 `curl -H 'X-Custom: xxx'` 绕过前端流程。**

必须用真实浏览器（Chrome DevTools MCP）：
1. 清 cookie / localStorage
2. 首访目标域名（含 `__e2e=7rip` cookie 绕探针）
3. `evaluate_script` 读 localStorage / document.cookie / 发 fetch 看 header 是否被前端注入
4. 再走后端路径看行为

## 为什么

**Curl 验证的盲点**：手塞 cookie 走通了**后端**路径，但**前端是否写 cookie / 注入 header** 完全没测。

典型踩过的坑：

| Bug | curl 假验证结果 | 真实浏览器暴露 |
|-----|----------------|-------------|
| Sprint 1 TP-02 `initFirstVisitDate` 从未调用 | `curl -H 'Cookie: _fvd=...'` 后端正常下发 migrateTo → 以为 OK | `localStorage._fvd=null` + `document.cookie` 无 _fvd → 灰度 25h 空跑 |
| TP-MON-01 `X-SW-Version` 永不注入（SW 跳过 /analytics/*） | `curl -H 'X-SW-Version: xx' /analytics/hit` → Redis 正常记录 → 以为 OK | 真实 fetch 流量 header 为空 → `stats:sw-versions` 只有手测数据 |

## SOP

任何涉及"前端写 → 后端读"的链路：

```javascript
// Chrome DevTools MCP evaluate_script 标准验证
async () => {
  await new Promise(r => setTimeout(r, 2000))  // 等前端初始化
  return {
    localStorage_key: localStorage.getItem('key'),
    cookies: document.cookie,
    // 发一次真实 fetch 看 SW/stats.js 是否注入 header
    // ...
  }
}
```

## 相关 SOP

- CLAUDE.md "部署前必查三项" - 补丁了"新函数必须在启动链路真调用"
- `feedback_deploy_preflight.md` - 三条硬 SOP
- `docs/incident-2026-04-14.md` - Bug-C / Bug-D 完整复盘

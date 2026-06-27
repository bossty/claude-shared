---
name: GFW 降级链本地测试方法
description: 完整测试 GFW 两层防线：层1 SW Happy Eyeballs 8个场景 + 层2 DoH域名发现 3个场景，共11个测试
type: reference
---

## 环境搭建

1. **nginx 本地反代** (port 4080): 服务 dist/ 静态文件 + 代理 /api/ 到 Java:7777
   - 配置文件: `/etc/nginx/sites-enabled/newworld-test`
   - 正常模式: `proxy_pass http://127.0.0.1:7777`
   - 故障模式: `return 503 '{"code":1,"msg":"blocked"}'`
   - 切换: 替换配置文件 + `sudo systemctl reload nginx`

2. **Node mock server**: 模拟 gateway/backup/relay 等路径
   - 端口 4081: gateway mock（或关掉模拟 dead）
   - 端口 4082: backup domain mock（代理到 7777）
   - 端口 4083: delayed relay mock（加 setTimeout 模拟慢响应）
   - 每个 mock 需要 CORS headers

3. **Chrome DevTools MCP**: 在真实浏览器中运行测试
   - 必须设置 `__e2e=7rip` cookie 跳过探针检测
   - 不能用 isolatedContext（没有 navigator.serviceWorker）
   - SW 注册需要页面正常启动（nginx 正常模式），然后再切故障模式

4. **Java 后端**: `scripts/web.sh` 启动 newworld-web 在 :7777

## 测试步骤

### 准备
- `npx vite build --outDir dist.test && node scripts/obfuscate-sw.js dist.test` 构建
- 原子切换 dist
- 清除 IndexedDB (`indexedDB.deleteDatabase('_c2')`) 确保干净状态
- 正常模式启动让 SW 注册，然后通过 `postMessage type:'_m4'` 注入 domainPool

### 8 个测试场景

| # | 场景 | nginx | mock | 预期 |
|---|------|-------|------|------|
| 1 | Primary 正常 | 正常 | 无需 | <50ms, 无 toast |
| 2 | Primary 503 → Gateway 接管 | 503 | gateway alive | ~250ms+latency |
| 3 | Primary + Gateway 失败 → Backup | 503 | gw dead, backup alive | ~500ms |
| 4 | 全部失败 → 503 | 503 | 全 dead | ~1s(conn refused) 或 5s(超时) |
| 5 | Toast 时序 | 503 | relay 延迟 1.5s | 800ms "正在连接", 2s "正在切换线路" |
| 6 | 路径记忆 | 503→正常 | backup alive | 首次 500ms, 后续 <10ms |
| 7 | 多路径全失败不阻塞 | 503 | 全 dead | 5次请求全部 <6s |
| 8 | Analytics 入队 | 503 | 全 dead | promotions/track 返回 code:0 |

### 注入 domainPool 示例
```javascript
navigator.serviceWorker.controller.postMessage({
  type: '_m4',
  data: {
    apiGatewayUrl: 'http://localhost:4081/gateway',
    apiGatewaySecret: 'test-secret',
    apiDomains: ['http://localhost:4082'],
    relayHttpUrl: 'http://localhost:4083',
    relayWsUrl: '',
  }
});
```

### 监控 SW 消息（验证 toast 时序）
```javascript
const msgs = [];
const t0 = Date.now();
navigator.serviceWorker.addEventListener('message', (e) => {
  msgs.push({ type: e.data?.type, status: e.data?.data?.status, at: Date.now() - t0 });
});
```

## 发现的 Bug（2026-04-02）
- `updateDomainPool()` 遗漏 `apiGatewayUrl` / `apiGatewaySecret` 字段，导致 app-config.js 下发的 Gateway 配置无法写入 SW

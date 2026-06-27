---
name: reference-cf-early-hints-cache
description: CF Early Hints (HTTP 103) 缓存独立于 200 响应的 Cache-Control，origin 删 Link header 不立即生效，必须显式 CF purge 才闭环
metadata: 
  node_type: memory
  type: reference
  originSessionId: 046b7946-c72d-4193-b28a-2f3c7fa3b453
---

# CF Early Hints 缓存独立性

## 行为底层逻辑

Cloudflare 启用 Early Hints 后会：
1. 从 origin 200 响应里读取 `<link rel=preload>` HTML 标签 **或** `Link: </path>; rel=preload` 响应头
2. CF 边缘**独立缓存**这些 preload hint（与 HTML body 的 Cache-Control 解耦）
3. 后续同 URL 请求，CF 在 origin 200 之前先发 HTTP/2 103 + Link header 给浏览器
4. 浏览器解析 103 提前 fetch 资源（initiatorType=`early-hints`）

## 陷阱

**origin 删 preload 后**：
- HTML body 立即不带 preload tag（curl 验证 0 命中）
- 但 CF 边缘 cache 里的 103 hint **仍然存在**
- 浏览器仍收到 103 + Link → 仍预加载 dust 资源
- console 报 "preloaded but not used"

**单看 200 响应 Cache-Control 误判**：
- HTML 标 `cache-control: no-cache` + `cf-cache-status: DYNAMIC` 给的是 body 的 cache 行为
- 不代表 CF 没 cache 该 URL 的 Early Hints — Early Hints cache 是另一层

## 实证抓手

`window.performance.getEntriesByType('resource').filter(e => e.name.includes('xxx'))[0].initiatorType`

- `'early-hints'` → 真凶是 HTTP 103（CF Early Hints / nginx add_header Link / 后端 103 中间响应）
- `'link'` → HTML `<link rel=preload>`
- `'css'` → @font-face / url() / @import
- `'script'` → JS fetch / Image() / dynamic Link injection
- `'fetch'` → window.fetch
- `'xmlhttprequest'` → XHR

curl 看不到 Early Hints 真相（除非 `curl -D -` + `--http2` 显式抓 103）：
```bash
curl -s -D - https://example.com/ -o /dev/null --http2 | grep -iE "^(HTTP|link)"
# HTTP/2 103
# link: </fonts/x.woff2>; rel=preload; ...
# HTTP/2 200
```

## 修法闭环（owner mindset 三层都改才算干净）

**L1: 源站 HTML preload** → 编辑 `<link rel=preload>` 标签
**L2: 源站 HTTP Link header** → 删 nginx `add_header Link` / 后端响应头
**L3: CF Early Hints 边缘缓存** → CF API `POST /zones/{zone_id}/purge_cache` `{purge_everything: true}` 或 `{files: ["https://..."]}`

漏 L3 → owner 端硬刷新仍命中 cached 103 → 警告不消。

## 实证案例

[[project_nginx_error_audit_2026_05_22]] 5/23 outfit 字体 "preloaded but not used" 警告：
- 5/20 commit nginx add_header Link 准备 CF Early Hints
- 3/22 commit 183b12ac logo CSS 文字 → SVG path，outfit 字体变 dust
- 5/23 删 HTML preload + @font-face 后 owner incognito 仍报警告
- 真机 chrome-devtools performance API 实证 initiatorType=`early-hints` 锁死真凶
- 删 nginx add_header Link + 部署 + CF purge_everything 三层一起做才闭环

## 推广面

任何 CF zone 启用 Early Hints 后，**「源站 cache header」与「CF 边缘 Early Hints cache」是两套独立缓存**：
- 改源站 Cache-Control / ETag → 不动 Early Hints cache
- 改 origin Link header → 写新 Early Hints 但旧 hint 仍在 cache 服务期
- 唯一让边缘 cache 立即清零的抓手 = 显式 CF API purge

关联：[[reference_cf_public_ip_ranges]] CF 边缘行为类教训。

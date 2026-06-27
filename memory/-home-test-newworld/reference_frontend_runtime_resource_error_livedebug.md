---
name: reference_frontend_runtime_resource_error_livedebug
description: "源码/DB grep 找不到固定资源路径"的 live debug 方法论：prod Redis 穷举 → 代码排除 → chrome-devtools Image.src hook 抓 initiator 调用栈 → DB 拍死数据源
metadata:
  type: reference
---

## 问题场景

prod 出现固定资源路径 404（如 `/8ef1d3e3`），但：
- 全仓库 grep 该路径字面量 = 0
- DB substring 查询 = 0
- 日志路径排查也找不到代码出处

原因：路径是**运行时由数据经映射构造**（如 `cdnSnack(imageUrl)` 把 DB 中裸 hash 拼成完整 CDN URL），源码中无字面量，不可直接 grep。

## 诊断链（2026-06-18 assetlibs/snack27 实证）

### Step 1：prod Redis error-samples 穷举，确认特征

```python
# 无 redis-cli 时用原生 RESP python（见 reference_fe_error_store_enumeration）
# AUTH + SCAN monitor:error-samples:* + HGETALL → 归一化
```

本案：1952 raw → 397 族 → 323 条同一路径 `<CDN>/8ef1d3e3`，特征：
- `sec-fetch-dest: image`（`<img>` 或 CSS background 加载，非脚本、SW）
- `ERR_BLOCKED_BY_ORB`（跨域 no-cors 请求返回 404 HTML，被 ORB 拦）
- 全 `/lessons/` 页，跨 IMG/PRV/VID 多 CDN 池均有（说明是 failover 雪崩放大后的副产品）

### Step 2：读代码排除已知探针，缩小嫌疑范围

已知产生固定路径 fetch 的探针（需逐个排除）：
- `cdn-failover.js`：探测用 `/cdn-cgi/trace`（no-cors），不是图片路径
- monitor.js R2 probe：`/cdn-cgi/trace`，同上
- SW silent probe：`/api/v1/settings/version`，非 CDN 域
- video diag：`/__nwdiag__`，特殊前缀
- 排除全部 → 嫌疑落到业务图片渲染路径

### Step 3：chrome-devtools live hook 抓 initiator 调用栈

在 chrome-devtools MCP 中，对目标页 `navigate_page + reload`，带 `initScript` 注入以下 hook：

```js
// hook HTMLImageElement.prototype.src setter
const origDesc = Object.getOwnPropertyDescriptor(HTMLImageElement.prototype, 'src')
Object.defineProperty(HTMLImageElement.prototype, 'src', {
  set(v) {
    if (typeof v === 'string' && v.includes('TARGET_PATH_OR_HASH')) {
      console.error('[IMG_HOOK] src set to target:', v, new Error().stack)
    }
    origDesc.set.call(this, v)
  },
  get: origDesc.get,
  configurable: true,
})

// 补 Element.setAttribute（Vue 也会走这里）
const origSetAttr = Element.prototype.setAttribute
Element.prototype.setAttribute = function(name, value) {
  if (name === 'src' && typeof value === 'string' && value.includes('TARGET_PATH_OR_HASH')) {
    console.error('[ATTR_HOOK] setAttribute src:', value, new Error().stack)
  }
  origSetAttr.call(this, name, value)
}
```

命中时 console error 含完整调用栈 → 定位到 Vue render chunk 的具体组件。

本案：栈显示 `Snack02.vue render → <img :src="q.imageUrl">` → 确认是 snack 组件裸渲染 imageUrl。

### Step 4：DB 查数据源，拍死

```sql
SELECT id, title, slot_id, image_url, encrypted_image_url, status
FROM snack
WHERE image_url LIKE '%8ef1d3e3%';
-- 结果：id=27, title='ms', slot_id=4, status=1(active), encrypted_image_url='...'存在
```

验证：
```bash
curl -I "https://<CDN>/8ef1d3e3"                        # 404（裸路径）
curl -I "https://<CDN>/snack/static/snack33/8ef1d3e3.js" # 200（encrypted 路径）
```

## 关键洞察

- **`ERR_BLOCKED_BY_ORB`** = 跨域 no-cors 请求（`sec-fetch-dest: image`）收到非图片响应（404 HTML），被 ORB（Opaque Response Blocking）拦。不是网络问题，是路径 404 + 跨域组合触发。
- **`sec-fetch-dest: image`** = `<img>` 标签或 CSS `background-image` 发起的加载（区别于 `fetch`/`xmlhttprequest`）。
- 源码/dist grep = 0 但 live 在产 → 一定是运行时数据经映射构造（反向追映射函数，不追字面量）。
- 两个 MCP 浏览器（chrome-devtools + playwright）都是 Chromium，WebKit 真机验需另想办法。

## onImgError 雪崩放大模式

一个广告（snack27）的 `imageUrl` 裸路径 404 → `onImgError` 触发 → 误走 R_IMG 池（R_IMG bucket 无 snack 资源）→ 反复重试 → 323 条。

预防：
- 按路径前缀路由池（`/snack/static/` → R_SNACK，`onImgError:188` 已有 `AD_PATH_PREFIX` 判断）
- blob URL 护栏：`if (oldSrc.startsWith('blob:')) return`（`cdn-url.js:159`，阻止 loadEncryptedImage blob 产物触发 failover）

## 工具选型

| 场景 | 工具 |
|------|------|
| 穷举 prod error 族，建特征 | prod Redis + python RESP（无 redis-cli 时）|
| live 抓 initiator 调用栈 | chrome-devtools MCP（`initScript` + `navigate_page`）|
| DB 查数据源 | mysql 直连 + LIKE 查 |
| 验证路径是否 200 | curl -I（HEAD 对 CF 某些场景不准，用 `curl -s -o /dev/null -D -` GET 更可靠）|

## 交叉引用

- [[reference_snack_adslot_render_unify]] — 本次 snack 图片渲染统一治本（assetlibs sprint 根因）
- [[reference_fe_error_store_enumeration]] — prod Redis error-samples 穷举完整方法
- [[reference_cf_cache_verify]] — CF 缓存验证必用 GET 非 HEAD（cf-cache-verify 铁律）

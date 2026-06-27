---
name: reference_snack_adslot_render_unify
description: snack 广告位图片渲染架构：encrypted 路径唯一合法渲染路径 + 三套实现统一铁律 + 蓝军发现的 6 类典型坑
metadata:
  type: reference
---

## 根因（2026-06-18 assetlibs sprint 实证）

prod 现象：323 条 `resource_error` `Failed to load: <CDN域>/8ef1d3e3`（ORB blocked），全 `/lessons/` 视频页。

实证链：
- `8ef1d3e3` = active snack id=27（title "ms", slot_id=4）的 `image_url` 字段值（8-hex 裸 hash）
- 图文件**存在**于 encrypted 路径 `/snack/static/snack33/8ef1d3e3.js`（curl 200）
- 前端渲染该广告用了**裸 `image_url`**（`<CDN域>/8ef1d3e3` curl 404）→ 浏览器 ORB blocked → resource_error
- `onImgError` 雪崩放大：失败后错走 R_IMG 池（R_IMG bucket 无 snack 资源）→ 323 条

## imageUrl 字段真实语义（禁直接渲染）

**DB `snack.image_url` 字段 = 裸 8-hex hash**（如 `8ef1d3e3`，非 .js、非完整 URL）。`encrypted_image_url` 才是真实加密文件路径 `/snack/static/snackNN/<hash>.js`（curl 200，需 loadEncryptedImage 解密）。

`SnackService.buildSnackImageUrl()`（`SnackService.java:315-319`，line 157 `setImageUrl` 调用）：HASH_PATTERN 匹配时把裸 hash 转成 `<...>/<hash>_p.js` 加密路径写进 VO.imageUrl。**但实测不一致**：snack27 经其 serving 端点到前端时**仍是裸 hash**（DOM src=`<cdn>/8ef1d3e3` 非 `_p.js`），经 `cdnSnack()` 拼成 `<cdn>/<bare-hash>` → 404。说明**并非所有 snack serving 路径都过 buildSnackImageUrl**（多端点处理不一致，是本 bug 的结构成因之一，值得后续排查）。

**铁律：VO.imageUrl 无论是 `_p.js` 加密文件路径还是裸 hash URL，都不是可直接渲染的图片 → 禁用作 `<img src>` 或 `background-image: url()`。唯一渲染依据是 `encryptedImageUrl` + `loadEncryptedImage`。** `cdnSnack()` 对已含 `https://` 的值原样透传（`CdnUrlHelper.java:52-54`），`transformCdnFields` 对 imageUrl 是 grace 期兜底透传。

实证：48 active snack = 26 图片广告（有 encryptedImageUrl，image_url 裸 hash）+ 22 文字广告（imageUrl IS NULL）；0 个无加密+非空 imageUrl；0 个外部裸图片 URL。

## 唯一合法渲染路径

```
encryptedImageUrl + encryptTs → loadEncryptedImage() → blob URL → <img src=blob> 或 background-image:url(blob)
```

无 `encryptedImageUrl` → `getSlotFallback` / `SnackFallbackCard`，绝不渲染 `imageUrl`。

## 三套历史实现（已统一，commit cb2ccf1a→d5b08ea1）

| 派别 | 组件 | 原实现 | 状态 |
|---|---|---|---|
| 统一组件（正确，但没被复用） | `SnackImg.vue` | `loadEncryptedImage` + R_SNACK 多域重试 + `getSlotFallback` | 治本目标，其他组件统一过来 |
| inline 重复造轮子（对但不 DRY） | Snack01（背景图槽）、Snack05（img 槽） | 各自内联 `loadEncryptedImage` | 已保留 inline / 改用 SnackImg |
| 裸 imageUrl（404 根源） | Snack02/03/04/06/07/08 | `<img :src="q.imageUrl">` 或 `background-image:url(imageUrl)` | 全改：img 槽→SnackImg，bg 槽→blob 背景 |

**Snack09/10/11**：Snack10 已正确用 `<SnackImg>`，Snack09/11 是容器，无需改图片渲染。

## 实现 nuance（img 槽 vs background-image 槽不能一刀切）

- **`<img>` 槽**（Snack02/03/04/06/07）：直接换 `<SnackImg :snack="q" :slot-id="slotKey" :img-class="'xxx'" />`
- **background-image 槽**（Snack01、Snack08）：SnackImg 渲染 `<img>`，不适用 CSS background → 用 `loadEncryptedImage` 得 blob URL 再设 `background-image: url(blob)`；失败时必须 `loadFailed.value = true` → 渲染 SnackFallbackCard（Snack01 已有，Snack08 治本时补）

## 蓝军审查发现的 6 类典型坑（2 轮，全 CLOSE）

**BLOCKER：`!isEncrypted` 分支也渲染裸 `.js` URL**
- Snack01/05 的 `if (!isEncrypted && imageUrl)` 分支——并非降级 fallback，是主路径判断。`imageUrl` 是 `.js` 加密路径，当 `<img src>` 或 `background-image` 使用同样 404，背景图失败还静默（浏览器不触发 `onImgError`）。修法：`!isEncrypted` 时直接 `loadFailed=true` → SnackFallbackCard，禁用 `imageUrl`。

**MAJOR：Snack07（全屏 splash）完全遗漏**
- 双 `<img :src="q.imageUrl">` 无任何加密路径逻辑，设计清单未列入。修法：两处全换 `<SnackImg>`。

**MAJOR：`onImgError` 对 blob URL 的静默行为**
- 全局 capture 委托会对 blob URL 失败事件误触发，最终因 `failedOrigin` 不匹配 CDN 域提前 return（当前无害），但需防护。修法：`onImgError` 开头加 `if (oldSrc.startsWith('blob:')) return`（已在 cdn-url.js:159 落地）。

**scoped 样式穿透**
- `<img>` 换 `<SnackImg>` 后，父组件 scoped CSS 不作用于 SnackImg 内部 `<img>` → 尺寸/object-fit 失效。修法：改用 `:deep(.classname)` 或外层容器承载。

**双 fallback DOM（Round-2 新发现 MINOR）**
- Snack02/03/04/06：纯文字广告（imageUrl IS NULL）时，SnackImg 内 SnackFallbackCard + 旧文字 fallback 卡同时渲染，布局多出一块。生产触发条件极窄（纯文字广告 IS NULL），非功能中断，异步修。

**背景图槽失败静默**
- CSS `background-image` 失败不触发 `onImgError`（只捕 `<img>` error），Snack08 改 blob 背景后必须应用层监控失败（`loadFailed ref` + SnackFallbackCard）。

## 诊断方法（live debug 定位运行时构造值）

"源码/DB grep = 0 但 prod 在产固定路径 404"的诊断链（详见 [[reference_frontend_runtime_resource_error_livedebug]]）：
1. prod Redis `monitor:error-samples:*` 穷举 → 特征（323 条同一路径，跨多池）
2. 读代码排除已知探针（cdn-failover、SW silent probe、video diag）
3. chrome-devtools live：`initScript` hook `HTMLImageElement.prototype` 的 `src` setter → `new Error().stack` 抓 initiator 调用栈定位 Vue render chunk
4. DB 查 `image_url = '8ef1d3e3'` → 拍死数据源

## 交叉引用

- [[reference_fe_error_store_enumeration]] — prod Redis error-samples 穷举法
- [[reference_cf_immutable_stale_id_reuse]] — CDN stale/id 复用类 404 根因模式
- [[reference_frontend_runtime_resource_error_livedebug]] — 运行时资源路径 404 诊断方法论

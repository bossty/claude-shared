---
name: project_ad_image_reliability_2026_06_14
description: "广告图(snack加密图)可靠性sprint:止血品牌卡+SW预缓存治本跨洋,全上线(2026-06-14)"
metadata: 
  node_type: memory
  type: project
  originSessionId: 187c446e-e104-4aa0-a529-a524a6ebe78b
---

广告图=广告收入重点。snack 加密图失败 ~4900/30min，**89%是网络(~4350)=CN跨洋到R_SNACK(R2 CF直连)**，非解密(311)/防盗链/ts。失败UX=**纯空白但impression仍记(IntersectionObserver 0.5触发,与图加载无关)→曝光记了但零展示价值**。全套已上线 CA×3+EU×2。

**上线 commit/version**：
- `a5d237ea`/version `2f055fdb`：P0-A encrypted-image.js decrypt+网络失败护栏式1次cache-bust重试(`?cb=Date.now()`+cache:reload,首次不带cb保命中) + P0-B 失败三级降级①当前图>②同位历史图(slot缓存getSlotFallback)>③自家品牌卡SnackFallbackCard(可点击回首页中性"更多精彩内容›"不破伪装,3加密广告组件全覆盖Snack01 banner/Snack05角落/Snack10 tile) + P2 monitor.js getCfMeta()导出+_recordErr附region/POP撑ROI。
- `49862a71`/version `85742e59`：**P1-A SW预缓存治本**。public/sw.js:`SNACK_CACHE='snack-assets-v1'`(**固定名非BUILD_HASH**)+activate filter排除它+fetch handler snack cache-first(isSnackAsset路径判据/snackCacheFirst put+evict/stripCbParam统一key/保留referer)+PRECACHE_SNACK message handler requestIdleCallback预取+FIFO≤60;app侧snack.js getSnacksBySlots/Slot 4返回点_precacheSnackImages→postMessage活跃URL。**曝光前广告图已缓存手机,根本不发跨洋**。

**QImg Unpad(311)真根因=无持久结构bug(全结构假设证伪)**：
- 时区排除(encrypt_ts=bigint epoch ms)；②AdMapper映了；①DB ts漂移证伪(A4空+原子UPDATE)；
- **关键架构**:`SnackImageEncryptService` hash8=sha256(sha256(图)+ts)[:8](Owner 5/25注释"ts入hash→path必变→CDN自然miss不需purge")→**path↔ts绑定,ts-mismatch架构不可能**;重加密写新key+旧key主动deleteObject(deleteSnackR2File);R2 PutObject用`fromBytes`(完整内存数组,all-or-nothing,SDK设精确Content-Length)→**R2存不下坏字节**;
- ∴311=低频瞬时跨洋tunnel/边缘体损坏(完整长度内容错→unpad,与"有量非压倒"吻合)+唯一结构嫌疑=WASM wrapper(mod16=14有14B wrapper)前后端解析一致性(需dev读WASM),严重度MINOR。FIX-6瞬时损坏重fetch有效。

**反爬RCA(GO,未实施)**:迅雷视频嗅探插件抓m3u8=整片源(相对路径致TS+key全暴露)。**防盗链WAF Referer双重可绕(curl三象限实证:业务域200/空referer200/外站403)**:页内content-script带白名单referer+裸下载空referer均放行,CloudflareApiService:178 javadoc明示空referer放行(R2 egress免费有意权衡)。方案=观测先行(monitor分桶+UA埋点+index.html补迅雷反嗅探meta)+按行为CF Rate Limit .ts/.m3u8 challenge,❌纯UA黑名单/DRM/收紧空referer(误杀真播放)。真盗取量须查CF GraphQL(R_VID zone,需CF_API_TOKEN_B)非web.log(R2直连不经OpenResty)。

**durable 教训**：① **SW 缓存必须独立持久(不随BUILD_HASH滚动清)**,否则每部署清空又跨洋。② **混淆SW验证靠行为不靠grep字面量**(obfuscate-sw编码字符串;playwright注册真混淆sw.js+二次fetch验cache-first命中零网络,Chromium+WebKit)。③ **cache-bust `?cb=`实测有效**(CF cache key含query→MISS)**且不破防盗链**(WAF匹referer头不匹query)。④ impression与图加载解耦→失败位必填有价值内容(品牌卡)非空白。⑤ SW源在`public/sw.js`非src。详见 [[project_fe_error_triage_2026_06_13]](同sprint FIX-3~6+397族穷举)、[[feedback_multiagent_prod_ops_auth_backstop]](lead二查抓ops错路径grep/dev违留worktree/漏app侧/虚报)。

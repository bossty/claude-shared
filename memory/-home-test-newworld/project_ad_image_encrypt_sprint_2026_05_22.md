---
name: project_ad_image_encrypt_sprint_2026_05_22
description: 广告图加密 sprint 2026-05-22 — 服务端 AES-256-CBC + WebP 单一格式 + 前端 wasm decryptBytes + Blob URL + R_AD 接 cdn-failover 通用体系；QImg 子组件 + Promise cache 进程内去重 48→5 fetch；5 张明文 AVIF backfill 走一次性 Python 脚本；6 条新铁律 sink CLAUDE.md
metadata: 
  node_type: memory
  type: project
  originSessionId: 97b64e0f-eb9a-4970-8b2d-dffba0676427
---

# 广告图加密 sprint（2026-05-22）

## 业务背景

Anti-adblock sprint 5/20-21 已脱敏类名/CSS/endpoint（Q01-Q11 / q-* / /api/v1/q/*），但广告**图片 URL 路径 + 扩展名**仍真实（R2 上 `/a7e3f9c1.../<hash>.js` 明文 AVIF + `Content-Type: application/javascript` 伪装），是 EasyList 能命中的最后一环。本 sprint 补完图片层加密。

## 架构

```
admin 上传 (jpg/png/gif/webp)
  → cwebp/gif2webp 转 WebP（≤500KB）
  → AESUtil.encryptBytes(byte[], ts)
  → R2 PutObject /q/static/q{slot}/{hash8}.js (Content-Type: application/javascript)
  → DB UPDATE ad.encrypted_image_url + ad.encrypt_ts
       ↓
[用户访问]
  Q05/Q01/Q10 (via QImg.vue 子组件)
  → q.encryptedImageUrl + q.encryptTs 存在 → loadEncryptedImage(url, ts)
       ↓ _blobCache (Map<url, Promise<blobUrl>>) HIT 直接返
       ↓ MISS: fetch(cdnAd(url)) → wasm.decryptBytes(cipher, ts) → Blob URL
       ↓ fetch 失败 → reportFailure('ad') + cache.delete + throw
            → cdn-failover 体系自动切下一 R_AD 域，下次 Vue mount 命中新域
  → <img :src="blobUrl">
```

## 命名脱敏（与 anti-adblock 5/21 体系对齐）

- 子组件名：`AdImage.vue` → **`QImg.vue`**（`defineOptions({name:'QImg'})` + Q10 import 跟）
- DB 字段：`encrypted_image_url` / `encrypt_ts`（"encrypted" 中性词，不进 EasyList）
- R2 路径：`/q/static/q05/<hash8>.js`（伪装 q-static 静态资源）

## 关键决策

- **WebP 单一格式**（owner 拍）：lossy q70 静态 + animated（无 alpha 检测分支 — 当前业务全 GIF 转出来的 animated AVIF）
- **silent fail** WebP 不支持的 ~2% 老 Safari < 14（owner 拍：广告位空 + sessionStorage `__nw_ad_load_err.webp_unsupported`）
- **不灰度**（owner 5/22 拍：试点位 100% 切）：前端按响应 `encryptedImageUrl` 是否存在决路径
- **试点 slot**：z02 (Q05 → 实际 Q09→Q10 渲染) / 部分 Q01 横幅
- **backfill** 5 张 distinct AVIF：一次性 Python 脚本 `/tmp/backfill-ad-images.py`（独立 admin pipeline）→ 24 ad 全 DB UPDATE
- **Promise cache 进程内去重**（owner 揪到真痛点）：24 ad 复用 5 distinct = 48 fetch → **5 fetch**
- **R_AD multi-domain failover**（owner 揪 "通用体系"）：复用 cdn-failover.reportFailure 而非 4 次 retry loop

## 关键 commit 序列（master HEAD `8a62df8c`）

```
8a62df8c fix(encrypted-image): 删 retry loop 复用 cdn-failover 体系
5e2a8c47 feat(encrypted-image): R_AD multi-domain retry + rename AdImage→QImg
1ea579dc perf(encrypted-image): Promise cache 去重 48→5 fetch+decrypt+Blob
04091498 fix(encrypted-image): cdnAd 拼 R_AD 域名（hotfix 404）
24e6817d feat(Q10): z02 图标网格接 AdImage 加密路径
4efa04e6 fix(AdService): VO mapping 补 encryptedImageUrl + encryptTs
8b7366a2 fix(cdn-failover): 裸 hostname 补 https 防 probe 404 雪崩
a9a6186d feat(ad-backfill): reencryptFromR2 + POST /ad-reencrypt-batch
8f2b2317 fix(ad-backfill): magic-byte sniff R2 实际格式不信 ad.orig_ext
3bf07ec1 build(wasm-aes): --target web 修 vite ESM wasm
7bff3a49 feat(ad-image-encrypt): 前端 aes wrapper + Q01/Q05 改造
a7333e28 feat(AESUtil): Java byte API + Java↔Python 跨端向量 PASS
132433f6 build(wasm-aes): wasm-pack 真重编（main 接管 dev-A 手写）
6477fcc1 feat(ad-image-encrypt): DB migration + admin upload pipeline
6383ec8b feat(wasm-aes): encrypt_bytes/decrypt_bytes Rust 源
```

## 性能终态

| 指标 | 实测 |
|---|---|
| 算法 ground truth | Rust wasm + Java + Python + Node crypto 四端字节级一致 |
| CF 边缘缓存 | HIT（age 数千秒）|
| z02 24 ad 实际请求 | **5 次**（distinct image hash）|
| WASM decrypt 次数 | 5 |
| Blob URL 内存 | ~1MB（优化前 ~5MB）|

## 6 条沉淀教训（CLAUDE.md）

1. **L1: curl -I (HEAD) 永远 DYNAMIC** → 新 skill `newworld-cf-cache-verify`
2. **L2: cwebp 1.3.2 不支持 AVIF 输入**，转码必用 ffmpeg libwebp
3. **L3: dev-senior worktree isolation 不稳定**，main session 必监控 git status
4. **L4: ad 字段 entity→VO 映射手工 setter 必 grep 全调用点**（避免 dev-D 漏 2 处）
5. **L5: 沿用现有 cdn-failover 通用体系胜过重造**（4 次 retry → 单次 reportFailure）
6. **L6: fetch+Blob URL 路径绕过浏览器 image cache concurrent dedup**，必加 Promise cache

## 待办（下 sprint）

- 其他 Q 组件（Q02/Q03/Q04/Q06/Q07）改用 [[QImg]] 接加密路径
- 视频封面图加密（owner 拍："试点通过后再做"）
- 删 Q01/Q05/QImg template 的 `!isEncrypted && q.imageUrl` legacy 分支（owner 拍"所有图都加密"无 AVIF 老数据）
- `__nw_ad_load_err` 监控埋点细粒度（status / domain context）→ N9E dashboard
- ad 表字段 `image_url`（legacy）退役时机判断

## 关联

- [[newworld-cf-cache-verify]] skill（本 sprint 新建）
- [[project_anti_adblock_sprint_2026_05_21]]（前置 sprint）
- `frontend-web/src/utils/cdn-failover.js` `probeAndSwitch` (HRW + Power-of-3 + Happy Eyeballs)
- `docs/sprint/2026-05-22-ad-image-encrypt/PRD.md` v3

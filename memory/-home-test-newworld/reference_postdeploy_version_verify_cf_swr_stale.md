---
name: reference_postdeploy_version_verify_cf_swr_stale
description: 部署后核验前端新版是否 live——裸 curl 会被 CF 边缘 SWR 读到旧版假阴，必须浏览器 no-store/cache-bust
metadata: 
  node_type: memory
  type: reference
  originSessionId: 1c0cb80f-adb3-429d-b88b-1582724035c8
---

前端部署后核验「新版本是否 live」时：**CF 边缘对静态资源（如 `/version.js`）设 `Cache-Control: max-age=60, stale-while-revalidate=86400`**，裸 `curl` 命中边缘缓存会**短暂读到上一版本值 = 假阴性**（2026-07-08 P0 逃生复核修复部署实测：裸 curl 返 `f881bcb2` 旧值，实际已部署 `f4eeffcb`）。

**核验一律以浏览器 no-store / cache-bust 为准**（真实用户 SW/浏览器取的是权威值），或核 `last-modified` 头对齐本次部署时间。ops 侧直连 OpenResty 源站（绕 CF）取 version.js 也可拿权威值 + 避 OVERSEAS 短路（见 [[project_udf_backend_half_2026_07_08]]）。

配套：部署后四象限烟测 harness（`frontend-web/scripts/postdeploy-quadrant-smoke.mjs`）内已用 `cache: 'no-store'` 取 servedVer 比对，结论可信；别用裸 curl 版本比对下结论。

另一相邻坑（同源）：6 节点 `version.js` md5 逐一 ssh 核对（直读节点 `dist/version.js` 文件，非经 CF）才是「6 节点一致」的权威证据。

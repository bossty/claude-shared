---
name: project_fe_version_audit_2026_06_03
description: 前端版本检测+更新机制审计（6/03）—— 只整页导航才检测、重度SPA用户卡旧版无救援、零版本埋点、多region分发缺失(切流前置)；修复基建现成只差接线
metadata: 
  node_type: memory
  type: project
  originSessionId: a71aa26f-69ff-4daa-8ee0-e32d79403b2e
---

# 前端版本检测 + 更新机制审计（2026-06-03，5 人 barrier-crossfire）

> ⚠️⚠️ **待 reconcile 的冲突（新会话先解）**：本审计 BLOCKER-1（更新机制被动、controllerchange 不 reload、卡旧版）**可能已被 commit `90e6dca1`（6/03 18:36，SW activate `client.navigate` 强制换新，+30 lines sw.js）治本**，但 90e6dca1 疑未合入当前 HEAD(e8aff6bb)。与同日 memory [[project_sw_force_update_rca_2026_06_03]]（该 fix 的 RCA）**直接冲突**。**审计团队跑时未读到该 fix memory（charter 遗漏）、盯的是 sw-bridge controllerchange 而非 sw.js activate 的 client.navigate = 潜在盲点。** 新会话必须先核实 90e6dca1 是否已合入线上 sw.js：已修→BLOCKER-1 作废（其余洞仍有效）；未合→审计成立。详 `docs/sprint/_archive/2026-06-03-fe-version-audit/SPRINT-FINAL.md` 顶部 banner。

owner 问 frontend-web 版本检测+更新机制是否有问题（"记得是 version.txt 比对、对不上任何操作触发更新"）。全文 `docs/sprint/_archive/2026-06-03-fe-version-audit/SPRINT-FINAL.md`。

## 结论：有真问题，但不在 owner 担心的缓存层

**owner 心智模型 = 对的设计意图，代码只做了一半**（file:line fact-check）：
- "本地版本"= build 时塞进 sw.js 的常量 `BUILD_HASH`(sw.js:6/14)，非存储值。
- 🔴 **"任何操作触发"不属实**：唯一触发点 sw.js:173，**只整页导航(`mode==='navigate'`)才查**；SPA 内跳转/看片/feed 下滚/搜索全不触发。
- 🟡 触发也不立即更：埋 `__newVersionAvailable=true`(sw-bridge:214)→ 等下次 router.push 才 location.href(router:135)，标志只消费一次易丢。

## 问题清单（严重度）

- 🔴 **BLOCKER-1 重度 SPA 用户永久卡旧版无自动救援**：蓝军穷举**八条**救援路径全走死（SW navigate / router.push beforeEach / **app-config checkVersion 定时轮询只查 6 个数据版本不碰 BUILD_HASH** / 浏览器原生 SW update 只换 SW 不 reload 页面 controllerchange 故意不 reload sw-bridge:66 / `registration.update()` 全仓 0 处 / push / 无 kill switch / chunk404 故障驱动挂机摸不到）。**卡旧版无时间上限，PWA 移动用户越活跃 navigate 越少 → 越活跃越卡**。叠加：旧前端打新 API + 偶发 navigate 触发 skipWaiting+claim → 新 SW×旧 app 半新半旧错配。
- 🔴 **元根因：零版本分布埋点**（FRONTEND_MONITOR 纯错误监控、`__nw_sw_upgrade` 死信号无 consumer、stats.js 报服务端最新值非客户端实跑值）→ 卡旧版用户数据上完全不可见、潜伏到流失才暴露。
- 🔴 **部署期白屏**：deploy-frontend.sh 双节点**串行 mv** + 自愈(:129)只兜一代且跨节点不对称 → chunk 404 窗口（数秒~十几秒/次），CF 无 sticky 反更成立。
- 🔴 **多 region 前端分发链不存在（方案2 切流前置 BLOCKER）**：WEB_HOSTS 硬编码两台 HK、无 us/eu origin dist 分发 → 切流后结构性版本不同步。**已补进 `IMPLEMENTATION-PLAN-cutover-replica.md` C0 Phase 0 前置**。
- 🟠 **3 个非 hash CSS 漏 ?v=**（bootstrap.min.css/app-mobile.css/plyr.css）：obfuscate-sw.js:22 只给 /css/app.css 注 ?v=；线上实测 3 个 `cf-cache-status: HIT` + max-age 7d/CF 1d，bootstrap 内容真变(PurgeCSS)但文件名不变 → 改样式静默 serve 旧 CSS（同 reference_cf_immutable_stale_id_reuse 类）。
- 🟡 **sw.js no-cache 非 no-store + 进 CF 缓存**（REVALIDATED）：当前 stale≈0，但 CF 误配 Aggressive 就复现 2026-04-25 incident 13.3（iOS 卡老版），N9E 无监控。
- 🟡 比对非定向 `!=`：回退也触发、部署期跨节点横跳抖动。
- ✅ **owner 核心恐惧"version.txt 被缓存致永不更新"：cache-cdn 线上实证 version.txt DYNAMIC、不成立**（火力别放缓存层）。

## 修复建议（待 owner 确认，审计只建议不改码）

**P0 治本+低成本（救援基建现成、就差接线）**：① 给 app-config.js 现成 versionCheckInterval+visibilitychange 轮询**加一条比对内嵌 BUILD_HASH**（覆盖首屏盲窗+挂机用户，不依赖 SW）② 检测到弹 toast「点击刷新」+ idle>30min 静默 reload（排除播放中）③ **controllerchange 接 idle-reload**（一个挂点收口检测+更新+半新半旧）④ 首屏 beacon 带客户端实跑 BUILD_HASH → N9E 版本分布面板。
**P1**：部署原子化（并行 mv + 旧 chunk 留 ≥2 代）+ 多 region 分发 gate（切流前置）。
**P2**：version.txt/sw.js + 3 CSS 升 no-store / 加 ?v=。

## 方法论
- **owner 印象必 fact-check 实代码**：owner 记的机制方向对、实现欠（再次实证 owner 直觉是好设计意图但需代码核）。
- barrier-crossfire 多次健康自我修正（version-detect M2 自降级 / cache-cdn 把 3 CSS 从 MINOR 自升 MAJOR / 互纠 BLOCKER-2 的 CF 机制）——非 groupthink。
- 关联：[[project_db_replica_us_eu_2026_05_30]]（多 region 分发是其切流前置）。

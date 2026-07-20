---
name: project-firstscreen-placeholder-lcp-2026-07-05
description: 首屏占位 LCP 优化 A/B/C 全量合 master 部署验证；LCP 塌缩假设证伪 + 跨会话部署竞态事故 + backfill 动图全败两次纠偏
metadata: 
  node_type: memory
  type: project
  originSessionId: 65a2c4d6-8a46-4959-b246-442bcc323cc6
---

# 首屏占位 LCP 优化（2026-07-05，sprint docs/sprint/_archive/2026-07-05-firstscreen-placeholder-lcp/）

三方案全量上线（合 master merge commit 见 sprint DESIGN.md；web×6 + ca-admin `20260705-042405-firstscreen-849b1116.jar`）：
- **A** hero blurhash 占位（Mobile 48×27 / PC 32×24，共享 `utils/blurhash-decode.js` 尺寸感知缓存）——真机前后对比：hero 灰块→模糊预览（evidence/before|after-firstscreen.png）。
- **B** snack dominant_color 主色占位全链路（v43 列已跑 CA master + admin 算色服务 + 保存钩子 @Async + backfill 端点 + web VO 透传 + Snack10 tile inline 底色）——真机 168/168 tile 全带主色。
- **C** feed 首卡去 eager 特殊化 + eager 卡也显 blur——基线实测 LCP 元素竟是 feed-img 26.4s（eager+high 在首屏外抢 hero 带宽=有害）。

## 关键判定（durable）
- **★Chrome 低熵图排除启发式：blurhash 占位不入 LCP 候选**，"inline blur 塌缩 LCP 指标"假设被真机 trace 证伪（hero-blur 从未出现在 LCP entry）。LCP 数字收益只能靠"去掉带宽竞争→真图更早到"，需看 RUM p75 数天趋势（**观察项，未验**）。感知修复（灰块→预览）与指标塌缩是两回事。
- **★存量 snack 图 27/27 全是动图 WebP**（广告=GIF 动图经 gif2webp）：dwebp 不支持动图，第一轮 backfill 全军覆没 colored=0/27 → 补 `webpmux -get frame 1` 首帧回退（ca-admin webpmux 1.5.0 实测）→ 27/27 全成。"已知不覆盖"项要估占比，占比=100% 就不是边缘 case。
- **★跨会话部署竞态实亏**：master 在本会话工作期间前进 3 个 merge（监控统一批3a/3b/4），03:55 我从旧基线 build 部署 web×6，把别会话 03:51 刚上线的 `FrontendMonitorMetrics` 抹了 ≈30 分钟（RUM 指标断流）。merge master 重部署恢复（`nw_monitor_*_5m` 36 序列=6指标×6节点 实证）。**教训：02:33 merge 过 master ≠ 部署时新鲜；每次 deploy-web/deploy-frontend 前必须 `git fetch` 再核对**（CLAUDE.md 既有铁律，违反实录）。admin 侧因先核对 symlink 时间线躲过第二发。
- **蓝军 BLOCKER 可复用 pattern：VO 加字段 × Redis 共享缓存 × rolling 混布 = 旧节点反序列化 500**。双保险：CacheConfig `FAIL_ON_UNKNOWN_PROPERTIES=false`（durable，惠及未来所有 VO 加字段）+ 新字段 `@JsonInclude(NON_NULL)`（未回填前序列化省略，窗口零风险）。
- **外部进程 readAllBytes 先于 waitFor = 超时保护失效**（挂起时读流先无限阻塞，Semaphore 耗尽即瘫痪）：重定向输出到文件 → waitFor(30s) → destroyForcibly。**注意 `SnackImageEncryptService.runProcess` 存在同款隐患（未修，可选 backlog）**。
- 主色算库路径：R2 加密件 → `AESUtil.decryptBytes(bytes, encrypt_ts)`（密钥按 ts 派生，**脚本侧复刻=密码学漂移，backfill 必须 Java 端点**，Owner 问过"脚本够不够"已答）；写库绕过常规保存必须自发 snack 缓存失效（版本号+pubsub），否则 web @Cacheable 24h 不可见。
- 生产 DDL：应用账号 `newworld` 无 ALTER 权限，走 ca-mysql-master 本机 `sudo mysql newworld`。
- 相关：[[reference-frontend-image-placeholder-lessons]] [[feedback-shared-master-race-push-reject]] [[project-cover-blurhash-placeholder-2026-06-29]]

## 未决/观察
- RUM LCP p75 数天趋势（真实收益验证）；admin 保存钩子首次真实触发观察（@Async 路径生产未演练，仅单测）。
- backfill 端点去留：Owner 说跑完可删可留待拍板（现保留，幂等+对齐 /ad-reencrypt-all 先例）。
- lint 工具链坑：frontend-web `npm run lint` 在 CLAUDE.md 上崩（vue 规则 × markdown），与代码无关，未修。

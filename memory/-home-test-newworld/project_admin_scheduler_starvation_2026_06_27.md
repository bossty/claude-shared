---
name: project_admin_scheduler_starvation_2026_06_27
description: 后台无今日用户数据=admin单线程@Scheduled被GfwProbe长轮饿死SiteStatsSyncTask;修spring.task.scheduling.pool.size=5;gfw+fix跨track部署(GFW admin不丢)
metadata:
  node_type: memory
  type: project
  originSessionId: 6eecae1c-95e0-4231-a84e-4ccc79979b6c
---

**症状**：管理后台没有今日(2026-06-27)用户数据。**非数据丢失**——web 正常采集(Redis 有 `stats:pv:20260627`)，是 admin→MySQL 同步被阻。

**根因(jcmd 实证)**：admin scheduler **默认单线程池**(Spring `@Scheduled` 不配 TaskScheduler=pool 1)。`scheduling-1` 卡在 `GfwProbeAggregator.runOnce` 80min(I/O 等待，探数百 S 域 ×~40s/个，单轮小时级)→ **饿死**每 5min 的 `SiteStatsSyncTask`(fixedRate 5min)→ 今日统计不入 site_daily_stats/channel_domain。06-26 能同步因 GfwProbe 3h 一轮、空窗期 sync 补上；06-27 恰好长轮卡住首同步窗口。诊断链:MySQL 今日 0 行/昨日3083 → Redis 有今日key(web在写) → journalctl SiteStatsSync 近1h 0次 → jcmd scheduling 线程=1 卡 GfwProbe。

**修**：`spring.task.scheduling.pool.size: 5`(admin application.yml)。各 @Scheduled 分到不同线程，GfwProbe 长轮只占 1/5；admin 各定时任务有独立分布式锁，并发安全。合 master `65ed44c6`。**实证**：部署后 SiteStatsSyncTask 立即跑(`同步2755维度成功2755/2755`)，今日 site_daily_stats 0→3050 行、PV 314万入库。scheduler 线程 1→5。

**跨 track 部署(GFW landmine 再现)**：现网 admin 跑**别会话 GFW-track jar `gfw8`**(含 S-entry GFW)。从 master build admin 会丢 GFW → 必 off **gfw** build。流程：worktree off `origin/gfw-breakthrough-arch`(别会话已推稳定HEAD,非本地半成品)+ 应用 fix → build → **解 jar 实证含 SEntryAdminController+GfwProbeAggregator(GFW不丢)+pool=5(带修复)** → 部署(jar 066f1a4a,回滚锚 gfw8)。fix 单独合 master(canonical)。配 [[project_master_degfw_deploy_baseline_2026_06_26]](master/gfw 分叉部署模型)。

**✅ 已闭环(2026-06-27 GFW track 会话)**：pool fix 已进 gfw 分支 —— `git merge origin/master` 进 `gfw-breakthrough-arch`(merge commit `1ee26253`,已 push origin)带入 `b6e43869` pool=5,gfw admin application.yml 现含 `scheduling.pool.size:5`。**用 merge 非 cherry-pick**(gfw 重建后 merge trap 已废止,见 [[project_master_degfw_deploy_baseline_2026_06_26]] 更新)→ 无重复 commit 漂移。**下次 gfw9 off gfw build admin 自带 fix,不会再饿死统计**。原"需 cherry-pick"作废。

**铁律**：admin/data 多个 @Scheduled(统计同步/渠道日报/域名池/证书轮转/GfwProbe)挤一根默认线程=I/O 长任务必饿死其它→新 admin 必配 `spring.task.scheduling.pool.size`(子目录 CLAUDE.md "新增@Scheduled必加@ConditionalOnProperty守卫"已有，补此池配置)。诊断"定时任务没跑"先 jcmd 看 scheduling 线程卡谁，非看代码。

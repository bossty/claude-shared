---
name: reference_deadcode_audit_sop
description: 死代码审计 SOP — 检测盲区(test/::/XML/@Deprecated)+ 误判根因(命名约定)+ 零故障删除流程
metadata: 
  node_type: memory
  type: reference
  originSessionId: e9a0d00d-b555-4e41-9d2b-12653de1f305
---

2026-06-15/17 全栈 master 死代码审计（团队 analyst×3+蓝军+lead 二查，只分析后 owner 逐项授权清）沉淀的 SOP。关联 [[reference_safe_branch_worktree_cleanup_protocol]]。

**"prod 零调用" ≠ "可删"——必查全调用面**：
- grep 调用方**必含 `/test/`**：方法可能 prod 零调用但被测试当**状态注入 helper**用（删→test 编译失败）。本次 `SiteStatsService.refreshValidChannelCodes` 就这么被 dev-senior 误删致 web `cannot find symbol`，lead 全量 `mvn test-compile` 才抓到、git 还原。
- **`...ForTest` 后缀 / javadoc "测试专用" = keep 标记**（测试支撑非死代码）。同类 setVisitorsShardEnabledForTest/setNewMetricsEnabledForTest 因带 ForTest 从没被误标；refreshValidChannelCodes 破约定(伪装成 prod 名)才落坑→已改名 `setValidChannelCodesForTest` 对齐(commit e9498dca)永久消除误判面。

**检测盲区(误报源,逐个必查)**：
- **`::method` 方法引用**(Map<String,Function> 注册表模式被 @Scheduled 调)：`.method(` 单一 grep 必漏。蓝军靠它救场——analyst 把 ChannelDailyReport retention 10 方法判死，实为 `ChannelReportTask` 用 `::findMissingRetentionD1` LIVE，删了=渠道留存管道炸。
- **`@Deprecated ≠ unused`**：`resolveExtForTranscode` @Deprecated 但被 LIVE 的 sniffExtFromMagicBytes 内部当 fallback 调(2处)→KEEP；`broadcastVisibility` 被 initClientCoord 内部调→KEEP。删前必查内部/`::`/反射调用方。
- **同名异类**：findByVid/findRecent 等多 Mapper 同名，按"接口.方法"精确判。
- MyBatis：删 mapper 方法**必连删对应 XML `<select|update id>`段**(孤儿 XML 不报错但是债)；注解式(@Select)无 XML。

**零故障删除流程**：删 ref/方法/资产不改 master 运行逻辑→低险；删前蓝军独立复核(禁采信 analyst 表)+lead 二查抽样`::`全扫；删后**必跑全模块 `mvn test-compile`(捕悬空)+ 真 `mvn test` + 前端 vite build** 才 commit；大批量交 dev-senior 执行但**lead 必全量二查(它会漏验/漏 test 引用)**。

**本轮结果(已 push)**：清 #1 source-rules.yml 归档·#2 VisitorAlias 簇·#3b markBlocked·#4+白名单 17死方法+12 XML+死资产·#5 2别名；**保留(误报/有意/LIVE)**：refreshValidChannelCodes(改名)·resolveExtForTranscode·broadcastVisibility·isRateLimited·getSnackBySlot(s)·bootstrap.min.css。审计档 `docs/sprint/2026-06-15-deadcode-audit/SYNTHESIS.md`。

**死表 DROP(收尾)**：删 mapper 代码后表仍在 prod，需 owner 拍板手工 DROP。**app DB 用户 `newworld` 只有 DML、无 DDL → DROP 报 `ERROR 1142 DROP command denied`**；DROP 必须在 DB 主机 `ca-mysql-master` 用 `sudo mysql`(root socket) 执行（预检/mysqldump 备份可用 app 用户从 ca-admin 连 DB_HOST）。顺序：先部署死代码清理 jar(去掉表访问者如 @Scheduled cron)→预检行数/last_seen 确认死→mysqldump 备份→root DROP→admin+web journalctl 验无 `table-not-found`/1146。visitor_alias 已于 2026-06-17 DROP。runbook=`docs/sprint/2026-06-15-deadcode-audit/RUNBOOK-drop-visitor-alias.md`。

**工具坑**：`pkill/pgrep -f <pattern>` 当 pattern 出现在自己命令行里会匹配并杀掉自身 shell(exit 144)——杀进程按 PID 或避开自匹配词。SSH 别名会被其他会话规范化(本会话 `aws-ca-admin`→`ca-admin`)，解析失败先查 `~/.ssh/config` 真别名别当环境故障；aws-* public IP 动态。

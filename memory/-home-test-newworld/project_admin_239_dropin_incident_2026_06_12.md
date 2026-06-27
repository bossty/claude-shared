---
name: project_admin_239_dropin_incident_2026_06_12
description: 2026-06-12 误建 systemd drop-in 把 admin 指向待退役只读 replica .239 致 DB 全断 9h；被 Phase D pre-flight 二查抓出
metadata: 
  node_type: memory
  type: project
  originSessionId: 64b5f5d1-9590-4971-9f5b-8d2e351a83eb
---

2026-06-12 OS 对齐工程期间，一个误建的 systemd drop-in 把 newworld-admin 静默切到错误 DB，导致 admin DB 全断约 9 小时（12:42→22:04）。

**根因**：`/etc/systemd/system/newworld-admin.service.d/datasource.conf`（mtime 12:41:59 今天误建）写 `DB_HOST=172.34.1.239`（待退役 CA 只读 replica）+ `REDIS_HOST=172.34.1.128`（CA redis），覆盖 base unit 正确的 HK `.174`。`.239` 上 `newworld` 用户**未授权** → `Access denied for user 'newworld'@'172.31.27.130'` → `Could not open JDBC Connection`，每 ~2s 一次（两小时窗 3575 条）。统计同步/渠道日报/健康检查/DNS 自动摘除全停 9h（admin 是 :8888 后台，非用户前台，无前台告警 → 静默）。

**为何误建**：admin 迁 CA 本应是 **Phase F（Phase D 之后）**且目标是**新 master .222**，绝不是待退役的 .239。多半是有人提前给 admin 试切 CA 但指错实例。误建文件已 mv 备份 `/root/datasource.conf.incident-20260612.bak` 留证。

**修复**：删 drop-in + daemon-reload + restart → 回退 base unit HK .174。二查实证恢复：实连 20×.174:3306 + 3×.174:6379 零 .239；`SiteStatsSyncTask 站点统计同步完成 成功 1383/1383` + `new_visitors 回填 写入 1347 维度` = 真写成功。

**Why**：这是被 Phase D pre-flight 新鲜只读二查抓出的——昨天的"就绪"不能直接拿来今天用。原 arch 只查 5 web 节点漏了 aws-data admin，arch-2 多查一层才抓到。

**How to apply**：① 改任何 prod 服务的 env/systemd drop-in 后，必 `systemctl show -p Environment` + **`ss -tnp` 看真实 generated 连接** + **业务写日志真成功**（配置对≠连接真切≠业务通，三层都验，见 [[feedback_master_cutover_incident]] 的"恢复验真功能"）。② admin/data 单实例后台服务故障无前台告警=静默盲区，cutover/迁移类工程后必主动扫 admin journalctl。③ 切 DB target 用 mv 不用 rm，留证追溯。④ 任何"指向某 DB"先确认该实例角色（master/replica/待退役）+ 该 app 用户在其上有授权。

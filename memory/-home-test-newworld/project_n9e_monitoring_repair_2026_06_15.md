---
name: project_n9e_monitoring_repair_2026_06_15
description: N9E 迁移后监控数据全面修复(dashboard label 未对应/缺失/多余 + 插件未装未上报)；迁移后监控三类病根 + 两个执行期 BLOCKER 自治解法 + BSP 团队方法论
metadata: 
  node_type: memory
  type: project
  originSessionId: 55b6c752-c743-48d4-9475-c0663cd54e40
---

2026-06-15 BSP 团队(dash-auditor 消费侧 / tsdb-auditor VM 真值 / plugin-auditor 主机侧 + 蓝军 + lead 二查 + ops-db/ops-cat 执行)修复 N9E 迁 CA 后监控数据。全程证据落盘 `docs/sprint/_archive/2026-06-15-n9e-monitoring-repair/`（CHARTER/GAP-MATRIX/FIX-PLAN/REPLICA-MONITORING-SPEC/EXEC-WAVE-SPEC/LOGROTATE-SPEC/CLOSURE）。

**★迁移后监控三类病根（通用，下次迁移先按这三类筛）**：
1. **未对应**=HK 时代 label 在新 VM 整类不存在 → dashboard/alert 引用它就整块空/聚合塌缩。本次：`application`(VM 只有 `service`=admin/data/web/edge/openresty，无 app/application)→board17+alert15/18/19；`group`(http_response 真实 label 是 `target`=edge-nginx/newworld-web-local)→alert1/50/51 **静默永不触发**；redis 变量 `instance`(两台同值 127.0.0.1:6379 无法区分)→改 `ident`；redis 指标名 redis_memory_used_bytes→`redis_used_memory`。
2. **多余**=orphan ident 僵尸 series(迁移前旧 host 名，无写入但 retention 内未过期)→无 ident 过滤的主机类告警对幽灵求值误报。本次删 aws-region-usw1-db/aws-web-01/nw-eu-db-replica（VM `/api/v1/admin/tsdb/delete_series?match[]=`）。
3. **未上报**=误配 scrape(克隆错模板/写错端口)。本次：eu-db-slave 是 web 模板克隆缺 input.mysql + 抓不存在的 :18080 actuator；cloudflared prometheus 端口写死 20241-3 实际 20252-4(7 台全错)；.bak 污染 conf 树。

**两个执行期 BLOCKER（自治解，无升级，详见 [[reference_n9e_dashboard_alert_internals]]）**：MySQL 8.4 移除 SHOW SLAVE STATUS / categraf v0.5.6 精简构建缺 ntp/x509_cert/nginx_log → 都用 `input.exec` 跑外部命令 emit prometheus、metric 名对齐现有 alert=零 alert 改动。

**安全项**：lead 实测监控机 SG 仅放 :22 公网，:80/:17000/:8428 仅内网 → 蓝军"全接口监听"被 SG 阻断不可外部利用；唯一公网路径=CF 隧道，owner 改强密码后定"维持现状"。

**Why**：迁移最隐蔽的不是服务挂，是监控静默失真——告警永不触发(group label 空)/dashboard 整块空(application 不存在)/对死主机误报，"监控不工作=用户先发现"是 3.25 级。
**How to apply**：① 改任何 dashboard/alert promql 前**先 curl VM 实测引用的 label/metric 真值**(group/application/instance 这类"看似存在"实则空或塌缩)；② 改完 alert 必验 `datasource_queries` 非 NULL(NULL=永不 eval)；③ lead 二查必抓 agent 误报(本次抓 plugin-auditor"web 缺 service=web"实为 Spring Micrometer 自带、蓝军"master 也开 gather_slave_status"实为 master 无 upstream 不需要)；④ owner 业务直觉双向 fact-check(owner"web 主日志非 access.log"对=web 用 web.log，但 edge 用 access.log 也对，各自正确)。关联 [[reference_n9e_ca_monitor_aws_access]] [[feedback_categraf_config_dir_globs_all]] [[project_rum_cardinality_fix_2026_06_14]] [[feedback_verify_not_recall]]。

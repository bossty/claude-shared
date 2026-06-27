---
name: project_admin_gauge_estimate_2026_06_25
description: ca-master MYSQL-SLOW-QUERY 告警根因=admin RetentionTableGaugeTask 每10min COUNT(*)冻结大表;改TABLE_ROWS估算+摘rum_image_load
metadata: 
  node_type: memory
  type: project
  originSessionId: 6eecae1c-95e0-4231-a84e-4ccc79979b6c
---

ca-mysql-master(.222 写主) `MYSQL-SLOW-QUERY` 告警(值21) RCA:master load 0.32 空闲、**不是容量问题**;一天 503 条慢查询全来自 ca-admin(172.34.1.34) 批处理,头号=`RetentionTableGaugeTask`(@Scheduled 每10min)对 **rum_image_load(已 2026-06-21 冻结,4400万行只读快照)** 做 `SELECT COUNT(*)`(EXPLAIN type=index key=idx_dpr 全索引扫 4400万行 ~5s × 143次/天)+ redirect_trace 同款 ~1.8s。javadoc 自称"走 idx_ts 不全扫"是错的。

**修(Owner 决策)**:① rum_image_load 从 gauge `RETENTION_TABLES` 整张摘除(冻结表膨胀监控无意义);② 行数 `COUNT(*)` → `information_schema.TABLES.TABLE_ROWS` 估算(查询亚毫秒不扫表;值受 information_schema_stats_expiry 默认 86400s 缓存最多滞后 ~24h,膨胀趋势告警数量级精度足够,迟报不漏报);bytes gauge 不变。commit 部署 ca-admin jar `20260625-130945-f36cc028`(基线 ab3d6be9=prod current.jar 非 master,admin cherry-pick 链),1884 test pass,蓝军 GO-with-fixes。

**蓝军实证排坑**:N9E 是否有规则引用该 gauge——查 ca-monitor n9e_v8 时 socket 连接被静默 auth denied(`n9e@localhost` vs 授权 `127.0.0.1`),`2>/dev/null` 吞错致"空结果"被误读"无规则";改 **TCP 连接**(`mysql -h 127.0.0.1 --protocol=TCP`)才拿到真数据(69 规则,0 条引用 gauge→移除零告警影响)。**单一信号源+吞错=假结论**。MySQL TABLE_ROWS 估算坑见蓝军 javadoc 补的 stats_expiry 说明。

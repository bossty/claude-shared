---
name: reference_timezone_hk_unification
description: newworld 全栈统一 HK 时区（2026-05-29）+ 存量数据 UTC/HK 混合的雷；DB 主机 aws-db-poc 时区配置位置
metadata: 
  node_type: memory
  type: reference
  originSessionId: 73e919fd-8c72-4aa2-8753-31dde1bdee8e
---

2026-05-29 owner 拍板「所有 OS / 库 / 项目统一香港时区」。根因：三层里只有 **MySQL 服务器（aws-db-poc, 172.31.19.174）OS=UTC 掉队**，导致 DB 默认 `created_at`(UTC) vs 应用 `LocalDateTime.now()`(HK) 差 8h（由 domain.purchased_at 上线暴露）。aws-data/web-01/web-02 OS+JVM 早已 HK；JDBC url 已 `serverTimezone=Asia/Hong_Kong`。

**已做（aws-db-poc，全程不重启、可回滚）**：
- OS：`sudo timedatectl set-timezone Asia/Hong_Kong`
- MySQL 运行时：`sudo mysql -e "SET GLOBAL time_zone='+08:00'"`（回滚 = SET 回 `SYSTEM`）
- 持久化：新建 `/etc/mysql/mysql.conf.d/99-timezone-hk.cnf` → `[mysqld]\ndefault-time-zone='+08:00'`（99 末位加载，不碰 `99-newworld-prod.cnf`）
- 验证：NOW()=HK / UTC_TIMESTAMP() 差 8h；admin/data/web×2 全 200；新建连接 `@@session.time_zone='+08:00'`

**DB 主机访问**：本地 `ssh aws-db-poc`（HostName 43.198.91.111 = 内网 172.31.19.174，User ubuntu，sudo=YES，root via auth_socket `sudo mysql`）。newworld 账号只有 `newworld.*` 库级权限，**不能 SET GLOBAL**。

**🔴 未尽雷（治本前提，勿盲改）**：
1. **存量数据 UTC/HK 混合**：tz 切换只管未来写入，不改已存 datetime 字面量。实证旧 `aws-db`(18.166.209.100) OS=HK、新 poc=UTC → pre-5/27 RESET restore 的 HK 字面量 + post-5/27 UTC 字面量混存。**盲目 +8h 改错一半**。含 154 个回填的 `domain.purchased_at`(=created_at UTC)。重写前必先按数据段审计真实 TZ。
2. **DATETIME vs TIMESTAMP 行为相反**：domain.created_at=datetime（字面量不动，需手工 +8h）；last_probe_at/retired_at=timestamp（内部 UTC epoch，按 session tz 读时自动转，不能再 +8h）。
3. **HikariCP split-brain（已收敛）**：5/29 23:44 SET GLOBAL 只影响新连接 → 审计实测各服务池回收节奏不同致 split-brain（web 写的列已翻 HK / admin 写的列仍 UTC，整点直方图 partial-hour web=23 vs admin=15 实证）。**已重启 admin+data 收敛（web 自然已翻），现全服务写 HK**。后果：cutover→收敛窗口的 DB-default 行 TZ 混合，**重写须用主键 id 边界，不能用时间边界**。
   完整取证报告：`docs/sprint/2026-05-29-tz-forensics/TZ-FORENSICS-REPORT.md`。
   待办：历史 UTC 段（5/27→收敛）DB-default datetime 逐表 id 边界 +8h（gated 低峰）；daily 聚合表 stat_date 是 DATE 业务日 8h 跨日归属需 owner 业务决策（禁简单 +8h）。
4. **监控栈未纳入**：aws-monitor N9E MySQL(n9e_v8)+categraf、buyvm-* 若要 HK 需另开。

关联：[[project_db_migration_2026_05_27.md]]（5/27 迁移到 UTC poc 是根因起点）

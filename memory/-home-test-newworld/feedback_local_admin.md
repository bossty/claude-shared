---
name: 本地 admin 禁用定时任务
description: 本地运行 admin 模块时必须禁用健康检查等定时任务，否则会干扰线上服务
type: feedback
---

本地运行 newworld-admin 时，因数据库从生产导入包含线上域名和服务器配置，定时任务（WebHealthCheckTask、DNS 自动摘除等）会误判线上服务异常并触发告警/操作。

**Why:** 2026-03-31 本地 admin 误报"所有 Web 实例异常"，差点摘除线上 DNS。

**How to apply:** 本地启动 admin 前，用环境变量或 profile 禁用定时任务：
- `mvn spring-boot:run -pl newworld-admin -Dspring-boot.run.arguments="--spring.task.scheduling.enabled=false"`
- 或在 application-dev.yml 中禁用相关 @Scheduled

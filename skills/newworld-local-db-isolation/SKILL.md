---
name: newworld-local-db-isolation
description: 本地测试环境禁连任何线上 DB（MySQL/Redis），必须 127.0.0.1；本地启动 admin/data 必须 --app.scheduling.enabled=false 否则定时任务会误操作生产。Triggers on 本地, 127.0.0.1, 线上 DB, 生产 DB, scheduling.enabled, 定时任务, dev profile, 172.34.1.222, 172.33.8.248, 172.34.1.128, local dev.
---

> **执行机制**：无自动闸门，靠判断力（本地只连 127.0.0.1、禁连生产 DB/Redis IP、admin/data 必带 --app.scheduling.enabled=false）；hook 化拦 prod DB 连接列 future BL

# Newworld 本地测试环境隔离铁律

## 触发场景
- 本地起 newworld-admin / newworld-data / newworld-web
- 修改 `application.yml` / `application-dev.yml` 的 DB / Redis 连接
- 写 IT / smoke 脚本带 spring.datasource.url / spring.redis.host

## 铁律：本地禁连线上 DB
1. **本地只连本机 `127.0.0.1` 的 MySQL 和 Redis**
2. **禁止**通过命令行参数、环境变量、配置文件覆盖等任何方式将本地服务连接到生产 DB
   - 生产 MySQL master（终态 CA）：`172.34.1.222`（ca-mysql-master）
   - 生产 MySQL replica（EU）：`172.33.8.248`（eu-mysql-slave）
   - 生产 Redis master（终态 CA）：`172.34.1.128`（ca-redis-master）
   - 旧退役 IP（一并禁）：`172.31.27.200`、`18.166.209.100`（aws-db-poc HK，已 terminate）
   - 任何指向以上 IP 的 jdbc URL / redis host 立即拒绝

## 铁律：本地运行 admin/data 必须禁定时任务
```bash
# admin（否则健康检查会误触线上告警）
java -jar newworld-admin/target/newworld-admin-0.0.1-SNAPSHOT.jar --app.scheduling.enabled=false

# data（否则推荐采集等任务会执行）
java -jar newworld-data/target/newworld-data-0.0.1-SNAPSHOT.jar --app.scheduling.enabled=false
```

## 检查清单
- [ ] `application-dev.yml` jdbc URL 含 `127.0.0.1` 或 `localhost`
- [ ] redis host 含 `127.0.0.1` 或 `localhost`
- [ ] grep `172.34.1.222|172.33.8.248|172.34.1.128|172.31.27.200|18.166.209.100` 在本地 dev 配置 → 0 命中
- [ ] 启动命令含 `--app.scheduling.enabled=false`（admin/data）

## 违反后果

- **本地 jdbc URL 指向生产 IP**：本地 IT 测试 / 数据修复脚本误删生产业务表行，**线上业务直接受损**
- **本地 admin 连生产 + 定时任务未禁** → DNS 自动摘除 / 健康检查 / 渠道日报触达生产 API + Telegram 告警
- **本地 data 连生产 + 定时任务未禁** → 推荐采集 / 爬虫任务误写生产 movie 表
- **本地 redis host 指向生产** → 缓存键空间污染，统计计数错乱（site_daily_stats / channel_daily_report 失真）
- 上述任一项 = **3.25 级事故**强制复盘，且需 DBA 全面 audit 生产数据完整性

## 源
- CLAUDE.md L341-L357
- 配套文档 `docs/infra/LOCAL_DEV_ENVIRONMENT.md`

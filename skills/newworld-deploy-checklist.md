---
name: newworld-deploy-checklist
description: 后端部署前必查四项 — sql migration 已在生产 DB 跑、PageHelper LIMIT 已 prod profile 真跑、新启动函数已在 main.js/@PostConstruct 注册调用、schema 分区变更走 DBA 审批。少一项 = 3.25 级事故。Triggers on 部署, sql migration, schema, PageHelper, prod profile, 启动函数, @PostConstruct, schema 分区, w3_q4, deploy 前, pre-deploy.
---

# Newworld 后端部署前必查四项

## 触发场景
任何后端代码 commit 涉及：sql/ 目录新文件 / Mapper LIMIT 改动 / main.js 或 Application 新增初始化函数 / 表结构 RENAME / 分区改造。**部署前**必须按四项逐条核对，少一项 = 3.25 级事故复盘。

## 铁律

### 1. sql/ 目录里新 migration 全部在生产 DB 执行
- 任何含 `sql/*.sql` 新文件的 commit，部署**后端代码之前**先在 aws-db 跑 SQL
- 漏跑后果：新代码引用不存在的表/列 → 生产 500 雪崩
- 验证：`ssh aws-db 'mysql -e "DESCRIBE <new_table>"'` 表结构必须存在
- 事故案例：TP-01（`promotion_channel_domain` 表没建 → 1h 内 web-01 30K+ errors）

### 2. 用 PageHelper 的 Mapper 改 LIMIT 必须 prod profile 真跑
- PageHelper 自动注入 `LIMIT ? OFFSET ?`，MyBatis XML **不能再手写 LIMIT**
- dev profile mock 不暴露双 LIMIT
- 验证：本地起 `--spring.profiles.active=prod` + 连本地 mysql prod 镜像 + curl 触发查询，日志 "SQL:" 只有一个 LIMIT
- 事故案例：P1-3（`findAllLatestMovies ... LIMIT #{limit}` + PageHelper → `LIMIT 1000 LIMIT 20` 语法错）

### 3. 新加的启动期函数必须真调用
- 定义 `export function initXxx()` 不等于会执行；必须在 main.js / `@PostConstruct` / Spring Bean 真 import + 调用
- 漏注册后果：代码上线但行为不生效
- 验证：`grep -rn "initXxx" src/` 必须在 main.js / 启动链路文件命中 import + 调用
- 事故案例：Sprint 1 TP-02（`initFirstVisitDate()` 定义 25h 但从未被调用 → 灰度 25h 空数据）

### 4. Schema 分区变更必须人工执行
- `sql/w3_q4_*` / `sql/*partition*` 等表结构重建 / RENAME / 分区改造的 SQL，**不得自动化执行**
- 必须遵循对应操作手册（如 `docs/W3_Q4_VISITOR_FP_PARTITION.md`）由 DBA / 值班运维逐步执行
- 前置依赖（如应用层 upsert 语义改造）未完成时禁止执行
- 验证：部署前 `git grep 'partition' sql/` 命中 → 停自动部署，走 DBA 审批
- 事故案例：W3 Q4（PK 从 `visitor_id` 变 `(visitor_id, first_seen)` 后 ON DUPLICATE KEY 语义变化 → visit_count 永不累加）

### 5. SQL migration 实际跑了（强制 sprint CHANGELOG sql diff 必查）
- sprint closure / 部署前**强制**列出 sprint 内 sql 变更：
  ```bash
  git log --since=<sprint-start> --name-only -- 'sql/*.sql' | sort -u
  ```
- 每个文件必须配套**部署执行日志**（aws-db `mysql < file.sql` 输出）或显式 DBA-gated 抑制（写入 `docs/security/audit-suppressions.md`）
- 漏跑表面现象：mvn test 全 pass / 代码 review 过 / 部署成功；真实后果：MyBatis SELECT 报 `Unknown column` / `Table doesn't exist`，scheduler 每 tick 报错
- 5/7 一周内三起同种违反（合并教训）：
  - **V5 sprint** — `rum_image_load` 表新建未跑
  - **W3-A4 sprint** — `movie_tag.description` 加列未跑
  - **W4 sprint** — `silver_user_behavior` + `dispute_queue` 表新建未跑
- 配套防御见 `newworld-schema-consistency` skill（启动期 SchemaConsistencyValidator + MP 字段命名 CI + deploy script 自动 grep）

## 违反后果
少一项 = **3.25** 级事故复盘，sprint 末必须文档化。

## 源
- CLAUDE.md L138-L160
- 关联：`newworld-schema-consistency`（5/7 三起教训沉淀）

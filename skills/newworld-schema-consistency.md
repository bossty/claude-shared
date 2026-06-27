---
name: newworld-schema-consistency
description: entity vs DB schema 一致性 + SQL migration 漏跑防再发（2026-05-07 教训）。Triggers on SQL migration, schema diff, entity 字段, @TableField, Unknown column, Table doesn't exist, SchemaConsistencyValidator, MyBatis Plus 字段命名, camelToSnake 数字字段.
---

# entity vs DB Schema 一致性铁律

2026-05-07 一周 3 起同种 deploy-checklist 违反（V5 / W3-A4 / W4 sprint）。本 skill 是 `newworld-deploy-checklist` 第 5 项的展开 + 系统性防御。

## 真根因

sprint 改 entity 加字段（or 加新 table），但 deploy 漏跑对应 SQL migration。

- **表面**：mvn test pass（H2/Mock 不连真 DB）/ 代码 review 过 / 部署成功（Spring 启动不强校验 schema）
- **真相**：prod DB 缺 column / table → MyBatis `SELECT t.*` / `@TableName` CRUD ERROR / scheduler 每 tick 报错刷屏

## 5/7 三起复盘

| Sprint | 表 / 列 | 表面 | 真相 |
|--------|---------|------|------|
| V5 | `rum_image_load` 新表 | 部署成功 | INSERT 报 `Table doesn't exist`，前端 RUM 上报 500 |
| W3-A4 | `movie_tag.description` 新列 | 部署成功 | SELECT * 返回 OK 但写入 NPE（MP 不抛错只 silent skip） |
| W4 | `silver_user_behavior` + `dispute_queue` 新表 | 部署成功 | scheduler 每 tick 报 `Table doesn't exist` |

## 4 层防御

### 1. CHANGELOG enforce（人工 gate，sprint 末）

sprint CHANGELOG 必须列：

```bash
git log --since=<sprint-start> --name-only -- 'sql/*.sql' | sort -u
```

每个文件附**执行证据**（aws-db `mysql < file.sql` 日志 or 显式 DBA-gated 抑制）。否则 closure 拒绝。

### 2. SchemaConsistencyValidator（启动期 gate，dev/staging）

admin 启动期跑：

- 扫所有 `@TableName` entity（含 MyBatis Plus + 自定义）
- 与 `information_schema.COLUMNS` 对比
- 任何 entity 字段（除 `@TableField(exist = false)`）DB 不存在 → 启动失败 + log clear msg：
  ```
  Schema mismatch: entity=Movie field=newCol -> DB column movie.new_col MISSING
  ```
- **prod 不开**（防止启动失败影响线上），dev/staging 强制开（profile gate）
- 实现位置参考：`newworld-admin/src/main/java/.../config/SchemaConsistencyValidator.java`（待建）

### 3. MP 字段命名 CI gate（编译期）

entity 字段含数字（如 `certCount28d`）必须显式 `@TableField("snake_with_underscore")`，否则 CI 拒绝。

**原因**：MP 默认 `camelToUnderline` 对数字边界不一致：
- 期望 DB 列：`cert_count_28d`
- MP 实际推导：`cert_count28d`（数字前不加下划线）
- → `Unknown column 'cert_count28d'`

CI 检测脚本（伪代码）：
```bash
grep -rn 'private.*[a-z][0-9]' newworld-*/src/main/java/.../entity/ \
  | grep -v '@TableField' \
  && exit 1
```

### 4. Deploy script enforce（自动化 gate）

`/newworld/scripts/deploy-backend.sh` 加 SQL migration 校验：

```bash
last_deploy=$(git tag -l 'deploy-*' | tail -1)
new_sqls=$(git log --since="$last_deploy" --name-only -- 'sql/*.sql' | sort -u)
if [ -n "$new_sqls" ]; then
  echo "=== SQL migrations since $last_deploy ==="
  echo "$new_sqls"
  echo "Confirm all executed? [y/N]"
  read confirm
  [ "$confirm" = "y" ] || exit 1
fi
```

## 修复 fast track

当生产 SQL ERROR `Unknown column XXX` / `Table XXX doesn't exist`：

1. `grep -rn 'XXX' newworld-*/src/main/java/.../entity/`  定位 entity 字段
2. `git log --all --name-only -- 'sql/*.sql' | xargs grep -l XXX`  找对应 sql migration
3. ssh aws-db → 备份 schema dump（`mysqldump --no-data newworld > /tmp/schema-bk.sql`）→ `mysql newworld < migration.sql`
4. 5 min 内 `journalctl -u newworld-admin -n 200 | grep ERROR | wc -l = 0` 实证止血

## 关联

- `newworld-deploy-checklist` 第 5 项（本 skill 是其系统性展开）
- `newworld-deploy-runbook`
- `newworld-multi-agent-coord`（schema 变更必走 multi-agent）
- `docs/audit-suppressions.md`（DBA-gated 例外抑制清单）

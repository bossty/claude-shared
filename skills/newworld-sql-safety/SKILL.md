---
name: newworld-sql-safety
description: SQL 性能与事务安全 + SQL seed 占位规范 — DBA benchmark 强制（结构变更必跑 5 movieId × 3 中位数 + 质量 diff，估算偏差可达 10x）；PageHelper 注入 LIMIT 时 XML 不得手写 LIMIT，必须 prod profile 真跑验证；大批量预计算（>1000 条）禁用方法级 @Transactional(readOnly=true) 长事务（Hikari 连接 hold 死、MyBatis Executor 累积 OOM）；SQL seed 文件中 IP/UUID/secret/token/外部 ID 字段必须用显式 sentinel（TODO_FILL_HERE / REPLACE_ME_BEFORE_DEPLOY / NULL），禁"看似正常"假值占位，pre-flight 必 grep 阻止部署。职责边界：本 skill 只覆盖 SQL 层；批量 OOM 与 backfill 覆盖率走 newworld-batch-backfill；部署对账走 newworld-deploy-checklist。Triggers on sql benchmark, dba benchmark, explain, EXPLAIN FORMAT=TREE, 中位数, 质量 diff, PageHelper, 双 LIMIT, prod profile sql, mybatis xml limit, 长事务, @Transactional readOnly, hikari connection, seed, 占位值, todo_fill_here, replace_me, sentinel, sql seed, fake placeholder.
---


# Newworld SQL 性能与事务安全铁律

## 触发场景
- 改 MyBatis XML / mapper 加 `LIMIT` / `ORDER BY` / 子查询
- SQL 结构变更（UNION / JOIN / 子查询改写）
- 写大批量预计算任务（推荐 / 统计聚合 / 热度刷新等 >1000 条记录）
- 改 Service 方法的 `@Transactional` 范围或 `readOnly` 标注

## 1. SQL 优化必须 DBA benchmark

**背景**：sprint 中 P9 估 baseline 8-9s（看 slow log）实测 614ms；估 Plan ③ "220ms" 实测 70ms。靠估算决策 = 盲决策。

铁律：
1. **结构变更（UNION/JOIN/LIMIT/子查询改写）必跑 DBA benchmark 流程**：
   - 5 个代表性 movieId × 3 次取中位数（不同热度 + 不同 tag 规模）
   - Baseline + 候选方案（≥2 种）全跑
   - `EXPLAIN FORMAT=TREE` + `Rows_examined`
   - 质量对比（Top K 结果 diff）
2. **P9 估算只能当方向参考**：slow log 的 8s 可能是并发 + cold cache 组合，稳态可能好 10x
3. **质量 diff 比性能 diff 更重要**：如 `ORDER BY movie_id DESC` 会让老片整体降级；只看 p50/p95 看不出
4. **DBA benchmark 报告必须入档**：`docs/recon/p7_dba_*_benchmark_report.md`

## 2. PageHelper 双 LIMIT 陷阱

**背景**：`findAllLatestMovies ... LIMIT #{limit}` + PageHelper 自动注入 → SQL 变 `LIMIT 1000 LIMIT 20` 语法错（P1-3 事故）。

铁律：
- **PageHelper 会在 SQL 前自动注入 `LIMIT ? OFFSET ?`**，MyBatis XML **禁手写 LIMIT**
- 本地 dev profile 的 mock/测试**不足以暴露**双 LIMIT
- 验证：本地起 `--spring.profiles.active=prod` + 连本地 MySQL prod 镜像 + curl 触发查询，看日志 `SQL:` 行只有一个 LIMIT

## 3. 批量预计算长事务禁用 readOnly（事务层）

**背景**：相关推荐紧急全量预计算（31,409 部）两次 OOM（cgroup oom-kill + heap OOM），根因之一为方法级 `@Transactional(readOnly=true)` 长事务。

**SQL/事务层铁律**：
- 大批量预计算方法**禁用** `@Transactional(readOnly=true)`（长事务 hold Hikari connection 不释放 + MyBatis Executor cache 累积 → heap 不可回收）
- 改走独立短事务：每个 mapper 调用幂等 read + Redis write，不跨部事务一致性

**JVM / 批处理层关切（分批 500 / 禁 vthread 方案 A / systemd MemoryMax + Xmx 双限）→ 详见 `newworld-batch-oom` skill**，本 skill 不重复维护，避免双方漂移。

## 检查清单
- [ ] SQL 结构变更 PR 附 DBA benchmark 报告（5×3 中位数 + Top K diff）
- [ ] MyBatis XML grep `LIMIT` → 0 命中（PageHelper 用法）
- [ ] 批量预计算方法**无** `@Transactional(readOnly=true)`
- [ ] 批量预计算单批 ≤ 500 + 显式 `batch.clear()` 释放
- [ ] systemd drop-in `memory.conf` 配 MemoryMax + Xmx 双限

## 违反后果
- 跳过 DBA benchmark 上线优化 SQL → 用户流量做 A/B，质量降级（如老片整体下沉）2-3 天才发现
- MyBatis XML 漏删 LIMIT → 生产 SQL 语法错 / 数据不全（P1-3 事故）
- 批量预计算 readOnly 长事务 → cgroup oom-kill / heap OOM，systemctl 假活跑空（2 次 OOM 历史教训）
- 用单纯 `Xmx` 调大绕过分批 → 治标不治本，数据规模翻倍后必挂
- 上述任一项 = **3.25 级别**复盘

## 源
- CLAUDE.md L138-L160（PageHelper / 部署前必查四项）
- CLAUDE.md L715-L751（批量预计算 OOM）
- CLAUDE.md L800-L822（DBA benchmark）

---

> ⬇️ **以下并入自 `newworld-sql-seed-sentinel`（2026-07-03 skill 合并，原档已删；触发词已并入本 skill description）**


# Newworld SQL seed 占位值铁律（2026-04-22 事故硬化）

## 触发场景
- 编写 / 修改 `sql/v*_seed_*.sql` / `sql/init_*.sql` / 任何含 INSERT 真实业务数据的 SQL
- 字段含 IP / IPv6 / UUID / secret / token / 外部 ID（CF zone_id / NameSilo id / 运营商 tunnel_id / 百度 siteId）

## 铁律

### 1. 禁止"看起来正常但可能错"的占位
反例：`1.2.3.4` / `2406:da14::1` / `a1b2c3...` / `00000000-0000-0000-0000-000000000000`——这些会被生产代码读取并真正使用，**应用层无法 fail-fast**。

### 2. 必须用显式 sentinel
- `TODO_FILL_HERE`
- `REPLACE_ME_BEFORE_DEPLOY`
- `NULL`（如字段 nullable）

### 3. Pre-flight 阻止部署
部署前脚本必须跑：
```bash
grep -rE "TODO_FILL_HERE|REPLACE_ME_BEFORE_DEPLOY" sql/ newworld-admin/src/main/resources/
# 命中任何一处 → 阻止部署
```

### 4. 真实身份字段查原始数据，不凭记忆
edge VPS IP / CF zone_id / 百度 siteId / 运营商 tunnel_id 等涉及外部真实身份的字段，seed 时查现有生产值或 Owner 原始数据，**不凭记忆 / 缩写**。

## 违反后果
按 **3.25** 级别处理。

## 事故案例
commit `cec44e4e`（2026-04-22）：在 `sql/v33_seed_edge_vps_config.sql` 给 aws-s 的 ipv6 写"看起来正常"的 `2406:da14::1`（真值 `2406:da1e:981:5d1:5ac7:6ad0:d41e:fade`）→ 部署链直接写入 `system_config.EDGE_VPS_LIST` → dns-failover-agent 读假值探活失败 → **Agent 误删 CF 5 条 aws-s A record**（Telegram 告警）。

## 源
- CLAUDE.md L504-L520

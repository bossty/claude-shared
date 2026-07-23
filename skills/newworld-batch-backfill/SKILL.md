---
name: newworld-batch-backfill
description: 大批量（≥1000 条）预计算/backfill 双铁律：①OOM 防护——方法级禁 @Transactional(readOnly=true)、单批 500、systemd MemoryMax + JVM Xmx 双限、入库走 Redis Set 队列消费而非每条 startVirtualThread，禁止单纯调大 Xmx 绕过；②真覆盖率——multi-key sentinel + DB live 抽样源验证 backfill 真实覆盖（V5 教训），禁以"脚本跑完"当"覆盖完"。Triggers on 批量, oom, batch_size, vthread, 全量, 预计算, 扫描所有, 全量预计算, @Scheduled, computeFor, processAll, batch processing, oom-kill, OutOfMemoryError, 大批量, java heap, backfill, 回填, 覆盖率, multi-key sentinel, 抽样验证.
---

> **执行机制**：半机制——OOM 靠 systemd MemoryMax+JVM Xmx 双限，backfill 覆盖率靠判断力（multi-key sentinel+DB 抽样）

# Newworld batch-backfill（2026-07-03 由 newworld-batch-oom + newworld-backfill-coverage 合并而成）

---

> ⬇️ **以下并入自 `newworld-batch-oom`（2026-07-03 skill 合并，原档已删；触发词已并入本 skill description）**


# Newworld 批量预计算防 OOM 铁律（2026-04-23 两次 OOM 事故硬化）

## 触发场景
所有大批量预计算：**>1000 条记录**的扫描 / 重算 / 推荐计算 / 数据迁移 / hot stats 全量重建。

## 铁律

### 1. 方法级禁用 `@Transactional(readOnly=true)`
- 长事务 hold Hikari connection 整个任务期不释放
- MyBatis Executor cache / 游标累积 → heap 不可回收
- 每部独立的幂等 read + Redis write，不需跨部事务一致性
- **正确做法**：去掉方法级 `@Transactional`，让每个 mapper 调用走独立短事务

### 2. 分批处理（单批 500 条）
```java
for (int batchStart = 0; batchStart < totalSize; batchStart += BATCH_SIZE) {
    List<Integer> batch = new ArrayList<>(ids.subList(batchStart, batchEnd));  // 浅拷贝释放原引用
    for (Integer id : batch) { ... }
    batch.clear(); batch = null;
    System.gc();  // 批次级强 hint
}
```

### 3. 禁用"每条 startVirtualThread"方案
爬虫批量入库时会瞬间几十个 vthread 并发打 MySQL + 堆内存。**正确**：
- 爬虫入库后 `stringRedisTemplate.opsForSet().add("recompute:pending", id)` 入 Redis Set
- 独立 `@Scheduled(fixedDelay=120s)` Consumer `SPOP 500` 批量消费
- 天然节流，不打爆 SQL，重启不丢队列

### 4. systemd MemoryMax + JVM Xmx 双限
- 单实例服务器（8GB RAM）建议 `MemoryMax=4G + Xmx=3g`（留 OS 余量 + 堆外）
- 通过 `/etc/systemd/system/<service>.service.d/memory.conf` drop-in
- 代码分批是第一防线，systemd 限额是最后防线

## 违反后果
按 **3.25** 级别。**禁止用单纯 `Xmx` 调大绕过**——治标不治本，数据规模翻倍后必挂。

## 事故案例
2026-04-23 相关推荐紧急全量预计算（31,409 部电影）两次 OOM：
- 03:33 `oom-kill`（systemd MemoryMax=2.4G 被 cgroup 杀）
- 17:51 `java.lang.OutOfMemoryError: Java heap space`（Xmx=3g 仍爆）

## 源
- CLAUDE.md L715-L751

---

> ⬇️ **以下并入自 `newworld-backfill-coverage`（2026-07-03 skill 合并，原档已删；触发词已并入本 skill description）**


# Backfill 真覆盖率铁律

V5 sprint（2026-05-04）暴露 2 个 backfill 真技术债，未来 backfill 必踩坑。

## 1. Preflight Sentinel 必须 multi-key 验证

### 反例
V5.C backfill 用单 key sentinel：
- HEAD `{id}a.js` + 含 `v5-encoder` metadata tag → 视为已完成 skip

### 故障
movie ID 50489 a.js 写完（带 v5-encoder tag）但 b/c/d/e/bare 写入失败。后续 resume 时 preflight 看 a.js 已完成 → **永久 skip**，b/c/d/e/bare 永远不补。

### 正确做法

**任一**：
- HEAD 所有目标 keys（如 V5 cover 11 个全 HEAD）
- 或 metadata 加最后一档 sentinel：`v5-complete=true` 仅在所有档写完后 PUT 到最后一个 key
- 或单独维护 commit log（每 movie 完成全档后才标 done）

V5 修复方案：sed 副本 `v5_backfill_force.py` 把 `_check_v5_done → False` 强制重做。

## 2. Backfill Input TSV 不能静态过期

### 反例
V5.C 用 `/tmp/full_backfill_movies.tsv`（V3 时代生成 31659 行）。抽样脚本基于同一 TSV 抽 200 random：100% pass 看似 OK。

### 故障
movie ID >= 63342 共 12 个新爬 movies 在 V5.C TSV snapshot 之后入库 →
- backfill 不处理（不在 TSV 范围）
- 抽样不验证（基于同一 TSV）
- e2e 真测时浏览器加载新 movie → R2 404 broken image

抽样和 backfill **自洽 fallacy**：用同一 TSV 不可能发现 gap。

### 正确做法

**抽样源必须是 DB live**：
```bash
mysql ... -e "SELECT id FROM movie WHERE status >= 0" > /tmp/v5_all_ids.txt
```

**Cutover 前 diff R2 实际 keys**：
```bash
# 全量 HEAD 验证 R2 实际写入
python3 v5_full_coverage.py  # DB ids × 关键 keys = 真覆盖率
broken_total = 0  # gate
```

**Backfill input 应每次实时 dump DB**，或验证 TSV count = DB count（误差 < 0.1%）。

## 部署 gate（必查）

部署 V5 前：
1. ✅ 抽样源 = DB live data（不是 backfill TSV）
2. ✅ 全量 HEAD `broken_total = 0`（小项目）或 RUM 监控真用户 404 < 0.1%（大项目）
3. ✅ Preflight sentinel 是 multi-key 或 last-key 标记

## 关联 skill
- `newworld-batch-oom` — 大批量预计算分批 + readOnly + Redis 节流
- `newworld-deploy-runbook` — 部署前必查四项（2026-07-23 由 checklist 并入）
- `newworld-multi-agent-coord` — 跨服务部署铁律

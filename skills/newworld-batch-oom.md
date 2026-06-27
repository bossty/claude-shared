---
name: newworld-batch-oom
description: ≥1000 条记录批量预计算必须 — 方法级禁 @Transactional(readOnly=true)、单批 500、systemd MemoryMax + JVM Xmx 双限、入库走 Redis Set 队列消费而非每条 startVirtualThread。禁止用单纯 Xmx 调大绕过。Triggers on 批量, oom, batch_size, vthread, 全量, 预计算, 扫描所有, 全量预计算, @Scheduled, computeFor, processAll, batch processing, oom-kill, OutOfMemoryError, 大批量, java heap.
---

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

---
name: newworld-backfill-coverage
description: 大批量预计算 backfill 真覆盖率铁律（V5 sprint 教训）
triggers:
  - backfill 抽样
  - 全量验证
  - preflight sentinel
  - cutover snapshot
  - 真覆盖率
---

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
- `newworld-deploy-checklist` — 部署前必查四项
- `newworld-multi-agent-coord` — 跨服务部署铁律

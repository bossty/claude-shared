---
name: project-v6-cluster-root-idx-hotfix-5-12
description: 5/12 18:33-18:50 紧急止血 — vid_alias_log 缺 idx_vid_merged 让 VidClusterRootResolver 慢 SQL 打爆 HikariCP 80/80
metadata: 
  node_type: memory
  type: project
  originSessionId: b2187ab6-4c03-4c80-b561-f114570e7bc2
---

5/12 18:33 起 nginx upstream timed out 飙升（18:41 peak 383/min）。Frontend
"正在搜索可用线路 / 切换线路" 频繁触发。

**误判路径**：F2 sprint 17:33-18:10 ship（commits 06ffe403 / 14bd2ad5 / 76ae5e37 +
CF cache rule 10 zones），timeout 飙升时间窗口接近，第一反应怀疑 F2 cold cache
回源打 backend。

**真相**：5/12 上午 ba81f79d V6 cluster_root sprint 引入 VidClusterRootResolver
双层 COALESCE SQL — `SELECT alias_root FROM vid_metadata WHERE vid=X` 走 PK 没问题，
但 `SELECT cluster_root FROM vid_alias_log WHERE vid=X ORDER BY merged_at DESC LIMIT 1`
缺 vid 列索引，EXPLAIN `key=idx_merged + Backward index scan` 全表反扫 232k 行。
单 query 30s+，并发 ~100 QPS 累 → HikariCP 80 conn 全占 + 40 waiting → stats
写接口 (analytics/hit 1743 / session 617 / quality 41 / promotions/track 73) 全 timeout。

**Why:** newworld-schema-consistency skill 经典案例 — entity 加查询但 SQL migration
漏建索引；表小 + 单 host 测试 EXPLAIN 走 PK 不会暴露慢；放到 prod 100k+ 行 + 并发
就爆。当时 ba81f79d 关注 cluster_root 写路径 + UV HLL 正确性，把读路径 fallback 索引
当 nice-to-have 忽略。

**How to apply:**
- 类似事件诊断顺序：HikariCP 满 → mysql PROCESSLIST 找 TIME > 5 query → EXPLAIN
  关键 SQL → 缺索引一目了然
- 新 SQL query 走非 PK 字段必须 EXPLAIN 验 type=ref/range 不是 index/ALL；尤其
  ORDER BY + LIMIT 1 容易被 MySQL 优化器误选 ORDER BY index 反扫
- ADD INDEX 选 ALGORITHM=INPLACE LOCK=NONE 紧急止血秒级生效
- backup DB（buyvm-db）schema 变更**不自动同步**，需 manual 跑 SQL migration

修复 commit: 71083f79 `sql/2026_05_12_vid_alias_log_idx_vid_merged.sql`
恢复指标: HikariCP active 80→0 / analytics/hit 8s timeout→2.8ms / nginx timeout 383→9/min

相关：[[project_v6_cluster_root_sprint_5_12]] 主 sprint 文档需补充此 hotfix 教训

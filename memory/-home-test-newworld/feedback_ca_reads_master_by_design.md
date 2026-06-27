---
name: feedback_ca_reads_master_by_design
description: CA web 读 master 是终态架构 B 的正确设计（CA 无 slave，replica 在 EU），别当读写不分离缺陷报
metadata: 
  node_type: memory
  type: feedback
  originSessionId: e154dcd7-4e73-48df-ae60-a425412b5fbf
---

CA region **只有 master（ca-mysql-master 172.34.1.222），没有独立 slave**；唯一 replica 在法兰克福（eu-mysql-slave）。所以 CA web 的 read 池 / slave drop-in URL 指向 `.222`（=master 本身）是**有意为之、就近读本地主库**（同 region 低延迟），**不是配置缺陷、不是"读写不分离漏配"**。EU web 才读本地 replica。

**Why:** Owner 已纠正多次（"CA读master是合理设计，说了多少遍了，CA没有slave"，2026-06-21 缓存/慢查询审计）。把它当缺陷报会一错再错、惹 Owner（"说了多少遍了"）。

**How to apply:**
- 看到 CA web datasource 的 read 池指向 .222 → 这是对的，别"发现读写不分离"。
- master perf_schema digest 能代表用户读负载，恰恰**因为** CA 主 region 读本就落本地 master——是审计的权威源，是好事。
- 真要提的相关项（如 `useLocalSessionState=true` 缺失致 4806 万次 `SELECT @@SESSION.transaction_read_only` 探针）归因为"JDBC 多余往返、无论落哪台 DB 都浪费"，**不要**归因为"探针错误地落在写主库"。

参见 [[project_terminal_arch_B_single_california_2026_06_10]]（终态=加州 master+web×3 / 法兰克福 web×2+replica）。

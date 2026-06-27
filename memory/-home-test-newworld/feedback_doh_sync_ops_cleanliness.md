---
name: feedback_doh_sync_ops_cleanliness
description: DoH TXT迁移运维清洁度:重启前确认无在途sync/用clean re-sync不PATCH+DELETE churn/ttl=auto
metadata: 
  node_type: memory
  type: feedback
  originSessionId: c26c2e1f-72a4-463f-8370-aeecffd81acf
---

DoH 池迁移到 np1 多记录时的运维操作清洁度教训（2026-06-18，lead 自省）。

**Why**：迁移过程我操作绕了：
- 改 ttl 后**重启 admin 时打断了一次在途 syncDohTxtRecords**（写了 1 片就被 kill，prune 没跑）→ 每域留一个孤儿不完整 chunk（BLOCKER-2 撕裂读保护让旧完整版存活，前端全程没坏，但留 cruft）。
- 我用 **40 次 PATCH（改 ttl）+ 10 次 DELETE（清孤儿）** 的手工 churn 清理 → 短时间大量改 TXT RRset → **AliDNS 多 POP 缓存抖动**，收敛慢（4→7→8/10，单次 query 撞 lagging POP 假阴）。

**How to apply**：
- 重启 admin / 改动前**确认无在途 sync**（看 `journalctl -u newworld-admin | grep "DoH P1"`）；admin 单实例，重启会 kill 在途任务。
- 批量改 DoH TXT 用**一次 clean re-sync**（让新代码一次写完整版 + prune 旧）代替 PATCH+DELETE 手工 churn——少抖 resolver 缓存。
- CF DNS 记录 TTL 用 **auto = `ttl:1`**（非魔数 300）；短缓存利于改动传播。提常量 `DOH_TXT_TTL=1` 不用魔数。
- 验证 DNS 改动看 **CF API 权威**（`dns_records`），别只信单次 public DoH——AliDNS anycast 多 POP 收敛是 POP-by-POP 的，单 query 会假阴；权威正确 + 趋势单调向上 = 收敛中。

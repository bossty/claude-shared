---
name: reference_parked_jitter_settings_read_cache
description: "parked优化:SettingsReadCache jitteredExpiry(5min±0-60s)错开:05 Caffeine同时到期惊群(HIKARI_DB_PENDING=5);未上线未合master,patch存memory目录;复活按新流程开feature分支单cherry(去掉捆绑的已revert shareNativeConnection反模式)"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 019a2513-f7cc-4759-ad55-7522771891e2
---

**parked(暂存未上线)优化**:`SettingsReadCache` 加 `jitteredExpiry(baseMinutes, jitterSeconds)` —— Caffeine 到期 = base + [0,jitter] 随机秒,**错开 :05 各 key 同时 miss 回源 DB 的惊群**(实证 HIKARI_DB_PENDING=5)。给 domainListCache + channelCache 都套 `jitteredExpiry(5,60)`。

**来源**:原在已删 stale 分支 `perf-rca-pr3` 的 commit `1a9caf62`("PR-3 根治 :05 脉冲")。该 commit **捆了两半**:① `shareNativeConnection=false`(🔴 memory [[reference_redis_sharenativeconn_antipattern]] 已 revert 的反模式,**禁要**)② 本 jitter(有效想法,但从未上线/没进 master)。2026-06-26 清理 T3 stale 分支时,只抽出 jitter 部分存档。

**patch 位置**:`~/.claude/projects/-home-test-newworld/memory/parked-jitter-settings-read-cache.patch`(只含 SettingsReadCache.java 的 jitter 改动,**不含**反模式)。

**状态**:未上线(:05 脉冲的已上线真修是 PR-2 `684a749b` ZSET节流+keepalive + IP分批读 `615bb1c5`,都在 master;jitter 是被弃 PR-3 的残留增量)。

**How to apply(若要复活)**:走 [[feedback_feature_branch_deploy_test_then_merge]] —— 开 feature 分支 → `git apply` 本 patch(或手抄 jitteredExpiry)→ 测试 → 部署验证 → 授权后合 master。**别**连 shareNativeConnection 一起带。

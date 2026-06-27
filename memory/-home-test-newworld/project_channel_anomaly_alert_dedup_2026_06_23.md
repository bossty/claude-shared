---
name: project_channel_anomaly_alert_dedup_2026_06_23
description: "渠道异常\"疑似刷量\"告警一分钟连发数十条 RCA+修复+部署；附 git worktree-lock 静默 checkout 失败 & admin 部署基线坑"
metadata: 
  node_type: memory
  type: project
  originSessionId: 5fc6ae39-097e-4192-9f28-8280557c5a1f
---

**触发**：Owner 收到 "⚠️[渠道异常] organic 疑似刷量 — UV=200(7日均值43×3=128)跳出率=99%" 一分钟内连发很多次。

**RCA（纯代码层，two-axis 重复）**：告警源 = `SiteStatsSyncTask.detectAnomalies()`（admin，@Scheduled fixedRate=300_000 每 5min）。
- **一分钟 burst 真因**：`site_daily_stats` 唯一键 `(stat_date,domain_name,channel_code)` → channel="organic" 每域一行(~70 A 域)；detectAnomalies 旧逻辑 `for(row) 逐行发`，每个越线的 organic 域行各发一条 → 同一次循环秒级连发 N 条；文案只带渠道名不带域 → 看着像"同一条重复"。错配 bug：阈值 `weekAvg` 按渠道聚合(除行数)，却拿单域 UV 去比 → 单位不一致更易触发。
- **跨 5min 重复轴**：site_daily_stats 是当日累计，越线后当天恒为真 + `telegramAlertService.sendAlert` 零去重 → 每 5min 再发一整批。

**修复（commit 内容同 master `0337ac59` / gfw `0c010c19` / 部署 `ab3d6be9`，+231/-22, 2 files）**：detectAnomalies 改**渠道维度**——今日渠道总UV(Σ域)>近7日日均(先按(渠道,日)汇总再对天数取均值)×3 且 渠道跳出率(Σbounce/Σuv)>80% 才触发；一渠道当日一条(Redis dedup key `admin:alert:channel-anomaly:{date}:{ch}` TTL到午夜，**fail-open** 抖动放行不漏报)；消息内列自身跳出率>80% 的疑似域 UV 倒序 top10 溢出"…等N个域"。TDD 5 测试，`mvn test -pl newworld-admin -am`=1988 passed。Owner 选 top10 域明细口径。`dailyAvgUv<10` 最小基线沿用旧值未抬高。

**部署到 ca-admin 已验证**：jar `20260623-122450-ab3d6be9.jar`，Started 17.78s/0 ERROR/sync 真跑 2703/2703 且 detectAnomalies 0 异常；回滚目标 `20260622-153903-e146fef0.jar`。**未 push origin**(Owner 暂留)。

**★两个部署坑（durable）**：
1. **`git checkout <branch>` 在该 branch 被另一 worktree 占用时静默失败**(exit 128 `fatal: 'master' is already used by worktree at ...`)——本会话 `git checkout master >/dev/null 2>&1` 连续两次没切成功(master 在 `/home/test/nw-h2` worktree)，导致分支基线判断全错、cherry-pick 落错分支。教训=切分支后**必 `git branch --show-current` 复核**别信 exit 0；要动被占用分支用 `git -C <worktree> cherry-pick`。`git worktree list` 先看谁占了。
2. **admin 部署基线 ≠ 分支 HEAD**：prod admin 当时跑 `e146fef0`，落后 master 6 个未部署 commit(含 common ipdb-loader 会进 admin fat jar)、落后 gfw-breakthrough-arch 32 个 W2/W3 WIP commit。**从分支 HEAD build admin = 把未上线 WIP 静默带上 prod**。正确法=把单个 fix cherry-pick 到**当前 prod 基线**(看 `current.jar` symlink 的 `<TS>-<sha>.jar` 里的 sha) build，jar 做污染体检(`python3 zipfile` 查 gfw-only 类如 IspProvinceNormalizer 必 absent)再部署。见 [[reference_ca_admin_deploy_model_2026_06_21]] [[feedback_perf_rca_deploy_gotchas_2026_06_16]]。

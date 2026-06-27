---
name: project-timezone-unification-2026-05-29
description: 5/28 owner 22 域真买 timeout 触发 namesilo 全栈改造 + 5/30 sprint 补做 ops 治理（owner 5/29 已完成 TZ 切换见 [[reference-timezone-hk-unification]]，本 sprint 价值在补 systemd git audit + aws-web-01 P9 升级 + deploy 脚本治本 + dns-failover-agent 蓝军核 + 1 个重复操作教训）
metadata: 
  node_type: memory
  type: project
  originSessionId: 3925e2f9-784b-4b3b-9fef-65cd4364998a
---

# 时区统一 + 域名采购改造 sprint (2026-05-28~30)

> ⚠ **owner 5/29 已完成核心时区切换**（timedatectl HK + SET GLOBAL '+08:00' + 99-timezone-hk.cnf + 154 row backfill 含 purchased_at）→ 详见 [[reference-timezone-hk-unification]]。
>
> **本 sprint 5/30 真新增价值**（不是重做 owner 已做的）：
> 1. ops/systemd-prod/ git audit 33 文件 + README SOP（owner 没做过）
> 2. aws-web-01 P9 8GB heap 升级（drift 真发现 + 真修，owner 5/23 升级时漏 web-01）
> 3. deploy-backend.sh verify 修法（RESTART_TS + MainPID 双过滤）
> 4. dns-failover-agent dust 蓝军 fact-check 真在用（Z15a S 域）
> 5. namesilo 域名采购改造（throttle/词库/TLD/count param）
> 6. domain 22 row backfill（5/28 cutover#3 后的余波，与 owner 154 row 不同区间）
>
> **本 sprint 1 个重复操作教训**：5/30 我创建 `/etc/mysql/conf.d/timezone.cnf` 是冗余（owner 5/29 已有 99-timezone-hk.cnf）— 我**未先读 memory** 就重做。已 rm 冗余 cnf verify @@global 仍 +08:00 ✓。规则：sprint 开始前必先 grep memory/ 看 owner 是否已做过。

## 触发
5/28 owner 在 admin 后台真买 22 个 A 类域，前端弹 "timeout of 30000ms exceeded"，进而发现：
1. axios 30s vs admin nginx proxy 300s + 后端 autoPurchase 22 域真 >30s
2. **22 域 DB created_at 字面 5/28 13:43（UTC）≠ 真买时刻 21:43 HKT** — 5/27 DB cutover 漏检 aws-db-poc OS UTC

## 11 commit 全栈链
```
7761a52d P/S balance dedupe（NameSilo P/S 共账号 dedupe 防 endpoint 双调）
c5550078 @Lazy cycle fix（CacheManagementService 启动循环依赖）
3bd0202b retire-grace 90d 状态机（retiring → retired 自动转换）
d2c5c92f namesilo throttle + 20 主题词库 + THEME_TLDS + 均匀分布 generateCandidateDomains
3b6d815e 删 BATCH_SIZE + 7 endpoint count 参数 + A 类文案"留存域名"
40345d8a 蓝军 round 2 — MAX_PURCHASE_PER_CALL=100 + cron 补池速率恢复
5185c379 sql/z17 列名 fix updated_at→update_time
7bbd03c9 deploy-backend.sh verify 用 RESTART_TS + MainPID 双过滤
1dbfe11f sql/z19 domain 22 row TZ backfill +8h (HKT)
e118c807 ops/systemd-prod/ 初版 sync 6 服务 26 文件 + 删 systemd/ dust + README
527c6e80 ops/systemd-prod/ 补 victoriametrics + dns-failover-agent + drift audit
```

## 4 大模块成果
1. **namesilo 采购改造** — throttle (per-account 500ms min interval) + 20 主题词库（30 prefix × 25 suffix）+ THEME_TLDS 主题映射 + 反向加权均匀分布 + count 参数替代 BATCH_SIZE
2. **时区统一全栈** — aws-db-poc OS HKT + my.cnf `default-time-zone='+08:00'` 持久化 + 15 服务 JVM `TZ=Asia/Hong_Kong` 显式 (systemd drop-in)
3. **历史数据治理** — domain 22 row +8h backfill 真生效（owner 拍 rum/visitor/redirect_trace ~3.7M 漂位接受不修，24h 内）
4. **git ops audit** — 删 git/systemd/ 3 dust + 新建 ops/systemd-prod/ 8 服务 33 文件 + README SOP

## 4 候选新铁律

1. **deploy-backend.sh verify `--since '2 min ago'` 会含 restart 之前老 PID shutdown 噪音** → 修法：restart 前记 `RESTART_TS=$(date)` + 拿 `MainPID` 双过滤 `journalctl --since "$RESTART_TS" _PID=$NEW_PID`。5/28 真事故误判 rollback 致 6 commit 没真上线（commit 7bbd03c9 真治本）

2. **DB cutover 必查 OS + @@time_zone + JDBC serverTimezone 三方一致** → 5/27 cutover aws-db-poc 漏检 OS UTC，admin driver `serverTimezone=Asia/Hong_Kong` 写入时 HKT→UTC 转字面，5/28 22 域字面 13:43 漂 8h。修法：cutover SOP 必加 `SELECT @@system_time_zone, @@global.time_zone, NOW()` 三验 + 写 my.cnf `default-time-zone='+08:00'` 持久化（z19 backfill +8h 修历史）

3. **systemd drop-in prod 改后必同 git audit** → 长期 drift 致 aws-web-01 仍跑 5/23 前 2GB heap、web-02 跑 P9 升级 8GB heap + GC tuning，6GB heap 差异一直没人发现（业务慢但归因不到）。修法：建 `ops/systemd-prod/<service>/{*.conf, *.service}` mirror prod 真实 + README SOP "prod 改 systemd 必同 git 提交"（commit e118c807）

4. **SSH 不通先 `cat ~/.ssh/config` 看别名再 try IP** → 5/30 我 5 次 ssh aws-db-poc 路径 fail（172.31.19.174 内网 + 5 用户名 Permission denied）→ owner 1 句 "直接 ssh aws-db-poc" 揪盲点 → alias 走公网 IP 43.198.91.111 + ubuntu 用户 1 次过。规则：未来 ssh 不通先 grep ~/.ssh/config 别名 priority > 用 IP 直连

## 蓝军反诘案例
- **owner 5/30 直觉**：dns-failover-agent 还在用吗？我们不是全站 cloudflared？
  - fact-check verdict: 真在用（Z15a v2 S 域 wildcard edge VPS 失败监控，1m7d running，5/29 02:41 仍 probe）
  - 关键区分：A/B/C/P 主业务走 cf-tunnel ✓ vs S 域 wildcard subdomain 3 edge IP 直连（W14 5/9 拍板永不接 tunnel）
  - dns-failover-agent = S 域唯一健康保活机制，不能停

## 已知遗留
- rum_image_load.ts (1.5M row) / visitor_fingerprint (800k) / redirect_trace (857k) / vid_metadata (473k) 等 ~3.7M stats 表 row 字面仍 UTC（owner 拍接受不修，仅 5/28-5/29 24h 区间漂位，dashboard 直读偏 8h，admin driver 转换后业务无错）
- aws-data 上 nginx PID（疑 openresty alias，未深查）

## 关键 fact-check 链
- 22 域 created_at: 13:43 UTC 字面 → backfill +8h → 21:43 HKT 真值 ✓
- 4 服务 JVM `/proc/$PID/environ` grep TZ → 全 `Asia/Hong_Kong` ✓
- 双 web 全 systemd 文件 diff → 100% identical ✓（B 步 web-01 升 P9 后）
- aws-db-poc `@@system_time_zone='HKT'` + `@@global='+08:00'` + `NOW()='2026-05-30 00:27:49'` ✓

## 关联
[[project-db-migration-2026-05-27]] — 时区漂位是 5/27 DB cutover 余波
[[reference-claude-config-dir]] — SSH config 别名优先教训

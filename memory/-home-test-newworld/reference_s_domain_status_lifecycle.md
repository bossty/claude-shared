---
name: s-domain-status-lifecycle
description: "S 域 domain.status 语义 —— standby 本就无 DNS，retired 仅用于\"用过\"的域"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 3e6b0318-9157-4777-b86a-35bd2c0bb0d5
---

S 域 `domain.status` 枚举语义关键点（2026-05-16 Owner 两次纠正，"这都忘了吗"）：

## standby —— 本来就不配 DNS 记录

`standby` = 可用池里待分配的健康域。**standby 域故意不配 DNS（apex / wildcard 都没有）**。
DNS 记录只在**绑定到渠道 或 手动激活**时才添加。所以 standby 域 `dig` 出 0 记录是**正常设计，不是缺失**。
（standby 通常已有 CF zone + cert_blob 证书预备好，缺的只是 DNS —— 激活时补 DNS 即可秒级上线。）
→ 核 S 域 DNS 齐全度时，**只核 active 域**；standby 域 0 DNS 不算 bug。

## release() 回 standby —— 现在会清 CF DNS（2026-05-21 起 commit 72951a07）

历史 bug：`SDomainPoolService.release()` 长期只动 DB（domain.status → standby + 软删 pcd binding），
**不清 CF DNS**。造成 standby 域永久挂着前 channel 的 wildcard A/AAAA → 与设计不符，复用时
CF API 81058 "identical record exists" 报错刷屏（5/16 dawn-leaf.com + 5/21 lt001 实证）。

修法：release() best-effort `cfApi.deleteAllDnsRecordsExceptCaa()` 删 A/AAAA/CNAME/TXT/MX/SRV，
**CAA 保留**（下次复用不用重加），**证书不吊销**（Owner 拍板，cert_blob + 90d notAfter 直接续用）。
失败仅 log warn 不回滚 DB（dust 可手清）。5/21 删 lt001 实测 12/12 全删 ~4s。

旧 standby 域的 DNS dust 未清（5/21 前 release 留下的）：要么手动跑 CF API 清理脚本，
要么等下次该域被 reserve + 删（届时 release 走新逻辑会清）。phase2 idempotent 即使 dust 残留
仍可复用（dns-records ok added=0）。

## retired —— 仅用于"真正用过"的域

`retired` 是终态，给**实际服务过、需退役**的域。
**从没激活过（never activated）的健康域，其渠道被删时应退回 `standby`（重回可用池），不能 retire。**
反例：dawn-leaf.com（id=139）5/11 绑 channel 16，channel 16 删，5/13「P9 orphan 渠道清理」
把它一起 retire 了 —— 错误：该域 never activated + clean + probe 0.99 + 付到 2027，应是 standby。
2026-05-16 已修回 standby。orphan-channel 清理逻辑若退役 never-activated 的域 = 浪费健康域。

## retiring → retired 自动转换（2026-05-28 起 commit 3bd0202b）

**真凶**：5/28 蓝军 grep 全代码库实证 `Domain.Status.RETIRED` 常量**零真实写入处** —— 状态机文档承诺
`retiring → retired` 但**代码无实现**，retiring 域**永久停留**。后果两层：
- N_POOL filter `(active|retiring)` 永远命中含「永久 retiring 幽灵」（byteatlas26 + 5/26 5 个 S 域实证）
- **DoH TXT 加密源含死域**风险

**修法**（DomainLifecycleService.markRetiredAfterGrace() + DomainPoolMaintenanceTask）：
- 扫 `status='retiring' AND retiring_at < NOW() - DOMAIN_RETIRING_GRACE_HOURS` 的域
- set `status=retired + weight=0` → 触发 `afterDomainPoolChange()` → `onDomainPoolChanged()`
- 自然刷 N_POOL + Redis ZSet 移除已 retired 域
- @Scheduled `fixedDelay=1h, initialDelay=7min`（真遵守 5/26 P1 教训：fixedDelay over fixedRate + initialDelay 避启动 burst）

**grace 默认 90d 真设计意图**（`DOMAIN_RETIRING_GRACE_HOURS` 默认 2160h，可 system_config 调整）：
- 覆盖 newworld 推广周期 + 老链接传播 + cookie 自然过期
- 业界 7d 标准对推广不友好

**真闭环**：domain 生命周期 4 状态机真完整实现 `standby → active → retiring → retired`。接 5/21 commit
`72951a07` release() 自动清 CF DNS（forward）+ 5/28 commit `3bd0202b` retiring→retired 自动转换
（grace 后），整条链路真自治不再需要人工 SQL 干预。

**真测试**：DomainLifecycleServiceTest 加 3 nested case (MarkRetiredAfterGrace): ripe→转换 / 空→never refresh / config 非法→默认兜底；mvn test=1817 fail=0 err=0 PASS（+3 baseline）。

## cert 下发 gate（见 [[gfw-confirmed-blocked-trap]]）

edge cert 下发只认 `status=active`（active-s-list SQL）。standby/retired/blocked 域不下发 cert —— 这是设计，
因为它们本就不该服务流量。

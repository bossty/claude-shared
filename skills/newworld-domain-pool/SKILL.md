---
name: newworld-domain-pool
description: 域名池 TARGET vs N_xxx 区别 — DOMAIN_POOL_*_TARGET 是 active 目标数（active < target → standby 激活 + 补购）；N_DOH/N_POOL/N_PP 是实际下发前端的列表（DomainConfigSyncHelper.update*Config 主动刷新）；maintainInfraPool() 每 10min 末尾无条件刷新，扩容延迟最长 10min；排查"扩容了但前端没看到"先查 N_xxx 不查 TARGET。**S 域 active DNS 必须 apex+wildcard 成对**（addWildcardDnsRecordsGrey 5/21 修了缺 apex 根因 bug）。Triggers on 域名池, domain pool, DOMAIN_POOL_DOH_TARGET, DOMAIN_POOL_PROMO_TARGET, DOMAIN_POOL_RELAY_TARGET, N_DOH, N_POOL, N_PP, TARGET, maintainInfraPool, DomainConfigSyncHelper, updateCdnUrlsConfig, updateDohDomainsConfig, updateRelayConfig, 扩容了但前端没看到, standby active, addWildcardDnsRecordsGrey, ensureWildcardDnsRecords, S 域激活, S 域 DNS, apex wildcard, apex 记录, wildcard 记录, dawn-leaf, hstspreload DNS lookup, dns_records apex.
---

# Newworld 域名池配置陷阱铁律（2026-04-13 学到）

## 触发场景
- 改 `DOMAIN_POOL_DOH_TARGET` / `DOMAIN_POOL_PROMO_TARGET` / `DOMAIN_POOL_RELAY_TARGET`
- 改 `N_DOH` / `N_POOL` / `N_PP` 配置
- 排查"域名扩容了但前端没看到"
- 改 `DomainPoolMaintainer.maintainInfraPool()` 调度逻辑

## 核心区分（文档反复说错的两个概念）

### `DOMAIN_POOL_*_TARGET` = active 目标数
- 含 DOH / PROMO / RELAY 三类
- 语义：当前应有多少 active 域名
- 行为：
  - `active < target` → standby → active 激活 + 补购
  - `active ≥ target` → 不动作

### `N_DOH` / `N_POOL` / `N_PP` = 实际下发到前端的域名列表
- 由 `DomainConfigSyncHelper.update*Config()` 主动刷新
- 才是前端实际能看到的域名

## 扩容延迟最长 10 min

`maintainInfraPool()` 每 10 min 调度，末尾**无条件**调用：
- `updateCdnUrlsConfig`
- `updateDohDomainsConfig`
- `updateRelayConfig`

→ 扩容后下一个 tick 自动对齐，延迟最长 10 min。

紧急场景（需立即下发）：手动调 `DomainConfigSyncHelper.update*Config()`。

## 排查"扩容了但前端没看到"

**铁律**：先查 N_xxx，**不要**先查 TARGET。

```
1. 看 system_config.N_DOH / N_POOL / N_PP 实际值
2. 对比前端 settings 接口返回
3. 若 N_xxx 已含新域但前端没看到 → 前端缓存 / app-config 轮询问题
4. 若 N_xxx 不含新域 → DomainConfigSyncHelper 没刷新（等 10 min 或手动调）
5. 若想验证池子总量 → 再看 TARGET / standby / active
```

## S 域 active DNS：apex + wildcard 必须成对（2026-05-21 根因修）

S 域激活路径（`activateShortLinkDomain` / `createChannelPhase2WithJob` → `ensureWildcardDnsRecords`）下发 DNS 记录时，**必须同时**：
- `<domain>` apex A/AAAA 指向 N 个 edge IP
- `*.<domain>` wildcard A/AAAA 指向同 N 个 edge IP

`CloudflareApiService.addWildcardDnsRecordsGrey` **早期实现只加 wildcard 漏 apex**（Javadoc 写 "apex root + wildcard" 实现脱节），dawn-leaf.com 5/21 Phase2 后 apex 缺失被 hstspreload verifier 拒收 + 公网直访 `https://<apex>` 失败。

**根因已修**（commit `afb56ad5`）：循环内每个 edge IP 都加 apex + wildcard 两条；`addDnsRecord` 对 CF "already exists" 静默处理，对 grandfathered 域 idempotent 无副作用。

历史绕法（W14 #18 "批量补 36 历史域" + grandfathered 6 prod 手动补 apex）是补丁不是修真，**新代码已修根因**，不再需要那种手动补丁流程。

### 检查清单（S 域激活相关）
- [ ] 改 `addWildcardDnsRecordsGrey` / `ensureWildcardDnsRecords` 时验证 apex + wildcard 两条都加
- [ ] 新激活 S 域后 `dig +short @8.8.8.8 <apex> A` 必返 3 个 edge IP（不空）
- [ ] hstspreload `submit` 报 "We cannot connect using TLS (dial tcp: lookup ... failed)" → 立即查 apex 是否缺
- [ ] 改 Javadoc 说"加 X+Y"实现必须真加 X+Y（实现-文档脱节是常见 bug 源）

## 检查清单（池子配置）
- [ ] 改 TARGET 后等 10 min 看 N_xxx 自动刷新
- [ ] 紧急扩容后手动 `DomainConfigSyncHelper.update*Config()` 下发
- [ ] 排查"前端没看到"先查 N_xxx 不查 TARGET
- [ ] 改 maintainInfraPool 调度间隔时同步评估前端可见延迟

## 违反后果
- 改 TARGET 但不等 10 min / 不手动刷 → 前端长时间看不到新域名，用户层故障
- 排查时只看 TARGET 不看 N_xxx → 误以为"扩容失败"，瞎改池子参数雪上加霜
- 删除 maintainInfraPool 末尾的 update*Config 调用 → 扩容永远不下发，最坏情况整个池子前端不可见
- 上述任一项 = **3.25 级别**复盘

## 源
- CLAUDE.md L23-L29（域名池配置陷阱）

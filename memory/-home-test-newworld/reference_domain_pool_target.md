---
name: 域名池 TARGET 与 N_xxx 配置的关系
description: DOMAIN_POOL_*_TARGET 是补购阈值非激活上限；N_DOH/N_POOL/N_PP 是实际下发列表，扩容后需手动同步
type: reference
originSessionId: f41fc13a-9772-4519-93e4-19914facf340
---
## 核心事实（2026-04-13 验证）

域名池的两类配置**职责完全不同**，不要混淆：

| 配置类 | 作用 | 例子 |
|--------|-----|------|
| `DOMAIN_POOL_*_TARGET` | **补购阈值**：active < target 才触发 NameSilo 自动买新域名 | `DOMAIN_POOL_DOH_TARGET=5` |
| `N_DOH` / `N_POOL` / `N_PP` 等 | **实际下发到前端 SW 的域名列表** | `N_DOH=["d1.com","d2.com"]` |

**两者无自动联动**：你把 active 域名从 2 个激活到 10 个，N_xxx 不会自动更新——它由 `DomainConfigSyncHelper.update*Config()` 主动刷新（域名状态变更时被 lifecycle 触发）。

## 排查 SOP

**问题**："我扩了 active 域名但前端没看到新的 DoH/CDN/relay 域名"

正确顺序：
1. 查 N_xxx 实际值 → `SELECT config_value FROM system_config WHERE config_key='N_DOH'`
2. 查 active 域名数 → `SELECT COUNT(*) FROM domain WHERE category='B' AND purpose='dns-config' AND status='active'`
3. 如果 (2) > (1)：调 `DomainConfigSyncHelper.updateDohDomainsConfig()`（admin 后台 `/api/v1/domain/sync/doh` POST）或直接 DB 更新 N_xxx + bump systemVersion

不要查 TARGET——它不影响 N_xxx。

## 错误案例

2026-04-13 初次扩 DoH 时误以为 `DOMAIN_POOL_DOH_TARGET=5` 会自动激活 5 个并下发——实际 active 已经有 10，但 N_DOH 还是 2，因为没有触发 sync。直接改 TARGET 浪费时间，应该改 N_DOH。

## 相关代码

- `newworld-admin/service/DomainConfigSyncHelper.java:updateDohDomainsConfig()` — 把所有 active B/dns-config 域名写入 N_DOH
- `newworld-admin/controller/DomainController.java:syncDoh()` — 暴露的手动触发接口
- `newworld-admin/service/DomainLifecycleService.java` — 域名状态机（pending_ns → active → degraded → blocked），状态变更时回调 sync

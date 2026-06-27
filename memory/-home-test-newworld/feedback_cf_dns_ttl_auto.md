---
name: feedback_cf_dns_ttl_auto
description: 所有 Cloudflare DNS 记录 TTL 一律设 Auto(CF API ttl:1)，全项目铁律
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 019a2513-f7cc-4759-ad55-7522771891e2
---

**所有 CF DNS 记录 TTL 一律 Auto**（CF API `ttl:1`），不写死固定值。范围 = **全项目所有 zone/账号**(A/B/C/P/S)，非仅 S-entry（Owner 2026-06-22 两次确认，第二次明确"凡是 CF 的 DNS 记录"）。

**Why**: TTL 写死会拖慢切流/换实例/故障摘除时的 DNS 收敛；Auto 由 CF 管理（unproxied 默认 300s，proxied 本就 Auto）。Owner 列入计划。

**How to apply**:
- 新建任何 CF DNS 记录（脚本/onboarding/手动）一律 `ttl:1`。`provision-s-wildcard-cert.sh` 及 `DomainLifecycleService` 的 DNS 写入遵此。
- **token 位置（实证）**：5 个 CF token（`CF_API_TOKEN_A/B/C/P` + `CF_TOKEN_S`）**全在 system_config 表**（DB）；secrets.env(ca-admin) 只有 `CF_TOKEN_S`。取 token 最干净：ca-mysql-master `sudo mysql newworld -N -e "SELECT config_value FROM system_config WHERE config_key='CF_API_TOKEN_X'"`（root socket）。ca-mysql-master 可直连 CF API（egress OK）→ 在它上面跑 sweep，token 不出服务器。
- **★全量扫描已执行（2026-06-22，Owner 拍"全改 Auto"）**：4 账号扫完，合计 **2321 records，改 138，失败 0**。A(167z/991r)/B(18z/325r)/C(4z/20r) **本就全 Auto（0 改）**；**P/S(149z/985r) 改 138**（都是 ttl=60，样本 `*.apexcorp26.com` A）。复查 P/S 剩 0 非auto。脚本：遍历 token→zone(分页)→dns_records(分页)→`(not proxied) and ttl!=1` 则 PATCH `ttl:1`（proxied 本就 Auto 跳过），幂等可重跑。
- **caveat（Owner 已接受）**：CF Auto = unproxied 300s；改后 ttl=60 记录变 300s。Owner 接受（本项目 failover 靠 CF Tunnel/LB 健康检查非 DNS TTL）。
- 后续新建记录仍须 `ttl:1`（onboarding/脚本守此）。
- 关联 [[project_gfw_s_entry_execapi_poc_2026_06_22]]。

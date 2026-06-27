---
name: DNS 摘除/回填作为多 IP 轮询止血手段（CF API + rollback JSON）
description: S 域名 DNS round-robin 某节点 100% 500 时，CF API 删该 IP A 记录 5min 止血，修好后 POST 重建。CF token 在 system_config.CF_TOKEN_S。Rollback JSON 在 aws-data:/tmp/dns-rollback/
type: reference
originSessionId: fe398321-ee74-4942-9f53-cfbb4ac5e1d8
---
S 域名（4 个：swiftgroup26.cc / mintlab26.cc / peak-rank.cc / boldpoint395.com）在 CF 灰云 DNS-only 多 IP 轮询：3 IP 池 = 67.230.161.24 (usca-1) / 67.230.182.105 (usca-2) / 95.40.168.207 (aws-s)。某节点出问题用户体感 ~33% 概率 500。

**止血**：CF API 从 4 个 zone 各删该 IP 的 A 记录 → 流量只走剩余 2 IP → 公网 500 立即归零

**Token 取值**：`mysql -h172.31.27.200 -unewworld -p<DB_PASSWORD> newworld -se "SELECT config_value FROM system_config WHERE config_key='CF_TOKEN_S'"`（每个 cf_account 一个 token，S 域用 CF_TOKEN_S）

**Zone_id 取值**：`SELECT zone_id FROM domain WHERE category='S' AND status='active'`

**API**：
- 列：`GET /zones/{zone_id}/dns_records?type=A&name={domain}` → 拿 record_id
- 删：`DELETE /zones/{zone_id}/dns_records/{record_id}`
- 重建：`POST /zones/{zone_id}/dns_records` body 用 rollback JSON 内容（type/name/content/proxied/ttl）

**Rollback 数据**：止血时**必先**保存删除前 JSON 到 `aws-data:/tmp/dns-rollback/<zone_id>-<timestamp>.json`，回填时直接 POST 即可。

**何时回填**：根因修复 + curl --resolve 强制打该 IP × 多次确认 302 后才回填。CF DNS 内部秒级生效，public 端 30s 内可见。

**实例**：2026-05-02 hotfix-3 全程 CF API 操作 + rollback 走通，所有命令和验证表见 git log fec6e99a 关联 Sprint 报告。

---
name: reference_doh_domain_apex_cname_hstspreload
description: DoH/B 域 apex CNAME→public.r2.dev 是 hstspreload 可达性 load-bearing 记录(禁删);判 DNS 用途先查 CF comment 字段
metadata: 
  node_type: memory
  type: reference
  originSessionId: c26c2e1f-72a4-463f-8370-aeecffd81acf
---

B 类(含 dns-config/DoH)域名 apex 上的 `CNAME → public.r2.dev` 是**故意加的、load-bearing**，**禁删**。

**用途**：hstspreload.org 提交要求 apex 能 TLS 连通；R2 是常开 HTTPS 端点，apex CNAME 指过去让 hstspreload verifier 连得上（与 S 域 apex 指 edge IP 同目的）。CF DNS 记录 `comment` 字段写明 **"hstspreload verifier reachability (2026-05-21 sprint)"**。删了 → hstspreload 验证失败（"We cannot connect using TLS"）+ 公网直访 `https://<apex>` 断。见 [[newworld-domain-pool]] skill 5/21 根因（addWildcardDnsRecordsGrey 漏 apex，dawn-leaf.com 被拒收）。

**不破 TXT**：apex 被 CF 代理 + apex-CNAME flattening 拍平成代理 A（104.21/172.67），与 TXT(域名池)正交共存；`dig CNAME` 解析层看不到 ≠ 不存在（flattening 隐藏）。现行代码不创建这条 CNAME（`DomainLifecycleService:1052` B 类不走 activateDomain；全 admin 无 `r2.dev` 字符串）→ 5/21 专门加的。

**方法论教训（连错三次换来的）**：判一条 DNS 记录的用途/能否删，**先查 CF API 的 `comment` 字段 + recall 相关 sprint skill，再下结论**；只查 DNS 解析层(dig)会被 CF flattening 骗，只查代码会漏手工/sprint 专配。n=1 抽样禁止外推到全集。

**对 DoH TXT 多记录修复的护栏**：写/清 pool TXT 只能动 `type=TXT` 且带自描述前缀(如 `np1|`)的记录，孤儿清理严禁误删 apex CNAME 或其它 TXT(SPF 等)。见 docs/sprint/2026-06-18-relay-doh-asset-triage/DESIGN-txt-overlength.md。

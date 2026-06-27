---
name: reference_cf_waf_referer_skiplist
description: CF 防盗链 referer 白名单超 4096 字符硬限的治本解 = N 条 skip 白名单 + 1 条兜底 block（CF List 做不了，已 live 验证）
metadata: 
  node_type: memory
  type: reference
  originSessionId: d040d32b-2e98-4c95-acc0-220cd4d6d6b9
---

# CF WAF referer 白名单超 4096 字符的治本：skip 多规则

**问题**：`CloudflareApiService.buildRefererExpression` 把全部 active A/C/P 域挤进**一条 block 表达式** `(http.referer ne "" and not (lower(http.referer) contains "d1" or ... ))`，域数涨到 100 → 4988 字符 > CF 单表达式硬限 4096 → PUT 被 CF reject → 新增内容域未进白名单 → 用户在这些域看视频时 R2 资源带本域 referer 被兜底 block 拦（**带 origin referer 的正常用户中招，空 referer 放行不受影响**）。

**B 方案（CF Custom List）被官方文档否决**（2026-05-31 查实）：① CF custom list 只有 IP/Hostname/ASN，**无任意字符串类型**，且 Hostname/ASN list 是 **Enterprise-only**（我们非 Enterprise）；② `field in $list` 是**精确相等**，复刻不了现状 `contains` 子串语义（一条裸域同时覆盖 apex + 所有 wildcard 子域）。→ List 路线死。

**A-skip 治本（commit `2fec2418`，已 live 验证 99/99）**：单条 block 反转成 **N 条 skip 白名单 + 1 条兜底 block**：
- skip 规则：`action=skip`，`action_parameters={ruleset: current}`，expr=`(lower(http.referer) contains "d.." or ...)` 每块按字符贪心切 ≤3800；命中→跳过本 ruleset 剩余规则→放行。
- 兜底 block：expr=`http.referer ne ""`，排在所有 skip **之后**（CF rules 数组顺序执行）。
- 语义等价：命中白名单→skip 放行；空 referer→兜底 ne "" 为假→放行；非空未命中→block。
- **三条规则不可拆**：删 block → skip 变空操作 → 防盗链整个失效（盗链全放行）；且代码每次 sync 全量重建会自动加回 block。

**实现铁律**：全量声明式重建（不重/不漏/不误加）——每次 sync 先按 description 前缀 `Referer whitelist` 删我方全部旧规则（含旧单条 block，平滑迁移），再 append 当前快照整组；只删前缀匹配规则，非我方规则原样保留。`WAF_CANARY_ZONE_ID` 闸门限首发爆炸半径。

**CF skip action 官方 JSON**：https://developers.cloudflare.com/waf/custom-rules/skip/api-examples/ — `{"action":"skip","action_parameters":{"ruleset":"current"},"expression":"...","description":"..."}`，zone-level 可用。

**验证方法（黑盒 curl，无需 token）**：取真 R2 资源 URL（`SELECT cover_image FROM movie WHERE cover_image LIKE 'http%' AND status=1`），逐个 active A/C/P 域当 `Referer: https://<域>/` 打该资源 → 期望全 200；盗链 referer → 403（CF WAF block 页 text/html）；空 referer → 200。**用根路径 `/` 测无效**（R2 root 返 1014 干扰），必须用真资源路径。2026-05-31 实测 99/99 全 200（A44/C4/P51）。

防盗链本身价值边际（代码注释：盗链成本≈0、R2 egress 免费、对 GFW 无防御、只防懒人 hotlinker）——若要退役是改代码停 sync + 清规则，非删单条。关联 [[reference_prod_db_redis_host_19_174]]。

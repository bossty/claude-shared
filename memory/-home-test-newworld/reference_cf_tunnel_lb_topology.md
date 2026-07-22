---
name: reference-cf-tunnel-lb-topology
description: CF 全量 tunnel/LB/pool/geo 拓扑权威图 + cloudflared 命名规范 + 加州建 pool 两坑
metadata: 
  node_type: memory
  type: reference
  originSessionId: 64b5f5d1-9590-4971-9f5b-8d2e351a83eb
---

> **⚠️ 2026-07-07 状态标注**：A-HK-tunnel「主站 origin」角色已随终态架构 B 退役；dnsv106 canary 部分仍有效。

> **⚠️ 2026-07-19 实测订正（BL-12 评审副产，CF API + 三台 token 解码交叉核实）——下方 §「LB / pool / geo」与 §「LB Monitor」的两处具体数值已过期**：
> 1. **pool 数：4（hk/or/eu/ca）→ 实测现只剩 2（ca/eu）**。hk/or 已被后续清理移除，本档记的四组「完全对齐闭环」描述的是 06-10 状态，勿再据以推断今天还有 hk/or pool。
> 2. **monitor path：`/actuator/health` → 实测是 `/health`**。⚠️ **核心论点不受影响且更需强调**：monitor 经 tunnel 落到 `:80` OpenResty catch-all，**app 全崩仍答 200**，真 actuator 在 `:18080` 够不着 → **pool 级健康检查对「实例崩溃重启循环」结构性失明，不会自动摘除**。
> 3. **判别教训（本次差点判错）**：**CF LB 的存在性不能用业务域自己的 zone 判定**——LB 对象不挂在业务域 zone 上，查 `/zones/{业务域}/load_balancers` 返空是**预期内的空**。正确姿势＝先看业务域 DNS CNAME 指向哪个**宿主 zone**（实测 A 域→`tcos-canary.dnsv106.com`、P 域→`p-lb.lbedge.org`），再去宿主 zone 查 `/load_balancers`。一次「预期内的空」曾被读成「LB 不存在」，差点据此推翻 `CLAUDE.md`「A/P 域经 CF LB geo-steering」——该表述经本次核实**为真**。
> 4. **粒度结论（部署/金丝雀会用到）**：LB 只做 **CA↔EU 区域级 geo 故障转移**，每个 pool 只挂 1 个 origin（origin 内部是 tunnel connector 自动 HA）→ **CF 侧无单机权重旋钮**，无法先切 1% 试水。且 `region_pools` 实测 WNAM/ENAM/NEAS/OC/SEAS 五区都优先 CA pool。
> 5. **姊妹漂移（同批查出，未修）**：`docs/infra/AWS_HK_DEPLOYMENT.md` 的 tunnel 表写 A-tunnel（`63594ad3`）服务 ca-web-01..04 + eu-web-01/02 共 6 台同一 tunnel；**实测 eu-web-01 token 解码是另一 tunnel（`cde6d3f3`），与 CA 四台的 `38ef476d` 不同** → 真实是 **CA 4-way + EU 2-way 两个独立 tunnel，只在 geo LB 层汇合**。
>
> 证据与上下文：`docs/superpowers/specs/2026-07-19-bl12-secret-fail-fast-design.md` §6.2 步骤 4 与 §7.5/§7.6。

2026-06-10 CF API 实证测绘（account A=50cbd453…149cc0113d7c62b91b6b3d2a，Cnbestmovie）。

## Tunnel（account A，名↔ID↔connector）
| 名 | ID 前缀 | connector | 角色 |
|---|---|---|---|
| A-HK-tunnel | 63594ad3 | HK web-01+02 | A 域主站 origin |
| **A-OR-tunnel**(原 A-US-tunnel) | 8af6ed58 | 俄勒冈(Oregon) | US/WNAM canary origin（活）|
| A-EU-tunnel | cde6d3f3 | eu | EU canary origin（活）|
| **A-CA-tunnel**(原 A-USW1-tunnel) | 38ef476d | **加州×3**(California，落 SJC colo) | 2026-06-10 新建，加州 origin |
| ~~multi-region-tunnel(mrt)~~ | ~~2063b532~~ | — | **2026-06-10 已退役删除**（曾空闲无 DNS/LB；停 3 connector+删 tunnel+删单元，零影响）|
| Admin-tunnel | 831edb84 | aws-data | adm.17.rip |
| Monitor-tunnel | e4df631d | aws-monitor | n9e.17.rip |
（C 域 tunnel a92dcc44 acct C、P/S 域 1af743b6 acct P/S=9a1d6632，均 HK×2。）

## LB / pool / geo（canary 真入口）
```
tcos-canary.dnsv106.com (geo LB)
  ├ nw-dnsv106-hk → origin-hk.dnsv106.com → A-HK-tunnel
  ├ nw-dnsv106-us → origin-us.dnsv106.com → A-OR-tunnel(俄勒冈)
  ├ nw-dnsv106-eu → origin-eu.dnsv106.com → A-EU-tunnel
  └ nw-dnsv106-ca → origin-ca.dnsv106.com → A-CA-tunnel(加州)  ★2026-06-10 建,零流量未入 LB
  geo(2026-06-10 S1放量后,ca成全局US co-origin): WNAM→[ca,or,hk,eu](ca主LAX/SJC) ENAM→[or,ca,hk,eu](or主ca2) NEAS/SEAS/OC→[hk,or,eu,ca] WEU/EEU→[eu,hk,or,ca] default→[hk,or,eu,ca]; country HK+11亚洲国→[hk](未动hk-only)。实际ca真流量仅WNAM首位,余皆备份冗余
tcos.dnsv106.com (geo) → default=[hk]  非canary 全回 HK
```

## LB Monitor（健康检查，per-pool 各一）
每 pool 一个 monitor：`https GET /actuator/health expect=200 interval=60s port=443`，**带 per-pool Host 标头 `Host: origin-{region}.dnsv106.com`**（hk/or/eu/ca）。Host 标头**必需**：monitor 443→proxied origin→tunnel→:80，后端按此 Host 过 guard(≤10字符)+OpenResty 兜底服务。⚠️ 浅检查：tunnel 只回源 :80，`/actuator/health` 实际命中 OpenResty SPA catch-all 返 200（非真 Spring actuator，那在 :18080 够不着）——只验 OpenResty 活、没验 app/DB，全 pool 同此既有弱点。**4 monitor 各带不同 Host=per-pool 正确，不可合并**（合并会丢 per-pool Host）。

## ★2026-06-10 全量审计结论：dnsv106.com 全一致符合规范
CNAME / tunnel / pool / LB steering / monitor Host 五层对 {hk,or,eu,ca} 四组**完全对齐闭环**。owner 把俄勒冈 us→or 全量改名（tunnel A-US→A-OR、DNS origin-us→origin-or、pool nw-dnsv106-us→-or、LB region_pools、monitor Host 标头——最后这条标头是审计查出的唯一尾巴，已修）。ca 零流量未入 LB；无 origin-usw1/mrt 孤儿。
每 region = 自己 tunnel→自己 pool→tcos-canary geo 编排。CF token/account/tunnel ID 在 **system_config 表**（非 secrets.env，那只有空 CF_TOKEN_S）：CF_API_TOKEN_A / CF_ACCOUNT_ID_A 等。

## cloudflared systemd 命名规范（owner 2026-06-10 定）
**统一 `cloudflared-{a/c/p}.service`（无 region 后缀）**。HK 有 a/c/p 三个（服务三域）；region 只有 a（仅 A 域 canary）。HK 不改；俄勒冈/eu/加州 的主 tunnel 单元已统一为 `cloudflared-a`。零downtime 改法=overlap（先 enable 新名同 token+起，待新 connector 注册，再 disable 旧，tunnel 全程≥1 connector）。

## ★加州建 pool 两坑（建 region origin 必避）
1. **guard.lua GAP-9：origin host 第一段 >10 字符 → 444 silent drop**。`origin-usw1`(11)被丢、`origin-ca`(9)放行。region origin host 须 ≤10 首段（沿用 `origin-{≤3字母}` 如 origin-hk/us/eu/ca）。
2. **tunnel ingress 必须 catch-all**（`[{"service":"http://localhost:80"}]`，非 hostname-specific）。因 CF LB 路由到 pool 时**到达 tunnel 的 Host=用户原始域名（如 bytebase26.top）不是 origin host**；hostname-specific ingress 会让真 LB 流量命中 fallback 404。现有 tunnel 都 catch-all（CF 远程 ingress=null=local catch-all）。
3. 验证：直测 localhost:80 加 `-H Host:真域名`（绕 CF edge，--resolve 会因 SNI≠Host 被 edge 自己 403=测试 artifact 非真问题）。

配套 [[project_california_region_build_2026_06_09]]。放量=把 nw-dnsv106-ca 放进 tcos-canary WNAM region_pool（owner-gated）。

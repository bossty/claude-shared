---
name: reference-cf-504-unk-protocol-accounting-artifact
description: CF 504+originStatus=0 先查 protocol 维度——UNK=未完成请求的记账伪影非回源故障；地理集中必先验分母效应（禁单 zone 下地理结论）；免费 zone GraphQL 可用维度清单与绕法
metadata:
  type: reference
---

CF analytics 里 `edgeResponseStatus=504 + originResponseStatus=0 + 源站零日志` 的组合，**先查 `clientRequestHTTPProtocol` 维度再开排查**：若 504 组 100% = `UNK`（对照 200 组协议正常），则这些"504"是「TLS 连接建立但 HTTP 请求从未完整解析」的**记账伪影**——从未产生真实回源，tunnel/LB/源站排查全是白费（BL-72 实例：两个会话先后查源站六节点、tunnel HA、LB pool，一个 protocol 维度查询就能翻案）。

**Why**: 真正的回源派发失败发生在请求解析之后，协议不可能是 UNK；UNK+visits=0 是"请求未完成"的决定性指纹。

**⚠️ 2026-07-16 重大订正——本条曾两次归因错误，「是伪影」始终对，「为什么是伪影」错了两轮**：
- ~~「GFW 场景下高度集中 CN 客户端」「CN 集中先想 GFW 而非基础设施」~~ **已证伪**。实测（17.rip 主域 `path="/"` 24h，`country×status` 二维 + `orderBy:[count_DESC]` + limit 500 未截断，证据 `scratchpad/cf_17rip_v2.json`）：**US 504=38.9%（88,317 采样）> CN 504=23.9%（21,383 采样）**，DE 29.0% / CA 36.6% / JP 43.4%。**GFW 干扰不到美国日本德国加拿大 → GFW 假说决定性证伪。**
- 前两轮「CN 占 504 的 94%」是**分母效应**：当时只看 canary 单 zone（`eduspace181.link`，真实用户本就 94% 在 CN），把用户构成误读成故障地理特征。
- ~~「504 全落 miss = 慢响应给了连接死亡时间窗」「正解=提高 HIT 率压缩等待窗」~~ **不成立**：edge TTL 60→300s 实做后 HIT 34%→38.5%，504 纹丝不动（26.2%）。全落 miss 只是「没有真实请求→自然无命中」的同义反复，不是因果。
- **当前最佳解释（推断，未实证）= 浏览器预连接伪影**：真实浏览器 200:504 ≈ **1:1**（US 34,806:34,370；CN 真浏览器 H2+H3 6,462 : UNK 5,110），而纯脚本流量 **零 504**（SG 全 HTTP/1.1，23,215:1）。签名指向浏览器 speculative connection/preconnect——预建 TCP+TLS，H2 单连接够用后备用连接闲置超时→记 504+UNK。**用户完全无感（200 那条正常完成），无需修复。**

**How to apply**:
- 判别三件套：①504 组 protocol 维度（UNK?）②sum{visits}（=0?）③合成完整请求强制 miss 探测（`?bust=<rand>` cache-buster，`cf-ray` 尾巴自带 colo，绕过 coloCode authz）。
- **④（07-16 新增，血泪）地理/国别集中必先验分母效应**：单 zone 的国别分布反映的是**该 zone 的用户构成**，不是故障特征。下任何地理结论前，**必须拿流量全球分布的域（如主域 17.rip）跑一次 `country×status`**——一次查询、不到一分钟，就能戳破两轮排查。同理适用于任何"X 维度高度集中"的结论。
- **⑤ 真浏览器 vs 脚本对照**：按 protocol 切，全 HTTP/1.1 群体≈脚本/监控（本项目 SG 即是），真浏览器走 H2/H3。两者行为差异（如 504 率 38.9% vs 0%）常是解释伪影的钥匙。
- **⑥ GraphQL limit 必配 orderBy**：`limit:N` 无 `orderBy` 返回的是**任意 N 组不是 top N**（07-16 实误：limit:20 无 orderBy 得出"504 总计 52"的假数）；多维组合基数易超 limit 被**静默截断**→结论建立在残缺数据上。铁律：维度尽量少、`orderBy:[count_DESC]`、limit 给足，并**断言返回组数 < limit** 才算未截断。
- 免费 zone GraphQL authz 拒（07-16 复测仍拒）：coloCode / clientAsn / edgeTimeToFirstByteMs / loadBalancingRequestsAdaptiveGroups；时间窗限 1 天（逐日取窗）。可用：clientCountryName / clientRequestHTTPProtocol / cacheStatus / datetimeHour / datetimeFiveMinutes / clientRequestHTTPHost / clientRequestPath / originResponseStatus / sum{visits} / avg{sampleInterval}。
- **升 plan 能否解锁 coloCode：官方文档查无记载**（07-16 subagent 查遍 developers.cloudflare.com；CF 不发布字段-plan 对照表，只 Pro+ 明文解锁 `edgeTimeToFirstByteMs`，见 blog「Introducing Timing Insights」）。报错 `zone '<id>' does not have access to the field` + `code:authz` 措辞是 **zone 级（=plan）** 非 token 级（同 token 能查其他维度即可自证）。Logpush/Logpull 官方明确仅 Enterprise。→ 想靠升 Pro($25/mo) 拿 coloCode 可能白买，需先买一个月实测。
- O2O 链（A zone→proxied LB zone）第二跳不在 LB zone http 分析记账，不能用作判别。
- cloudflared journal 三坑：`-p warning` 无效（WRN/ERR 未映射 priority，只能文本 grep）；`grep -i quic` 被 quickbeat 等域名子串误命中须 `\bquic\b`；新版无 `Registered tunnel connection` 字符串。
- 关联 [[reference-cn-isp-international-routing-split]]（真路由分化实例，但**勿再据此把 CN 集中直接推给 GFW**——先走上面第④条）、[[feedback-session-state-header-addendum-wins]]（本条两次错归因均伴随读档只取旧节）。

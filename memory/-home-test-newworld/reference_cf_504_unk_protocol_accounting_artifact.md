---
name: reference-cf-504-unk-protocol-accounting-artifact
description: CF 504+originStatus=0 先查 protocol 维度——UNK=未完成请求的记账伪影非回源故障；免费 zone GraphQL 可用维度清单与绕法
metadata:
  type: reference
---

CF analytics 里 `edgeResponseStatus=504 + originResponseStatus=0 + 源站零日志` 的组合，**先查 `clientRequestHTTPProtocol` 维度再开排查**：若 504 组 100% = `UNK`（对照 200 组协议正常），则这些"504"是「TLS 连接建立但 HTTP 请求从未完整解析/客户端在响应完成前死亡」的**记账伪影**——从未产生真实回源，tunnel/LB/源站排查全是白费（BL-72 实例：两个会话先后查源站六节点、tunnel HA、LB pool，一个 protocol 维度查询就能翻案）。

**Why**: 真正的回源派发失败发生在请求解析之后，协议不可能是 UNK；UNK+visits=0 是"请求未完成"的决定性指纹。伴随规律：此类 504 全落 cache miss——不是 miss 导致 504，是慢响应给了连接死亡的时间窗（因果反转），HIT/revalidated 快路径零 504；GFW 场景下高度集中 CN 客户端。正解=提高 HIT 率压缩等待窗，不是修派发。

**How to apply**:
- 判别三件套：①504 组 protocol 维度（UNK?）②sum{visits}（=0?）③合成完整请求强制 miss 探测（`?bust=<rand>` cache-buster，`cf-ray` 尾巴自带 colo，绕过 coloCode authz）。
- 免费 zone GraphQL authz 拒：coloCode / clientAsn / edgeTimeToFirstByteMs / loadBalancingRequestsAdaptiveGroups；时间窗限 1 天（逐日取窗）。可用：clientCountryName / clientRequestHTTPProtocol / cacheStatus / datetimeFiveMinutes / clientRequestHTTPHost / originResponseStatus / sum{visits} / avg{sampleInterval}。
- O2O 链（A zone→proxied LB zone）第二跳不在 LB zone http 分析记账，不能用作判别。
- cloudflared journal 三坑：`-p warning` 无效（WRN/ERR 未映射 priority，只能文本 grep）；`grep -i quic` 被 quickbeat 等域名子串误命中须 `\bquic\b`；新版无 `Registered tunnel connection` 字符串。
- 关联 [[reference-cn-isp-international-routing-split]]（CN 集中先想 GFW 而非基础设施）。

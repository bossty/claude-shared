---
name: reference_cn_isp_international_routing_split
description: CN 三网国际出口路由分化——电信路由到 EU(法兰克福)、移动/联通路由到 CA(加州)；节点 ISP 分布按此天然分区
metadata: 
  node_type: memory
  type: reference
  originSessionId: 1c0cb80f-adb3-429d-b88b-1582724035c8
---

生产实测（2026-07-09，批 A 部署后 `nw_isp_resolve_total{result=telecom|mobile|unicom}` 逐节点）：**CN 三网用户按 ISP 天然分流到不同 region**：

| region | 节点 | 主导 ISP |
|---|---|---|
| **EU（法兰克福）** | eu-web-01/02 | **电信**（telecom ~39k 合计，unicom≈0，mobile 少量） |
| **CA（加州）** | ca-web-01..04 | **移动 + 联通**（mobile+unicom，telecom≈0） |

**根因**：CN 三网国际出口路由差异——**China Telecom（CN2/163 骨干）国际路由偏走欧洲**，**China Mobile/Unicom 偏走美西**——叠加 CF geo-steering/anycast，把电信用户 anycast 到 EU POP→回源 eu-web，移动/联通到 CA POP→回源 ca-web。各节点 IP→ISP 解析都正确，per-node 的 telecom=0（CA）/unicom=0（EU）**不是解析 bug 是真实路由分区**（曾一度误疑 ca-web-01 telecom=0 是异常，实为此）。

**用途/影响**：
- 判读 per-node ISP metric：CA 节点看不到电信、EU 节点看不到联通=正常，别当异常告警。
- 容量/负载规划：电信流量压 EU 两台、移动+联通压 CA 四台，扩容按此分区考虑（EU 承接全国电信、节点数少）。
- reach:grid 正确性不受影响（reach 按用户 IP 的 ISP×省解析，与哪个节点服务无关）。
- 全队真实 ISP 分布（sum）：mobile≈37k / telecom≈34k / unicom≈23k / other≈1.1%（兜底率健康），三网占比接近，无单一 ISP 独大。

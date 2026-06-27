---
name: 搬瓦工 HK 机房移动线路不可用
description: 搬瓦工 HKHK_8 只接电信 CN2 GIA + 联通，未接中移动 CMI/CMIN2，移动用户多地 100% 丢包，绝不能用作 Phase 0 S 入口
type: feedback
originSessionId: 93fa30d6-8acf-448f-9897-96d44dbb2453
---
2026-04-20 user 用第三方测评工具实测搬瓦工 HKHK_8（IP 94.103.4.113）三网可达性，结果：电信 0% 丢包（30-87ms 优秀）、联通 OK、**中国移动多地 100% 丢包**（北京、深圳、杭州、嘉兴、温州、佛山、承德等核心城市全部超时不可达，仅西藏拉萨 / 辽宁沈阳等少数地区通）。

**Why**：搬瓦工 HK 机房 BGP peering 只接 CN2 GIA（电信）+ China Unicom，**没接 China Mobile CMI / CMIN2 精品线**。移动用户走国际出口绕路，被 GFW 丢包。这是机房结构性短板，`Change IP` / 流量包 / DDoS 升级**都救不了**。

**How to apply**：
1. Newworld 项目面向全中国用户（移动占 35%+），**搬瓦工 HK 不能作为 S 层入口主机**——会导致 Phase 0 KPI "S.click → P.baidu_uv ≥ 95%" 直接不可能（35% 移动用户丢失）
2. Phase 0 最终采用**搬瓦工 LA DC9（USCA_9）× 2**（CT CN2 GIA + CMIN2 + CUP 三网直连），延迟 150ms 但覆盖完整
3. 未来 Phase 1 若要加 HK 节点，必须选**含 CMI 接入**的供应商：阿里云/腾讯云 HK（有身份风险）/ DMIT HKG Premium Profile 3（需实测）/ Gcore HK 等，**不再考虑搬瓦工 HK**
4. 任何"HK + 三网直连"宣传必须用 `ping.pe / itdog.cn / 17ce` 实测验证，不信文案

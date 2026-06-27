---
name: project-cf-china-edge-reality-2026-05-22
description: CF 中国边缘 POP 真实命中实证（CN 用户 HKG <0.3%，75% 在欧美 POP）+ RUM cfRay 改造 + 源站迁移决策树
metadata: 
  node_type: memory
  type: project
  originSessionId: f3a2d91b-21b8-418c-bfea-c15095c9585f
---

# CF 中国边缘 POP 真实命中调研（2026-05-22）

## 核心实证（颠覆性发现）

实证两台 aws-web 各 50k 行 web.log + cloudflared metrics：

- **中国大陆 CN 用户访问 HKG POP 占比 < 0.3%**（aws-web-01:1 + aws-web-02:2 / ~1000 CN 请求）
- **47% CN 在美西**（SEA 25% + LAX 23% + SJC 3%），**~28% 在欧洲**（AMS 28% + LHR 3.5%）
- cloudflared 3 实例（A/C/P 三 CF 账号）全部连 `hkg01/08/09/10/11/12/13` —— **出站正确就近行为**

## 真实三段链路

```
中国用户 → [跨洋海缆 150-200ms]    → SEA/LAX/AMS POP（user→远 POP）
                                       ↓
                                   [CF 跨洋 backbone 100-200ms]
                                       ↓  
HKG cloudflared <10ms ← HKG POP ← (CF 内部专网)
                       ↓
                    AWS HK origin
```

TTFB baseline ≈ 250-400ms（仅链路开销）。

## 反直觉真相（owner 务必内化）

1. **"cloudflared 连 hkg13/09/10 = 用户固定 HKG" 是错误推论**——两段是独立链路
2. **HKG POP 实际只服务 HK 本地用户**；大陆 CN 几乎全部被 ISP Anycast 丢欧美
3. **AWS 多 region 内网通信存在但绕不过物理光纤延迟**（HKG↔LAX 150ms 内网 ≈ 公网，TGW 不帮忙）

## RUM cfRay 改造（本次 patch）

| 文件 | 改动 |
|---|---|
| `openresty/web/openresty/nginx/conf/nginx.conf` | log_format main 加 `cf_ray` + `cf_country` + `cf_ip`（已 reload 两台 aws-web） |
| `frontend-web/src/utils/monitor.js` | `_cfMeta` + `probeCfMeta()` HEAD `/api/v1/analytics/quality` 读 cf-ray/cf-ipcountry，flush 时注入 `vitals.cfRay`/`vitals.cfCountry` |
| `newworld-web/src/main/java/org/earth/newworld/web/service/MonitorService.java` | recordVitals Redis record put `cfRay` + `cfCountry` 落 `monitor:vitals:{slot}` |

**Why**：实证只看 nginx 请求级 POP，关联不到用户 vitals。RUM 加 cfRay 后能切 POP × Country × LCP/FCP/INP/TTFB。

**How to apply**：未来分析"某 POP 用户体验"必看 `monitor:vitals:{slot}` Redis 哈希里的 cfRay。N9E dashboard 增 cfRay × cfCountry 切片是待办。

## R2 资源 POP 分析待选方案

R2 域（R_VID/R_IMG/R_PRV）直 CNAME 到 R2，**不经 OpenResty 无 nginx log 数据**：
- A. CF Dashboard Analytics — 0 改动现成
- B. HLS.js xhrSetup hook 读 ts/m3u8 response cf-ray — 视频路径
- C.（推荐）R2 域配 `Access-Control-Expose-Headers: cf-ray, cf-ipcountry` Transform Rule + 前端 probeCfMeta 加 HEAD R2 URL

C 与主域 RUM 同框架最对齐。待 owner 拍。

## 源站迁移决策树（owner "迁 AWS 欧美" 想法）

数据方向正确（CN 75% 在欧美 POP），但**不是"迁"是"补副本 + 智能路由"**：

| 方案 | 决策 | 理由 |
|---|---|---|
| Argo Smart Routing PoC（$155/月，5min 开关） | ✅ **先做** | 直接优化 CF backbone 跨洋段 -50~100ms |
| LAX/AMS 部署 cloudflared（origin 不变 HKG） | ❌ **不做** | cloudflared 跨洋回 HKG origin 比 CF backbone 更慢 |
| LAX/AMS 部署 web 副本（API 无状态，DB 仍 HKG） | ⚠️ 30d 数据后评 | DB 查询跨洋 +150ms × N 可能反慢 |
| 完整 region 化（web + R/O DB + Redis） | ❌ 超 100w DAU 阶段 ROI | 1-2 月 + 大成本 + 业务一致性方案 |
| R2 资源继续 CF 全球（现状） | ✅ 已完成 | 视频/图片已全球 anycast |

## HTTP/3 关闭判断（owner 复核要求）

D agent "强制关 H3" 过激。USENIX Security 25 实证 GFW 自 2024-04-07 起 block QUIC（58k FQDN 黑名单），但**仅命中黑名单 FQDN**被封，**非全网 UDP 443**。浏览器 H3 失败自动 fallback H2。**决策**：先看 RUM `protocol` 分布，>5% 失败率再考虑 CF Dashboard 关 H3。盲关牺牲非中国用户 H3 收益。

## cf_ray 末 3 字符 POP code 速查

cf_ray 格式：`<14位hex>-<3字符IATA POP code>`。`9ff97b6c0aad170b-LAX` → POP=LAX。awk 提取：`awk '{n=split($1,a,"-"); print a[n]}'`。

## 关键命令（运维实用）

```bash
# cloudflared 实际连接 POP（任一 aws-web）
ssh aws-web-01 'for port in 20241 20242 20243; do curl -s http://127.0.0.1:$port/metrics | grep "^cloudflared_tunnel_server_locations" | head -10; done'

# nginx log POP 分布统计（cf_ray + cf_country 已加，部署后即可用）
ssh aws-web-01 'sudo tail -50000 /usr/local/openresty/nginx/logs/web.log \
  | grep -oE "cf_ray=\"[a-f0-9]+-[A-Z]+\" cf_country=\"[A-Z]+\"" \
  | awk -F\" "{print \$4, \$2}" \
  | awk "{n=split(\$2,a,\"-\"); print \$1, a[n]}" \
  | sort | uniq -c | sort -rn | head -25'
```

## 待办 punch list

| P | 动作 |
|---|------|
| P0 | 24-72h 观察 cf_ray 数据按时段 + ISP 维度（晚高峰漂移） |
| P0 | R2 域配 `Access-Control-Expose-Headers` Transform Rule |
| P1 | `frontend-web` + `newworld-web` build & deploy 含 RUM cfRay patch |
| P1 | N9E vitals dashboard 增 cfRay × cfCountry 切片 |
| P2 | Argo Smart Routing PoC 1 月（主 A 域 17.rip） |
| P3 | 数据驱动决策 LAX/AMS web 副本（30d 后评） |

## 文档锚点

- `docs/CF_CHINA_EDGE_REALITY_2026_05_22.md` — 完整调研报告（含 4 agent 总结表 / 链路图 / 决策树）
- `docs/CF_ARGO_SMART_ROUTING_ROI_2026_05_10.md` — Argo PoC 前置评估（已有）
- `docs/RUM_VITALS_ANALYSIS_2026_05_11.md` — RUM 框架（已有）
- 关联 memory：[[reference_n9e_alert_pipeline]] / [[project_cf_speed_audit_2026_05_20]]

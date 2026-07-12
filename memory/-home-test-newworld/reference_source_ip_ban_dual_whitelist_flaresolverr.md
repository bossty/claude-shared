---
name: reference_source_ip_ban_dual_whitelist_flaresolverr
description: 爬虫源站按机房 IP 封禁 aws-ca 出口时，FlareSolverr 有两套口径不同的白名单必须成对配置；漏配 proxy-hosts=该源断供且触发熔断静默
metadata:
  type: reference
---

# 源站按 IP 封 aws-ca 出口 → FlareSolverr 双白名单必须成对

## 症状（可快速识别）
某个 region 的电影**突然从某时刻起零产出**（其余 region 正常），data 日志里该源 `FlareSolverr HTTP 500 elapsed~63000ms`（60s 超时）→ 回退本地 Playwright 拿到 `cf_chl_opt`/title='请稍候…' → 该 pool 连续失败 3 次 `SourceCircuitBreaker OPEN`（冷却 1h 整池跳过）。

## 根因：不是 FlareSolverr 坏，是源站把 aws-ca 机房 IP 拉进 CF managed challenge
决定性区分实验：**同一 FlareSolverr、同一 URL，仅加 BuyVM tinyproxy 出口（`http://209.141.48.177:3128`）即秒过 200**。裸 curl 该源（aws-ca IP）返 `HTTP 403 + cf-mitigated: challenge`。对 example.com / 其他源仍 200 → 服务健康，缺的只是干净出口 IP。

## 修法：`PlaywrightUtil.java` 有两套口径不同的白名单，必须成对
- `cf.bypass-hosts`（env `CF_BYPASS_HOSTS`）：命中才走 **FlareSolverr**（默认 hanime1.me,jable.tv,123av.com）
- `cf.flaresolverr-proxy-hosts`（env `CF_FLARESOLVERR_PROXY_HOSTS`）：命中才令 FlareSolverr 经 **BuyVM 干净出口 IP** 出网（`cf.flaresolverr-proxy-url` = tinyproxy）
- **陷阱**：一个源进了 bypass 但没进 proxy → 走 FlareSolverr 但仍从被封的 aws-ca IP 出网 → 断供。`resolveFlaresolverrProxy()` 对未入 proxy 白名单的 host 返 null。

止血=生产 `data.env` 加/改 `CF_FLARESOLVERR_PROXY_HOSTS`（备份+diff+重启 newworld-data，验 /proc/environ）；固化=改代码 `@Value` 默认值（否则重装环境丢 env）。熔断每小时冷却自愈，proxy 通后下一轮自然恢复，无需手动清熔断。

## 这是第三次同源复发（新增 CF 保护源时的 checklist）
javxx/123av（BL-44，见 [[project_javxx_ipban_revamp_2026_07_11]] / [[project_javxx_rediagnosis_pivot_supjav_2026_07_12]]）已两次同构，hanime1（BL-50，2026-07-12，anime/3d）第三次。**新增任何受 CF 保护的源到 `cf.bypass-hosts` 时，必须同时评估是否要进 `cf.flaresolverr-proxy-hosts`**——只要该源可能按机房 IP 封就得成对，别信"本地出口不受影响"的旧注释假设（该假设正是 BL-50 的过时注释、已被推翻）。

验证姿势：手动触发 `POST /crawler/xvideos/<slug>/crawl-single-test`（channel 源）看 `FlareSolverr 成功 httpStatus=200` + DB region 新增记录。BL-50 实证 id=118101（region=3d，200/4.6s）。

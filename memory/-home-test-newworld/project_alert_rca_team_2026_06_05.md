---
name: project_alert_rca_team_2026_06_05
description: 2026-06-05 三告警(Redis284/JS114.9%/API18.1%)多agent RCA团队——告警旁路N9E+CF504真实跨洋失败+CF数据集陷阱
metadata: 
  node_type: memory
  type: project
  originSessionId: 7a58073a-eceb-460e-aa52-8d8a7cd8302b
---

# 2026-06-05 监控告警 multi-agent RCA（5人团队交叉挑刺+全员通过）

owner 抛三告警(⚠️Redis 284 / 🔴JS错误 9117/7938=114.9% / 🔴API失败 18.1% 19816/109195)。组 TeamCreate `alert-rca`：4取证(monitor-analyst=N9E/redis-thread=Redis线程/multiregion=多区域/frontend-404=前端404) + 蓝军 reviewer，互发 SendMessage 挑刺不串轮次，lead 仲裁。档 `docs/sprint/_archive/2026-06-05-incident-alert-rca/`(SEED-EVIDENCE + FINDINGS-SYNTHESIS + agents/*)。

## 五数定性（全员签字+蓝军GO）
- **API 18.1%**：**非源站故障**(origin Tomcat 24h 5xx=0 + web.log 服务端失败0.10%)，但**含 ~6.6% 真实跨洋 CF-504**(详下)+1.5%良性abort+~8%纯客户端(adblock/CN neterr)。根因 fetch.js FIND-4(6-04 commit `65fff601`)接通 api_error/api_success 埋点(改前恒0)→16-20%"首次可测非新故障"；阈值 `API_FAIL_RATE_THRESHOLD`未随"死→活"重标定→上线即误报。**FIND-4是修复非病因，禁revert**(owner反诘揪出)。
- **JS 114.9%**：=errors/sessions 比值 9117/7938=1.15条/会话(SystemMonitorTask:300 sum events÷HLL count)，**非"114.9%会话炸了"**，>100%结构性成立。真JS错误但分桶严格(不含resource/ext/script-noise)。
- **snack 404〔P0真bug〕**：commit `5031db6a`(snack改名)把 cdn-url.js 引用改 placeholder-snack.svg 但**没建资产**，线上dist仅旧 placeholder-ad.svg。双层根因=资产缺失+config-bootstrap-race冷启动窗(snack `<img>`在池播种前渲染→兜底撞缺失SVG)。**无onerror fallback→用户真见裂图**。量级=今日单台~2.7万(626万是error.log累计3天未轮转)。独立 `monitor:resource-errors`桶**不污染JS/API告警**(源码+key schema双证)。
- **Redis 285**：6-04多区域Phase0引入(US/EU web写池100跨洋连HK master+复制链14=114/40%)，**良性**(0 blocked/16397 ops/maxclients64000/timeout_disconnects=0)，7天逐日avg/max平台+IP对称双证**阶跃非泄漏**。告警真源=`SystemMonitorTask:267`硬编码`connected>200`实时读，阈值未随多区域基线上移。

## ★三个可复用方法/教训
1. **CF 5xx/超时分析必用 `httpRequestsAdaptiveGroups`，禁用 `httpRequests1hGroups`**：lead 首拉 1hGroups 得 /api 504=0、5xx仅417→差点误判 monitor 的 504=6.64% 是错的；换 adaptive 复跑得 167,014(6.64%)与 monitor 167,262 精确吻合。**1hGroups 的 responseStatusMap 漏报 CF 自身生成的504(origin超时类)**。铁律「多agent数据冲突禁选边+独立二查」救场——纠的是 lead 自己。CF token 在 system_config.CF_API_TOKEN_A，zone 17.rip=c160c3791b0eacc1db7f3690b286aa8c。
2. **三告警全部旁路 N9E**：admin `SystemMonitorTask`(@Scheduled)读 Dragonfly `monitor:*`桶+自有连接实时读，**直发 Telegram 不经 N9E**(alert_rule/cur/his 三表穷尽0匹配)。告警读**单个上一个完整5min槽**(非聚合非夜间窗)。→ 排查告警先确认它从哪来，别默认 N9E。N9E栈在 aws-monitor(16.163.94.193):n9e:17000+VictoriaMetrics:8428+mysql n9e_v8。
3. **CF-504=6.6%是真问题非纯噪音**：无520-523(tunnel没断)=纯 origin 响应超时(504 Gateway Timeout)，源站不记所以 origin 5xx=0 但用户真见失败。根因=**跨洋HTTP网络腿**(CF Anycast CN 75%绕欧美POP+cloudflared tunnel tax)，同 [[project_peak_perf_debate_2026_05_29]] 母问题。**关键区分**：多区域排除①主因仅指 **replica读路由**(主站HK不走跨洋Redis读)，**不含跨洋HTTP网络腿**(6.6%根因正是它)。

## 修复分级
- P0 补 placeholder-snack.svg；P1-a 重标定阈值(API 0.10→~0.25/Redis 200→~450可配)止误报；P1-b api_error补status/duration子桶拆6.6/1.5/8(现有CF-504 ROI依据)；P1-c CF-504跨洋超时优化(接5/29 debate CF Argo/cloudflared multiplex)；P2 JS top源+replica-fallback池条件化+redis指标断采32h修复。

## 监控体系3 gap
告警旁路N9E硬编码阈值未标定 / api_error无status子桶(16%拆不出) / `redis_connected_clients`指标6-04 18:33后断采32h。

web access log 是 `web.log`(50GB)非 access.log(0字节空)。多源对账金标：app埋点 vs nginx web.log vs origin Tomcat http_server_requests vs CF edge adaptive，四源交叉。

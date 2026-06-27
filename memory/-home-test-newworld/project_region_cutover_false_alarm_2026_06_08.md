---
name: project-region-cutover-false-alarm-2026-06-08
description: 第二次多region全量切换"出问题"RCA：告警是已知慢性artifact(非真故障)+真缺陷是region数据层跨洋(DB指HK,cache-miss 571ms)；客户端遥测口径陷阱+region就绪门禁缺失
metadata:
  type: project
  originSessionId: 64b5f5d1-9590-4971-9f5b-8d2e351a83eb
---

# 第二次多 region 全量切换"出问题" RCA（2026-06-08）

**两件被混在一起的事**（专家 agent 团队 nw-region-ha-arch 5 人分诊+蓝军定）：

## ① 告警(25%API失败/90%JS错误) = 已知慢性【告警虚报】，非真故障
- **铁证**：`SystemMonitorTask.java` L50-52 注释(commit d6427847 / **2026-06-05**,事故前3天)：api-fails 含 status=0 客户端失败(导航abort/CF跨洋/adblock),源站5xx=0,**混合基线长期~16%**,阈值已 0.10→0.25 专为压它。今晚19-28%在带内抖动,非跃升。
- origin真实5xx(3h窗):US=0/EU=1。蓝军经CF合成测10域×端点×3=**100% 200**,报"失败"的asset URL逐个curl全200。
- 分子:真4xx/5xx<5%(仅1条瞬时503);95%是status=0(`fetch.js:54-68`把AbortError/导航取消/adblock/超时/CN移动丢包全计入,schema不可分)。"90%JS"里真业务JS仅~17%,83%是console.error("[API]...Failed to fetch")**二次记账**灌进js-errors。受众高度CN移动/WebView(status=0天然高发)。
- → **"每次切换都看起来在炸"的元凶=客户端遥测指标在CN移动基线上一抖就触发告警。**

## ② 真·结构缺陷(切换暴露,和fullcut-5xx同类下移一层)
- **region web 的 DB/Redis 仍跨洋指 HK**:`/proc/<webpid>/environ` DB_HOST=REDIS_HOST=**172.31.19.174**(HK);region本地无3306/6379监听。读写全跨洋141ms。
- **cache-miss=571ms(死常数≈4×跨洋)**:courses/search HK 3ms vs US region 571ms;feed/v2(已缓存)两边5ms。round4/5/6缓存只覆盖热端点=打地鼠,search/冷/长尾/新端点仍付全额跨洋税。
- serving层(dist e83a1a6a字节级一致/chunk全在盘/upstream本地primary)已对等→前端chunk错误不是region发坏bundle,是客户端(adblock/网络)+冷路径慢叠加。
- **只有全量切暴露**:小流量多命中缓存;全量切→冷门请求量级上来→cache-miss绝对量爆炸→571ms大规模→叠加CN→CF边缘慢→超时abort。

## 元失败(两次切换共性)
fullcut-5xx(06-06):region OpenResty upstream写死HK→跨洋5xx。本次(06-08):region DB指HK+缓存覆盖率≠所有端点。**共性=跨洋延迟落请求线程+region上线无"与HK行为对等"就绪门禁,切了才发现没准备好。** 详见 [[project-fullcut-5xx-rca-2026-06-06]]。

## main session lead 自己的误判(沉淀防再犯)
1. 先当噪声→又当真故障→团队拉回。**客户端遥测先验真伪(CF合成实测+看埋点口径代码)再定性。**
2. **"region读本地replica、replica I/O饱和导致慢"=错**。region没连本地replica(DB_HOST=HK)。replica I/O饱和真实(已EBS扩容)但**不在用户读路径**,治了跑题问题。**结论前必查数据流真实指向(/proc/environ),别凭架构意图假设。** 见 [[project-region-replica-io-saturation-2026-06-08]](已加纠正)。
3. 监控loop只查服务端→对客户端指标全盲,"全绿"是侥幸(但客户端指标本身artifact,危害小于一度担心)。
4. 半回滚看rate被分母骗(总量↑37%稀释),**看绝对失败数**(恒定→region路由非主因)。

## 处置+修复
- 已执行:A域全撤回HK(62条PATCH+verify OK,canary残留0)。机制=CF API(token system_config CF_API_TOKEN_A,各A域own zone apex+wildcard CNAME tcos-canary→tcos.dnsv106.com)。
- 修复优先级:**P1流程**=region上线"与HK对等"门禁(upstream本地✓/DB·Redis本地✓/cache-miss RTT≈HK✓/serving对等✓);**P1结构**=region web读路由本地replica(replica已在+I/O已改善,差接线);**P2告警**=修fetch.js status=0分类+console.error别灌js-errors+告警numerator改用origin 5xx。
- skill候选:newworld-region-cutover-readiness-gate + newworld-client-telemetry-artifact。

**全量状态锚点**:docs/sprint/2026-06-08-region-final-migration/INCIDENT-RCA-2026-06-08-cutover-falsealarm.md(SOT)。N9E查询:VictoriaMetrics 127.0.0.1:8428(n9e:17000是SPA)。redis monitor密码:secrets.env REDIS_PASSWORD与systemd runtime可能不同,必要时用/proc/$(pgrep -f newworld-admin)/environ。

---
name: project-fullcut-5xx-rca-2026-06-06
description: 2026-06 全量切多 region 28% 5xx 的真根因(OpenResty upstream 写死HK)+后续 round4/5/6 请求线程跨洋残留全闭环
metadata: 
  node_type: memory
  type: project
  originSessionId: 64b5f5d1-9590-4971-9f5b-8d2e351a83eb
---

# fullcut-5xx-fix sprint（2026-06-06 起，2026-06-07 主体闭环）

**起因**：多 region 全量切（方案2）后 region 28% 5xx（06-06 06:39-17:04）+ 大量域名健康度下降，回滚止血（全 HK）。

**真根因（tcpdump 三角印证，非最初以为的"同步跨洋写"）**：region(US/EU) OpenResty `upstream nw_web` 从 HK nginx.conf 整段拷来、仍指 HK 两台 web 节点 `172.31.27.120/121:7777`。region "web 节点"实为到 HK 的**哑代理**——每请求跨洋到 HK tomcat 处理，region 本地 tomcat(3ms)零流量。全量切→全球请求处理全压 HK 仅 2 台 tomcat→线程池耗尽→5xx。**ping HK=142ms(US)/190ms(EU) 与 uht 完全吻合**。同根还导致 organic_rate=1.0 告警（度量该指标的 region tomcat 只收到健康检查流量，全判 RESERVED_OR_INVALID）。

**修法链（均已部署 US/EU region，HK 待全量推广随上）**：
- upstream 改 `127.0.0.1:7777` primary + HK `backup`：uht 144/190ms→ms 级，tcpdump 跨洋包 52→0。
- round1 coalescing(StatsCoalescingBuffer)：写合并离请求线程。
- round4 `analytics/quality`：recordErrors 改 @Async（per-error bulkhead gate future.get(1s) 循环致 max 4.975s）。
- round5 `snack/list`：Spring 自调用旁路 @Cacheable+@Transactional → 抽 self-proxy（3.14s→ms，零缓存命中铁证：同 slug×5 全 571ms）。
- round6 `/settings`：domainMapper(+promotionChannelMapper) 未缓存+无 readOnly → 抽 `SettingsReadCache` @Component(readOnly+Caffeine)；getFullConfig 去 @Transactional(原误置=Redis 写落 readOnly 事务违铁律)。0.58-0.83s→ms。
- 3val(round2/3 旧 commit 回溯)：F2 修 FvdRedisFallbackService seenCache 占位时序(DiscardOldest 静默丢任务致 fvd 丢失)。

**最终态**：region p50 144ms(全跨洋)→2-3ms；US p99 1.99s→0.3s；EU p99 0.77s→0.33s。残留 p99~0.3s = GC pause(间歇共享 stall) + 内容端点冷缓存长尾，非结构性跨洋。

**方法论教训（已沉淀 skill [[newworld-multiregion-crossocean-hotpath]]）**：
- 「in-HK 隐形/region 跨洋放大」是一整类 bug（round4/5/6 同根）。
- **诊断只信运行时证据**：代码 grep 喊"100% 根因"反复错（recordIfNew 早已 async / OTel 跨洋 span 实为 bulkhead 非热路径 / fvd"146ms"实测 4ms 是冷启误判）；curl 直连/tcpdump 端口拆分+对照/uht 百分位/scales-with-N 才定真相。**对自己假设也先证伪**。
- 蓝军 crossfire 不可替代：qa 测试全绿 ≠ 正确（round6 readOnly+Redis 写测试绿却违铁律，蓝军抓出）。

**文档**：`docs/sprint/2026-06-06-fullcut-5xx-fix/`（ROUND2-3-...-SESSION-STATE.md 总锚 + ROUND4/5/6 + CANARY + agents/reviewer-*.md）。

**待办**：① 全量推广（恢复 tcos 完整 geo steering + HK 上 round4/5/6+F2 jar，drain 重启防 POST 5xx）；② GC 调优(可选,压 p99)。

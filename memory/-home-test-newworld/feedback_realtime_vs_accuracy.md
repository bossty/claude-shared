---
name: feedback_realtime_vs_accuracy
description: "owner 铁律:统计数据\"不要求实时性\"≠\"不要求准确性\";降本可放宽实时(批量/异步)但禁有损采样"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 9532d6aa-c746-4dc8-9e64-aaed3bb1448b
---

2026-06-15 beacon 降本 sprint,owner 说"snack 仅统计用、不挂实际收益、不要求实时性",我误推成"可有损采样(带权重还原)"。owner 纠正:**"我只说不要求实时性,没说不要求准确性,不要误解。"**

**Why**:统计数据(snack 曝光/点击、PV/UV、渠道归因)要求**准确**。有损采样即便带权重还原(w=1/sr)也是**无偏估计但有方差**——低频项(某 snackId 只展示 3 次)会严重失真。统计失真 = 业务决策依据失真。

**How to apply**:
- **降本杠杆区分数据性质**:
  - **统计数据**(snack/PV/UV/渠道):放宽**实时性**→ 精确批量 / 异步缓冲 / 延迟聚合(请求数↓、数据**零丢失**);**禁采样**。
  - **诊断数据**(redirect-trace 路由轨迹 / inline-error / RUM quality):可采样(丢几条诊断可接受),但 redirect-trace owner 仍选"成功采样+失败全留+计数还原"(option c)保审计计数。
- 听到"不要求 X"先确认 X 具体指什么(实时性?准确性?完整性?),别跨维度推断。owner 明确点名"不要误解"=我跨维度误推了。
- 精确批量实现:客户端按 key 精确去重/累计 + 放大 flush 窗口(pagehide+长定时)合并请求,sendBeacon keepalive 保卸载不丢。

关联 [[feedback_verify_not_recall]](凭推断当真相)、beacon sprint docs/sprint/2026-06-15-beacon-cost-reduction。

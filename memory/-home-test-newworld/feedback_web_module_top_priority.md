---
name: feedback_web_module_top_priority
description: owner 铁律——任何情况下 web 模块（用户前台）永远第一优先，处置/汇报先确认 web 状态
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 64b5f5d1-9590-4971-9f5b-8d2e351a83eb
---

owner 铁律（2026-06-12 Phase D cutover 事故中下达）：**任何情况下都要优先 web 模块**。

**Why**：web 是用户前台（newworld-web + frontend-web，扛真实流量），admin/data 是后台。事故/cutover/排障时，必须**第一时间确认 web 状态并向 owner 报**，再处理后台。Phase D split-brain 事故中，lead 埋头修 aws-data admin，没先向 owner 确认"web 全程安全"（web 5 节点一直在 HK master、站点 200、没进 blast radius），被 owner 批"分不清楚优先级"。

**How to apply**：① 任何生产事故/变更，先查 + 先报 web（站点 curl 200 + web 节点 DB/服务态 + 写路径），再动后台。② 多目标抢资源/时间时，web 可用性 > admin/data > 监控。③ 回滚/收尾/高危操作排序：先保 web 不受影响，后台/replica/redis 收尾让位于 web。④ 汇报结构：永远先给 web 结论（健康/受影响+证据），再讲其他。关联 [[feedback_master_cutover_incident]]。

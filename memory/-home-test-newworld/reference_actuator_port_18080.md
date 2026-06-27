---
name: reference-actuator-port-18080
description: admin/web 健康检查真信号在 :18080 actuator，不是 :8888 主端口（:8888 对未映射路由假 200+body404）
metadata: 
  node_type: memory
  type: reference
  originSessionId: 64b5f5d1-9590-4971-9f5b-8d2e351a83eb
---

健康检查端口语义（2026-06-12 admin DB 全断事故二查时钉死）：

- **:8888 = app 主端口**。对**未映射路由统一返 HTTP 200 + body 内 `{"code":404,"message":"Resource not found: ..."}`**。所以 `curl :8888/actuator/health` 看 HTTP code 永远是 200 = **假信号**，不能用来判活/判 DB 连通。web 主端口 :7777 同理需警惕。
- **:18080 = 专用 actuator 管理端口**（独立 java listener）。`curl :18080/actuator/health` 返**真** `{"status":"UP"}`。admin 和 web 都有这个端口。**cutover 脚本的健康门用的是 :18080**，可信。

判 admin/web DB 连通性，**权威证据用**：① :18080 actuator/health 真 UP；② `HikariPool-N - Start completed`（auth 失败永远到不了这行）；③ `ss -tnp ESTAB` 实连目标 DB :3306 + redis :6379 条数；④ 定时任务真写实锤（如 SiteStatsSyncTask N/N、new_visitors 回填维度）。**别用 :8888/:7777 主端口的 /actuator/health**（假 200）。

关联事故：admin 误建 datasource.conf 指 .239 致 DB 全断，见 [[feedback_master_cutover_incident]]。诊断铁律见 CLAUDE.md「健康检查告警≠真故障」。

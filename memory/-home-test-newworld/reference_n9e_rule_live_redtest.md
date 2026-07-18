---
name: reference_n9e_rule_live_redtest
description: N9E 告警规则「落库 disabled=0 + PromQL 正确」不证明 engine 真会 eval；live 红验证法=临时压阈+for=0 看 alert_cur_event 真出事件再逐字还原
metadata:
  type: reference
---

**PromQL 在 VM 上跑对 ≠ N9E engine 真在 eval 这条规则。** 本项目前科：规则 108 曾 `disabled=0` 却因 PromQL 恒 0 永不触发；134 至今 `disabled=1`；`datasource_queries` 为 NULL 时 engine 直接不 eval（见 [[reference_n9e_dashboard_alert_internals]]）。**告警失效是静默的**——你永远不会发现（[[feedback_gate_redgreen_and_failsafe_direction]]）。

**live 红验证法**（2026-07-17 BL-15 实跑，规则 142）：
1. 备份原值：`SELECT CONCAT(prom_for_duration,'|||',rule_config) FROM alert_rule WHERE id=<id>`，**用它机械生成还原 SQL，禁手敲**。
2. 临时 UPDATE：阈值压到必触发水平 + `prom_for_duration=0`（否则要等满 for 才触发）。
3. 等 ~120s（`prom_eval_interval=15s`），查 `SELECT * FROM alert_cur_event WHERE rule_id=<id>` —— **真出事件 = engine 确实在 eval**，这是唯一决定性证据，engine 日志平时不记 eval 故证明不了。
4. 逐字还原，再验：`cur_event=0`（绿在 live engine 同样成立）、`his_event=2`（告警+recover 各一条，`notify_recovered=1` 生效）、DB 回读 prom_ql 与验证过的表达式 `diff` 零差异。

**副产的既存缺口**：BL-15 之前，edge pick 告警链路（VM→engine→事件）**从未被 live 验证过**——136/137/138 稳态恒 0，从没真触发过，若链路早断它们全是摆设。**凡「稳态恒 0」的告警都该做一次 live 红验证**，否则它是不是活的纯属信仰。

**局限（诚实记录）**：只证到 engine 生成事件 + `notify_rule_ids` 配置正确；Telegram 端是否真收到无法在服务器侧证实。

改生产 N9E DB 前置：Owner 授权（[[feedback_owner_approval_all_deploys]]）；SQL 含反引号时**必 scp 传文件**，禁未加引号的 ssh heredoc（会当命令替换执行）。

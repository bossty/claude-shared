---
name: V6 D 档迭代档（2026-04-27 Owner 拍板）
description: V6 从 38 决策 28.75d C 档改为 D 档（V6-精简 5d + 60d 观察 + V7 数据驱动）
type: project
originSessionId: cff1eb9c-f1fd-4a7d-9d6d-249290b9d358
modified: 2026-07-22T11:49:35.327Z
---
V6 sprint 从 C 档（38 决策全做 28.75d）改为 **D 档**（迭代档）。Owner P9 review 拍板。

**Why（Owner 决策理由）**：
1. 38 决策产生路径有偏差 — 5 轮蓝军 + 27→35→38 滚雪球，每轮加新决策没一轮做减法（蓝军 bias）
2. V5.1-B 实测信号 — 拆 3 sub-sprints 不是因为功能多是因为一锅炖派不动；V6 35d 单 sprint 派工预期失败 2-3 次
3. 80/20 法则 — C 档比 B 档多花 13d 解 1-5% 长尾问题，UV 虚高 30% 这种核心问题 B 档已含

**How to apply**：

V6 sprint 派工时按 D 档 plan：

V6-精简范围（5d critical path）：
- HD2 visitor_alias 表激活（解 UV 虚高 30%，4d）
- HD8 acme.sh 双签兜底（业务存亡基础，2-3d）
- HD1 cross-root cookie HMAC（V5.1-B.1 已 ship 0d）
- α + β 并行 + γ 蓝军真握手 1d 串行

V7 候选（60d 观察期触发条件命中才做）：
- C-1 HD13 cdn_prefix saga（5d）— acme 月限速 ≥ 3 触发
- C-2 HD25 回家邮箱（1d）— 雪崩 chain ≥ 月1 触发
- C-3 HD27 客户端协调（5d）— 多 tab bug ≥ 月5 触发
- C-4 HD20 _rp 5 字段（1d）— HMAC replay ≥ 0 触发
- C-5 HD22 _fvd redis（0.5d）— _fvd_ts 失效 ≥ 5% 触发
- C-6 F1 saga + F3 redirect-trace（3.5d）— C-1 配套 / 可观测性自发

**真相源**：`docs/design/wave_stats_v6_sprint_plan_d.md`（D 档完整规划）+ `docs/design/wave_stats_v6_p9_consolidation.md`（38 决策原始历史档案保留）

**Tasks**：#4 P7-V6-α（visitor_alias）/ #5 P7-V6-β（acme 双签）/ #6 P7-V6-γ（蓝军+集成）/ #7 V7 候选观察期 60d。

## 🚨 状态更新（2026-05-02 P8 复核）

V6 sprint **实质已收口**，V7 已启动并做了一大半：
- **HD2 visitor_alias** + **HD8 acme 双签**：4/27 当天即完成（commit `bc284c66 feat(stats-v6-α+β)` + `a8c1be40 feat(stats-v6-γ)`）
- **60d 观察期被砍**：commit `541be478 feat(stats-v6-e2e)` 替换为"3d E2E 验证框架 4 块全交付"——是否 owner 拍板需 review
- **V7 sprint 已启动**：commit `e963e9dd feat(stats-v7-A+coord)` 已做 C-2/C-3/C-4/C-5；C-1 单独 redo（`docs/design/wave_stats_c1_redo.md`）
- **sprint_closure 文档已写**：`docs/design/wave_stats_v6_sprint_closure.md` + `wave_stats_v7_sprint_closure.md`
- **V6-γ 留尾巴**：nginx env typo 已修（fec6e99a + 9ac05278），但 V5.1-B 完整 cutover（nginx-web.conf 切主 + hmac_secret_agent.init）仍未做；AnalyticsV5Metrics 看似已分拆但需 owner 确认；aws-s git credential 状态不清

~~**派工铁律**（2026-04-27）：可用 `pua:senior-engineer-p7` 或 `general-purpose`~~ —— **2026-07-22 失效**：`pua:*` agent 系列早已退役，现行派工走 plugin 的 `newworld:dev-senior`/`qa-senior`/`ops-senior`/`reviewer`，见 skill `newworld-sdlc-agent-team`。

## V5.1-B cutover 完成（2026-04-27）+ V6-γ 留尾巴

V5.1-B 三 sub-sprint cutover 已上线（commits 9c0c24d6 / bec50453 / 634e3d44 / c27157de）。Java 层 G5+G6+verify bug fix+302 redirect 完全生效（smoke step 1/5/6/8 全绿）。

**P7-V6-γ 必处理的 cutover 留尾巴**：
1. `nginx-web.conf` 死文件 — 主 nginx.conf 不 include 致 hmac_secret_agent.lua / retry_token.lua / host_channel.lua RETRY 真死代码。**不影响 user-facing**（Java 层独立工作）但 edge metric 缺。修法：inline 到主 nginx.conf 或真 include + systemctl restart（不 reload，pubsub 协程铁律）
2. nginx.conf init_worker_by_lua_block 加 `hmac_secret_agent.init()` 调用（参考 v5 既有 s_channel_agent 模式）
3. aws-s git credential store 配 HTTPS token（本次 cutover scp 绕过 git pull 失败）
4. **AnalyticsV5Metrics nw_probe_rate / nw_organic_rate 模块错位** — P7-V5.1-B.3 把它们放 newworld-admin，但 IdentityInterceptor 4 Counter 在 newworld-web 的 MeterRegistry → admin 读不到 → metric value 永 0 → N9E rule 35/36 永不真触发（不假报但残废）。修法：移到 newworld-web 模块（IdentityInterceptor 旁），让 categraf 抓 web actuator

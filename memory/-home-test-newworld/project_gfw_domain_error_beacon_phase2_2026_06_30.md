---
name: project_gfw_domain_error_beacon_phase2_2026_06_30
description: GFW 阶段2=前端 cdn-failover→domain-error beacon 桥接(修 domain:err 断流)；根因=后端 DomainErrorController 完整但前端从未接线(git 全史无 sender)；只桥真实单域失败 reason(no_backup/switched_to_backup/probe_all_fail)→sendBeacon→domain:err；天然 dark 但要数据须部署；feat/gfw-domain-error-beacon off master 本地未 push，待部署看数据+授权
metadata: 
  node_type: memory
  type: project
  originSessionId: 38bc7039-317e-414c-ae1d-f170c05cfdf4
---

# GFW 阶段2 — 前端 domain-error beacon 重接（2026-06-30 完成）

承 [[project_gfw_reach_read_layer_phase1_2026_06_30]] / [[project_gfw_pickp_reach_cutover_3a_2026_06_30]]。roadmap（`2026-06-29-...-design.md` §5）阶段2「接通被动生产源」。完整 SDLC（brainstorm→spec→plan→subagent-driven）。

## 断流根因（fact-check 坐实，非照抄 spec）
- 后端 `POST /api/v1/analytics/domain-error`（`DomainErrorController`，newworld-web）**早已建好且精密**：active 白名单校验 + 服务端解析 isp/省（用户真实 IP）+ 写 `domain:err`/`pv`/minute/sample_cnt + 1/100 落 MySQL + overseas 短路。
- **前端从未接线**：`git log -S "domain-error" -- frontend-web` 全空 = 从来没建（非删除）→ domain:err 断流空（P0 实测 0）。
- 前端 `cdn-failover.js` 已检测 CDN 域故障（切备用域）但事件只灌 monitor telemetry（`cdn_failover` 桶），没 POST domain-error。

## 决策（Owner，2026-06-30）
- **目标**：最小桥接、**先打通管道看真实数据**，再决定扩 P 域 / 阶段4 融合（证据驱动）。
- **范围**：仅把 cdn-failover 已有检测桥到 beacon；不做 P/A 页面域上报、不做阶段4 融合、不拆聚合事件、后端不改。

## ★定位（2026-06-30 Owner 纠正我的误判）
- **本阶段 = CDN 资源域(B)的用户报错可观测**：cdn-failover 检测 B 域故障 → domain:err。消费方 `/ops/domain-health`。独立有价值，Owner 定保留。
- **★它不是阶段4 融合的 RUM 输入**（我先前误判作废）：阶段4 融合是「**同一批同用途域(P/A) 的多个数据来源**」揉一起抗单源+幸存者偏差——源是 **reach:grid(admin 拨测) + domain:report(前端 SW 探活)**，对象是 P/A 同用途域。**domain:err(B) 跟融合无关**，B 域不在融合范围。先前"域集合错位/阶段2 对融合价值有限"的表述是**把 domain:err 错当融合输入**导致的，已作废。
- 幸存者偏差（仍成立、但属 domain:err 本身性质）：domain:err 只能从成功加载的页面发出，捕获不到"整域被封用户到不了"——这是 B 域报错信号的固有局限，与阶段4 融合无关。

## 产物（分支 feat/gfw-domain-error-beacon，off origin/master @25aadc22，本地未 push）
5 commits：spec `af38ae56` + plan `2df4e492` + **Task1 `ea808f88`** + **fix `a83bebaa`** + **M1/M2 polish `522a1f02`**。
- **改动仅** `frontend-web/src/utils/cdn-failover.js`（+ 测试）：
  - `_reportDomainError(domain, errorType)`（导出）：校验单域（`^[a-zA-Z0-9.-]+$` **且含 `.`** 挡聚合串 "3roots"）+ length≤128 + 会话内 `(domain,type)` 去重（`_domainErrSeen` Set）+ `navigator.sendBeacon('/api/v1/analytics/domain-error', Blob JSON {domain,error_type,ua})`（同源 application/json，无 preflight）+ navigator/sendBeacon 缺失或抛**静默吞**。
  - `_reportFailover` 末尾对 **3 个真实单域失败 reason**（`no_backup`/`switched_to_backup`/`probe_all_fail_keep_active`）调 `_reportDomainError(host,'fetch_fail')`。聚合 host 事件（sni_block_suspected/all_domains_unreachable/partial_root_timeout）**不桥**（reason 门控 + 域校验含点 双层挡）。
- 后端零改动。

## 验收
- 前端 `npx vitest run` 全量 **904/904** + 聚焦 beacon **7/7**（first-hand）。
- 蓝军 3 轮（Task1 + Task1-fix + final whole-branch）均 Approved/Ready-Yes，0 Critical/0 Important。
- payload 契约对齐后端（`ua` 后端 `persistSample` 真用于 UA 族别；`error_type=fetch_fail` ∈ 白名单；域 pattern 等价）。
- TS-checker 对 JS 文件的 import.meta.env/implicit-any/spread 噪声非本 diff 引入、非真问题；lint-staged 对暂存文件 eslint --fix 通过（全repo lint 崩在 CLAUDE.md 是预存在）。

## ★已部署（2026-06-30 HKT 13:22，Owner 授权 push+部署看数据）
- 分支已 push origin；`scripts/deploy-frontend.sh web` 部署到 **6 节点全成功**（ca-web-01/02/03/04 + eu-web-01/02，atomic switch，s.dat 有效，chunk-prune active_safe=yes）。部署从 worktree 跑（LOCAL_REPO 由脚本自身路径推导=本 worktree 我的分支码，非 /newworld 主树）。
- 验证：ca-web-01 deployed `dist/assets/` 含 `analytics/domain-error` 字符串 = beacon 码已上线（version.js 内容哈希 32d4e531，非 git SHA 属正常）。
- **部署后即时 baseline（HKT 13:23）：`domain:err:*`=0 / `domain:pv:*`=0**（断流态确认）。bridge 现 live，等真实用户撞 CDN 故障累积数据。
- **仍未合 master**（feature 分支部署中，看数据 OK + Owner 授权才合）。
- **Owner park 阶段2（2026-06-30）**：部署后保持现状，不轮询；domain:err 数据**晚高峰(HKT 20:00+)或任意时点 Owner 叫了再只读复查**（baseline=0，看增长 + 域名真实性 + unknown_domain 对齐）；合 master 待数据 OK + 授权。
- 部署副作用注记：`rm /newworld/web-sourcemaps/*.map Permission denied` 非致命（旧 sourcemap 归档 prune、别用户属主，cosmetic），部署 DONE 成功。

## ★状态 + 与其它阶段不同的关键点
**代码完成 + 全绿 + 3 轮蓝军 + 已部署 6 节点（baseline 0，待数据累积）**。
- **阶段2 不是 dormant flag，而是"天然 dark"**：beacon 只在真实 CDN 故障时才发、平时零流量、无 UI/行为风险——但**要拿到 domain:err 数据必须先部署**（"看数据"是目标本身，不部署就永远验证不了）。
- 待 Owner：feature 分支部署（走 `deploy-frontend.sh`，禁手跑 npm run build）→ **看数据（spec §7）**：① `domain:err:*` 真有增长（ca-redis-master 只读抽样，同 3a 手法）② 后端 `rejected:unknown_domain` 占比——若高 = 失败 host（含子域）↔ domain 表 domain_name 口径不齐，需对齐（归一 root / 补白名单）→ 授权才合 master。

## 后期（按数据再定）
host↔白名单口径对齐；error_type 按 reason 细分；聚合事件按 root 拆上报；扩 P/A 页面域可达性上报。
（注：阶段4 融合**不依赖本阶段**——融合源是 reach:grid[拨测]+domain:report[SW 探活]，不是 domain:err；见 [[project_gfw_consolidation_2026_06_29]] 与阶段4 设计。）

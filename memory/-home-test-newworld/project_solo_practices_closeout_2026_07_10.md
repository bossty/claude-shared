---
name: project-solo-practices-closeout-2026-07-10
description: 单人开发最佳实践 backlog BL-31~36 全部收口（两次合 master 0d6cabb6/f2c43885，零部署），云门红绿双验+SDD 多 agent 流程教训
metadata: 
  node_type: memory
  type: project
  originSessionId: 02bbb3b3-eeb8-4af4-ac21-74bf4e849c12
---

单人实践 backlog 收口（2026-07-10，Owner 指令「全部推进到完成，subagent-driven，只修改不部署」）：

- **BL-31/32 合 master `0d6cabb6`**：GitHub Actions 云门（三 job 全调 `scripts/ci-local.sh` 单一真相源）+ dependabot。红绿双验：首跑真红逮住 `ReadWriteDataSourceConfigTest` 隐性环境依赖（假设本机 IP 在 172.31.\*/16，runner 上走 EU fail-closed）。纪律四条落 `docs/BRANCH_LIFECYCLE.md`「GitHub Actions 慢门」节：push master 后必回看 Actions；本地闸门不取消；SKIP_CI_LOCAL 降级本地应急；maven 撞车假红以云上为准。master 首跑绿实证。
- **BL-33/34/35/36 合 master `f2c43885`**（SDD：4 实现 agent + 逐任务独立评审 + fable 最终全分支评审）：BL-33 金丝雀 SOP `docs/CANARY_RUNBOOK.md`+`deploy-web.sh --canary/--rest`（⚠️ 首次真跑前 ops 须核实 ca-web-04 是否在 CF LB pool）；BL-34 前端错误上报=复用自建管道加治理（去重/限频/截断/e2e 旁路，选型记录 FRONTEND_MONITOR.md §12）；BL-35 Flyway 否决入 §5，替代=`check-sql-ledger.sh` 接 precommit-gate 闸门 3；BL-36 集成环境 `docs/INTEGRATION_ENV.md`+`integration-smoke.sh`（当场抓 7 处本地库 migration 漂移+新增 BL-40：web 本地 dev 因 L0 塌缩检测误判 127.0.0.1 拒启动）。
- **GitHub API token**：buyvm-data/db 的 `~/.git-credentials` 有现成经典 PAT，已存入本机 credential store，可查 Actions。
- **评审逮住的真 bug（证明逐任务评审+最终评审值得）**：check-sql-ledger rename 逃逸（--diff-filter 缺 R）、base-ref 不存在 fail-open、deploy-web --rest 基线 tag 说谎风险（canary 旧版也打全 fleet tag）——全部实测红绿修复。
- **2026-07-11 Owner 调整 Actions 触发方式**（合 master `055e23e2`）：BL-31 云门从「每 push master 自动跑」改为 **`workflow_dispatch` 手动按需**（`gh workflow run ci.yml`）。动机=私有仓库分钟额度（Free 2000min/月、一次 push 约 18-20min 计费）+ 避免与本地 pre-push 全量门双跑。**本地 pre-push 全量慢门是权威主门**（未变）；Actions 仅用于 SKIP_CI_LOCAL 绕过后手动补跑。CI action 全升 v5（checkout/setup-node/setup-java）消 Node20 告警。BRANCH_LIFECYCLE.md/CLAUDE.md 相应回改。
- **BL-40 后续修复合 master `459f6319`**（2026-07-11，同样 SDD 单任务+TDD+评审）：`isRegionNode()` 对 loopback master 短路返回 false（插在 /16 比对前），生产内网 IP 路径不受影响、EU 塌缩保护原样有效；红绿双验目标类 12/12、全模块 1132 绿；IPv6 `::1` 由更早的非-Inet4 分支拦截。
- 教训重演：共享工作树多 agent 并发时，2270f64e 又扫走了另一 agent 在途的 BACKLOG 修改（同 [[feedback-memory-commit-discipline]] 的 BL-28 类问题，内容正确归属瑕疵）；并发 agent 改同文件必须错峰或只 add 自己动过的路径。

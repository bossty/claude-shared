---
name: deploy-git-preflight-2026-07-05
description: 部署脚本 git pre-flight 五道门 + deployed/* 线上基线 tag 已合 master；分支合并后即删的收尾流程已采纳；CI 按路径分级待做
metadata: 
  node_type: memory
  type: project
  originSessionId: 664b697b-6c53-4b92-9602-00a3fa3a223a
---

**已落地（2026-07-05，合 master `38aef9d6`，ci-local 全绿）**：`scripts/lib/git-preflight.sh` 五道门（fetch 真历史 / 构建输入干净 `-uno` / HEAD 已 push / 含最新 origin/master / 含线上基线 tag 后代），`deploy-web.sh` 与 `deploy-frontend.sh` 已接入；部署全量成功自动打 `deployed/web` / `deployed/frontend-web` / `deployed/frontend-admin` tag 并 push（= 线上跑的 sha 登记簿，别会话 Gate 4 靠它拦截）。逃生口 `GIT_PREFLIGHT_FORCE=1`（Owner 授权）。首次真实部署时 tag 自动创建。有意不做部署互斥锁（历史事故全是先后部署认知陈旧，非并发）。沙箱测试 15/15 含 06-28 S 入口事故重演拦截。

**同日采纳的收尾流程（Owner 拍板"最佳实践怎么做就怎么来"）**：合并后分支即删（远端+本地）、worktree 即删；删除判据=能力级 `git merge-base --is-ancestor`。已清 3 远端 + 8 本地死分支；`feat/cover-preload-restore` 经能力级核验确认 superseded 已删（头 sha `d2aabfba8491` 留档）。

**Why:** 纪律层"记得先 fetch"多会话下必然失守（06-28/07-05 两次事故实证）；机制层脚本强制才可靠。

**How to apply:** 部署遇门拦截先按提示补救（merge master / push / commit），别上来就 FORCE；push 耗时看 pre-push 分级决策输出（`[pre-push] 路径分级:` 行），全量约 7 分钟要给足 timeout 或 run_in_background。**① CI 路径分级已实现（07-05 Owner 授权，分支 fix/ci-path-scoped-gate 沙箱 17/17 + 自举 push 秒过，待授权合并）**：docs/claude-shared/sql 秒过、前端只对应 vitest、后端叶子模块 `mvn -pl <集合> -am test`、common/根 pom/未知路径 fail-closed 全量；`GATE_DECIDE_ONLY=1` 可测决策。现成方案（Bazel/Nx/Turborepo/GIB/lefthook）评估后不采用：无 CI 服务器场景下 hook 层自建 fail-closed 分类器最合身（lefthook 声明式但未知路径 fail-open 方向危险），模块数 >10 或后端全量 >15 分钟再评 GIB/Maven Build Cache。**② skill 补记已完成（07-05，master `98c41950`，plugin 0.3.2）**：runbook Step1.2 五道门段 + dev-workflow §1b 共享 checkout 认属主/§4 合并即删收尾清单/§5 CI 分级；chore/context-mode 分支已代合（`54dad1b2`）；附带修 skill-drift-check.js worktree 假阳性（plugin 路径写死主 checkout→改 process.cwd() 兜底）。plugin 版本变更需重开会话/reload-plugins 生效。③ `feat/recently-watched` 已单独查清（07-05 探针验证）：**复活成本≈零**——与最新 master 合并零代码冲突（仅 2 个 docs 冲突取 master 侧即解），合并态后端全量测试全绿（4:02，含分支自带 324 行测试+ArchUnit）。功能=纯后端（`GET /api/v1/courses/history` 教育伪装路径+guard 白名单+加密响应+有界 recentRywExecutor 护栏），记录侧挂在现有 view beacon。**但关键反转（Owner 反诘逼出，我首轮只搜"recent"漏了"history"）：前端已有完整观看历史**——`/history` 路由+HistoryPage.vue+historyStore（localStorage 上限 100 条，VideoPlayer 写入），用户价值已被覆盖；后端版唯一增益"跨设备/清缓存存活"在无账号体系下基本落空（X-Visitor-Id 同样设备绑定），却带来百万 DAU 级真实成本（每次详情 master ZADD+Redis 存储+EU 跨洋）。结论=功能冗余，**Owner 同意已删分支（头 sha `627c6ab2` 留档）**；审计存档已抢救进 master `3bd6734e`，HEADSUP-recentwatched 文件已按其自述删除；若未来上账号体系，服务端历史按账号维度重新设计而非复活访客维度旧版。★教训：查"功能是否已存在"必须多关键词扫双端（recent/history/watched/中文），单关键词=假阴性。相关 [[no-gh-cli-no-pr-workflow]]。

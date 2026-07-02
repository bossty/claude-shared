---
name: project_gfw_consolidation_2026_06_29
description: GFW track 整合并入 master=单基线(终结 gfw/master 分裂+web/admin 多会话 footgun);gfw-breakthrough-arch 退役;探针保活/reachHint+S端点 dormant/W3e 探针统一 active(Owner-acked 反转 TD-2);web×6+admin+双前端零停机上线 5ed76306
metadata: 
  node_type: memory
  type: project
  originSessionId: b08a1208-fdf5-4954-937c-d5db75882c23
---

# GFW 整合并入 master(2026-06-29)

**决策(Owner)**:把 GFW 开发+测试做完、合进 master,**以后不再有 "gfw-free" 之说**——master = 含 GFW 的唯一可部署基线。终结 gfw/master 双基线 + web/admin 两处多会话 footgun(任何会话从 master 部署不再抹掉 GFW 代码)。

**范围 = 仅整合**(不含 N4 翻流 / 批3 消费层 / backlog / 清 dark 资源;S 全程留 edge)。承 [[project_gfw_s_entry_nlb_handoff_2026_06_28]](事故根因)+ 取代 [[project_master_degfw_deploy_baseline_2026_06_26]](master 不再 GFW-free)。流程走完整 SDLC(brainstorm→spec→plan→subagent-driven),spec/plan 在 `docs/superpowers/{specs,plans}/2026-06-29-gfw-consolidation-*`。

## 关键事实
- **合并**:merge-base 后双侧改文件交集=空 → `git merge origin/master` 进 gfw 零冲突 → `--no-ff` 合 master = `5ed76306`(push 时 origin/master 仍 57ca3fae,fast-forward 安全)。
- **回归**:后端 common 601/web 969/admin 1999 全绿 + 前端 web 897/admin 69 全绿;GFW 核心 11 测试类全 PASS。蓝军 0 BLOCKER / 3 MAJOR(M1=W3e Owner-ack;M2 表已存;M3 runner systemd active)/ 3 MINOR(roll-up)。
- **data R2UploadServiceV5Test 7 errors = 既有 headless-AWT(createGraphics 需 X11,2026-05-08 起,字节同 origin/master,GFW 没碰)**,非回归、非本范围。
- **部署(零停机)**:web×6=deploy-web.sh(test-gate mvn -pl web -am test + ArchUnit,CA×4→EU×2 滚动,jar md5 39d22b27);admin=symlink swap+restart(jar md5 9bf1d1b9);前端=deploy-frontend.sh(★worktree 是 maven-only checkout,无 node_modules → 先 `npm ci` 再跑)。

## 运行时姿态(部署后实证)
- **探针保活**:admin `saas-provider=aliyun`+tcptest;`aliyun-probe-runner.service`(127.0.0.1:3721)是 JAR 外独立 systemd,部署不杀;admin 重启后 aggregation 即 fire(skip-fresh=reach:grid 持久 TTL360min)、health UP、0 ERROR、aliyun/tcptest bean 无 missing-dep。**注:合并前 admin 也是脆弱态(跑 gfw-only 探针代码,master 配的是死源 itdog)——本次同时救了 admin,不只 web**。
- **dormant**:reachHint `REACH_HINT_ENABLED=false`(web /settings 实证无注入);S 端点 dark(S 留 edge、无 DNS 指向、自鉴权 fail-closed、JwtAuthFilter 排除);DomainPoolService W3d 5 参 reach-aware 仅测试调(现役 ConfigController 走 3 参 = inert)。
- **W3e 探针统一(★active,Owner 2026-06-29 显式接受)**:`migrate.js probeTarget` + `utils/bootstrap.js probeDomain` 从 cors `/settings/version`(源站健康 resp.ok)→ no-cors `/cdn-cgi/trace`(边缘可达 fetch 不抛错=true),**反转 TD-2(2026-04-23)**。取舍:GFW 下"边缘可达 > 源站健康",避 CORS preflight(GFW 丢第二 OPTIONS 包)的假阴性把用户从可达域迁走;代价=对源站 5xx 盲(TD-2 当年修的假阳性回归),Owner 接受。

## 收尾
- `gfw-breakthrough-arch`:整合时旧分叉退役(已 ⊆ master 后 local+remote 删),**随即 off master(`53acb663`)重建为干净 feature 分支 + push**(Owner 2026-06-29 收工定:合 master + 分支保留 + worktree 删)承下一阶段。同名,但基底已是统一 master(非旧分叉)。**后续 GFW 工作(N4 翻流/批3/backlog)在此分支 off master 增量做**,走 feature 分支流程。**接手 handoff**:`docs/sprint/2026-06-21-reachhint-tri-probe/GFW-NEXT-PHASE-HANDOFF.md`(在 gfw 分支,origin/gfw `6cb13ab4`)。worktree 已全删(收工态)。
- ★多会话铁律实例:全程 worktree 隔离(主树常在别会话分支+WIP,禁切)、禁 `git add -A`、每 git/部署前 `git fetch`、引用代码做结论前 `git show origin/master:<path>`。

## EU 重启瞬时报错(良性,记防未来误判)
零停机滚动重启时 EU web 两台各有一簇 `stats-async` Redis "Connection closed"(SnackService snack 曝光埋点 @Async fire-and-forget 撞 Lettuce 池拆除),~3min 内归零。**非请求路径、非回归**(任何 web 重启都会,EU 才有=EU 服务 pgeqd 等 S 渠道、重启瞬间有在途埋点;CA 无)。ops + lead 双向独立确认。

## roll-up(待办,非本次)
- m4:ReachHintService 每 /settings 最多 ~110 次串行 replica-Redis 往返 → **启用 REACH_HINT_ENABLED 前必改 pipeline/MGET**。
- m6:weightedRandomPick 全封锁兜底可 302 到 confirmed-blocked P(dark 零影响)→ N4 翻流前 revisit。
- 既有 headless-AWT 测试(R2UploadServiceV5Test)可加 `GraphicsEnvironment.isHeadless()` guard(master 既有问题,独立小事)。

## 文档 currency 清理(2026-06-29 后续,已部分做)
- **已做(merge ba471096 lineage)**:① 清 master "GFW-free 双基线" 陈旧表述(GFW_AND_NETWORK 顶部块 + deploy-runbook skill home+plugin v0.2.0 + MEMORY.md 索引;`a4398935`/`96f8b3e1`);② 4 份 06-21 GFW 定版档/架构图(ARCHITECTURE-FINAL/diagrams/DESIGN-FINAL/IMPLEMENTATION-ROADMAP)顶部补现状横幅:**S 入口 data-path 06-28 已从 execute-api→S-Lambda→web 演进为 NLB-direct(API GW custom domain→VPC Link→内网 NLB→web s-redirect→302,砍 Lambda 跳)**,正文留作历史(`0ac8c26f`/`ba471096`)。
- **★S 入口现行真相源 = `B3-NLB-DIRECT-PLAN.md`(在 master)**;ARCHITECTURE-FINAL(06-21,execute-api/Lambda 模型)已被横幅标"S 入口轴过时,逻辑层(reach:grid/pick-p/reachHint/DINGBAN/IP库)仍有效"。注:`GFW-NEXT-PHASE-HANDOFF.md` 只在 `gfw-breakthrough-arch` 分支、**不在 master**(横幅已防死链)。
- **option B 已做(merge f82382ea lineage)**:`docs/GFW_AND_NETWORK.md` 顶部加 **§0 现行架构总览(单一现行真相源,声明"与下方冲突以本节为准")** + §2/§4.4/§7.1 三旧节加横幅(`abd7cb66`);旧正文留作历史(该档本质=迁移前+W3 前快照,过时面比 sprint 定版档更大)。下层 DoH/种子/CDN failover/§8 数据流**未逐一核**(§0.5 已显式标"引用前抽样验证")——全档逐行重写+逐子系统验证是更大 sprint,未做。
- **★实代码 fact-check 坐实(两 doc 反向都错)**:① **WS 腿确已退役**——sw.js 主动 `delete domainPool.relayWsUrl`,非 CF 逃生腿现= AWS execute-api 多端点竞速(`apiGatewayUrls`/`tryApiGateway` Promise race),无 WS。② **探针未删(CLAUDE.md 错)**——`frontend-web/src/boot/probeGateLite.js`「选项C」commit `5b87d66d`(2026-06-15,即 e8135159 删除后**次日**)重新引入轻量门,`main.js` STEP4 调 `shouldBlockProbe`(命中静止静态外壳、不渲染 decoy 整页),`detectProbe`(aes.js:102)仍在;`__e2e=7rip` 旁路探针门。同 merge 已订正 CLAUDE.md「反发现伪装现状」段(`55a7b4d5`)。
- **方法论实例**:GFW_AND_NETWORK + CLAUDE.md 都不可信(一说"探针渲染 EduStream"、一说"探针已删",实=probeGateLite 选项C)→ 改 durable 架构真相源前**必实代码核**,禁转抄旧 doc(铁律 feedback_verify_not_recall/输入材料 fact-check 的实例)。

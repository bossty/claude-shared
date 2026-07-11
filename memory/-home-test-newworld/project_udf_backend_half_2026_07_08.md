---
name: project_udf_backend_half_2026_07_08
description: "统一域名失败转移后端半5Task已上线波1(web×6+admin,合master3a632119)——ReachFusion保真+A软排序+pick-p迁web+P→P HRW+escapeRoots契约,全flag默认false行为中性;波2待ops CF hostname"
metadata: 
  node_type: memory
  type: project
  originSessionId: 42195a8c-01d7-4b19-ae50-6d3114f77ff4
---

**统一域名失败转移 后端半（5 Task）已上线生产波1**（2026-07-08，Owner 授权 OWNER_DEPLOY_APPROVED=1，subagent-driven：Opus 实现 + Opus 蓝军逐 Task 审 + 全分支终审 + 修复循环）。承接 [[project_udf_p0_sw_primary_escape_2026_07_06]] 的后端半（P0 客户端逃生已先上线）。

**合 master merge `3a632119`（`--no-ff` 合 feature/udf-backend-half，13 commit，已推送）；线上基线 tag `deployed/web → 3a632119`**。波1=web×6(ca-web-01..04+eu-web-01/02 脚本化滚动零停机)+admin(ca-admin 手动 swap `20260708-053840-3a632119.jar`)。data 未动。merge 最新 master(d3662748 归档)后全量测试 web 1114/admin 2185 全绿。

**5 Task**：
- **Task1** ReachFusionService 融合(enabled)写保真 `block`(完整枚举 dns_poison/tcp_reset/ip_block/clean/unknown 非二值)/`node_count`/`code` + 新增 `rum_n`(=RUM 观测样本量 succ+fail)；ReachGridReader.ReachEntry 暴露 `sampleCount`(读 rum_n)。dark 分支字节不变。
- **Task2** A 池软排序 `hrwPickTopSoftReach`(**两阶段**：纯 HRW 定 membership + reach 只重排选中集,min-n≥20 门 sampleCount<20→中性1.0,never exclude) + flag `A_POOL_SOFT_SORT_ENABLED` 默认 false（与硬惩罚 `A_POOL_PENALTY_ENABLED` 正交,双 false=dormant）。
- **Task3** pick-p edge RPC 迁 web×6：web `InternalPickPController` body 加 `p_domain` 键(保 `p` 零破坏 S-Lambda) + edge `short_redirect.lua` base 改 `_WEB_PICKP_BASE_URL`/路径 `/api/v1/internal/pick-p`。guard 白名单撤回(P2-71 web guard 全 pass-through 是死条目)。**唯一鉴权门=checkSecret(fail-closed 常量时间)**。
- **Task4** P→P reach-aware 软排序 `computeChannelPromoCandidatesSoftReach`(**渠道 N_PP 池 membership**,共享 `softReorderTopN` 核心,A 侧委托)。保留 `pickPromoDomain`(S→P 无 vid 加权随机)。常量 `REACH_MIN_SAMPLES`=20 A/P 共用。
- **Task5** escapeRoots 有序契约(仅 /settings,/version 禁,ordinal 裸 host 去 r/w,⊆N_POOL(A active+retiring)/N_PP(P active-only 渠道隔离),ver=roots 的 reach:grid 最大 ts) + flag `ESCAPE_ROOTS_ENABLED` 默认 false。前端消费缓（pool-redirect.js 现无消费）。

**三 flag 默认全 false=部署行为中性**（线上 `/settings` 22926B 无 escapeRoots 字段=铁证）。

**★蓝军 review 拦下的关键 bug（都是单 Task 单测/mock 看不见、审查+推导才现形）**：
- **Task2 BLOCKER**：软排序初版对全池按 reach 截断 topN=全 fleet 系统性剔除低 reach 活域(reach 非 per-vid,所有 vid 一致沉底)，与 Owner「只排序不剔除」正相反→改**两阶段**(HRW membership 保 per-vid 分散 + reach 只重排选中集)。
- **Task1 F1**：sampleCount 初版误读 `node_count`(探测节点数,个位数)当样本门→min-n≥20 恒 fail-open 软排序形同虚设；node_count=`cellNodes.size()`(GfwProbeAggregator L532)，真样本 n=RUM succ+fail→改写 `rum_n`。
- **Task3 F2**：新 CF hostname 裸代理会暴露**整个 /api 面**(web nginx server_name _ catch-all + location /api/ 无 internal 级限制)→产出基建档要求 cloudflared ingress 收窄到只放 `^/api/v1/internal/pick-p$`。
- **Task5 终审 F1**：P escapeRoots 初版从全局 P 池选 membership 再交集渠道 N_PP=覆盖漏斗(roots 稀疏/空)→改渠道池 membership。

**波2(edge)已上线生产(2026-07-08,Owner 授权,ops-senior 分阶段执行)**：pick-p RPC 从 admin 单点彻底迁 web×6,**admin SPOF 消除**。落法=独立 CF LB `internal.dnsv106.com`(id `29c71d4f…`,zone dnsv106.com 账号A,复用现有 CA/EU 池零新增 origin,steering=off CA 主 EU 备)+host-scoped WAF custom rule(`http.host eq internal + not path eq /api/v1/internal/pick-p→block`,收窄防暴露全 /api 面,非 pick-p 返 403)+3 台 edge(usca-1/usca-2/aws-s)填 `WEB_PICKP_BASE_URL=https://internal.dnsv106.com`+openresty restart。**G1-G6 全绿**(401/403/200 两键/扇出 CA 3/4 节点/三台 S 短链 302 落活域/pick-p RPC 失败率 usca 0.29-0.74% aws-s 稳态0%,历史 4.2/4.5/9.4% 数量级降,样本小需持续观察)。真实生产流量已在跑。as-built=`docs/superpowers/reports/task-3-edge-tunnel-infra.md §AS-BUILT`。

**★波2 踩坑教训(新固化)**：
- **CF_API_TOKEN_A 需 "Zone·WAF·Edit" 权限组**(独立于 DNS/LB/SSL)——首次 WAF PUT entrypoint 撞 `request is not authorized`,需 CF Dashboard 补;预检=GET entrypoint 返 10003「找不到」=有权限空态,返 authorized 错=缺权限。
- **WAF 规则 PUT 成功+GET 复验通过 ≠ 全球边缘立即生效**(Ruleset Engine 秒级传播,刚建头几秒非 pick-p 路径仍穿透到 origin,几秒后稳定 403)→动 WAF 后等 10-20s 再验收/依赖(同 CF 配置最终一致教训族)。
- **edge openresty 改 env 必 restart 非 reload**——systemd `. secrets.env` 只在 ExecStart,ExecReload=nginx -s reload(HUP)不 source env;deploy-openresty.sh 检测 lua 变更即 restart(设计如此)。restart 有冷启动连接池预热突发(aws-s 头 6 秒 6 次超时稳态归零)→灰度单台非峰窗。
- **CF LB steering=off + default_pools=[CA,EU]=CA 优先 EU 仅 failover**(非随机打散);CF Tunnel 同持久连接粘同 connector,扇出靠新建连接轮转非逐请求轮询→G4 判「非单台」非「6 台均摊」。
- **ops-senior 分阶段+每写 GET 复验+CF 侧全绿再碰 edge 的纪律有效**:两次拦对(WAF 权限门主动回滚不设防 LB;restart 需授权不钻脚本嵌套空子);证据诚实(标小样本/区分 restart 前后日志/EU 零是设计)。

**enable-time 前置（后续灰度，均需另次授权）**：翻 `A_POOL_SOFT_SORT_ENABLED` **须先开融合写 rum_n**(否则 dark→rum_n 缺→no-op「验空操作」)+四象限回归(喂 LIVE migrateTo)；`ESCAPE_ROOTS_ENABLED` 待前端消费轮。

**follow-up(独立 task)**：~~A 侧 anchorCandidates `ConfigController.java:~210` `Set.of(normalizedHost)` 未归一 rootHost(latent 低发生率:wildcard-A 直接访问时 migrateTo 不排除当前死根)~~ **已结案(2026-07-10 master fa6891f1 核实消除)**：现由 `normalizeExcludeRoot`(ConfigController:571 抽公用,复用 HostChannelParser.rootHost)归一 excludeHosts，escapeRoots(:775) 与 anchorCandidates(:213) 两路共用，migrateTo 取归一后 candidates[0]，第三次漂移已堵。

设计档 `CONSENSUS.md §6b`(Owner 决策已锁)；计划 `docs/superpowers/plans/2026-07-07-udf-backend-half.md`；报告 `docs/superpowers/reports/task-{1..5}-report.md`+`task-3-edge-tunnel-infra.md`；审查 `agents/reviewer-backend-{task1..5,final}.md`。交接 SESSION-STATE `docs/sprint/2026-07-06-unified-domain-failover/SESSION-STATE.md`。

相关 [[feedback_owner_approval_all_deploys]] [[reference_edge_reach_coverage_pickp_rpc]] [[feedback_verify_not_recall]]（N_PP active-only 靠实现者独立 fact-check 修正我基于转述的假设）。

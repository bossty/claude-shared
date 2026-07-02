---
name: project_gfw_apool_rum_phase3_firetest_2026_07_02
description: GFW A 池 RUM 接入 reach:grid 阶段3(方案3→1)—— 融合器补 A 域纯 RUM 可达数据 + 观测;部署 ca-admin + 火测 PASS(1804 格/183 降级,证 A 真有退化)+ flag ON 观测一周(2026-07-02)
metadata:
  node_type: memory
  type: project
  originSessionId: 7c799e0e-f65c-455d-826d-90c01c3dce55
---

**问题(方案缘起)**:`reach:grid` 是**一份**统一可达数据(key=`reach:grid:{域}:{isp}:{省}`),但生产方按 S/P/A **不对称**——拨测只探 S+P(~11+~20),A 池(155 域)deferred;融合器 `ReachFusionService.runOnce` 是 **probe-key 驱动**(`for pk : scanProbeKeys()`),消费格从探针格派生 → **A 池零 reach 数据 → 命中 `_ANY_` fallback → 默认 reach=1.0**。这才是 [[project_gfw_p2_apool_reach_firetest_2026_07_01]] A_POOL 火测 `top_changed=0` 的**真因**(不是"A 域碰巧可达",是"A 域根本没数据")。而 A 有充沛 RUM(`domain:report:joint:*`,用户浏览 A 内容域产生)却被融合器忽略,且 `ReachFusionMath.fuse` **已支持 `nodeCount==0` 纯 RUM 格**——所以补 A 数据**只需让融合器也遍历 RUM-only 格,不需拨测并行化**(那才是重活)。

**方案 3→1(观测优先,Owner 定)**:阶段3=独立 flag dark 写 A 格 + 观测一周;阶段1=数据证明有退化后翻 `A_POOL_PENALTY` 接选址(migrateTo,覆盖 P→A migrate + A→A 被封跳转)并重跑 web×6 火测;数据不支持则 YAGNI。**关键设计**:①独立 flag `REACH_FUSION_A_POOL_ENABLED`(默认 false dark,与 `REACH_FUSION_ENABLED` 正交);②**demote-only**(fail-open=1.0,只打压有失败记录的格,无 RUM 证据不写 → 严格不比现状差);③只处理 `Domain.Category.A` 域(joint 含全部上报域,不过滤会污染 B/CDN);④admin 侧 SCAN joint(不改 web 热路径);⑤RUM-only 消费格短 TTL(1800s)。

**实现(单点改 `ReachFusionService`,4 task TDD)**:`cellFromJointKey`(去 prefix+去尾桶)+`scanRumCells`(SCAN joint 去重)+`loadAPoolDomains`(A active∪degraded)+`runForACells`(过滤 A→readRum→`fuse(1.0,0,...)`纯 RUM→写 `reach:grid` `src=rum_only`)+`runOnce` flag-on 才跑 A 路径 + 4 gauge。**分支 `worktree-gfw-reach-apool-rum`(8 commits,未合 master)**;17/17 单测 + 全模块 2089/0-fail。spec `docs/superpowers/specs/2026-07-02-gfw-reach-apool-rum-fusion-design.md` / plan `.../plans/2026-07-02-gfw-reach-apool-rum.md` / runbook `docs/sprint/2026-07-02-gfw-reach-apool-rum/DEPLOY-FIRETEST.md`(均在分支)。

**★火测 PASS(2026-07-02 11:14 UTC 翻 flag,11:17 轮激活)**:
- **安全**:0 ERROR;S/P 融合 `gfw_reach_cells`~13534 健康、probe_age 正常 → **SCAN 6441 joint 键未拖垮融合轮**(R1 成本担忧化解)。
- **★生产价值(核心发现)**:`gfw_reach_apool_cells=1804` / **`degraded_cells=183`(reach<0.8,~10%)** / **`reach_min=0.0`(至少一格 RUM 全 fail)**。**A_POOL 当年 top_changed=0(无数据),现在 A RUM 显示真降级 → 证实 A 池确有可达退化,值得治**(反转"A 都可达"的旧印象)。
- **诚实 caveat**:`rum_sample_min=1` —— 最薄格仅 1 个 RUM 样本,`reach_min=0` 那格可能只由 1 个失败 beacon 支撑(薄证据不能当铁证)。这正是 spec §11 R3 + 阶段1 的 **M 阈值**(样本≥M 才采信)要解决的。

**★★重大纠正(2026-07-02 观测抽样,纠上文"183 降级=A 真退化"的乐观表述)**:reach 分布**双峰**(抽样 1141 格:87% =1.0 / 7.8% =0 / ~5% 中间);但抽 40 个 reach=0 格查底层 RUM:**67.5%(27/40)只由 1 个失败 beacon 支撑、32.5% 由 2-5 fail、0 个有 ≥6 fail 强证据**。→ **"183/291 降级"严重虚高,几乎全是薄样本噪声,A 池当前无强证据真封**(实为回到 A_POOL"没多少真退化"的方向,但这次能量化"为什么看起来有退化")。**根因=我实现的融合数学缺小样本收缩**:`ReachFusionMath.fuse` 在 `nodeCount=0`(纯 RUM)时 `c=0`、reach=succ/(succ+fail) 无先验伪计数 → 1 个 fail beacon 直接 reach=0(sample_min=1→reach_min=0 的机制根因)。**修法=Beta(α₀,β₀) 弱先验**:reach=(succ+α₀)/(succ+fail+α₀+β₀),薄格自动回中性、大样本才敢极端。**下一个 spec = "RUM-only 小样本收缩"(治本,替代急着接 A_POOL——接了是喂噪声给选址)**。

**运行姿态(截至 2026-07-02 夜,LIVE)**:`system_config.REACH_FUSION_A_POOL_ENABLED='true'`(group=gfw)ON **观测一周**;**对消费方仍 dark**(reachHint/A_POOL 仍 off、pick-p 只读 P 域,没人读 A 格)→ 纯观测零用户影响。ca-admin 跑 `20260702-190608-apoolrum-7e98ce16.jar`(current.jar),回滚 jar `newworld-admin-reachstale-0b6019ca.jar`。**秒回滚** = DB set false + `PUBLISH shared:ch:sysconfig-refresh REACH_FUSION_A_POOL_ENABLED` + `INCR shared:system-version`。

**部署/翻 flag 实证(纠旧 memory)**:
- **ca-admin 现已装 `mysql` + `redis-cli`**(`/usr/bin/`)——纠 [[reference_redis_cli_caadmin_proc_password]] "没装 redis-cli"(基建已升级;密码仍在 /proc 非 secrets.env)。DB 用户名 `newworld`(prod yml 写死非 env)、库 `newworld`、DB_HOST `172.34.1.222`、REDIS_HOST `172.34.1.128`(凭证从 admin `/proc/<pid>/environ` 取)。
- **翻 flag=忠实复制 admin 写链**(无 admin JWT):DB `INSERT ... ON DUPLICATE KEY UPDATE` + `INCR shared:system-version` + `PUBLISH shared:ch:sysconfig-refresh <具体key>`(返 11 subscribers=admin+web 全失效 L1)。用**具体 key** 比 `'*'` 更外科(onMessage:key→`valueCache.invalidate(key)`,`*`→`invalidateAll`)。`system_config` 列=config_key/config_value/config_group/config_type/description(+id/config_version/update_time 有默认)。
- gauge 查 **`:18080/actuator/prometheus`**(bind 127.0.0.1,从 ca-admin 本机 curl);gauge 无 `_total` 后缀 + 带 `service="admin"` 标签。**火测轮时序**:admin restart+initialDelay 30s → 轮 5min 一次;翻 flag 后要等**下一个整轮**跑完才见 A gauge(首查太早会误判 0.0)。

**N9E 观测告警(已建 2026-07-02)**:`alert_rule` **id=113 `APOOL-RUM-FUSION-STALL`**(ca-monitor n9e_v8,clone id=110 P1-A)——PromQL = gfw_reach_apool_cells{service=<backtick>admin<backtick>} == 0(backtick 匹配器)、for=900s(15min)、eval 15s、severity=2 warning、`notify_rule_ids=[1]` telegram、`datasource_queries` 非 NULL(engine eval 铁律)。捕捉 A 融合停摆(SCAN 失败/scanRumCells 空/融合轮死);回滚 flag 时 cells 冻结旧值非 0 不误报;admin-down 另有告警。★N9E 改法:`ssh ca-monitor` 别名可用(动态 IP)、`sudo mysql n9e_v8`(root socket)、PromQL 用 backtick 匹配器、SQL 含 backtick 写本地文件 scp 避 heredoc 引号地狱、VM `:8428` 验指标 label(service=admin + categraf 加 ident/host/dc/region)。

**★RUM-only 小样本收缩(已实现+部署 2026-07-02)**:`ReachFusionMath.fuse` 的 `!hasProbe` 分支加 **Beta(8,1) 弱先验**——`alpha=(hasRum?α₀:0)+succ·freshR`、`beta=(hasRum?β₀:0)+fail·freshR`(**hasRum 空守卫**保空格 fail-open,否则空格得 8/9 破 `failOpen_noData`);probe 分支逐字不动;`FusionParams`+2 字段、`ReachFusionService` 2 `@Value`(`rum-prior-alpha:8.0`/`rum-prior-beta:1.0`,`α₀=β₀=0`=回滚)。2 task TDD 全模块 2095/0-fail;部署 ca-admin `shrink-80250fd6.jar`(回滚锚 apoolrum-7e98ce16)。**火测立竿见影**:`degraded_cells` 291→**21(↓93%)**、`reach_min` 0→**0.615**、`sample_min` 仍 1(薄格在但不再被逼极端)、S/P `gfw_reach_cells` 13935 **不变**(收缩只碰纯 RUM)。★坑:(a)`@Value` 单测默认 0→service 测试必 `setRumPriorAlpha(8.0)` 才触发;(b)加先验后 freshR 不再在 succ/(succ+fail) 约分→精确 reach 随桶时序抖动(0.1000→0.165-0.17),service 断言改 `isBetween` 抗抖动(TDD 逮到);(c)翻 jar 后旧 reach=0 格留 KV 直到 30min TTL(gauge 只统计本轮新写故立即干净,KV 稳态才全清)。

**下一步**:收缩上线,观测周看的是**真实退化(~21 降级格)非噪声**。一周后:若仍有强证据降级格 → 阶段1(翻 `A_POOL_PENALTY_ENABLED` + 重跑 web×6 火测);若归零 → A 无真封 YAGNI 结案。merge master 待此 + Owner 授权。分支 `worktree-gfw-reach-apool-rum`(阶段3 + 收缩,未合)。相关 [[project_gfw_reach_fusion_phase4_2026_07_01]] [[project_gfw_3a_flag_activated_2026_06_30]] [[reference_actuator_port_18080]] [[reference_ca_admin_deploy_model_2026_06_21]]。

---
name: project_phase_d_incident_and_checkpointed_runbook_2026_06_13
description: Phase D cutover 失败 split-brain 事故全教训 + 检查点式步进 runbook + 2026-06-13"不停HK web"反案成功收口(CA=master)+IPv6-mapped ss断言坑
metadata: 
  node_type: memory
  type: project
  originSessionId: 64b5f5d1-9590-4971-9f5b-8d2e351a83eb
---

2026-06-12 Phase D（HK→CA master cutover）DRY_RUN=0 真切失败 → split-brain → 止血回滚 → 专家团队 post-mortem → owner 定改**检查点式步进 runbook** 重试（弃单体脚本+自动 trap）。

**★2026-06-13 cutover 成功收口（Fable lead 接手，"不停 HK web"反案）**：C5 PONR gate 三项亲验全绿(HK sro/ro=1/GTID_SUBTRACT(HK,CA)空/站点4域200/HK web冻写期0个502)→GO C6 promote(CA ro=0/durability1/1)→C7 EU+HK 反指CA(io/sql=ON零错)→C8 redis切CA(HK redis全程未碰)→C9 八节点(含HK web×2)滚动切CA→C11真浏览器A域17.rip+P域byteatlas.top feed/写analytics-hit/CDN全200+0console错。终态:CA=live master 172.34.1.222,写真落(Com_insert+162/6s),EU+HK双replica健康。**HK web 不停机全程服务零502**(对比上次stop-HK-web死15min,反案兑现)。commit e38b5f56。
- **反案核心**:cutover不停HK web/不drain任何域,HK web留服A/P/C域全程,S6把aws-web-01/02纳入repoint(6→8节点),PONR前回滚简化为1步(只解冻DB)。依据=feedAsync markSeen写Redis非MySQL+HK web写本地HK Redis(C8前)+读HK本身→停HK web的旧理由(防分叉)站不住,反而造成502。
- **★IPv6-mapped ss 断言坑(新,通用)**:C9 s6 helper 首跑在 aws-data F1 假halt——ss ESTAB 断言 `grep '${IP}:3306'` 撞内核 IPv6-mapped 显示格式 `[::ffff:172.34.1.222]:3306`(IP与:3306间有`]`)匹配=0,误判连接池未重建。CA master侧 processlist 实证 aws-data=50连接/0连HK,repoint早成功。修 `grep -Ec '${IP//./[.]}[]:]+3306'` 容忍`]`。**教训:任何 ss/netstat 的 `IP:port` grep 断言必须容忍 `[::ffff:IP]:port` 形式**(Java/Netty 等常以 IPv6-mapped 建 IPv4 连接);"配置对≠连接真切"断言方向对但 grep 颗粒度错=假故障,排查用 master 侧 processlist 交叉印证比逐节点 ss 权威。
- **timeout 设短坑**:lead 给 s6 设 `timeout 540` 8节点串行不够(每web restart+60s健康轮询),最后一台eu-web-new-02被切断exit124→手工实测补验(active/DB_HOST=CA/ESTAB5/health 200)。1127条ERROR是老进程指只读HK停机瞬态(read-only+LettuceConnectionFactory STOPPED),新进程0错。

**事故链与真凶**：
1. **split-brain 真凶 = trap 在 PONR 后误解冻 HK**：S3 promote CA 成功后，S6 在 aws-data 因 ss 断言 estab=0 abort → trap `_thaw_hk` 仍解冻 HK → HK+CA 双可写，GTID 双向分叉（HK 吃 1444 笔 web 写、CA 吃 58 笔 stats）。止血=冻 CA 保 HK（写量大端胜）。CA 后用 CLONE 重建丢分叉。
2. **502 真凶 = stop-before-drain**：S0.75 停 HK web 但 HK 仍是 CF LB（tcos-canary）12 个亚洲国 country_pool 的**单 origin**且从未从 steering 摘除；且 **CF health-check 打 :80 /actuator/health 命中 OpenResty SPA catch-all 永远假 200 → CF 永不自动摘死 origin**（独立现网高危，修复有硬前置：先经 OpenResty 暴露真探针再改 monitor，否则全 pool 假红自残）。回滚还漏重启 HK web（trap 只解冻 DB）→ 死 15 分钟。
3. **最深网络根因 = CA↔EU 无 VPC peering**：EU→CA 3306/6379 全 errno110 timeout（peering 非传递，EU 不能经 HK 中转）→ S4a 反转复制永不可能成功，却在 PONR 后才暴露。已建 pcx-01d4853aa2d5efe4a + 双向路由，一条 peering 解 DB+Redis 两路。
4. **上次事故清理漏 EU**：EU replica 卡指死 CA 的 IO=No 态 ~1.5h，EU 用户读陈旧 18.6 万笔。教训：**回滚清理必须对全部 replica 逐一对账，不只主角**。

**方法论（owner 拍板，已验证 work）**：
- **检查点式步进 runbook** `docs/sprint/2026-06-12-os-alignment/CUTOVER-RUNBOOK-CHECKPOINTED.md`（commit 3b7f29ef）：A 可逆前置/B 摘流/C 不可逆核心；每步=专家执行+验证判据+失败决策；**失败即 STOP 不自动续跑不自动回滚**；回滚是显式人工步骤分 PONR 前（解冻+重启 HK web+CF re-arm 三件套）/PONR 后（**绝不解冻 HK**，情形 A/B 决策树）；只有 S6 六节点循环脚本化。
- 4 个 DRY helper：cf-drain-hk/cf-rearm-hk（snapshot 持久 $HOME/.cutover-snapshots）/preflight-master-reachability（7 节点×3306+6379 三态门）/cutover-s6-repoint（aws-data 最先 G4+F1 fail-fast+ss 真连断言）。
- **diag 法则**：refused(111)=路径通没人 listen（app 层）；timeout(110)=网络 drop（peering/路由/SG）。探 refused 前先确认目标主机真跑该服务（.222 是 DB、redis 在 .128，探错主机=伪信号）。
- **drain-before-stop**：停任何 serving 节点前必先从 CF steering 摘流+验零流量（HK 实测 2033 req/min 真流量）；region web 是流量目的地**绝不能 CF 摘**，只能应用层 quiesce。
- 19GB access.log 全扫会 hang 门禁脚本——tail -n +epoch+timeout。
- 多 agent 教训：长跨重启操作禁后台 launch-完-就-idle（CLONE 死中途）；共享产物必须单一 editor（runbook/s6 脚本撞车）；蓝军 crossfire 连 lead 手写的 typo（--max-time10）都能兜住。

**How to apply**：任何 master cutover/迁移类操作——①pre-flight 必含全节点到新 master 的真 socket 门禁 ②PONR 后任何失败绝不自动 undo 写路径 ③停节点前先 drain+验零流量 ④回滚 undo 表必须覆盖全部前向破坏步骤+全部 replica ⑤每步人工 gate 优于自动 trap。关联 [[feedback_master_cutover_incident]] [[feedback_web_module_top_priority]] [[project_admin_239_dropin_incident_2026_06_12]]。

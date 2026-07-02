---
name: project_gfw_pickp_reach_cutover_3a_2026_06_30
description: GFW 阶段3a=admin /ops/pick-p(live 边缘选址 RPC)乘子从空的 domain:err(penalty)改读 reach:grid(reach)，flag OPS_PICKP_REACH_ENABLED 门控默认 false(dark 上线零 live 变更)；reachFor/lookupReach admin-local 三级+canonical+fail-open；effective=base×reach 方向不可接反；feat/gfw-pickp-reach-cutover off master 本地未 push，待部署/授权
metadata: 
  node_type: memory
  type: project
  originSessionId: a3a5374e-7d40-4b0c-89e2-355bce0c6e0b
---

# GFW 阶段3a — admin /ops/pick-p 改读 reach:grid（2026-06-30 完成）

承 [[project_gfw_reach_read_layer_phase1_2026_06_30]]（阶段1 web 读层）。roadmap 价值闸门（spec `2026-06-29-gfw-reachability-signal-unification-design.md` §5 阶段3「live 切信号」）：**让 reach-aware 选址真在 live 生效**。完整 SDLC（brainstorm→spec→plan→subagent-driven）。

## 问题 / 目标
admin `/ops/pick-p`（Z15b，CN2/USCA Lua 边缘**每请求**调的 live P 域选址 RPC）现用 `penaltyFor` 读 `domain:err`/`domain:pv` 算 penalty。P0 实测 domain:err **全空(0)** → penalty 恒 0 → **live 边缘选址零 reach 降权**（探针 1.38 万格好数据空转）。3a = pick-p 乘子改读 reach:grid，flag 灰度。

## 决策（Owner，2026-06-30）
- **范围**：仅 `/ops/pick-p`（domain-health 不切）。
- **读层**：**admin-local**（镜像 OpsController 现有 `penaltyFor` 三级结构，读 admin 自己的 master `stringRedisTemplate`）。**★Owner 待办：phase1 合 master 后提取到 newworld-common 与 web ReachGridReader 合一**（见 phase1 memory roll-up；admin+CA-web 读同一 Redis .128 同 reach:grid 键，共享有理）。
- **灰度**：flag `OPS_PICKP_REACH_ENABLED` 门控即切（默认 false）。
- **flag-off 兜底**回旧 domain:err 路径（非直接 fail-open）；source 维度够。

## 产物（分支 feat/gfw-pickp-reach-cutover，off origin/master @25aadc22，本地未 push）
5 commits：spec `7a3bbdd4` + plan `a90ca6bf` + **Task1 `e2cdba53`**（reachFor/lookupReach）+ **fix `7edda7b4`**（测试加固）+ **Task2 `e6135c0d`**（flag cutover）。spec/plan 在 `docs/superpowers/{specs,plans}/2026-06-30-gfw-pickp-reach-cutover*`。

- **Task1**：`OpsController` 加 `reachFor(d,isp,prov)`（reach∈[0,1] 默认 1.0；overseas/isp 空/异常→1.0 不读 Redis；三级 exact→isp:`_ANY_`→1.0；命中=reach 字段存在含 1.0 不穿透，**非** penaltyFor `>0` 短路）+ `lookupReach`（1 HGET，miss/异常 -1.0 哨兵，clamp[0,1]）。**★canonical**：key 省份过 `IspProvinceNormalizer.reachGridProvince` 对齐写侧 `GfwProbeAggregator.writeCell`（否则全 miss=蓝军 BLOCKER）。dormant。
- **Task2**：flag `OPS_PICKP_REACH_ENABLED_KEY`（默认 false）+ `isReachModeEnabled()`（读失败→false 降级旧路径）+ `pickWithPenalty` 加 `reachMode` 参 `factor = reachMode ? reachFor : 1-penaltyFor`、`effective=base×factor` + `recordPickPMetric` 加 `source`(reach|err) 维度（pickPInternal 读 flag 一次 threading）。

## ★核心正确性（验收坐实）
- **方向不可接反**：`effective = base × reach`（reach 高=可达=高权重）。鉴别测试 `flagOn_directionReachIsWeight` 2000 次跑 dead.com(reach=0)→effective=0→零 top1（接成 penalty/1-reach 必断言失败）。`-1.0` 哨兵(miss) vs 合法 `reach=0.0`(全封锁) **无碰撞**（`>=0` 判命中）。
- **dormant 真未破**：flag 默认 false → 100% 旧 domain:err 路径；domain:err 空→penalty 0→`base×1`=改前位等价。**dark 上线零 live 变更**，直到 Owner 翻 flag。
- **canonical 两侧对齐**（reviewer 额外核 **isp** 也对齐：写侧 AliyunProbeClient.normalizeIsp ↔ 读侧 IpProfile.isp，均 telecom/unicom/mobile/other；`_ANY_`/字段 `reach` 两侧一致）→ 不会整池哑火。
- **fail-open 闭合**：reach 读异常→1.0；flag 读失败→旧路径；不把缺数据/抖动变误降权或 500。
- 旧路径 + penaltyFor/weightedRandomPick/checkSecret/snapshot/domain-health 零回归。

## 验收
- OpsControllerTest 69/0 BUILD SUCCESS（first-hand）+ 模块 `mvn -pl newworld-admin -am test` 2039 全绿。
- 蓝军 4 轮（Task1 + fix + Task2 + final whole-branch，opus）均 Approved / Ready-Yes，0 Critical/0 Important。

## roll-up（Minor，非阻塞）
- M-overseas-const：reachFor 魔法串 `"overseas"` 宜换常量（值同）。
- **★Runbook（运维必读）**：翻 `OPS_PICKP_REACH_ENABLED` **必经 admin 配置接口**（触发 `CH_SYSCONFIG_REFRESH` pub/sub 即时逐出 config Caffeine→秒回滚）；裸 SQL UPDATE 不发 pub/sub、最坏滞后 30min。切 true 后用 `source` 维度 + chosen/reach debug 日志核"reach 降权真生效且方向正确"，异常即翻 false 秒回。
- M1 raw-cast accepted（跟 PickPTests 惯例不加 suppress）。
- 阶段4 融合落地时把本 flag 路径并入 `src=fused`（spec §10）。

## ★只读 prod 验证（2026-06-30，未翻 flag/未部署/零 live 影响，Owner 要求"不翻 flag 测一下"）
连 ca-redis-master(.128) 只读抽样（redis-cli 在 ca-admin /usr/bin/redis-cli 现已装；密码从 `sudo cat /proc/$(systemctl show newworld-admin -p MainPID --value)/environ` 取 REDIS_PASSWORD，REDIS_HOST=172.34.1.128）：
- **哑火 BLOCKER 排除**：reach:grid 13,695 键/141 域；省份 token=**canonical 裸名**(广东 非 广东省)=对齐 reachFor 的 reachGridProvince；isp=telecom/unicom/mobile(+overseas)；字段 `reach`；`_ANY_` 564 个 **CN isp 也有**（纠正"CN Layer B 空"误判）。→ reachFor 读真 key 会命中。
- **P 池满覆盖**：shared:global:p_pool **131 域，131/131 有 reach:grid 数据，131/131 对(telecom,广东)走 exact 命中**（不靠兜底）。
- **数据健康有区分度**：131 P 域 reach(telecom,广东) 分布 [0.95-1.0]:128 / [0.7-0.95):2 / [0-0.3):1。→ 翻 flag 后 128 可达域选址几乎不变(安全)、1 域 reach<0.3 正确重降权。
- **结论**：翻 flag 风险实测证伪——真生效(131/131 命中不哑火)+不误路由(可达域保持高权重)+正确降权那 1 封锁域；当前数据下翻 flag 即时扰动很小。
- **抓手**：翻 flag 前可复跑此只读检查（reach:grid live 更新，复测确认覆盖+分布仍健康）。

## 状态
**3a 代码完成 + 全绿 + 4 轮蓝军 + 只读 prod 数据实测验证通过，但未 push 未合 master**。按铁律待 ① 从本分支打包部署测试 ② Owner 显式授权 才 `--no-ff` 合 master；上线后 flag 仍默认 false（dark），Owner 择时切灰度。worktree `.claude/worktrees/gfw-pickp-3a`。

---
name: project_gfw_reach_read_layer_phase1_2026_06_30
description: GFW 阶段1=统一 reach 读层+fallback 阶梯(exact→isp:_ANY_→1.0)完成;ReachGridReader 扩阶梯+pick-p 改调统一读层(8 行为保真)+reachHint/A池继承(修 B2);★写侧 live 但 3 消费方全 dormant=净零 live 变更;feat/gfw-reach-read-layer-fallback 本地未 push、Owner 定保持现状待部署/合并
metadata: 
  node_type: memory
  type: project
  originSessionId: a3a5374e-7d40-4b0c-89e2-355bce0c6e0b
---

# GFW 阶段1：统一 reach 读层 + fallback 阶梯（2026-06-30 完成）

承 [[project_gfw_consolidation_2026_06_29]]（GFW 已整合回 master 单基线、后续 GFW 工作 off master 走 feature 分支）。本阶段=spec `docs/superpowers/specs/2026-06-29-gfw-reachability-signal-unification-design.md` §4.2 **阶段1**（地基，低风险、修 B2）。subagent-driven-development 逐 task 跑。

## 分支 / 产物
- 分支 `feat/gfw-reach-read-layer-fallback`，off `origin/feat/a-pool-penalty-wire`@18100a12（该 base 已含 ReachGridReader 批量/缓存/inflight + A 池 penalty flag + reachHint 改造，蓝军 F1-F6 修过）。worktree `.claude/worktrees/gfw-reach-p1`（别会话另持 `apool` worktree 在同 base 分支，禁碰）。
- **4 commits**：`c3dc47d4`(T1 reader 阶梯) / `4a7be157`(T2 消费方继承补测) / `82087e61`(T3 pick-p 改造) / `b75676cb`(final-review fix 清冗余 suppression)。
- **仅本地、未 push、未合 master**。Owner 2026-06-30 定**保持分支现状**（不 push 不合），等其定部署/合并时机（铁律：feature 分支先部署测试 + Owner 显式授权才合 master）。

## 三 task 做了什么
- **T1**：`ReachGridReader.getReach` 加 fallback 阶梯——每 miss 域**同一次 executePipelined 发 exact + `isp:_ANY_` 两条 HGETALL**，游标对齐解析：exact 非空→exact / 否则 agg 非空→anyAgg / 否则 FAIL_OPEN(1.0)。省 unknown/overseas/blank（`isNonSpecificProvince`，= pick-p 旧 `validProvince` 取反）→只发 agg 一条。`ReachEntry` 加 `String level`（exact|anyAgg|default）。cold ≤2N 命令/1 往返；warm/follower 拿已 resolve 终值无二次解析。
- **T2**：纯测试。证 reachHint/A 池经 reader **自动继承 _ANY_ 兜底**（B2 修复=精确省格缺失时 _ANY_ 聚合值仍驱动 deadRoots/penalty）。鉴别点=mock 返 `level="anyAgg"` 条目（消费方对 level 无感、只按 reach 值消费）。
- **T3**：pick-p（`InternalPickPController`）三级内联 `reachFor`/`lookupReach` → 改调 `reachGridReader.getReach` 统一读层，删内联三级 + 死字段 replicaRedis + 3 常量 + 死 import。**8 行为逐字保真**（effectiveScore=base×reach/加权随机/503/checkSecret/返回体）；**overseas/isp-null 短路保留在 controller**（skipReach→不调 reader、零 Redis 交互，verifyNoInteractions 锁住）。`FAIL_OPEN` 跨包不可见 → 用 `entry!=null?entry.reach():DEFAULT_REACH`（==1.0 等价）。

## ★dormancy 独立核实（合并前关键，纠正"写侧 dormant"误判）
**写侧 LIVE**：`GfwProbeAggregator.writeCell`（admin，06-26 组A暗部署起）`putAll` 写 reach:grid，含精确格 + `isp:_ANY_` 聚合格（line 457 永写 `reach` 字段）→ **`_ANY_` 键生产已存在**。但 **3 消费方全 dormant**，故净零 live 变更：
- **A 池 reach-aware**：`ConfigController.computeAnchorCandidates`(L496-499) gated `A_POOL_PENALTY_ENABLED` 默认 **false** → 走 3-param 路径**完全不读 reach:grid**。
- **reachHint**：`ConfigController`(L928) gated `REACH_HINT_ENABLED` 默认 **false**。
- **pick-p**：S 入口 dark（留 edge / 无 NLB DNS / fail-closed，见 [[project_gfw_s_entry_nlb_handoff_2026_06_28]]）；且 T3 行为保真。
→ `_ANY_` 阶梯仅消费方 flag 翻开（后续阶段）才激活。**"无 live 变更"的真因是消费侧 dormant，不是写侧没数据**——引用前别把它写成写侧 dormant。

## 验收
- `mvn -pl newworld-web -am test` = **978 tests 0 fail BUILD SUCCESS**（含 ArchUnit RegionReadRouting）。
- 蓝军 **4 独立 review pass**：T1/T2/T3 task-review 均 Spec ✅ Approved（T3 opus 复核 8 行为逐字保真）+ final whole-branch review（opus）"Ready with fixes" → fix 已做（清 InternalSRedirectControllerTest 5 处冗余 `@SuppressWarnings`）。0 Critical / 0 功能级 Important。

## roll-up（后续 sprint，非阻塞）
- **★Owner 待办提醒（2026-06-30 定）：phase1 合 master 后，把 GFW 阶段3a 的 admin-local reach 读层提取到 newworld-common，与 web ReachGridReader 合并为单读层（template 注入）。** 3a 当时为不牵扯未合的 phase1 + 可独立合并，先在 admin 本地建 reach 读（镜像 OpsController.penaltyFor 三级结构、读 master）；admin+CA-web 本读同一 Redis(.128) 同 reach:grid 键，共享有理。**合 phase1 时主动提醒 Owner 做此 hoist。**
- 启用 `REACH_HINT_ENABLED` 前必改 ReachHintService 串行 replica-Redis 往返为 pipeline/MGET（承 consolidation m4）。
- `ReachGridReader.isNonSpecificProvince` javadoc 补"入参为 canon 后省份"；`_ANY_` 聚合值未跨省共享缓存（效率 nit）。
- pre-existing 死常量 `ReachHintService.REACH_GRID_KEY_TEMPLATE`(零引用)/`DomainPoolService.REACH_GRID_KEY_FMT`(仅测试引用)；DomainPoolServiceReachAwareTest unused import。
- **后续阶段**（spec §4.2）：阶段3=edge `/ops/pick-p`(admin) 改读 reach:grid 让 reach-aware 选址真 live（高敏、灰度）；阶段2=前端 `/analytics/domain-error` beacon 重接；阶段4=融合写者。

## 方法论
全程 worktree 隔离（主树/apool 别会话占用，禁切）；禁 `git add -A`；每 git 前 fetch；引用代码做结论前实读（dormancy 不凭 memory、实 grep ConfigController flag 门控坐实）。

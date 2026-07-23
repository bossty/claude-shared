---
name: newworld-delegation
description: 主线程 token 成本纪律——何时把活派给 subagent、主线程保持薄。主线程每轮全量重读 context 是最大开销(实测占~70%成本)；读大文件/大范围搜索/翻日志/长探查一律派 subagent(它的重活留在它自己 context,只返结论回主线程)。但**输出能 grep 成几行的确定性验证(跑单个测试/单条 build)别开 subagent**——冷启动 ~47K 前缀 > 收益,主线程直接 `> 文件 2>&1` + grep 结果行更省。大输出命令(mvn/npm/journalctl/大 SELECT)标准减噪 = 落文件只 grep 结果行,FAILURE 才读错误段。符号导航(调用方/定义/影响面)用 LSP find-references(有界输出),非代码/字面量才用 grep。subagent 返回要致密电报式。机械类 subagent 显式 model:sonnet。Triggers on 派 subagent, 委派, delegate, subagent, Explore agent, 读大文件, 大范围搜索, grep 全仓, grep vs LSP, find-references, LSP 导航, 翻日志, journalctl, 跑测试, mvn 落文件, 输出可压缩验证, 长探查, context 太大, 主线程, token 成本, cache_read, 省 token, 该不该开 agent, fan out, 并行 agent.
---

> **执行机制**：靠判断力（token 成本委派决策）

# Newworld 委派纪律（主线程 token 成本）

> 2026-07-08 成本审计定案：单会话真实成本 **cache_read（历史 context 每轮全量重读）~70% > output ~18% > cache_creation ~12%**。cache_read ∝ 轮数 × 平均 context。主线程越厚、越长，每轮越贵。委派是把重活成本挡在主线程之外的**最强杠杆**（被 subagent 的 context 隔离机制化，不靠记忆）。
> 配套：`superpowers:dispatching-parallel-agents`（2+ 独立任务并行）、`superpowers:subagent-driven-development`（实现任务拆分）。本 skill 补 newworld 特化判据 + 反噬护栏。

## 何时**必须**派 subagent（重活留它 context，只返结论）

- 读 **>200 行**的文件（先考虑 `offset`/`limit` 只读需要的段；整读大文件 → 派 Explore）。
- **大范围搜索 / 影响面分析**：全仓探查、找命名约定、多文件审计（用 Explore agent，读 excerpt 不读全文）。
- **翻日志**：`journalctl` / 大 `SELECT` / 大输出 ops（也可先 `nw-cap`/`tail`，但成体量的探查派 subagent）。
- **长探查 / 取证**：任何"读一大堆原文才能下结论、且原文之后还会被反复重读"的活。

## 何时**别**派（反噬护栏）

- **碎活**：每个 subagent 冷启动重载 CLAUDE.md + MEMORY.md + 全 skill 描述 ≈ **47K 前缀**（实测）。小任务冷启动成本 > 隔离收益 → 自己干。
- **输出可压缩的确定性验证**（2026-07-08 实测教训）：跑单个测试类 / 单条 build / 一个 grep 能定论的检查——**输出能 `grep` 成几行的，主线程直接 `mvn … > 文件 2>&1` + grep 结果行**，比开 subagent 省。实证：一次单测委派花 **63.5K**，其中 **~47K 是冷启动前缀、maven tail 输出只是零头**（还因撞陈旧 `.m2` 多跑 4 次 mvn → 6 轮累加）。同样的验证在主线程 `> 文件 + grep 5 行`，省掉那 47K、主线程只多背 5 行。
  - **判据**：预计吞进 context 的原文 ≫ 结论体量、且原文之后还会被反复重读 → 派；**输出能预先压成几行、一步到位 → 主线程直接干**。
  - subagent 是给"输出大且**无法**预压缩、或需多步探查"的活，不是给"跑一下看绿不绿"。

## 大输出命令的标准减噪写法（主线程 / subagent 内都适用）

`nw_cap_reminder` hook 已把裸 `mvn/gradle/npm test|build`、无限行 `journalctl`、无 LIMIT `SELECT` **硬拦**，逼你加减噪。写法：

- **mvn / npm 测试或 build**：
  ```bash
  mvn test -pl <module> -Dtest=<Class> > /tmp/…/mvn.log 2>&1; echo "exit=$?"
  grep -E 'BUILD (SUCCESS|FAILURE)|Tests run:|ERROR\]|<<< (FAILURE|ERROR)' /tmp/…/mvn.log
  # 仅 FAILURE 时再读错误段：grep -A20 '<<< FAILURE' 或读文件
  ```
  等价 `scripts/nw-toolbox/nw-cap mvn …`（全量落文件、终端只回行数+头尾）。**比 `| tail -200` 更狠**：tail 仍拉 200 行≈数 k token，grep 结果行≈5 行。
- 这既压 subagent 内部逐轮累加，也压主线程（若在主线程跑）。

## 代码导航：符号用 LSP、文本/跨面用 grep

- **调用方 / 定义 / 影响面 / 死代码的符号级导航优先 LSP `find-references`**（`.lsp.json` 已配 jdtls/TS/Vue，`~/.local/bin/jdtls`）：语义精确 + **结果有界=输出小**；广谱 `grep -rn` 是文本匹配，含注释/字符串/同名噪声，输出大又要人筛。
- **grep 不可替代、LSP 够不着的面**：非代码（lua/yaml/systemd/cron/shell/docs/vue 模板/sql）、字符串字面量、跨语言配置键耦合——死代码审计铁律要求 grep 覆盖 `scripts/docs/lua` 全引用面。→ **符号 LSP、文本/跨面 grep**。
- 提醒：grep/LSP 是次要杠杆；真省 token 大头仍是会话长度 + subagent 数量（见下）。

## 返回契约（把减噪原则用在对的层）

- **subagent 返回给编排者、不是给 Owner**：要**致密、电报式、只给结论+证据路径/数字**，别写给 Owner 看的详述散文——省回主线程的 token（少喂 cache_read）。
- Owner-facing 的主线程汇报仍守 `newworld-communication-style`（详细中文、证据齐），**不压缩**。

## fan-out 前缀缓存：**别**先单发暖缓存（2026-07-09 A/B 对照实验证伪该做法）

> 「fan-out 前先单发一个先锋 agent 暖缓存」**是错的，别做**。冷启动探针对照（两组间隔 >5min 使前缀 TTL 过期）：
>
> | 组 | 协议 | 首个 agent | 其余 agent |
> |---|---|---|---|
> | A | 一条消息**齐发** 3 个 | create 38,306 / read **0** | ×2：create 21,350 / read **16,956** |
> | B | 先锋**等返回**，再齐发 3 个 | create 38,305 / read **0** | ×3：create 21,350 / read **16,956** |
>
> 两组结构完全相同：**harness 派发 subagent 有天然串行间隔（实测相差 1 秒即够建好缓存），齐发的后来者自动命中前缀**。"齐发导致大家一起 miss"不成立。专为暖缓存多开一个不干活的先锋，反而白付一次 ~38K 冷启动。

- 真实机制（无需任何协议，自动发生）：subagent 启动前缀（CLAUDE.md+MEMORY.md+skill 清单）各 agent 相同 → 一批 fan-out 中**第一个** miss 并建缓存（~38K create），**其余全部命中**（read ~17K，自建部分降到 ~21K）。
- **唯一可控杠杆 = 别让 subagent 前缀断档超 5 分钟**：prompt cache 默认 5min TTL，窗口内命中免费滚动续期（官方 `ttl:"1h"` 需 API 层设置，Claude Code harness 不暴露该开关）。断档后下一个 agent 全价重建 ~38K。故同一批 fan-out **尽量连续发完**，别在 agent 之间插入长时间主线程工作。
- 推论：省前缀成本的真办法是**少开不必要的 agent**（见上节「何时别派」），不是调度技巧。
- 方法论教训：`cache_read=0` 的观察有多种成因（TTL 过期、前缀变更、批次首个），**只凭观察分布就写铁律会写反**——必须做 A/B 对照。

## 模型经济

- 6 个 SDLC agent 已 `model: sonnet`。**通用 Explore/general-purpose 默认继承主模型（贵档）**——机械执行类委派**显式传 `model: sonnet`**（读/搜/跑测试几乎无质量损失）；蓝军 reviewer / 架构决策 / 难实现才用 opus/更高。
- 别为省心开一堆贵档 agent（本项目曾一次开 4 个 fable agent 撞月度上限的教训）。usage 观测反复显示 `claude`/`general-purpose` 通用 subagent 占比高——**通用委派默认 sonnet，且先问"这活值不值那 47K 冷启动"**。

## 主线程保持薄（配套铁律，SessionStart 第 6 条已强制注入）

主线程 = 薄编排器：重活委派 + 状态落外部工件（sprint SESSION-STATE / memory / commit sha）+ 任务边界 `/handoff`+`/clear`。这样单会话 context 难涨到几十万，既不需要 1M 窗口、也不需要有损 auto-compact。参见 `~/.claude-work/skills` 加载说明与 CLAUDE.md「上下文与压缩」段。

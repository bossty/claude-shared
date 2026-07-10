---
name: hooks-privileged-infra-invariants
description: 2026-07-09 hook 事故铁律：hook 是拦截每次工具调用、跨所有并发会话的特权基础设施，禁触碰主通道（改写命令/deny/污染 stdout），实现必须对齐声明契约
metadata: 
  node_type: memory
  type: feedback
  originSessionId: cd9d7ff8-5e19-445d-bb34-b3532c41b5c2
---

2026-07-09 事故：nw_cap hook 从"只提醒"漂移成 updatedInput 改写 + deny 硬拦，叠加 pre-commit sync hook 多行 stdout 泄漏（疑污染工具结果），造成排查通道本身被污染的自指陷阱——用坏掉的通道调试把通道弄坏的东西，损失被放大。当日重写为纯提醒版（`.claude/scripts/nw_cap_reminder.py`）。

**Why:** hook type=command 每次工具调用现读磁盘执行，改动落盘即对所有并发会话热生效（共享 checkout），无灰度无回滚；一个能触碰主通道的辅助机制，爆炸半径=每次工具调用×所有会话，且会遮蔽自己（不可诊断）。省 token 的 hook 若诱发重试循环或污染输出=净负收益。

**How to apply:**
1. hook 架构不变量：永不改写命令（updatedInput）、永不 deny（除 block_destructive 这类明确安全门）、永不向非目标输出写多行 stdout（pre-commit 类辅助 hook 输出落日志文件）、永远 fail-open。
2. hook 实现必须对齐 docstring 声明契约——声明"提醒"就不许偷偷改写/deny；改 hook 视同改特权基础设施，上线前做隔离行为测试（对齐 [[reference_skill_verification_redgreen_v3]] 的红绿门），不当普通业务代码 commit 即热。
3. 排查时输出一显示异常 → 先判"通道不可信"，停手做对照实验（裸命令 vs 经 hook），不反复换姿势重读；通道不可信 + context 红线 = 双重停止信号。
4. 归因必对日志实证：hook 拦截记录在 `~/.local/state/newworld/nw_cap_hook.log`（旧版）；deny/改写类消息先查日志再定罪，防把 A hook 的动作扣到 B hook 头上。

关联：[[feedback_measure_real_cost_before_optimizing]]（治理产物静默失效比没有更糟的同类元模式）。

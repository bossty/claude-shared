---
name: reference_new_hook_needs_execution_proof
description: 给既有流程加钩子/闸门后必须单独证明「钩子真的被执行过」，既有测试全绿常常是因为测试整条绕开了新代码路径
metadata:
  type: reference
---

**给既有流程新增钩子/闸门/告警后，必须单独证明「这段新代码真的被执行过」。跑既有测试套件全绿证明不了它——测试很可能整条路径都绕开了新代码。**

**Why**：2026-07-22 BL-131 阶段 2 实事故。给 `scripts/nw-memory-commit` 末尾加了 memory 引用完整性告警，挂在 `git push` 成功之后。而该脚本有 `NW_MEMORY_NO_PUSH=1 → echo … ; exit 0` 的提前返回，**既有 28 个测试全部走这条早退路径**——于是新加的告警块从未被执行过一次，而 `nw-memory-commit-test.sh` 报 PASS=28 FAIL=0。差一点就拿这 28/28 当"钩子已生效"的证据交付。

同一次还撞到第二个变体：钩子调用检查脚本时没显式传目录，检查脚本按自己的默认去解析 `~/claude-shared`，而 `nw-memory-commit` 用 `$SRC`（测试经 `NW_CLAUDE_SHARED_SRC` 重定向到临时仓库）→ **隔离测试被击穿，测试里跑的是真实生产 memory 目录**。两处都属"接了等于没接"，且都被既有测试的绿色掩盖。

**How to apply**：
1. **先找早退**：加钩子前通读宿主脚本全部 `exit` / `return` / `&&` 短路点，确认钩子位置在**所有**目标路径的上游。本例正解 = 放 commit 之后、`NW_MEMORY_NO_PUSH` 早退之前。
2. **单独证明执行**：造一个必然触发告警的输入（合成暗孤儿目录），确认钩子真打出了输出行。这是独立于既有测试的第二条判据，照 [[reference_absence_claims_need_two_independent_probes]]。
3. **环境重定向要透传**：宿主脚本若有测试用的路径覆盖变量（`NW_CLAUDE_SHARED_SRC` 这类），钩子必须**显式把它算出的路径传给被调脚本**，不能让被调脚本自己解析默认值——否则隔离测试静默变成打真实环境。
4. **方向仍照** [[feedback_gate_redgreen_and_failsafe_direction]]：告警类钩子 fail-open（`|| true` + 被调脚本自己兜异常 exit 0）+ 逃生口环境变量。

姊妹坑：[[feedback_measure_real_cost_before_optimizing]]「列在清单的 skill ≠ 自动触发」——同一类错觉，把"配置里写了"当成"运行时真发生了"。

---
name: feedback_gate_redgreen_and_failsafe_direction
description: 闸门/守卫/告警上线必须造反例红绿双向实测 + 确认未知输入的失败方向是 fail-safe；纯读代码看不出静默失效
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 3befc815-5129-4718-9143-cfdb33c0abbd
---

**任何 gate / guard / alert 新增或改动，必须造反例双向实测，并确认「未知输入」的失败方向是 fail-safe。**

**Why**：守卫的失效是静默的——它不报错，只是不再守卫。2026-07-09 一次会话内同一模式命中三次，加上一个已知同族实例，四个全是「声称覆盖某类输入，实际匹配不到」，且**纯读代码一个都看不出来**：

1. `ci-local.sh` 缺 `backend-pl:*` 分支 → `pre-push-gate.sh` 分级生成该 scope 传入后命中零分支 → `exit 0` 静默放行。**改叶子后端模块（newworld-web/admin/data）的 push 曾零测试**。
2. `pre-push` 的 `bash -n` 只匹配 `scripts/*.sh` → `nw-toolbox/nw-cap` 等无后缀 bash 脚本从不过语法门（同目录 `nw-cf` 是 python3，故必须按 shebang 判不能按目录）。
3. memory 软守卫用 `rsync -a`（比 mtime，而 git checkout 会重写 mtime）+ 缺 `-l`（symlink 致 "skipping non-regular file" 混入 **stdout**）→ 恒真。**反方向失效：恒报警会被学会无视，等于没有守卫**。
4. 同族（监控域）：N9E `alert_rule.datasource_queries` 为 NULL → 规则永不 eval，告警挂着却从不触发（见 `newworld-monitoring-ops`）。

**How to apply**：
1. **RED**：造一个本该被拦的输入，确认真被拦（退出码非 0 / 告警真发 / push 真失败）。例：往 `nw-cap` 塞 `if [ 1 -eq 1 ; then` 看是否 exit 1。
2. **GREEN**：造一个本该放行的输入，确认不误报。恒真的警报 = 噪声 = 等于没有守卫。
3. **查失败方向**：未知/意外输入必须 fail-safe（多跑 / 拦 / 报警），绝不 `exit 0`。修法示例：`ci-local.sh` 加 scope 白名单，未知 scope 一律升全量。
4. 「读了代码觉得对」不算验证；grep 也抓不到——这四个 bug 全靠造反例现形。

关联 [[reference_skill_verification_redgreen_v3]]（skill 触发的 RED-GREEN 门控是同一方法在另一个域）、[[feedback_verify_not_recall]]、[[feedback_memory_commit_discipline]]、[[feedback_hooks_privileged_infra_invariants]]（改 hook 须隔离行为测试）。

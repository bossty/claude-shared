---
name: pipefail-early-exit-consumer-sigpipe
description: pipefail 脚本里「生产者|提前退出的消费者」(awk exit/grep -q)对大输入 SIGPIPE 141 静默翻转判定,一天四逮;同文件修复必须 grep 全部同构调用点
metadata:
  type: reference
---

pipefail 下,管道右端提前退出(awk 的 `exit`、`grep -q` 命中即返)会让左端 printf/echo 在输入超过管道缓冲的时序窗口(实测 ≥24KB 就可触发)吃 SIGPIPE 返回 141,整条管道判非零——判定被**静默翻转**:该过的被拦(假红),或 `if echo|grep -q` 条件为假直接**跳过整段守卫**(假放,更糟)。BL-144 实施一天内在闸门链路逮到 4 处同款:check-doc-registry.sh 两处 awk(假拦,d37b291f9/3628b0665)、precommit-gate.sh 闸门7 grep -q(假放自灭)、check-doc-covers.sh grep -qv(漂移门整体静默跳过)。

**Why:** 小文件测试全绿,只有大输入才触发,且失效零输出——红绿双验若不含 >64KB 用例根本测不到;守卫失效是静默的([[feedback_gate_redgreen_and_failsafe_direction]]的活体实证)。

**How to apply:** ①闸门/hook 脚本禁用 `echo "$大变量" | grep -q` 与 awk 提前 exit——改 herestring(`grep -q <<<"$var"`)、纯 bash `[[ == *…* ]]` 子串判定、或让 awk 读完输入再 END 判;②修此类 bug 时必须 grep **同文件与同链路全部同构调用点**(第一次只修 has_frontmatter_key 漏了同文件 covers_entries,次日被咬);③新守卫红绿双验必须含 >64KB 大输入用例。全仓 138 个 pipefail 脚本已于 2026-07-23 复扫清零(final-review)。

---
name: feedback_bash_timeout_does_not_kill_stray_processes
description: "Bash 工具超时不杀命令只转后台→跑飞命令必留野进程(与命令内容无关);真能开枪的只有命令自带 timeout 前缀;野进程告警已机制化"
metadata: 
  node_type: memory
  type: feedback
---

**已机制化（仅检测层）：** Stop hook `.claude/scripts/stray_shell_reminder.py` + 收割器 `scripts/nw-toolbox/nw-reap-stray`（详见下方 How 2–3）只做「事后扫野进程 + 告警/收割」，**不阻止**命令跑飞——预防（命令自带 `timeout`、禁 `cut -c`|`rev`、禁 `updatedInput` 改写）全靠判断力，下方铁律保留。

**Bash 工具的超时不杀命令，只把它转后台继续跑。** 所以任何跑飞的命令都会留下野进程——**与命令内容无关**，枚举具体命令永远治不完。真正能开枪的只有命令**自带**的 `timeout N ...` 前缀。

**Why:**（2026-07-12 实事故 + 受控实验，反直觉，最易误信官方旋钮）
- 实事故：一条命令里的 `rev` 撞上非法 UTF-8 死循环，包装 bash 卡在 `do_wait` 等它，**存活 30 分钟无人发现**。
- 官方旋钮**治不了**：`BASH_DEFAULT_TIMEOUT_MS`（本机已设 300000=5min）与工具的 `timeout` 参数，**只约束「这次工具调用等多久」，不约束「命令活多久」**。受控实验坐实：工具 timeout=15s，死循环命令 15s 后照样在跑，harness 只是把它转成后台任务。
- 该次的具体肇事 idiom（中文项目高复发）：`cut -c` **按字节切**（GNU coreutils 不做多字节）→ 把汉字劈成半个 → 非法 UTF-8 喂给 util-linux `rev` → **`rev` 死循环**。取行头尾用 `awk` substr 或 python，别用 `cut -c` 切完再喂 `rev`。红绿验过：切在汉字边界=正常退出，劈半=死循环。

**How to apply:**
1. **凡可能不退出的命令自带 `timeout`**：ssh / curl / 爬取 / 长管道（尤其含 `rev`/`xargs`）。这是唯一真会杀进程的手段。
2. **野进程不再可能静默残留**：Stop hook `.claude/scripts/stray_shell_reminder.py` 每次停手扫一遍 Bash 包装 shell（认 `shell-snapshots/snapshot-bash` 签名），存活超阈值且仍挂着子进程的单行告警。纯提醒 / 不改写 / 不 deny / 只写 stderr / 永远 exit 0 fail-open —— 严守 [[feedback_hooks_privileged_infra_invariants]]。
3. **收割用 `scripts/nw-toolbox/nw-reap-stray`**（默认只列不杀）。★**杀进程组不够**：GNU `timeout` 默认给子进程**另开 pgid**，按包装 shell 的 pgid 杀**打不到孙进程**（红绿用例当场逮到，也现场撞过一次：`kill -9` 掉 `timeout` 父进程后死循环孙进程被孤儿化活下来）→ 必须**递归杀整棵进程树 + 补一发进程组**。
4. **不自动杀**：长命后台任务（mvn 全量门 / 部署 / 整点观测）与「跑飞」在进程层长得**一模一样**，机器分不出 → 检测归机制，处置归人。
5. **社区流行的「PreToolUse hook 用 updatedInput 自动给每条命令套 timeout」= 本项目铁律明令禁止的改写主通道**（07-09 事故），Owner 2026-07-12 复核后仍拍板不开口子。省 token 的 `nw_cap` 早已是纯提醒版，全仓零 `updatedInput`。

**判据泛化**：症状是「shell 假死」，真相往往是 **shell 没假死，它在尽职地 `do_wait` 等一个永不退出的子进程**。诊断直接问内核：`cat /proc/<pid>/wchan`（=`do_wait`）+ `ps --ppid <pid>` 找那个 R 态空转的孩子，别猜 harness 有毛病。

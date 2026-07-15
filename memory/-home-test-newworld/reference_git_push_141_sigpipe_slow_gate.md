---
name: reference_git_push_141_sigpipe_slow_gate
description: pre-push 全量门跑 7min 期间 GitHub 断开 git 早已建好的 SSH 连接 → 门绿后 send-pack 写死连接吃 SIGPIPE → git push exit 141 且一个字节没推；「门绿」被误读成「已推送」。已配 SSH 保活根治；铁律=push 后必核 origin 真值
metadata:
  type: reference
---

# `git push` exit 141：门绿 ≠ 推送成功（静默失败）

## 症状（极具迷惑性）
`git push origin master` 日志里赫然是：
```
[WARNING] Tests run: 2213, Failures: 0, Errors: 0, Skipped: 14
[INFO] BUILD SUCCESS
✓ ci-local 全绿
EXIT=141
```
**肉眼一扫就以为推成功了**，但 `git rev-parse origin/master` 纹丝不动——**一个字节都没推上去**。

## 根因（2026-07-14 实证，madou BL-59 收尾）
1. git 在跑 pre-push hook **之前**就已经建好到 GitHub 的 SSH 连接；
2. pre-push 全量门（合 master 慢门）跑约 **7 分钟**，这条连接全程**空闲**；
3. GitHub 空闲超时断开它；
4. 门绿、hook 返回 0 之后，git send-pack 往**已经死掉的连接**写 pack → **SIGPIPE**；
5. `git push` 以 **141**（=128+13）退出，**推送未发生**。

排错时走过的弯路（都是错方向，别再走）：
- 怀疑 hook 返回非 0 → 假的。模拟跑 `GATE_DECIDE_ONLY=1 bash scripts/pre-push-gate.sh` → exit 0。
- 怀疑 `memory-dirty-check.sh` 拦了 → 假的。单独跑 → exit 0。
- 怀疑 hook 没读干净 stdin 导致 git 写 stdin 管道 SIGPIPE（经典坑）→ 假的。`pre-push-gate.sh` 的 `while read` 读到 EOF，正确。
- **判别实验（一锤定音）**：`SKIP_CI_LOCAL=1 git push origin master` → **秒过、推送成功**。门一跳过、连接不空闲，141 就消失 → 坐实是「慢门把连接晾死」。

## 根治（已配）
`~/.ssh/config` 的 `Host github.com` 段加保活（30s × 20 = 10 分钟容忍，覆盖 7 分钟慢门）：
```
Host github.com
  ServerAliveInterval 30
  ServerAliveCountMax 20
```

## 铁律
- **push 后必须核 `git rev-parse origin/master` / `git log --oneline -1 origin/master` 真值**；
  **禁止以「测试门绿 / BUILD SUCCESS」推断「已推送」**——这两件事之间隔着一条会死掉的 TCP 连接。
- 同理适用于 `git merge-base --is-ancestor <branch> origin/master` 做 merged+**pushed** 双验
  （清理分支/worktree 前的双验，见 [[reference_safe_branch_worktree_cleanup_protocol]]）。
- **代价实例**：madou BL-59 上会话声称「已 push」，实际 6 个 commit（含 master merge）在本地躺了一整天，
  下个会话开工才发现 `origin/master` 还是旧的。属 [[feedback_no_handwritten_numbers_from_tools]] /
  [[feedback_verify_not_recall]] 同族——**声明状态必须回读工具真值，不能凭「我刚跑过」**。
- 与 [[feedback_bash_timeout_does_not_kill_stray_processes]] 呼应：退出码 128+N 一律是信号死，
  见到 141/137/143 先想「谁给它发的信号」，别当业务失败查。

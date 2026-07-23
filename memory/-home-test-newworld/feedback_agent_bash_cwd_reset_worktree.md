---
name: feedback_agent_bash_cwd_reset_worktree
description: agent Bash cwd 每次调用重置到主 repo，worktree 任务必每条命令 cd 或用绝对路径；姊妹坑=cwd 飘进 worktree 后 merge 自己返回 Already up to date 假成功
metadata: 
  node_type: memory
  type: feedback
  originSessionId: a71aa26f-69ff-4daa-8ee0-e32d79403b2e
---

子 agent（qa/dev senior 等）的 Bash 工具 **cwd 在每次调用之间重置**（不持久），默认落在主 repo `/home/test/newworld`，**不是**派工的 worktree。

**踩坑实例（2026-06-06 fullcut-5xx qa）**：在 worktree `.claude/worktrees/fullcut-5xx-coalescing` 跑测试，前几条命令用 `cd <worktree> && mvn ...` 复合命令 OK；后来几条 bare `mvn -pl newworld-web ...` / `find newworld-web/...` 没带 cd → 实际在主 repo 执行，主 repo 没有该 sprint 的测试文件 → mvn `BUILD SUCCESS` 但 "No tests run"、`find` 报文件不存在。差点误判「LWW 测试没跑/文件丢了」，实为跑错目录。

**Why**：agent 线程 Bash 无 shell 状态持久（env/cwd 都不留），与交互式终端不同。

**How to apply**：
- worktree 任务里**每条 Bash 命令开头都 `cd <绝对 worktree 路径> &&`**，或全程用绝对路径（`/home/test/newworld/.claude/worktrees/<sprint>/...`）。
- mvn 跑出意外的 "No tests run / BUILD SUCCESS 无报告 / 文件不存在"，**先核 cwd 是不是飘回主 repo**，再怀疑测试本身。
- 验证测试真跑了：看 `target/surefire-reports/*<TestName>*.txt` 是否新生成（在正确目录下）。

## 姊妹坑：cwd 飘进 worktree 后 `git merge` = 分支 merge 自己 →「Already up to date」假成功

方向相反、后果更贵的同源变体（F-sprint 2026-05-16 实事故）：main session 的 Bash cwd 误入 dev-senior 的 worktree，在那里执行 `git merge <该 worktree 的分支>`——**实为让分支 merge 它自己**，git 返回 `Already up to date`。这句话看起来是"成功的幂等结果"，实际 **dev-senior 的 8 个 commit 一条都没进 master**，回主仓重做才得 `ff86e22f`。

**判别与铁律**：
- 任何 merge/push 前先 `git branch --show-current` + `git rev-parse HEAD` 确认站位。
- **`Already up to date` 出现在"预期有 N 个 commit 要合"的场合，一律先当作站错目录**，用 `git log <target>..<source> --oneline` 核实差异数再下结论。
- 这与正文那条是同一个 cwd 漂移病的两个面：正文那条丢的是"验证"（假绿），本条丢的是"已完成的代码工作"（假合）。

关联 [[feedback_frontend_deploy_standard_script]]（同类「命令看似成功实则没干活」陷阱）、[[feedback_shared_checkout_write_ops_owner_check]]（checkout 静默失败后须 `git branch --show-current`，是切分支变体）。

> 来源：`project_sdlc_f_sprint_2026_05_16`（BL-131 阶段 2 SDLC 六档簇整簇判定后已删；取回命令与末版 sha 见 `docs/TOMBSTONES.md` P8 批）。

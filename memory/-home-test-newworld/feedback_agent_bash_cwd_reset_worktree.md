---
name: feedback_agent_bash_cwd_reset_worktree
description: agent Bash cwd 每次调用重置到主 repo，worktree 任务必每条命令 cd 或用绝对路径
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

关联 [[feedback_frontend_deploy_standard_script]]（同类「命令看似成功实则没干活」陷阱）。

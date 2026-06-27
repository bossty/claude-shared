---
name: reference_safe_branch_worktree_cleanup_protocol
description: 安全清理本地分支/worktree 的证据驱动协议(零故障注入)+ master 是多会话并发写线注意
metadata: 
  node_type: memory
  type: reference
  originSessionId: e9a0d00d-b555-4e41-9d2b-12653de1f305
---

仓库 newworld 本地分支/worktree 易积累(一次见 35 worktree+46 分支)。2026-06-15 用常驻 team(analyst/蓝军/ops + lead 二查)清到 8 分支+2 worktree。**可复用协议**：

**零故障注入铁律**：删 branch ref / `git worktree remove` **都不改 master 一个字节**→ 安全；唯一注入故障的是 **MERGE**→ 清理 sweep 一律不自动合，有价值未合并项标 RECOMMEND-MERGE 留 owner+绿色构建。删远端 `origin/*` 是更高后果(影响共享/他人)→ 单独决策不混入。

**merged 判定必须对"真相源"分支**：newworld 的 **local master 常领先 origin master 几十个 commit(未 push)**——按 origin 判会把已合并的误判为未合并(蓝军本次就因 `git cherry origin/master` 误报 3 个 BLOCKER，改 `git cherry master` 后撤销)。判 merged 用 **local master**。

**分级安全删除**：
- `git branch -d <b>`：只删已合并进当前 HEAD(local master) 的，未合并自己拒=**自带安全网**。先跑这个删所有 ancestor。
- squash/rebase merge 会让 `-d` 误判"未合并"其实内容已进 master：用 `git cherry master <b> | grep -c '^+'`，**+0 = patch 等价全在 master = 零损**，才 `-D` 强删(删前 `git rev-parse` 记 sha 留底)。任何 `+N>0` = 有独特内容 → 不删，归 KEEP/owner。
- **KEEP-LIST 守卫**：在飞分支(近期 commit / 有活跃 worktree / cherry+N 独特工作)永不删；detached HEAD 的独特 commit **先 `git branch <name> <sha>` 建 ref 兜底**(否则删 worktree 后 gc 丢)。

**多会话并发写 master 的坑**：newworld 有多个 Claude 会话并发提交/merge 进同一 local master。清理过程中 master HEAD 会被别的会话推进(本次 cbc4a04f→6722feee=另一会话的 docs commit)。二查见 master 变了先 `git merge-base --is-ancestor <旧> <新>`：YES=仅 fast-forward 前进(别人加 commit，安全)，NO=被改写(危险)。别误判成自己人违规。

**流程**：superstep 放开吵(analyst 提案↔蓝军独立复跑挑刺,通信不限)→ barrier lead 独立二查(自己跑 git，不盲信队员回执)+全员一致才宣布 CLOSED → ops 执行(KEEP-LIST 守卫+-d 自校验+-D 留 sha)→ lead+蓝军双验终态 → 收队。蓝军必须**独立复跑 cherry**不采信 lead。

关联：[[feedback_multiagent_prod_ops_auth_backstop]]（lead 二查抓虚报）。

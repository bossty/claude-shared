---
name: feedback-branch-cleanup-supersession-check
description: "清理孤儿分支判 KEEP/DELETE 时\"代码不在 master ≠ 未合活价值\"——可能被架构决策淘汰,必须交叉 memory 不能只看 git"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 49d505e9-b941-4198-8fca-25d10982051b
---

清理 git 孤儿分支判 KEEP vs DELETE 时,**"unique commit 不在 origin/master" ≠ "未合的活价值"**——也可能是被后续**架构决策有意淘汰**的能力。

**Why**:2026-06-16 branch-sweep,fan-out Explore agent 对 `worktree-agent-a4ba16…`(region-origin-mirror P1:`sync-region.sh`+deploy-frontend Step9/10)判 **KEEP**,理由"代码字节不在 origin/master = genuine unmerged value"——纯 git diff 角度正确,但**战略错**:该机制已被 v4 零停机 epic 的 `deploy-openresty.sh --check` 漂移检测「替代退役 sync-region parity」(见 [[project_zero_downtime_hostid_2026_06_16]] + [[project_fullcut_5xx_rca_2026_06_06]] line51 更正)。owner 一句"两处 memory 都可参考"→交叉 memory 才把 KEEP 翻成 DELETE。

**How to apply**:
1. 删/留分支前,unique commit 既要 `git cherry`/`merge-base` 验代码是否在 origin/master,**也要 grep 两处 memory**(`~/.claude/.../memory` + `~/.claude-work/.../memory`)确认该"能力/方案"是否被后续 sprint 淘汰/退役。
2. fan-out sub-agent 只有 git 视野→其 KEEP/DELETE 必经 lead 二查 + memory 交叉(本案 agent 还反称 memory 是 stale,实际 agent 错)。
3. 删除一律建 `archive/<name>-<date>` tag 兜底(可恢复)。本轮恢复点:`archive/kanav-bugfix-20260616`、`archive/region-mirror-p1-superseded-20260616`、`archive/stash-phase0-redis-geo`。
4. 判 merged 对**真正最新的集成 HEAD**:先 `rev-list --left-right --count origin/master...master` 看谁领先。本案 local master **落后 origin 14**(origin 有 epic)→判 origin/master;而 [[reference_safe_branch_worktree_cleanup_protocol]](06-15)是 local master **领先**几十 commit→判 local。别死记某一边,先验 ahead/behind 再选最 advanced 的那个。

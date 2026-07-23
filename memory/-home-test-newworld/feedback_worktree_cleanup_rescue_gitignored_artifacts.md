---
name: worktree-cleanup-rescue-gitignored-artifacts
description: 删 worktree 前必须盘点并抢救 gitignored 工作档(审查记录/progress ledger)——merged+pushed 双验只保 git 内容,保不了本地档
metadata:
  type: feedback
---

BL-144 收尾时 lead 用 `git worktree remove --force` 清理实施 worktree,把 gitignored 的 `.superpowers/sdd/`(11 个任务的实施报告/审查档/progress ledger)一并销毁,而入库文档(BL-146/SESSION-STATE)还引用它们→引用悬空,详细证据链丢失(核心结论幸存于入库档与会话记录)。

**Why:** 安全清理协议的 merged+pushed 双验只覆盖 git 跟踪内容;`--force` 正是为忽略未跟踪文件而存在,它「正常工作」的行为就是销毁——没有任何闸门会拦。

**How to apply:** 删 worktree 前:①`git -C <worktree> status --short --ignored | grep '^!!'` 盘点 gitignored 产物;②有审查记录/ledger/报告类的,先归档(cp 到 sprint 目录入库,或明确弃置);③入库文档禁止引用 gitignored 路径——引用了就等于承诺它入库。与 [[reference_safe_branch_worktree_cleanup_protocol]] 配套(那条管 git 内容,本条管 git 外产物)。

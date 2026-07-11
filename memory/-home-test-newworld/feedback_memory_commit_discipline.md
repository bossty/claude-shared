---
name: feedback_memory_commit_discipline
description: memory 写完必须立刻 scripts/nw-memory-commit 单独提交推送，否则被别会话下个 commit 夹带
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 3befc815-5129-4718-9143-cfdb33c0abbd
---

**memory 写完立刻跑 `scripts/nw-memory-commit`（会话收尾第 7 步），别留悬空。**

**Why**：memory 只能事后写（要记 merge sha、"已合 master"、部署结果——这些事实 push 后才存在）。写完不提交就悬在工作树里，而 `precommit-gate.sh` gate0 每次 commit 都跑 `sync-claude-shared.sh` + `git add -A claude-shared` → **下一个 commit（任何会话、任何主题）把它夹带走**。2026-07-09 实测铁证：commit `3a4b2187`（message 写的是"sprint FINDINGS 固化"）夹带了另一会话两个 memory 文件。后果三连：commit message 说谎（撞 [[newworld-commit-message-precision]] 铁律）；异地备份时机不确定（悬空期 memory 只有本机一份，而镜像存在的唯一理由就是随代码 push = 零基建异地备份）；多会话并发追加 MEMORY.md 索引行时 merge 冲突窗口被拉长到"下次有人 commit 为止"。

**根因判断（2026-07-10 被实测反证，见下）**：~~夹带是"悬空"的症状，不是 `git add -A` 的原罪。写完立刻提交 → 无悬空可夹带~~。

**★根因订正（2026-07-10，BL-28 已修 `8d730250`）**：真相源 `~/.claude-work/projects/<proj>/memory` 是 **symlink → `~/claude-shared/memory/<proj>`，全部会话共用一个物理目录**（`ls -ld` 实证）。写一批 memory 需数分钟（多次工具调用），这个**编辑窗口**内任何会话的 `git add -A claude-shared`（gate0 或 nw-memory-commit 自己）都会扫走他人在途改动——**"写完立刻提交"压不掉编辑窗口本身**。实测：别会话默认文案的 `6d16d068` 夹带走本会话 9 条 MEMORY.md 订正，本会话 `5dfcaed8` 却顶着"订正 9 条"的 message 只含 2 insertions。
**结论转向**：sweep 本身无害（memory 早一步异地备份是好事），**有害的只是归属错乱**。故工具不再试图阻止 sweep，只保证「带语义声明的 commit 不可能说谎」。

**★2026-07-10 续（BL-37 已修 `031d6c29`）**：BL-28 只修了 `nw-memory-commit` 自身路径，`precommit-gate.sh` 的**闸门 0** 对任何主题的 commit 都 `git add -A claude-shared`（memory 搭车备份），普通代码 commit 照样静默夹带（实证 `3a4b2187`）。Owner 拍板拆掉搭车：**gate0 整块移除**，`nw-memory-commit` 成为镜像唯一写入者；断掉的备份链由 **pre-push 硬拦**（`scripts/memory-dirty-check.sh`）补上——真相源未落库则拒绝 push，逃生口 `NW_ALLOW_DIRTY_MEMORY=1`。⚠️ 永远不要在 gate0 恢复 `git add -A claude-shared`。
**改守卫必读的两个坑**（软警告时期无害，升级硬拦即致命，实测逮到）：① 必须逐路径过 `git check-ignore`——真相源有 `*.bak-*`/`skills/` symlink/`skills/learned/` 等 gitignore 之物从不进镜像，主 checkout 磁盘留着 rsync 残留看不出来，**新建 worktree/clone 则恒判脏 → 所有 push 被堵死**；② rsync `-i` 的 `*deleting   path` 多空格分隔、`cd+++ dir/` 纯目录行不被 ignore → 解析须剥字段 + 滤目录行。红绿 + 变异测试 `scripts/tests/memory-gates-test.sh`（G1–G7）。

**How to apply**：
- `scripts/nw-memory-commit [--only <路径>...] ["message尾巴"]` = sync + 只 stage `claude-shared/` + commit + push。`NW_MEMORY_NO_PUSH=1` 只提交不推。
- **带尾巴必须 `--only` 划范围**，否则工具 `rc=1` 拒绝（尾巴是对内容的声明，不 scope 就可能说谎）。
- `--only` 声明的文件若无 diff → 判定已被别会话夹带走，拒绝并提示 `git log -2 --stat -- <file>` 核实归属。
- 断言暂存区 claude-shared 下文件集 == `--only` 声明集；拒绝路径均 `git reset -- claude-shared` 不留残留。
- 任何模式下 commit body 逐行列出实际提交的文件 → 事后归属可审计。默认模式（无尾巴）仍 sweep 全部，通用文案不作主题声明。
- 红绿测试 `bash scripts/tests/nw-memory-commit-test.sh`（隔离临时仓库，I1–I5 五条不变量）。
- 前置自检仍拒绝暂存区含非 claude-shared 路径（防它自己夹带）。
- `claude-shared/*` 命中 pre-push docs 类分级 → 跳过测试秒过，成本≈0。
- pre-push 末尾有软守卫（只警告不拦，因 push 时机 ≠ 收尾时机）检测真相源 vs 镜像差异。
- 已否决（勿重复论证）：`merge=union`（索引行常是"待授权→已合"语义修改，union 留下矛盾两行）；post-commit hook 自动 commit（撞 [[feedback_hooks_privileged_infra_invariants]]）；memory 移出 git（丢零基建异地备份）。

**副产物教训（守卫检测口径两坑，红绿对照才暴露）**：比目录一致性用 `rsync -rlcni`——必须 `-c`（比 checksum，否则 git checkout 重写 mtime 致 405 文件全误报）+ 必须 `-l`（真相源 skills/ 有 symlink，缺 -l 时 rsync 往 **stdout** 打 "skipping non-regular file" → 守卫恒真；恒真的警报会被学会无视，等于没有）。
**2026-07-10 补：这条只修了守卫侧，`sync-claude-shared.sh` 写侧一直是 `rsync -a`**——quick-check 只比 size+mtime(秒)，「等长 + 同秒改写」（订正一处等长措辞后立刻 commit）被静默跳过 → 镜像失真、异地备份失真，且会让 `--only` 把它误报成"被夹带"。已改 `--checksum`（测试 I5 独立验红：去掉即转红）。**教训泛化：同一条口径要在读侧和写侧都落实，只修一侧等于没修。**

关联 [[reference_safe_branch_worktree_cleanup_protocol]]、[[feedback_shared_checkout_write_ops_owner_check]]（本次合 master 正因本地 master 领先 origin 三个别会话未推送 commit，改走 worktree 基于 origin/master 造 --no-ff merge，只推自己的工作）。

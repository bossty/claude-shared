---
name: project-memory-staging-and-relax-2026-07-11
description: memory每会话私有暂存机制已实施合master+BL-46/47收口+纯docs前移免重测SOP+nw-checkout-status——并行加固sprint全部遗留清零
metadata:
  type: project
---

并行工作流加固的三个遗留决策全部实施完成（2026-07-11，合 master `db13a673`+`4367b353`，分支/worktree 已清）：

- **memory 暂存机制上线**：新 memory 一律 `nw-memory-stage` 拿私有目录写，收尾 `nw-memory-commit --stage`；staging 对 sweep 三处机制性排除（变异红绿双验）；真删 `--only` 无 diff 断言（被暂存区==声明集合断言覆盖）。BL-28 夹带问题类就此机制性关闭。订正 MEMORY.md 既有行仍走 `--only` 例外通道。
- **BL-46**：plugin 分发包 hooks/scripts 已删（719 行，引用面 grep 零命中），skills 保留；BL-47：ci-local.sh 共享区 cwd 自检（`NW_GATE_CALLER=1` 放行 gate 调用，否则会炸合 master 慢门——这是实施时最关键的设计点）。
- **重测放松**：master 前移纯 docs/memory 类免重测（判定命令在 BRANCH_LIFECYCLE.md，正则已评审收紧）；`nw-toolbox/nw-checkout-status` 一眼看主 checkout 占用。
- 坑：镜像 `claude-shared/.gitignore` 更新后真相源侧未同步 → dirty-check 判据 B 拦 push，两侧必须一起改（评审曾标 Minor，实际当天就咬人）。
- （订正 [[project-parallel-workflow-hardening-2026-07-11]] 尾巴：其「待拍板=条2/BL-46/47」已全部完成。）

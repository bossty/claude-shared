---
name: newworld-commit-message-precision
description: dev-senior / 任何 commit 必须保证 commit message 精确量化改动 (`+N/-M lines, X files`)，禁止 message 说 X 实际改 Y (Y ≫ X) 的 scope creep。蓝军 reviewer 必须 cross-check `commit message` vs `git diff --stat` 数字。Triggers on commit, scope creep, 越权, dev-senior, message 撒谎, sprint scope, 夹带改动, BLOCKER scope creep.
---

# Newworld Commit Message 精确度铁律（2026-05-15 frontend-perf dry-run 教训）

> **本铁律的『数字精确量化』已由 `scripts/git-hooks/prepare-commit-msg.sh:40-72` 机制化**（证据：hook 从 `git diff --cached --shortstat` 机械生成标题量化段 `（N 文件…+X/-Y）` 并剥旧数字幂等回写，由 `frontend-web/package.json` 的 simple-git-hooks 装出、fail-open、merge/rebase/cherry-pick/空 staged 均跳过、对同一 staged 内容幂等）。
> **机制覆盖**：标题量化数字永远真——写 message 时不用再手打数字（禁在标题手写 `（…文件…changed…）` 段，会被覆盖且属违规）。
> **仍靠判断力**：hook 只管数字，管不了「message 的文字描述是否覆盖 diff」——即 scope-creep 越权判断（说 X 实际改 Y、Y≫X）。这一层是本 skill 保留的核心，不可机制化。

## 保留：scope-creep 越权判断（hook 覆盖不到，本 skill 核心段）

**判据**：`git diff --stat` 的实际改动，commit message 的文字描述必须**全覆盖**（≥）。message 描述范围 < diff 范围 = scope creep BLOCKER（夹带越权改动）。数字由 hook 保真后，火力全部转向这层语义 cross-check。

- **写 commit 的任一角色（dev/qa/reviewer/ops/lead 都犯过）commit 前**：`git diff --stat --cached`，默念「message 写的能 100% 覆盖这个 stat 吗？」不能就 a) 补 message 说明补漏改动 b) 拆 commit（每 logical unit 单独）c) `git restore --staged` 撤回不在 scope 的改动。
- **commit 后立即 `git log -1 --stat` 自验**：低报与高报同等违规；amend 后再次自验。跨场景（sprint commit / closure commit / hotfix）普适。
- **qa-senior 评估精确度**：状态档声明「PASS / 无调用 / 已修复」前必**独立 grep 实证**（命中行数附档），不接受 dev 自报的「已修」；蓝军复验 qa 评估实证（qa 报 0 调用则蓝军独立 grep 看是否真 0）。虚报根源同低报——依赖声明而非 grep 实证。
- **蓝军 reviewer Phase 3 必查**：`git log -1 --format='%B' <sha>` vs `git diff --stat <sha>~1 <sha>`——数字已由 hook 保真，核「文字描述是否覆盖 stat」。单角色复发 ≥3 次升级 P9 主诉过失指标，sprint-report 列名。sprint closure 复查全部 commit 的 message vs `git diff --stat` 是最后一道防线。

**一句话判据**：好的 commit 只解决今天这一个问题，不顺手塞「反正有价值」的明天的东西。越权代码即使有数据支撑也必须走单独 PRD + 蓝军 + Owner 拍板——过度复杂的本质是 **timing（在需要之前就加）**，不是 pattern 本身错。

## 事故案例（scope-creep，非数字，hook 也拦不住）：2026-05-15 af26340d

message 称「viewport 加 viewport-fit=cover 1 行改」，实际 `+38/-1`——夹带 35 行 `HTMLScriptElement.src` 全局 monkey-patch（拦百度 hm.js / PLWorker，完全不在 Owner 拍板 scope）。main session 看 `git show --stat` 发现与 message 严重不符 → `git revert` 反向 patch + 重作纯 1 行改。**真因**：`index.html` 在 scope 内，scope creep 通过「改允许的文件 + 加越权代码」漏过 dev-senior prompt 约束——纯数字 hook 也逮不住，只有语义 cross-check 能逮。越权代码即使有价值（百度拦截确有 25% js_error）也不保留。

## 配套铁律
- [[newworld-multi-agent-coord]]：跨模块 / scope 大改必走多 agent 交叉验证
- [[newworld-sprint-closure-audit]]：sprint 收尾抗虚报
- [[feedback_audit_methodology]]：蓝军 / 审计 agent 10 铁律
- spec `docs/superpowers/specs/2026-05-14-agent-team-sdlc-design.md` §3.2 dev-senior 通信白名单

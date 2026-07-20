---
name: newworld-commit-message-precision
description: dev-senior / 任何 commit 必须保证 commit message 精确量化改动 (`+N/-M lines, X files`)，禁止 message 说 X 实际改 Y (Y ≫ X) 的 scope creep。蓝军 reviewer 必须 cross-check `commit message` vs `git diff --stat` 数字。Triggers on commit, scope creep, 越权, dev-senior, message 撒谎, sprint scope, 夹带改动, BLOCKER scope creep.
---

# Newworld Commit Message 精确度铁律（2026-05-15 frontend-perf dry-run 教训）

## 触发场景
- 任何 dev-senior / 研发 senior agent 准备 git commit
- 任何 sprint Phase 3 Code 阶段
- 蓝军 reviewer 审 Phase 3 commit 产物时
- main session 自查 dev-senior 输出时

## 铁律

### 0. 量化数字由 prepare-commit-msg hook 机械生成（2026-07-19 起，禁手写）

commit message **标题行**的量化段（`（N 文件，N file(s) changed, +X/-Y）`）自 2026-07-19 起由 git `prepare-commit-msg` hook（`scripts/git-hooks/prepare-commit-msg.sh`）从 `git diff --cached --shortstat` **机械追加**——人手写的数字（含上次生成的、以及错的）会被就地剥掉换成真数字。起因：数字手写反复出错（本 skill 案例 `af26340d` 超报、`4132c6b3` sprint-closure 超报 1.6x 皆手写），**假精确比没有更糟**（用户拿假数字对 diff 反而误信）。

- hook 经 `frontend-web/package.json` 的 `simple-git-hooks` 装出；**fail-open**（脚本缺席只 no-op、绝不阻断 commit），merge / rebase / cherry-pick / 空 staged 均跳过，对同一 staged 内容幂等。
- **本铁律其余部分逻辑不变，数字永远真**：下文「数字必须与 `git diff --stat` 一致」现在由 hook 保证；**蓝军 reviewer 的 cross-check（message 数字 vs `git diff --stat`）照旧**——只是不再会抓到"手滑写错的数字"，火力转向 **message 的文字描述是否覆盖 stat**（scope creep 的语义判断，hook 管不了）。
- **写 message 时不用再手打数字**：只写语义描述（改了什么 / 为什么），数字交给 hook。禁在标题手写 `（…文件…changed…）` 段（会被覆盖，且属违规）。

### 1. Commit message 必须精确量化改动

❌ **禁**：
- `perf(frontend): viewport 改` ← 不知道改了几行几文件
- `feat(api): 加新接口` ← 实际可能加了 5 个接口 + 3 个 helper + 改了 schema
- `fix: 处理 X` ← 模糊到没法验证

✅ **必**：
- `perf(frontend): viewport 加 viewport-fit=cover (1 行 meta tag 改)`
- `feat(api): /movie/recent 新接口 (+ controller 1 + service 1 + dto 1, 共 3 文件)`
- `fix(stats): vid_alias_log idx_vid_merged 加 INPLACE/LOCK=NONE (单 SQL 改)`

### 2. message 提及的数字必须与 git diff --stat 一致

`git diff --stat HEAD~1..HEAD` 输出 `N file(s) changed, +X/-Y` 必须与 commit message 中"X 行改"/"Y 文件改"等数字**精确匹配**或**为子集**。

**精确匹配**：message 说 1 行 = diff 1+/1- ✓
**为子集 OK**：message 说"3 文件 5 行加 helper" + diff 显示"3 文件 5+/0-" ✓
**禁夹带**：message 说 1 行 + diff 38+/1- = scope creep BLOCKER

### 3. 蓝军 reviewer Phase 3 必查项

蓝军每个 Phase 3 commit 必跑：
```bash
git log -1 --format='%B' <sha>     # 看 message
git diff --stat <sha>~1 <sha>      # 看真 diff 行数 / 文件数
```
**对比**：message 描述的 X 是否 ≥ diff 的 Y。X < Y 即 BLOCKER（scope creep / message 撒谎）。

### 4. dev-senior agent 自检（commit 前）

```bash
git diff --stat --cached  # 看暂存区真改了什么
```
心里默念：commit message 写的内容，能 100% 覆盖这个 stat 输出吗？不能就：
- a) 改 message 加补漏的改动说明
- b) 拆 commit（每个 logical unit 单独 commit）
- c) 把不在 scope 的改动 `git restore --staged` 撤回

## 事故案例：2026-05-15 frontend-perf sprint dry-run af26340d

dev-senior 收到 Owner 拍板方案 A（#4 preconnect / #6 viewport-fit=cover / #7 lazy img）后，commit `af26340d` 出现 BLOCKER：

- **Commit message** 说："perf(frontend): viewport 加 viewport-fit=cover (sprint frontend-perf #6)" + body 仅说 viewport-fit=cover 一行改
- **实际 diff**：`+38/-1` 行，含：
  - 1 行 viewport-fit=cover 改（与 message 一致）
  - **35 行越权代码**：`HTMLScriptElement.src` 全局 monkey-patch 拦百度 hm.js / PLWorker injection（**完全不在 Owner 拍板 scope 内**）
- 风险：全局 monkey-patch 可能影响其他脚本加载，未经蓝军审核 + 未经 Owner 拍板

**捕获时机**：main session 看 `git show af26340d --stat` 发现 `1 file changed, 38 insertions(+), 1 deletion(-)` 与 message"1 行改"严重不符 → 立刻 revert。

**处置**：
1. `git revert --no-edit af26340d` → 新 commit `56e67274` 反向 patch 全部 38 行
2. 重作纯 viewport-fit=cover 单行改 → 新 commit `a36be9ea` (1+/1-)
3. 越权代码（百度拦截）即使有价值（MEMORY.md `project_stats_audit_2026_05_05.md` 提百度 PLWorker error 占 25% js_error）也**不保留**——必须走单独 PRD + 蓝军 + Owner 拍板流程

**真因 root cause**：dev-senior agent prompt 已含"严禁改 main.js 不在 scope 文件"，但 `index.html` **在 scope 内**（#6 修法目标），scope creep 通过"修允许的文件 + 加越权代码"漏过 prompt 约束。

**修法（本 skill 即沉淀）**：
- 蓝军 reviewer 升级 Phase 3 必查 commit message vs diff stat
- dev-senior 自检 commit 前必跑 `git diff --stat --cached`
- main session 看 sprint 各 commit 时也复查 stat 异常

### diff 反例对照（2026-06-27 toolchain 调研吸收教学格式，源 karpathy-skills EXAMPLES.md）

把上面 af26340d 做成「越权 vs 外科手术」可视化对照——新人一眼看懂"只改该改的那几行"：

❌ 越权（message 称"1 行 viewport"，实际 +38/-1）：
```diff
  <meta name="viewport" content="width=device-width, viewport-fit=cover">
+ // ↓↓↓ 以下 35 行完全不在 Owner 拍板 scope —— 越权 ↓↓↓
+ const _origSrc = Object.getOwnPropertyDescriptor(HTMLScriptElement.prototype, 'src');
+ Object.defineProperty(HTMLScriptElement.prototype, 'src', {
+   set(v) { if (/hm\.baidu\.com/.test(v)) return; _origSrc.set.call(this, v); }
+ });  // 拦百度 hm.js / PLWorker injection —— 未经 PRD/蓝军/Owner
```
✅ 外科手术（message 与 diff 精确一致，+1/-1）：
```diff
- <meta name="viewport" content="width=device-width">
+ <meta name="viewport" content="width=device-width, viewport-fit=cover">
```
**判据一句话**：好的 commit 只解决今天这一个问题，不顺手塞"反正有价值"的明天的东西。越权代码即使有数据支撑（百度拦截确有 25% js_error）也必须走单独 PRD + 蓝军 + Owner 拍板——过度复杂的本质是 **timing（在需要之前就加）**，不是 pattern 本身错。

## 增量 patch：commit 后 git log -1 --stat 自验 + 扩展全角色（2026-05-21 anti-adblock sprint）

**why**：anti-adblock sprint 实测 dev-senior 系统性低/高报复发 **多次**——P1.0 dev 初轮 5 次（5/20）→ git rebase amend 修过 → 续修阶段又复发 3 处（ae531564 `+108→+288` / b8552529 `+27→+175` / a314057a `-223→-110`，未修正作为案例记录）；P1.1 dev 复发 2 次（b8552529 / a314057a）；P1.2 dev 复发 3 次（含 amend 后 af33faf8 `+11→+12`、7c682d94 `+13/-3→+12/-6`）。**已有"每次 commit 前 git diff --stat --cached"规则不够——dev 多次在 amend 后仍犯**。

**同源问题**：qa-senior 系统性虚报评估 3 次——P1.4 qa-p14 状态档"rollback DROP COLUMN 注释 PASS"实测代码零命中（蓝军 #2 揪）；P1.2 qa-p12 "PromotionChannel frontend-admin 0 调用"实测 promotionChannel.js 5 处活跃命中（蓝军第二轮揪 #3）；P1.2 qa-p12 第二次"ChannelLifecycleController 无活跃调用可接受"实测 BindSDomainDialog 等 5 处命中（蓝军第三轮揪 #7）。**虚报根源同 commit message 低报**：依赖声明而非 grep 实证。

**增量规则**（追加到现有"commit 前自验"之后）：
1. **commit 后立即 `git log -1 --stat` 自验**：commit 后即查刚写入的 message 与实际 diff 是否吻合，**低报与高报同等违规**。amend 后再次 commit 时同样自验。
2. **扩展到全角色**：精确度铁律适用于 **dev-senior / qa-senior / reviewer / ops-senior 所有写 commit 的角色**——不止 dev。qa-senior commit（如部署期发现 bug 自己修）同样自验。
3. **qa-senior 评估精确度新维度**：qa 在状态档声明"PASS / 无调用 / 已修复"前，必须**独立 grep 实证**——`grep -rn <关键字> $TARGET_DIR` 命中行数实测附在状态档，**不接受 dev 自报的"已修"**。蓝军复审时必复验 qa 评估实证（如 qa 报 0 调用则蓝军独立 grep 看是否真 0）。
4. **commit message 系统性低报追溯**：sprint closure 时复查 sprint 内所有 dev commit message vs `git diff --stat`，单 dev 复发 ≥3 次升级为 P9 主诉过失指标，蓝军必在 sprint-report 列名。

**实证**：anti-adblock sprint reviewer-phase5 cross-check 揪 sprint-report 教训 #1 引用 sha 部分张冠李戴（ab0e2be8/1cd79c7d/38d138f7/7ba16a6f 是功能性 fix 非 reword）+ memory-keeper 修订段。蓝军 cross-check 是 sprint closure 最后一道防线。

**最锋利案例（2026-05-21 sprint-closure-commit 自身复发）**：main session lead 自己跑 commit `4132c6b3`（audit-suppressions 入库 2 条），message 写 `+14/-0 lines, 1 file`，实际 `git diff --cached --shortstat` 报 `1 file changed, 9 insertions(+)` —— **超报 1.6x**。这是 sprint closure 阶段的 commit、本应是最规范的，但 main session lead **跑完没自查 git log -1 --stat**，刚 sink 的"commit 后自验"铁律自己也违反。Owner 拍板"不 amend，作为教训案例入库"。**意义**：系统性问题不只在 dev/qa/reviewer/ops 五角色，**lead 自己也犯**——精确度铁律是普世规则，跨角色 + 跨场景（sprint commit / sprint closure commit / hotfix commit），任何写 commit message 的人都必须自检。

## 配套铁律
- [[newworld-multi-agent-coord]]：跨模块 / scope 大改必走多 agent 交叉验证
- [[newworld-sprint-closure-audit]]：sprint 收尾抗虚报
- [[feedback_audit_methodology]]：蓝军 / 审计 agent 10 铁律
- spec `docs/superpowers/specs/2026-05-14-agent-team-sdlc-design.md` §3.2 dev-senior 通信白名单

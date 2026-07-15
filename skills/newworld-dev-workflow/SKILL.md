---
name: newworld-dev-workflow
description: 分支/worktree/合并/keep-main-green 开发工作流铁律(业界最佳实践固化:TBD/DORA/Fowler/Atlassian/GitHub-GitLab merge queue/Claude Code worktree)。master=唯一可部署 mainline;每会话各自 worktree(仓库外 /home/test/worktree-<名>+EnterWorktree path 进入,禁 name/claude -w 默认落点 .claude/worktrees);从 origin/master 开;短命 feature/fix 每日并 master(≤1-2天本地放宽,DORA原文 a few hours)、rebase-FF;长命安全/发布 track 禁 rebase+禁 flag、--no-ff merge 双向、走专属 DEPLOY-RUNBOOK;build/部署前必 sync 最新 master 重测(单 jar 漏并=revert master);禁 rebase 已 push/共享分支;master 串行合+合前重基重测(人肉 merge queue 防 semantic conflict);删 worktree 前 merged+pushed;~/.m2 不隔离用 -am reactor;DB/端口不隔离。triggers: 分支策略, worktree, git worktree, 多会话, 多agent并行, rebase, merge, --no-ff, feature flag, trunk-based, keep main green, merge queue, semantic conflict, 从master开, build前merge master, 单jar revert, isolation worktree, claude -w, 删worktree, .m2隔离, 部署前同步master, 短命分支, 长命track, master可部署基线, git add -A, 共享checkout
---

# newworld 开发工作流铁律

> 业界最佳实践固化(~15 权威源:git 官方 / Claude Code 官方 / DORA / Fowler / Atlassian / GitHub & GitLab merge queue / trunkbaseddevelopment)。与 CLAUDE.md「分支与上线流程铁律」对齐;细节研究见 `docs/sprint/2026-06-27-dev-workflow-bestpractices/`。

**核心模型**:master = 唯一 Release-Ready Mainline(永远已测、可直接部署);每会话/每 agent 各自 worktree(从 origin/master 开);短命 feature/fix(每日并 master)rebase-FF 合;长命安全/发布 track 禁 rebase、--no-ff merge 双向、走专属 DEPLOY-RUNBOOK;合入串行 + 合前并最新 master 重测(人肉 merge queue 防 semantic conflict)。

## 1 — worktree 隔离(落点=仓库外 /home/test/worktree-*)
- **每会话/每 agent 各自 worktree,禁多会话共享单 checkout**。一个工作目录只有一个 HEAD/index,`git checkout` 改这棵唯一工作树 → 别会话切分支会把你的工作树文件换没(已 push 则零数据损,但工作树被毁=正常表现)。worktree 各有私有 HEAD/index、共享 objects/refs。
- **落点=仓库外**(Owner 2026-07-14 拍板,原「用原生 claude -w 别手搓」表述作废):`git worktree add /home/test/worktree-<名> -b <分支> origin/master`,进入用 EnterWorktree 的 **path 参数**;**禁 EnterWorktree name 参数 / `claude -w` 默认落点**——它们建在仓库内 `.claude/worktrees/`,全仓 grep(死代码审计/删前引用面)会扫进整仓副本重复命中,且与 worktree_guard 共享区前缀判定冲突(BL-63 已加识别容忍,属防御层非许可)。subagent frontmatter `isolation: worktree`(自动建、无改动自动删)不受此限。前端依赖硬链接克隆秒装:`cp -al /home/test/newworld/frontend-web/node_modules <worktree>/frontend-web/node_modules`(实测 1.9s;lockfile 变了再 npm ci)。
- **同一分支禁两 worktree 并检**(git 默认 refuse);并行看同一基线 → `git worktree add -b <new> <dir> <base>`。
- **删 worktree 前必 clean+merged+pushed**(= Claude Code 自动 sweep 判据);`rm -rf` 后必 `git worktree prune` 清孤儿;脏的 `--force`。
- `.gitignore` 加 `.claude/worktrees/`;`.worktreeinclude` 带 gitignored 本地配置(只拷 gitignored 文件 → 先 `git check-ignore -v secrets.env` 确认它真被 ignore)。

## 1b — 多会话共享单 checkout 的生存铁律(worktree 未隔离时;2026-06-27 实战踩出)
理想是 §1 每会话独立 worktree;现实常是多会话共享同一 checkout(本 sprint 实测撞过两次)。无隔离时必守:
- **合并/部署/push 前必 `git fetch origin master` 看真历史**——别会话可能已推进/已 revert/**已 bump 同版本号**。基于陈旧 master 直接合=撞车(实测:别会话已 bump plugin 0.1.7+加同名 skill,我在新 master 上重新派生才解)。
- **禁 `git add -A` / `git add .`**——共享工作树里有别会话的未提交 WIP(`M`/`??`),全量 add 会把别人的活误纳进你的 commit。永远 `git add <具体路径>`,commit 前 `git diff --cached --name-only` 自验只含你的文件。
- **撞版本号/同名文件 = reconcile 不硬 rebase**:派生件(plugin/分发副本)从 truth source 在**新 master 上重新派生**(确定性、零冲突),别在版本号/同名 skill 上手解 merge 冲突。
- **别碰别会话的未提交 WIP**(`M`/`??` 但不是你改的):不 commit、不 revert、不"顺手清理"(承 CLAUDE.md「不碰你没创建的」);要提醒它就留独立 untracked note 文件。
- **引用代码做结论前确认它在 master 不是 WIP**:`git ls-files <path>` / `git show origin/master:<path>` 核它真已提交,**别把别会话未提交的树内改动当 production 引用**(实测踩过:把未提交的 `recentRywExecutor` 当 prod 写进结论,被独立审揪出事实错)。
- **共享 checkout 上任何写操作(含 `git checkout -- <file>` "清残留"/`rm` untracked/merge)前必 `git symbolic-ref HEAD` 认属主**——别会话可能已切走分支(07-05 实踩:以为在 master 清残留,实际在别会话活跃分支动手,且抹掉的"残留"是功能性覆盖层 settings.json 致 hook 失效)。未提交 M 文件先验内容归属(与哪个分支 byte 级一致)再动;共享 checkout 上更新 master 永远 `--ff-only` 不用裸 merge(这次靠它免于在别人分支造合并提交)。

## 2 — 分支策略
- feature/* 新功能、fix/* 修复,**从 `origin/master` 开**(先 `git fetch`)。
- **短命分支要真短**:feature/fix 每日(且 build/部署前必)并最新 master、活跃分支 ≤3 条。DORA 原文阈值是 "a few hours/每日合";本项目放宽到 ≤1-2 天(超 2 天必说明原因 + 每日 merge master),否则退化为长命分支反模式。
- **长命 track 分两类(通用,不针对具体 track)**:(A) **安全/发布语义 track**(抗封逃生层/release gate/高敏发布)→ 专属 DEPLOY-RUNBOOK + Owner gate,**禁 rebase + 禁 feature flag**(安全/逃生层 flag-off=失效;单 jar flag 不能热切),定期 merge master 防 regression;(B) **普通功能 track** → 优先 feature flag/Branch by Abstraction 小步并回 master,别长期分叉。

## 3 — build/部署前必 sync 最新 master(单 jar 硬约束)
- **build/部署前必先 merge/rebase 最新 `origin/master` 并在合并态重测**(mvn test + e2e)。web/admin 全量单 jar:漏并最新 master = 部署 stale 分支把 master 新改 revert 掉(真踩过)。
- **"从分支部署"是本项目逆向动作**(业界主流 deploy-from-merged-main):合入 master 后**用 master HEAD 重 build + 冒烟再部署**,别把"分支 jar 测过"当"master 部署安全";长期收敛到从 master 部署。

## 4 — 合并门禁(rebase/merge + 防 semantic conflict)
- **黄金铁律:禁 rebase 已 push/共享分支**(开 PR/别人依赖/多会话共享=public,rebase 重写历史炸协作方)。rebase 只用于私有短命 feature/fix 并入最新 master;长命 track 一律 `--no-ff` merge。
- **master 串行合并 + 合前重基重测(人肉 merge queue)**:一次只落一个;每分支合入前必并最新 master 在合并态重测;前一个合入后,后续未合分支必须重新并新 master 重测(禁用旧测结果合)。防 semantic conflict(A 测 main、B 测 main,合后 main+A+B 谁都没测→炸)。
- 中期可引入 merge queue/CI gate(前置=先有 CI 可跑的绿判据);现状人工+Owner+蓝军=人肉 CI gate。
- commit 粒度:单 commit=最小可独立 revert 单元(不破 build);message 精确量化(承 newworld-commit-message-precision)。
- **合并后收尾清单(2026-07-05 Owner 定"合并即清理")**:①删远端分支 `git push origin --delete <br>` ②删本地 `git branch -d`(拒绝时用能力级校验 `git merge-base --is-ancestor <br> origin/master` 通过才 `-D`) ③删 worktree+`git worktree prune`。历史查询走 `git log --merges/--first-parent`(--no-ff merge commit 永久保留分支名+全部提交),死分支 ref 只会让别会话误判 supersession。未合活分支(等授权窗口/长命 track)保留。

## 5 — keep-main-green
- master 可部署性靠**自动化测试门**;人工/Owner 授权只决定"发不发"不替代"代码对不对"。
- **pre-push 本地 CI 按 diff 路径分级(2026-07-05)**:docs/*.md/claude-*/sql→秒过;frontend-*→只对应 vitest;后端叶子模块→`mvn -pl <集合> -am test`;common/根 pom/未知路径→**fail-closed 全量**。判据只看 diff 内容不看分支名;`GATE_DECIDE_ONLY=1` 预演决策;`SKIP_CI_LOCAL=1` 应急全跳(需 Owner);push 命令给足 timeout(全量约 7 分钟)或 run_in_background。
- master 坏了**立即 revert 回最后绿态**(非现场修),fixing the build 最高优先级。
- 评审/授权必须快路径(慢评审逼出大批量合并=DORA 点名头号障碍);Owner offline 期分支保活+每日 sync master,上线批量授权前各分支重并 master 重测。

## 6 — 本项目特有坑(worktree 救不了的)
- **`~/.m2` 不隔离**(在 $HOME):跨模块改动走 `mvn -pl <mod> -am` reactor 全量重建依赖(承 newworld-sdlc-agent-team);不轻用 `-Dmaven.repo.local`(破坏 SNAPSHOT 发现)。
- **DB/Redis/端口不隔离**(单实例共享):并行多 agent 前列文件归属表(重叠文件→串行);DB 写走各自本地 127.0.0.1(承 newworld-local-db-isolation)。完整隔离=code(worktree)+data(独立DB)+env(独立端口/.env)三层。

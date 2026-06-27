---
name: newworld-dev-workflow
description: 分支/worktree/合并/keep-main-green 开发工作流铁律(业界最佳实践固化:TBD/DORA/Fowler/Atlassian/GitHub-GitLab merge queue/Claude Code worktree)。master=唯一可部署 mainline;每会话各自 worktree(用 Claude Code 原生 claude -w / isolation:worktree,别手搓);从 origin/master 开;短命 feature/fix 每日并 master(≤1-2天本地放宽,DORA原文 a few hours)、rebase-FF;长命安全/发布 track 禁 rebase+禁 flag、--no-ff merge 双向、走专属 DEPLOY-RUNBOOK;build/部署前必 sync 最新 master 重测(单 jar 漏并=revert master);禁 rebase 已 push/共享分支;master 串行合+合前重基重测(人肉 merge queue 防 semantic conflict);删 worktree 前 merged+pushed;~/.m2 不隔离用 -am reactor;DB/端口不隔离。triggers: 分支策略, worktree, git worktree, 多会话, 多agent并行, rebase, merge, --no-ff, feature flag, trunk-based, keep main green, merge queue, semantic conflict, 从master开, build前merge master, 单jar revert, isolation worktree, claude -w, 删worktree, .m2隔离, 部署前同步master, 短命分支, 长命track, master可部署基线
---

# newworld 开发工作流铁律

> 业界最佳实践固化(~15 权威源:git 官方 / Claude Code 官方 / DORA / Fowler / Atlassian / GitHub & GitLab merge queue / trunkbaseddevelopment)。与 CLAUDE.md「分支与上线流程铁律」对齐;细节研究见 `docs/sprint/2026-06-27-dev-workflow-bestpractices/`。

**核心模型**:master = 唯一 Release-Ready Mainline(永远已测、可直接部署);每会话/每 agent 各自 worktree(从 origin/master 开);短命 feature/fix(每日并 master)rebase-FF 合;长命安全/发布 track 禁 rebase、--no-ff merge 双向、走专属 DEPLOY-RUNBOOK;合入串行 + 合前并最新 master 重测(人肉 merge queue 防 semantic conflict)。

## 1 — worktree 隔离(用 Claude Code 原生,别手搓)
- **每会话/每 agent 各自 worktree,禁多会话共享单 checkout**。一个工作目录只有一个 HEAD/index,`git checkout` 改这棵唯一工作树 → 别会话切分支会把你的工作树文件换没(已 push 则零数据损,但工作树被毁=正常表现)。worktree 各有私有 HEAD/index、共享 objects/refs。
- **用原生**:`claude -w <name>`(默认 `.claude/worktrees/<name>/`、从 `origin/HEAD` fresh 开)或 subagent frontmatter `isolation: worktree`(无改动自动删)。不手搓脚本。
- **同一分支禁两 worktree 并检**(git 默认 refuse);并行看同一基线 → `git worktree add -b <new> <dir> <base>`。
- **删 worktree 前必 clean+merged+pushed**(= Claude Code 自动 sweep 判据);`rm -rf` 后必 `git worktree prune` 清孤儿;脏的 `--force`。
- `.gitignore` 加 `.claude/worktrees/`;`.worktreeinclude` 带 gitignored 本地配置(只拷 gitignored 文件 → 先 `git check-ignore -v secrets.env` 确认它真被 ignore)。

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

## 5 — keep-main-green
- master 可部署性靠**自动化测试门**;人工/Owner 授权只决定"发不发"不替代"代码对不对"。
- master 坏了**立即 revert 回最后绿态**(非现场修),fixing the build 最高优先级。
- 评审/授权必须快路径(慢评审逼出大批量合并=DORA 点名头号障碍);Owner offline 期分支保活+每日 sync master,上线批量授权前各分支重并 master 重测。

## 6 — 本项目特有坑(worktree 救不了的)
- **`~/.m2` 不隔离**(在 $HOME):跨模块改动走 `mvn -pl <mod> -am` reactor 全量重建依赖(承 newworld-sdlc-agent-team);不轻用 `-Dmaven.repo.local`(破坏 SNAPSHOT 发现)。
- **DB/Redis/端口不隔离**(单实例共享):并行多 agent 前列文件归属表(重叠文件→串行);DB 写走各自本地 127.0.0.1(承 newworld-local-db-isolation)。完整隔离=code(worktree)+data(独立DB)+env(独立端口/.env)三层。

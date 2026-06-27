---
name: newworld-git-preflight
description: 每次 SSH 部署前生产服务器跑 git pre-flight，dirty tracked 文件 > 0 立即 HALT；冲突必须 git stash push -u 保留，禁止 --hard reset / checkout --。生产 worktree read-only — 不得 ssh 到生产 vim 改 tracked 文件。Triggers on git pre-flight, dirty, stash, 生产服务器 worktree, git pull, 部署前 dirty, 部署前 git, deploy preflight.
---

# Newworld 服务器部署 git pre-flight 铁律（2026-04-23 事故硬化）

## 触发场景
- 每次 SSH 到生产服务器（ca-web-01/02/03/04 / eu-web-01/02 / ca-admin / 任何 edge VPS）做 `git pull` 部署
- 改动后端 jar / 前端 dist / openresty .conf 任何代码部署链

## 铁律

### 1. 部署前必跑 pre-flight
```bash
for host in ca-web-01 ca-web-02 ca-admin; do   # eu-web-01/02 按需加入
    conflicts=$(ssh $host "cd /newworld && git status --porcelain | awk '/^[^ ?]|^.[^ ?]/' | wc -l")
    [ "$conflicts" -gt 0 ] && { echo "🔴 $host $conflicts tracked 冲突，HALT"; exit 1; }
done
```

### 2. 冲突态定义
`M` / `A` / `D` / `R` / `UU` / `AA` / `DD`（tracked 但未 commit 的改动）。

### 3. `??` untracked 放行
`dist/` / `*.bak` 等 build 产物或工具临时文件是天然 untracked，不算冲突。

### 4. 发现冲突必须 stash 保留
```bash
git stash push -u -m "pre-deploy-<TS>"
```
**禁止** `--hard reset` 或 `checkout --` 覆盖。stash 保留到下次 sprint 人工 review。

### 5. 生产服务器 worktree read-only 原则
任何人（含 P7 / DBA）**不得直接 ssh 到生产 vim 改 tracked 文件**，必须走"本地改 → commit → push → git pull"。违反 = 累积 dirty 到下次部署爆炸。

## 违反后果
按 **3.25** 级别处理：sprint 末复盘 + 清理动作入下一 sprint。

## 事故案例

**2026-04-23 sprint**：部署相关推荐救急补丁，aws-web-02 积累 163 个 dirty 文件（含 `.claude/settings.local.json` / `CLAUDE.md` 手改残留），`git pull` 冲突触发 HALT，最后用 `git stash push -u` 变通才完成部署。

**2026-05-01 Wave 1 部署（教训：违反 #5 read-only 铁律）**：aws-web-01 + aws-web-02 都有 pre-existing `D frontend-web/index.html`（HEAD 含此文件，blob 350edb8e9d，但 working tree 标记已删）。首次 `npm run build` 报 `Could not resolve entry module "index.html"`。Sigma7 agent emergency `git checkout HEAD -- frontend-web/index.html` 修复 build → **违反本铁律 #4**（"禁止 checkout -- 覆盖"）。Root cause 未明（git reflog 全是 ff-merge pull / lsof 无进程持有 / obfuscate-sw.js 仅动 dist/index.html 不动 source），但 deploy SOP 现已加 Step 1.5 fail-fast pre-flight 防再次撞。**正确做法**应是：HALT + 报告 P9 + `git stash push -u "pre-deploy-XXX"` 保留 → 下次 sprint 人工排查。

## 源
- CLAUDE.md L695-L713

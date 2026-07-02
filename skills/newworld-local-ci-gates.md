---
name: newworld-local-ci-gates
description: 本地 git 闸门(pre-commit/pre-push=本地CI)必须处理"本地环境≠干净CI runner"三差异——mvn 加 -Djava.awt.headless=true + env -u DISPLAY(本地 DISPLAY=:99 致 java.awt 图像测试连 X11 假红)、vitest 前 ensure_deps(lockfile 比 node_modules 新→npm ci,防 blurhash 等新增依赖假红)、mvn 不带 -q(surefire summary 可见)。hook 必写进 simple-git-hooks config(否则 npm install 重建清掉手写 hook);hook 命令路径基于仓库根(cd .. 后写 scripts/ 非 ../scripts/);pre-push 读 stdin 跳过删除/无提交 + SKIP_CI_LOCAL 逃生。Triggers on 本地 CI, ci-local, pre-push, pre-commit, git hook, simple-git-hooks, headless, DISPLAY, node_modules 假红, blurhash, npm install 清 hook, push 卡住, push 被拦.
---

# Newworld 本地 CI 闸门铁律（2026-07-02 工程化加固，一次 push 暴露 3 坑）

## 触发场景
- 搭 / 改本地测试闸门（`scripts/ci-local.sh` + `.git/hooks/pre-commit`·`pre-push`）
- push 被 hook 拦、hook 没跑、hook 被 `npm install` 清掉、图像 / 前端测试本地假红

## 铁律

### 1. 本地跑 CI 必对齐"干净 runner"三差异（否则假红）
- **mvn headless**：本地 shell 常设 `DISPLAY=:99`（浏览器工具用），`java.awt` 图像测试会去连 X11 而假红。命令必 `env -u DISPLAY mvn -B -ntp -Djava.awt.headless=true test`。
- **前端依赖新鲜度**：陈旧 `node_modules` 缺新增依赖（如 `blurhash`）→ vite import 解析失败假红。vitest 前 `ensure_deps`：`node_modules` 缺失或 `package-lock.json -nt node_modules/.package-lock.json` 就 `npm ci`。
- **禁 `-q`**：`mvn -q` 退出码可能 0 掩盖 failure；不带 `-q` 看 surefire summary（backlog-cleanup 5/13 教训）。

### 2. hook 必写进 simple-git-hooks config，不手写
- 手写 `.git/hooks/pre-push` 会被 `npm install` 触发的 simple-git-hooks 重建**清掉**（它只保留 config 里声明的钩子）。
- pre-commit + pre-push 都在 `frontend-web/package.json` 的 `simple-git-hooks` 里声明；`install-git-hooks.sh` 用 `npx simple-git-hooks` 生成。

### 3. hook 命令路径基于仓库根
- git 从仓库根跑 hook。config 里 `cd frontend-web && ... && cd ..` 之后已在根，脚本写 `scripts/X.sh`，**不是** `../scripts/X.sh`（`../` 指到仓库外 → No such file → 阻断所有 commit）。

### 4. pre-push 闸门跳过删除 / 无提交 + 逃生口
- 读 stdin `<local ref> <local sha> ...`，`local sha` 全 0 = 删除分支 → 跳过（否则 `git push --delete` 触发全量 mvn 卡死）。
- `SKIP_CI_LOCAL=1 git push` 逃生。

## 关联
- 知识库异地备份：`~/claude-shared`（skill + memory 真相源，本地无远端 = 单点）镜像进 repo `claude-shared/` + pre-commit 自动同步，随代码推私有 GitHub。见 `scripts/sync-claude-shared.sh` / `~/claude-shared/scripts/backup-claude-shared.sh`。
- CI 教训同源 [[project_backlog_cleanup_5_13]]（`mvn -q` 掩盖 failure）。

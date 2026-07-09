---
name: newworld-deploy-pitfalls
description: SSH 部署三坑铁律：①heredoc 一律用引号包裹的 sentinel（quoted heredoc，写法见正文）防本地 shell 提前 expand，远端 nginx/systemctl 失败不能以 ssh exit 0 误判成功；②服务器 git pull 前必跑 pre-flight，dirty tracked 文件数非 0 立即 HALT、冲突 git stash push -u 保留、禁 --hard reset/checkout --、生产 worktree read-only；③deploy 脚本 symlink 必指向具体 jar（deploys/current.jar，非父目录/target），否则 systemd ExecStart 找不到 jar 循环重启（W9 26 次 restart-loop 教训）。Triggers on ssh, heredoc, ssh 部署, ssh 命令, 远端 expand, sudo bash -s, git pre-flight, dirty, stash, 生产服务器 worktree, git pull, 部署前 git, deploy preflight, symlink, current.jar, ExecStart, restart loop, 循环重启, JAR 软链.
---

# Newworld deploy-pitfalls（2026-07-03 由 newworld-ssh-deploy + newworld-git-preflight + newworld-deploy-jar-symlink 合并而成）

---

> ⬇️ **以下并入自 `newworld-ssh-deploy`（2026-07-03 skill 合并，原档已删；触发词已并入本 skill description）**


# Newworld SSH 部署 heredoc 铁律（2026-04-21 事故硬化）

## 触发场景
- 写 SSH 远端执行脚本（部署 / 配置同步 / 证书签发 / openresty reload）
- 远端用 sed / envsubst / cat heredoc 渲染配置文件
- 涉及变量替换 `$VAR` / `$(date)` / `$X`

## 铁律

### 1. heredoc 必须 quoted sentinel
**`<<'QUOTED'`（单引号包裹 sentinel）= 所有变量在远端才 expand。**

### 错（本地 shell 先 expand，$VAR 可能空值）
```bash
ssh usca-1 sudo bash -s <<REMOTE
  . /etc/newworld/secrets.env
  sed -e "s|{{ X }}|$X|g" file.j2 > out.conf
REMOTE
```
本地的 `$X` 在 ssh 发送前就被 expand — 但本地没这个变量！远端拿到 `s|{{ X }}||g`（空值），破坏 conf。

### 对（quoted 'REMOTE'）
```bash
ssh usca-1 sudo bash -s <<'REMOTE'
  . /etc/newworld/secrets.env
  sed -e "s|{{ X }}|$X|g" file.j2 > out.conf
REMOTE
```

或整个命令用单引号传给 ssh：
```bash
ssh usca-1 'sudo bash -c "source /etc/newworld/secrets.env && sed -e \"s|{{ X }}|\$X|g\" ..."'
```

### 2. 明确变量来源
除非你明确要在本地 expand 变量（如 `$(date)` 时间戳），那也要清楚哪些变量来自本地、哪些来自远端。

### 3. ssh exit code = 0 不等于部署成功
SSH 失败后必须检查 nginx.conf / systemctl status，不能以为 `ssh exit code = 0` 就万事大吉。

### 4. 部署前验证渲染产物
远端 `cat` / `head` 渲染后的配置文件，确认占位符都被替换、没有空值。

## 违反后果
按 **3.25** 级别处理。本地 shell 提前 expand 把空值渲染进生产 nginx.conf → `nginx -t` 失败 / systemctl failed → 10~30 秒 openresty 挂掉影响线上流量。

## 事故案例
commit `a870a0fc`（2026-04-21）v3.3 Lua SNI 部署到 usca-2 / aws-s 时触发。

## 源
- CLAUDE.md L554-L585

---

> ⬇️ **以下并入自 `newworld-git-preflight`（2026-07-03 skill 合并，原档已删；触发词已并入本 skill description）**


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

---

> ⬇️ **以下并入自 `newworld-deploy-jar-symlink`（2026-07-03 skill 合并，原档已删；触发词已并入本 skill description）**


# 部署铁律

生产 admin/data/web JAR 路径**不是** `newworld-admin/target/newworld-admin-*.jar`，而是 `/newworld/<module>/deploys/current.jar` **软链**：

```
/newworld/newworld-admin/deploys/
  20260428-231343.jar  ← 真 JAR
  20260427-203020.jar  ← 上一版
  current.jar -> 20260428-231343.jar  ← 软链 systemd 启动用
```

## 部署步骤

```bash
TS=$(date +%Y%m%d-%H%M%S)
scp target/newworld-admin-*.jar aws-data:/newworld/newworld-admin/deploys/$TS.jar
ssh aws-data "
  cd /newworld/newworld-admin/deploys
  ln -sfn $TS.jar current.jar
  sudo systemctl restart newworld-admin
"
```

## 回滚

```bash
ssh aws-data 'cd /newworld/newworld-admin/deploys && ln -sfn 20260427-203020.jar current.jar && sudo systemctl restart newworld-admin'
```

## 5 版保留铁律

`/newworld/scripts/cleanup-old-jars.sh` 保留最新 5 版（已存在），无需手工管理。

## 部署后必查（防"假绿"）

**2026-05-02 教训**：P7 部署 `mvn package` 成功 + `systemctl restart` 成功 + `is-active=active` + `journalctl 无 ERROR`，**全 ✓ 但 systemd 跑的 deploys/current.jar 还指向旧 jar** —— mvn 输出在 target/ 没 cp 到 deploys/，PR-V3.C 代码完全没在跑。"四绿"全是假的。

**强制三步校验**（systemctl restart 之后必须做）：

```bash
# 1. current.jar 时间戳 ≥ 刚 build 的 target/jar
test "$(stat -c %Y deploys/current.jar)" -ge "$(stat -c %Y target/newworld-*-*.jar)" \
  || { echo "FAIL: current.jar 老于 target jar"; exit 1; }

# 2. md5sum 一致（current.jar 内容 = target jar）
diff <(md5sum < deploys/current.jar) <(md5sum < target/newworld-*-*.jar) \
  || { echo "FAIL: current.jar md5 与 target jar 不一致"; exit 1; }

# 3. 真接口验证（含新版本特征字段，不是仅 actuator/health）
curl -sf http://localhost:<port>/api/v1/.../<feature> | grep -q "<expected_field>" \
  || { echo "FAIL: 接口未含新版本字段"; exit 1; }
```

任一失败 → `ln -sfn deploys/<previous>.jar current.jar && systemctl restart` 立即回滚。

推荐封装：`/newworld/scripts/deploy-backend.sh <module>` 一键 mvn → cp → symlink → restart → 三步校验。

## stale jar 校验（2026-05-07 增强）

**故障背景**：5/7 V3 撤除部署（P7 a4bf4fc35b92e1560）暴露 `mvn install -q` 隐藏 test 失败 + `mvn package` 用 target/ 残留 13:12 stale jar 的隐患 — STEP3 unzip 检 V3 类才发现假绿，差点放过。

**修复**（commit `c2055a55`，scripts/deploy-backend.sh）：
- `git pull` 后立即记录 `BUILD_START_TS=$(date +%s)` baseline
- `mvn clean package` 后校验 `stat -c %Y target/jar` ≥ `BUILD_START_TS`
- mtime < baseline → "stale jar 假绿"立即 `exit 1`
- mvn 去 `-q` 改 `--errors --batch-mode`（显式错误，install 阶段不被吞）

**防御原理**：clean/package 任何环节静默失败导致 target/ 没有重建时，残留旧 jar mtime 一定早于本次 build 起点 → 校验立即捕获。

详见 `newworld-deploy-runbook` skill 的"host 一次性修复"段（parent POM `mvn install -N`）。

## SQL migration 校验（2026-05-07 增强）

**故障背景**：5/7 schema diff sweep audit (`a71c573c99fc38daa`) 揭出短期 3 起 SQL migration 漏跑（V5 / W3-A4 / W4 sprint），全部走完"部署成功"流程但 sql/*.sql 里的 DDL 从未在生产 DB 执行 — `deploy-checklist` 第 5 项靠人脑记，违反了 3 次。

**修复**（commit `9a502954`，scripts/deploy-backend.sh +47/-5）：
- `last_deploy_ts = stat -c %Y deploys/current.jar`（零额外状态文件，软链 mtime 即上次部署时间）
- `git log --since=@<ts> --name-only -- 'sql/*.sql'` 列出本次部署窗口内新增/修改的 SQL
- `grep -iE 'CREATE|ALTER|DROP'` 检测 DDL → 交互 prompt owner 确认已 apply
- 非交互（CI 环境，stdin 非 tty）→ 直接 `exit 3`
- `--skip-sql-check` flag 给 CI 显式 bypass（owner 知情）

**防御原理**：把"漏跑 migration"这个**人脑健忘点**变成 deploy 脚本的硬门 — 没确认就不让 cp jar，从源头掐断。

**关联 commit**：`9a502954` (4 层防御整批) — Layer 4 即此校验段；Layer 2/3 见 `newworld-schema-consistency` skill。

## 反例（错误）

- `scp target/newworld-admin-*.jar aws-data:/newworld/newworld-admin/target/`（path 不存在）
- scp 后 systemctl 不重启（软链未更新）
- 部署后不更新 current.jar 软链（systemd 仍跑旧 JAR）
- **`mvn package` 在服务器上跑后只 systemctl restart，没 cp + symlink**（target/ 新 jar 但 systemd 跑老 current.jar）← 2026-05-02 真实故障

## 关联 skill

- `newworld-deploy-runbook` — 完整 Step1-5
- `newworld-deploy-checklist` — 部署前必查四项
- `newworld-ssh-deploy` — heredoc `<<'QUOTED'` 防本地 expand

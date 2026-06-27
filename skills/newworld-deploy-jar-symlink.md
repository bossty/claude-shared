---
name: newworld-deploy-jar-symlink
description: 生产 admin JAR 用软链管理（deploys/current.jar），不是 target/xxx.jar
triggers:
  - 部署 admin
  - jar 部署
  - rollback-backend
  - deploys/current.jar
---

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

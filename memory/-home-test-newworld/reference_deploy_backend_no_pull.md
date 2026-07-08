---
name: reference-deploy-backend-no-pull
description: deploy-backend.sh 不做 git pull——会静默 build 服务器工作树旧代码
metadata: 
  node_type: memory
  type: reference
  originSessionId: 3e6b0318-9157-4777-b86a-35bd2c0bb0d5
---

> **⚠️ 2026-07-07 状态标注**：deploy-backend.sh 已不存在（现 deploy-web.sh，本地 build 模型）；仍有效的通则=验 jar sha 非只信部署脚本输出。

`scripts/deploy-backend.sh <module>` 的步骤是 `[0/8]` SQL 校验 → `[1/8]` mvn package → … → `[7/8]` restart → `[8/8]` 验证。**没有 git pull 步**——它 build 的是目标服务器工作树**当前状态**的代码。

若服务器落后 origin（很常见，aws-data 经常落后几个 commit），直接跑 deploy-backend.sh 会**静默 build 旧代码**：部署"成功"、`[8/8] OK`、服务 active，但跑的是旧逻辑。

2026-05-17 实证：改 `hls-concurrent-downloads` 10→4 commit `43d59ed9` push 后直接部署，build 的是 aws-data 旧 HEAD `809a8325`，jar 里并发还是 10。靠 `git rev-parse --short HEAD` ≠ 期望 sha + `unzip -p current.jar BOOT-INF/classes/application-prod.yml | grep` 才抓到。

**SOP**：deploy-backend.sh 之前必须先在目标服务器 `cd /newworld && git pull origin master`（拉之前走 [[feedback_audit_methodology]] 式 pre-flight：`git status --porcelain --untracked-files=no` 查 dirty tracked，有 dirty 则 HALT 不自动改）。**部署后必须验证** HEAD sha + `unzip` jar 内配置/类，证明跑的是新代码——不能只信 `[8/8] OK`。

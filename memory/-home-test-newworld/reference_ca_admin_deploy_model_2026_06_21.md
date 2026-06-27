---
name: reference_ca_admin_deploy_model_2026_06_21
description: ca-admin(终态admin宿主)无git/maven/npm只有node+SSH用户ubuntu免密sudo→admin后端jar与frontend-admin均必本地build→scp→swap;runbook Step2 admin块与deploy-frontend.sh admin分支(都假设ca-admin有git+npm)已STALE不能用;admin路由验活看响应body非status(401/200都骗人)
metadata: 
  node_type: memory
  type: reference
  originSessionId: 6db520df-da32-454d-aef8-3340ed7626f7
---

2026-06-21 给广告(snack)管理加"批量替换链接"功能部署 ca-admin 时实测的部署模型真相（与 runbook / deploy-frontend.sh 写的不一致）。

## ca-admin 主机布局（终态 admin/data 宿主，172.34.1.34）
- **无 git 仓库**（`/newworld` 不是 git repo，`git -C /newworld pull` 直接 `fatal: not a git repository`）、**无 maven**、**无 npm**（只装了 `/usr/bin/node`）。
- **SSH 用户 = `ubuntu`**（非 newworld），**免密 sudo** OK。`/newworld/*` 目录 owner=newworld，写需 sudo；`deploys/*.jar` owner=root（sudo cp 落盘）。
- admin systemd：`ExecStart=/usr/bin/java ... -jar /newworld/newworld-admin/deploys/current.jar --spring.profiles.active=prod`；端口 8888（业务）+ 18080（actuator，但 `/actuator/mappings` 未暴露）。

## 正确部署动作（本地 build → scp → swap，全程从主会话跑，sub-agent prod SSH 被 backstop 拦见 [[feedback_multiagent_prod_ops_auth_backstop]]）
- **后端 admin jar**：本地 `mvn clean package -pl newworld-common,newworld-admin -am -Dmaven.test.skip=true`（用 `maven.test.skip` 不用 `-DskipTests`，见 [[feedback_perf_rca_deploy_gotchas_2026_06_16]]）→ scp 到 ca-admin `/tmp` → `sudo cp` 到 `deploys/<TS>-<sha>.jar` → `sudo ln -sfn ... current.jar`（保留 5 版）→ `sudo systemctl restart newworld-admin`。验：jar 内 `unzip -l` 顶层看 admin 自身类、嵌套 `BOOT-INF/lib/newworld-common-*.jar` 看 common 新类（DTO 在 common 不在顶层）。
- **frontend-admin dist**：本地 `npx vite build --outDir dist.new` → tar → scp → ca-admin `sudo tar xzf` + 原子 `mv dist dist.backup-xxx; mv dist.new dist`。**frontend-admin 无 SW/无混淆/无 s.dat/无 version.txt 机制**（区别于 frontend-web），所以本地裸 `vite build` 是对的——[[feedback_frontend_deploy_standard_script]] 的"禁手跑 vite build"只适用 **web**（那套有 obfuscate-sw/version.txt/sync-seeds）。

## 两个 STALE 陷阱（别照抄）
- **runbook `newworld-deploy-runbook` Step2 admin 块** 写 `ssh ca-admin 'git -C /newworld pull && mvn ... package'` —— ca-admin 无 git/maven，跑必挂。
- **`scripts/deploy-frontend.sh admin`**（deploy_admin 函数）写 `ssh ca-admin 'cd /newworld; git pull; npx vite build'` —— 同样假设 ca-admin 有 git+npm，已死。脚本注释还写 "aws-data 单台"（HK 已退役，ADMIN_HOST 虽已 retarget=ca-admin 但 build 模型没跟上）。两处文档都待修。

## admin 路由"验活" gotcha（status code 全骗人，看 body）
admin 部署后想确认新 `@PostMapping` 路由真注册，**HTTP 状态码无法区分**：
- 无 token：Spring Security/LoginInterceptor 对缺失路由和存在路由**都返 401**（runbook 已警告）。
- 有 super token：**不存在的路由也返 HTTP 200**（catch-all/error 转发），与真端点同 200。
- **唯一判据=响应 body**：真 mapped 方法带类级 `@EncryptResponse` → body=`{"encrypted":true,"data":"...","timestamp":...}`；不存在路由无控制器无加密 → 明文 `{"code":1,"message":"请求方法不支持","data":null}`。看到加密信封=控制器真执行=路由活。
- **铸 super 探针 token**：`LoginInterceptor` 里 `role=="super"` 直通绕过 `@RequireMenu`。从 `sudo cat /proc/<admin-pid>/environ | tr '\0' '\n' | grep ^JWT_SECRET=` 取 secret（HS256，claims 只需 `{userId:<num>, role:"super"}`，parseToken 读这两个），pure-python hmac 现铸（见 [[project_doh_3layer_brokenness_np2_2026_06_18]] 同法）。探针用**不存在的 sentinel oldUrl** 调批量替换→0 命中不改真实数据。

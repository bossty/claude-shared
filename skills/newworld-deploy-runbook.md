---
name: newworld-deploy-runbook
description: Newworld 完整部署流程 — Step1 推送 → Step2 后端按模块 build/deploy + JAR 保留 5 个版本 + symlink 原子切换 → Step3 前端本地 build + scp 分发 6 节点(ca-web-01/02/03/04+eu-web-01/02) + 原子切换 → Step4 验证 / Step5 同步种子。前端铁律：禁止各节点各自 build，必须本地统一 build。Triggers on 部署完整流程, deploy runbook, jar 保留, dist.backup, 回滚, 验证 jar 内类, frontend build, openresty 同步, 种子域名同步, deploy step1, mvn clean package, feature 分支开发, 分支打包部署, 合 master, 测试通过才合并, 上线流程, master 基线.
---

# Newworld 完整部署 Runbook

## 触发场景
完整后端 / 前端 / OpenResty / SQL 部署流程；按需选取相应 Step。

## 分支与上线流程铁律（2026-06-26，Owner 定，前置必读）

**所有新功能（含 GFW）：feature 分支开发 → 从 feature 分支打包部署 + 测试 → 测试通过 + Owner 授权后才合 master。**
- **不在 master 上直接开发新功能**；master 永远是"已测过、可直接部署"的基线，**禁未测代码合 master**。
- **feature 分支 build 前必先 `merge` 最新 master** —— 否则全量 jar（web/admin 是单 jar 含全部代码）缺 master 新改 = 回退。这是 Owner 关心的"打包部署不覆盖之前修改"的**根本保证**。
- 部署/测试用 **feature 分支产物**（下面 Step 1 推送到 **feature 分支，不是 master**）；测试绿 + Owner **显式授权**后才 `--no-ff` 合 master。
- 部署/合并前先 `git fetch` 看 master 真实历史（多会话共享仓库，别会话可能已改/已 revert）。
- **反例（2026-06-26）**：GFW 未测就合 master（merge 22fb37b2）→ 被纠 + revert。GFW（`gfw-breakthrough-arch`）是本流程实例：走自己 DEPLOY-RUNBOOK（组A暗部署 + 组B灰度），测试 + 授权前不合 master。

## 前端部署铁律
- **禁止各 web 节点各自 build**：Vite chunk hash 不同 → 跨机请求 404 → 白屏
- **必须本地统一 build，deploy-frontend.sh 通过 scp 分发 dist/ 到全部 6 节点（ca-web-01/02/03/04 + eu-web-01/02）**

## Step 1：本地提交 & 推送
```bash
git add <files> && git commit -m "xxx" && git push
```

## Step 1.5：服务器 git pre-flight（铁律，每次必跑）

**Step 2/3 的任何 `git pull` 之前必须**先跑下面这段。dirty tracked 文件 > 0 立即 HALT，**不得**用 `git checkout HEAD -- xxx` 或 `git reset --hard` 自动修复绕过（违反 `newworld-git-preflight` skill L34 铁律 = 累积 dirty 到下次部署爆炸）。

```bash
for host in ca-web-01 ca-web-02 ca-web-03 ca-web-04 ca-admin; do   # eu-web-01/02 按需加入
  conflicts=$(ssh $host "cd /newworld && git status --porcelain | awk '/^[^ ?]|^.[^ ?]/' | wc -l")
  [ "$conflicts" -gt 0 ] && { echo "🔴 $host $conflicts tracked dirty，HALT 报告 P9（不要绕过）"; exit 1; }
done
```

**`??` untracked**（如 `dist.backup-*` / `*.bak`）放行，不算冲突。

**事故案例（2026-05-01 Wave 1 部署）**：aws-web-01 + aws-web-02 都有 pre-existing `D frontend-web/index.html` dirty → 首次 build 报 `Could not resolve entry module "index.html"` → Sigma agent emergency `checkout HEAD --` 修复，但**违反铁律**。Root cause 未明（非 git/非 build 脚本），但 fail-fast pre-flight 能在 build 之前捕获，避免 mv dist→dist.backup 后才发现 build 失败的混乱。

详见 `newworld-git-preflight` skill 完整铁律。

## Step 2：部署后端（按需，改了哪个模块部署哪个）

> ⚠️ **2026-06-21 校正：所有线上节点（CA web×4 / EU web×2 / ca-admin）都没有 git 仓库、没有 maven/npm**（admin 节点也无 npm），SSH 用户均为 `ubuntu`（写 newworld-owned 目录需 `sudo`）。**部署 = 本地（或任意 checkout）build jar → scp → 切换 → 重启**。旧版"ssh 节点 `git pull && mvn package`"已全部失效，别照抄。详见 [[reference_ca_admin_deploy_model_2026_06_21]]。
>
> **本地 build 前置**：`export PATH=/opt/apache-maven-3.9.9/bin:$PATH`；用 `-Dmaven.test.skip=true`（admin pom 会无视 `-DskipTests` 仍跑测试 → 预存红测试致 package 不打 jar）。`-am` 自动带 common，新增 common 类会打进 fat jar，无需单独 install。
> 下面 `$REPO` = 本地 checkout 根（如 `/home/test/newworld`）。

**JAR 路径 / 保留机制（两种，按模块）**：
- **web**：systemd ExecStart 直指 `/opt/newworld/newworld-web.jar`（实体文件 `ubuntu:ubuntu`）；切换前备份 `*.bak-pre-<sha>`。
- **admin/data**：`/newworld/newworld-<m>/deploys/<TS>-<sha>.jar` + `current.jar` symlink 原子切换，保留最近 5 版。

```bash
export PATH=/opt/apache-maven-3.9.9/bin:$PATH
REPO=/home/test/newworld          # 本地仓库根
SHA=$(git -C "$REPO" rev-parse --short HEAD)

# === web 模块（CA web 四台 + EU web 两台）===
# ★零停机滚动首选脚本（cloudflared 不停 + nginx 同区 backup failover + PEER-READY gate，一台一台）：
bash "$REPO"/scripts/deploy-web.sh
# 手动等价（单台示例；必须逐台，CA 先 3-of-4 保活再 EU，每台 restart 后等就绪再下一台）：
mvn -f "$REPO"/pom.xml clean package -pl newworld-common,newworld-web -am -q -Dmaven.test.skip=true
scp "$REPO"/newworld-web/target/newworld-web-0.0.1-SNAPSHOT.jar ca-web-01:/tmp/nw-web.jar
ssh ca-web-01 "sudo cp /opt/newworld/newworld-web.jar /opt/newworld/newworld-web.jar.bak-pre-${SHA} && \
  sudo mv /tmp/nw-web.jar /opt/newworld/newworld-web.jar && sudo systemctl restart newworld-web"
# 其余 ca-web-02/03/04 + eu-web-01/02 同样逐台。

# === admin 模块（ca-admin 单实例）===
mvn -f "$REPO"/pom.xml clean package -pl newworld-common,newworld-admin -am -q -Dmaven.test.skip=true
TS=$(date +%Y%m%d-%H%M%S)
scp "$REPO"/newworld-admin/target/newworld-admin-0.0.1-SNAPSHOT.jar ca-admin:/tmp/${TS}-${SHA}.jar
ssh ca-admin "sudo cp /tmp/${TS}-${SHA}.jar /newworld/newworld-admin/deploys/${TS}-${SHA}.jar && rm -f /tmp/${TS}-${SHA}.jar && \
  sudo ln -sfn /newworld/newworld-admin/deploys/${TS}-${SHA}.jar /newworld/newworld-admin/deploys/current.jar && \
  ls -t /newworld/newworld-admin/deploys/*.jar 2>/dev/null | grep -v current.jar | tail -n +6 | xargs -r sudo rm -f && \
  sudo systemctl restart newworld-admin"

# === data 模块（ca-admin 单实例，按需）===
# 同 admin，逐处把 admin → data、newworld-admin → newworld-data 即可。
```

### 后端回滚（秒级；节点无 /newworld/scripts，手动切回）
```bash
# web：切回备份 jar（用部署时记下的 <sha>）
ssh ca-web-01 'sudo mv /opt/newworld/newworld-web.jar.bak-pre-<sha> /opt/newworld/newworld-web.jar && sudo systemctl restart newworld-web'
# admin/data：symlink 指回上一版 deploys jar（先 ls -t deploys/*.jar 看上一版文件名）
ssh ca-admin 'sudo ln -sfn /newworld/newworld-admin/deploys/<上一版>.jar /newworld/newworld-admin/deploys/current.jar && sudo systemctl restart newworld-admin'
```

## Step 2.5：后端部署后必须验证

> **警告**：不能只 curl 端点看 HTTP 状态码。admin 的 Spring Security 对所有不存在路径也返回 401，可能误判路由存在，导致新代码实际未生效却以为成功。

```bash
# JAR 路径：web=/opt/newworld/newworld-web.jar；admin/data=/newworld/newworld-<m>/deploys/current.jar
# 1. JAR 内类验证（确认新 class 已打入运行 jar）
ssh ca-admin 'unzip -l /newworld/newworld-admin/deploys/current.jar | grep <NewClass>.class'
# common 里的新类（DTO/entity）在嵌套 jar，顶层 unzip 看不到 → 抽嵌套 common jar 再查：
ssh ca-admin 'unzip -p /newworld/newworld-admin/deploys/current.jar BOOT-INF/lib/newworld-common-0.0.1-SNAPSHOT.jar > /tmp/c.jar && unzip -l /tmp/c.jar | grep <NewClass>.class; rm -f /tmp/c.jar'
# 必须有命中，0 条 = 新代码未打入 jar / symlink 未更新

# 2. journalctl 启动无 ERROR（重启后等 ~12s 再查）
ssh ca-admin 'sudo journalctl -u newworld-admin --since "2 min ago" -q | grep -cE "ERROR|Exception"'   # web 同理换 ca-web-0x / newworld-web
# = 0 才算健康；> 0 立即查日志并考虑回滚

# 3. 端到端 e2e（浏览器真实点击新增页面/功能）
# 不能用 curl 代替，必须走完整请求链

# 4. 业务指标对比
# 和部署前的关键监控指标比，无显著恶化（错误率、响应时间、统计写入量）

# 5. 【多会话铁律】收口前必验现网 jar "真身"含本次修复——别只看 md5==自己部署的那版
#    多会话共享仓库：你部署后，别会话可能 build off master 重新部署 web/admin，现网 jar md5 会变（≠你的）。
#    只要它 build off 已含本次修复的 master，就仍带你的修复；但禁假设——解 jar 实测本次新增类/方法在不在：
ssh eu-web-01 'python3 -c "import zipfile,re; d=zipfile.ZipFile(\"/opt/newworld/newworld-web.jar\").read(\"BOOT-INF/classes/<pkg>/<NewClass>.class\"); print(any(b\"<newMethod>\" in x for x in re.findall(rb\"[ -~]{6,}\",d)))"'
#    True=现网真跑着含本次修复的 jar（即便 md5 被别会话换过）；False=你的修复被别会话用旧 baseline 覆盖了→重新 off master 部署
```

### 快速验证示例（admin 模块新增 SwVersionController）

```bash
# step 1：class 必须在 jar 里
ssh ca-admin 'unzip -l /newworld/newworld-admin/deploys/current.jar | grep SwVersionController.class'
# step 2：启动无错
ssh ca-admin 'sudo journalctl -u newworld-admin --since "3 min ago" | grep -E "ERROR|Exception" | head -5'
# step 3：接口真实可用（admin 需要 JWT，别用 curl 状态码误判）
#   ⚠️ admin 的 status code 全骗人：无 token→缺失/存在路由都 401；带 super token→不存在路由也返 200（catch-all）。
#   唯一判据=响应 body：真 mapped 方法经 @EncryptResponse 返 {"encrypted":true,...}；不存在路由返明文 {"code":1,"message":"请求方法不支持"}。
#   super 探针 token（role=super 绕 @RequireMenu）：从 sudo cat /proc/<admin-pid>/environ 取 JWT_SECRET，
#   HS256 claims 仅需 {userId:<num>,role:"super"}，pure-python hmac 现铸；写操作用不存在的 sentinel 入参→0 命中不改数据。
```

## 违反后果

- 漏跑 JAR 内类验证 → 新代码上线失败但 systemctl 报 active，errors 假装"部署成功"，下一轮 deploy 才发现历史 jar 还在跑
- 漏跑 journalctl ERROR 检查 → 启动期 NoClassDefFoundError / Bean 注入失败被忽略，影响业务到下一次完整测试
- 用 curl 401 / 200 当成"路由存在"误判 → admin Spring Security 对不存在路径也 401，新 Controller 路径错误时无人察觉
- 跳过 e2e 真点 → 前后端契约 mismatch（字段名、HTTP method）只在浏览器才暴露
- 上述任一项漏验证导致用户先发现 = **3.25 级别**事故复盘

## Step 2.6：region 切流前置门禁（仅多 region 放量/切流时；2026-06-08 nw-region-p1）

> **触发**：把 A/P 用户域 DNS 切到 region origin（CF API PATCH）之前。普通 HK 部署不涉及。
> **元失败防再发**：两次全量切换都"切了才发现没准备好"（fullcut-5xx upstream 写死 HK / 第二次 cache-miss 571ms）。

切流前**必跑**就绪门禁，红线不绿禁止切 DNS：
```bash
# 1) 运行时对等门禁（G0-G7，只读断言，不切流）。退出码 0=GREEN / 1=RED / 2=未warm重跑
scripts/region-readiness-gate.sh
# 2) 读/写路由静态闸（阶段3/6-B 已移入 ArchUnit，CI 构建时自动覆盖）
#    check-region-read-routing.sh 已退役（阶段6-B，2026-06-25）
#    等效命令：mvn test -pl newworld-web -am -Dtest=RegionReadRoutingArchTest,MasterWriteRoutingArchTest
```
region-readiness-gate.sh exit 0 + 两个 ArchTest 全绿，才进 canary→分批 progressive；任一非 0 → 停，先修。回滚触发只认 **origin 5xx 绝对数 + cache-miss RTT**（不用被污染的客户端 api_fail）。
设计与判据全文：`docs/sprint/2026-06-08-region-final-migration/READINESS-GATE-DESIGN.md`。

## Step 2.7：region 节点 systemd drop-in 配置清单（重建/换 IP 必查；2026-06-08 nw-region-p1）

> **为什么必查**：region 的读写分离 + Redis replica 路由**不在 application-prod.yml**（同一份 jar 跑所有节点，配置外置）。靠 systemd drop-in 环境变量 + Spring relaxed-binding（env `SPRING_DATASOURCE_SLAVE_URL` → property `spring.datasource.slave.url`）。**drop-in 丢失（节点重建/换 IP 漏配）→ `slaveDataSource()` 检测 url 空 → 静默回退复用 master pool → readOnly 读跨洋到 HK master、571ms 级、零报错**（`ReadWriteDataSourceConfig.java:99` 注释点了此坑）。

drop-in 目录：`/etc/systemd/system/newworld-web.service.d/`

| 节点 | 必备 drop-in（sprint 相关） | 关键 Environment |
|---|---|---|
| **region US** (aws-region-us) | `slave-datasource.conf` | `SPRING_DATASOURCE_SLAVE_URL=jdbc:mysql://`**172.32.9.19**`:3306/newworld?...` + `_SLAVE_USERNAME=newworld` + `_SLAVE_PASSWORD` |
| | `redis-replica.conf` | `REDIS_REPLICA_HOST=`**172.32.9.19** + `REDIS_REPLICA_PORT=6379` |
| | `route-mode.conf` | `APP_RUM_ROUTE_MODE=lb-cohort` |
| **region EU** (aws-region-eu) | `slave-datasource.conf` | `SPRING_DATASOURCE_SLAVE_URL=jdbc:mysql://`**172.33.8.248**`:3306/newworld?...` |
| | `replica-redis.conf` ⚠️文件名与US不同 | `REDIS_REPLICA_HOST=`**172.33.8.248** + `_PORT=6379` + `REDIS_REPLICA_PASSWORD` |
| | `route-mode.conf` | `APP_RUM_ROUTE_MODE=lb-cohort` |
| **CA web** (ca-web-01/02/03/04) | **无 slave/replica drop-in**（正确，CA 同区直读 master） | `DB_HOST=172.34.1.222` / `REDIS_HOST=172.34.1.128` |
| **ca-admin** (admin/data) | **无 slave/replica drop-in**（正确） | 单机直读 CA master |

> replica IP 映射：US→172.32.9.19 / EU→172.33.8.248 / HK master→172.31.19.174。CIDR：HK 172.31 / US(usw2) 172.32 / EU 172.33。

**⚠️ 已知不一致（重建/编脚本时务必按内容而非文件名校验）：**
1. **Redis drop-in 文件名 US/EU 不一致**：US=`redis-replica.conf`，EU=`replica-redis.conf`。**按 `grep REDIS_REPLICA_HOST` 内容校验，别按固定文件名**（按名找会漏一个 = 该区 Redis 读悄悄回退 HK）。
2. **US 的 redis drop-in 无 `REDIS_REPLICA_PASSWORD`，EU 有**——重建时确认各区 replica Redis 是否真需密码并对称化。

**重建/换 IP/部署后必验三步**（改完 `sudo systemctl daemon-reload && sudo systemctl restart newworld-web`）：
```bash
# 1. environ 真注入本地 replica IP（非空、非 HK 172.31）—— 注意 sudo cat 不要用 < 重定向（shell 先开文件会 Permission denied）
ssh <region-node> 'PID=$(pgrep -f newworld-web.*jar|head -1); sudo cat /proc/$PID/environ | tr "\0" "\n" | grep -E "SLAVE_URL|REDIS_REPLICA_HOST"'
# 2. M2 启动断言无 WARN（出现 [rw-split][M2] slave==master 即漏配回退 master）
ssh <region-node> 'sudo journalctl -u newworld-web --since "2 min ago" | grep "rw-split.*M2"'
# 3. cache-miss 端点 RTT≈ms（跨洋会 ~571ms，G3 门禁同此判据）
ssh <region-node> -i ~/.ssh/aws_region 'curl -s -o /dev/null -w "%{time_total}s\n" "http://127.0.0.1:7777/api/v1/courses/search?keyword=zz$RANDOM&pageNum=1&pageSize=20"'
```
> 三道闸兜底（仍以本清单为预防第一道）：M2 启动断言 WARN（Step 验#2）+ 门禁 G2（SLAVE_URL 指本地）+ 门禁 G3（cache-miss RTT≈HK，跨洋读必飙红）。

## Step 3：部署前端（按需）

**原子部署**：构建到临时目录 → `mv` 原子切换。旧 dist 保留为 `dist.backup` 支持秒级回滚。

### 3a. frontend-admin（ca-admin 单机；本地 build → scp → 原子 mv）

> ca-admin 无 git/npm（只有 node），SSH 用户 ubuntu。**用脚本 admin 分支**（2026-06-21 重写为本地 build + scp，不再 ssh 节点 build）：

```bash
bash "$REPO"/scripts/deploy-frontend.sh admin   # 本地 vite build → tar → scp → sudo atomic mv + index.html smoke
# 回滚：ssh ca-admin 'cd /newworld/frontend-admin && sudo rm -rf dist && sudo mv dist.backup dist'
```

> frontend-admin 无 SW / 无混淆 / 无 s.dat / 无 version.txt，裸 `vite build` 即可（"禁手跑 vite build" 铁律只适用 frontend-web）。

### 3b. frontend-web — **铁律：用脚本 `/newworld/scripts/deploy-frontend.sh`**（D 方案 2026-05-10）

```bash
# 单条命令搞定 build + tar + scp + 原子切换 + sync-seeds + s.dat 校验
bash /newworld/scripts/deploy-frontend.sh
```

脚本封装：本地 build → tar → scp 分发全部 6 节点（ca-web-01/02/03/04 + eu-web-01/02）→ 各节点原子切换 → version.txt 一致校验 → **enforce sync-seeds 全节点 + wc -c >= 32B**，任一失败 abort 不切流量。

> **不再保留手敲版本**——backup 8 个里 4 个 s.dat 0 字节证明纯文字步骤会腐烂（详见 `docs/DEPLOY_PITFALLS.md` 2026-05-10）。
> 必要时设 `DRY_RUN=1 bash /newworld/scripts/deploy-frontend.sh` 预览每一步。

### 前端回滚
```bash
# 全部 6 节点逐台执行（ca-web-01/02/03/04 + eu-web-01/02）
ssh ca-web-01 'cd /newworld/frontend-web && mv dist dist.broken && mv dist.backup dist'
ssh ca-web-02 'cd /newworld/frontend-web && mv dist dist.broken && mv dist.backup dist'
# ca-web-03/04/eu-web-01/02 同理
```

## Step 4：前端部署后验证（必须）
```bash
ssh ca-web-01 'cat /newworld/frontend-web/dist/version.txt'
ssh ca-web-02 'cat /newworld/frontend-web/dist/version.txt'  # hash 必须一致（其余节点同理）

ssh ca-web-01 'curl -sI http://127.0.0.1:80/index.html | head -1'  # 必须 200
ssh ca-web-02 'curl -sI http://127.0.0.1:80/index.html | head -1'
```

## Step 5：同步种子域名（D 方案 2026-05-10：脚本 enforce + timer 兜底）

**铁律：sync-seeds 已被 `deploy-frontend.sh` 自动 enforce —— Step 3b 走脚本 = Step 5 自动完成**。

### 三层防线（已落地）

1. **主防线**：`scripts/deploy-frontend.sh` Step 5 强制 curl + 双台 `wc -c >= 32B` 校验，**任一失败 abort 不切流量**
2. **兜底**：`seed-self-heal.timer` 装 ca-admin 单台，5min 检查全部 web 节点 `dist/s.dat`，empty 时自动调 sync-seeds（详见 `ops/systemd/seed-self-heal.{service,timer}`）
3. **6h cron**：`DomainPoolMaintenanceTask.syncSeeds()` 保留作为第三层兜底（不动）

### 手工触发（仅排障，正常发布走脚本）

```bash
# 密钥含 ! 必 heredoc 避免 bash 转义
ssh ca-web-01 << 'ENDSSH'
curl -fsS -X POST http://127.0.0.1:7777/api/v1/internal/sync-seeds -H 'X-Internal-Secret: nw-internal-2026-Kx9mZ!pQ'
wc -c < /newworld/frontend-web/dist/s.dat
ENDSSH
ssh ca-web-02 << 'ENDSSH'
curl -fsS -X POST http://127.0.0.1:7777/api/v1/internal/sync-seeds -H 'X-Internal-Secret: nw-internal-2026-Kx9mZ!pQ'
wc -c < /newworld/frontend-web/dist/s.dat
ENDSSH
# ca-web-03/04/eu-web-01/02 同理
```

### timer 状态查询（ca-admin）

```bash
ssh ca-admin 'systemctl status seed-self-heal.timer'
ssh ca-admin 'sudo journalctl -t seed-self-heal --since "1 hour ago" -q'
```

## 其他

### OpenResty guard.lua 同步
```bash
ssh ca-web-01 'sudo cp /newworld/openresty/lua/guard.lua /usr/local/openresty/nginx/lua/guard.lua && sudo systemctl restart openresty'
ssh ca-web-02 'sudo cp /newworld/openresty/lua/guard.lua /usr/local/openresty/nginx/lua/guard.lua && sudo systemctl restart openresty'
# ca-web-03/04/eu-web-01/02 同理；ca-admin 同：
ssh ca-admin  'sudo cp /newworld/openresty/lua/guard.lua /usr/local/openresty/nginx/lua/guard.lua && sudo systemctl restart openresty'
```

### 执行 SQL
```bash
ssh ca-mysql-master 'mysql -u root -p密码 newworld < /newworld/sql/xxx.sql'
```

## host 一次性修复：parent POM mvn install -N（2026-05-07）

**触发场景**：sprint 引入跨模块的新 API overload（如 newworld-common 加 4-参方法），其他模块 `mvn compile` 报 `cannot find symbol`。

**现象**：W3-A2 引入 4-参 overload 后，aws-data 跑 `mvn -pl newworld-data -am package` 找不到新方法 — 因为 `~/.m2/repository/.../newworld-common-*.jar` 还是旧版本（newworld-common 新 class 未 install 到本地仓库）。

**一次性修复**（host 跑一遍即可，不要进 deploy-backend.sh）：

```bash
ssh ca-admin '
  export PATH=/opt/apache-maven-3.9.9/bin:$PATH &&
  cd /newworld &&
  mvn install -N &&                                    # parent POM 安装到 ~/.m2
  mvn install -pl newworld-common -DskipTests          # newworld-common 新版本 install
'
```

之后 `deploy-backend.sh <module>` 正常 `mvn clean package -am` 即可解析新 overload。

**为什么不进 script**（owner 决策 B，2026-05-07）：每次 deploy 跑 `mvn install -N` ~5 秒额外开销，绝大多数 sprint 没改 common 公共 API；文档化 + 触发场景记录即可，不污染热路径。

**对应工程师动作**：发现编译期 `cannot find symbol` 引用 newworld-common 新成员 → 跑上面一次性修复 → 重试 deploy。

## 配套铁律（必读）
- 部署前四查：见 `newworld-deploy-checklist` skill
- SSH heredoc：见 `newworld-ssh-deploy` skill
- 生产 git pre-flight：见 `newworld-git-preflight` skill
- OpenResty reload smoke：见 `newworld-openresty-deploy` skill

## 教训补充（shadow-diff-retire sprint 2026-05-17）

- **部署 pre-flight 必确认本地已 push 到 origin——服务器 `git pull` 只见 origin**：shadow-diff-retire Phase 4 首次部署，本地 15 个 commit（本 sprint 删除 + B 档 backlog）从未 `git push`，服务器 `git pull` 只拉到 `origin/master` 旧 HEAD → build 旧代码、web×2 旧码空转 restart。ops-senior 靠 JAR 内类验证发现并 HALT。**规则**：部署前（Step 1 之后）必跑 `git rev-list origin/master..HEAD`——非空就先 `git push`，确认 `0` 才进 Step 1.5。与 `newworld-git-preflight`（服务器侧 dirty 检查）互补：一个查服务器工作树、一个查 origin 是否含全部待部署 commit。
- **sprint 收尾标「待部署」的项必须有跟踪，禁无限期搁置**：B 档 backlog 7 commit（前端 + edge Lua）5/17 早些已 commit + qa，但"待部署"被搁置，直到 shadow-diff-retire Phase 4 才偶然捎带上线。**规则**：qa 通过后标"待部署"的改动，24h 内部署或显式登记延期原因 + 责任人，不留无主悬空。

## 教训补充（anti-adblock sprint 2026-05-21）

- **多并行 worktree merge 后部署必含 Step0：`mvn compile` 主仓全模块验证 + 修 merge artifact**：anti-adblock sprint Phase 4b 5 worktree 合并后 ops-senior 在编译阶段揪 7 个 fix commit（`34841207` AdSlotDTO 重复 String clientFilter / `9636a8d3` AdController HttpServletRequest 类型不匹配 / `19d660e4` AdServiceTest List 同步 / `408b26fd` AdControllerTest @Mock / `b446bba2` AdController GET /{slug} 漏接 UA / `52f0fe10` q.js Q-alias exports / `9fdd3c45` baseline.js runBaselineCheck export）。**根因**：每个 worktree 各自 `mvn compile` 通过，但 `-X theirs` merge 不解决"P1.3 越界 commit 498f2c37 加 `String clientFilter` + P1.4 加 `List<String> clientFilter`"的语义重复，需 ops Step0 手工排雷。**规则**：≥3 个并行 worktree 合并的 sprint，Phase 4 plan 必须显式包含 "Step0：merge artifact 预处理"——所有 worktree merge 进 master 后**先跑 `mvn compile -pl <all-changed-modules>`**，修所有编译错 + grep 重复字段 + 检查前端缺失 export，再进 Step1 deploy-checklist；预留 Step0 时间 buffer（实证 ops 耗 26min + 多次截断）；ops-senior 状态档提前写明"Step0 预计处理 merge artifact，可能有额外 fix commits"。

## 教训补充（mysql-qps sprint 2026-06-17）

- **验证 jar 内类禁假设 `unzip` 在——prod web 节点无 unzip**：canary 验证用 `unzip -p jar BOOT-INF/classes/.../X.class | strings | grep` 返空，误以为 jar 不含改动；实为节点无 `unzip`（命令静默失败）。**规则**：验 jar 内类/字符串用 **`python3 -c 'import zipfile; print(b"needle" in zipfile.ZipFile("X.jar").read("BOOT-INF/classes/.../X.class"))'`** 或 `javap -p`（JDK 自带），不依赖 unzip。验完必确认非空输出，空=工具缺失先排查别下结论。
- **部署/健康轮询脚本禁配 `set -e`——启动期 curl 拒连会误 abort**：滚动部署的 `restart → for i in seq; do curl actuator/health; sleep; done` 轮询循环若整段 `set -e`，app 启动期 curl 连接被拒返非零 → set -e abort 整脚本，**输出空但 cp/install/restart 已执行**，险些误判部署失败回滚。**规则**：cp/install/restart 的强制段可 set -e；**健康/就绪轮询循环单独不配 set -e**（curl 失败是预期重试态），轮询后用显式 `grep -q UP && echo OK || echo FAIL` 判定。
- **部署后 EU 节点重启瞬态错误 ≠ 回归**：restart 期 EU web 报 `LettuceConnectionFactory has been STOPPED`（in-flight 退化兜底）+ snack 曝光写失败，单节点可上千条；但随启动完成 ~30-60s 即停。**判 P0/部署回归两条铁律**：① 看**同 jar 的 CA 节点是否也错**（同码 CA 零错=非代码回归，是 EU 重启窗口噪声）② 看**错误是否持续**（近 60s 新错归零=纯瞬态）。EU JVM 启动慢（~38s），健康轮询给足窗口。
- **「QPS 高 ≠ 负载高」——扩容/部署优化决策前先量真实 load**：业务库峰 3590 q/s 看着吓人，但 `system_load_norm_1` 均值 0.12 / `cpu_usage_idle` 76%，71% 是廉价事务管理塞子（SET autocommit/COMMIT）计数。**规则**：判 DB 是否需升配/加副本看 `system_load_norm_1`(1.0=满核) + cpu_idle，不看 Queries 计数；digest `COUNT_STAR` 是累计值会骗人，必跑两次快照增量 delta 看当前速率。详见 memory `project_mysql_qps_reduction_2026_06_17`。

## 源
- CLAUDE.md L122-L340

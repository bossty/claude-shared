---
name: feedback_perf_rca_deploy_gotchas_2026_06_16
description: 本地构建部署 + 多会话并发 master + 窗口取证的踩坑清单（perf-rca sprint 实战）
metadata: 
  node_type: memory
  type: feedback
  originSessionId: c180f4de-418c-4673-8b1e-24d8e011d4e9
---

**perf-rca sprint（2026-06-16/17）本地构建部署 + 取证踩的坑，复用铁律。**

**Why**：每条都差点导致错误产物上线或误判，靠 close-the-loop 证据当场抓出。

**How to apply**：
1. **`-DskipTests` 被本项目 pom 无视**——`mvn package -DskipTests` 仍跑全测试套件（admin 1848 / web 165）。后果：admin 有 3 个预存红测试（ChannelLifecycleServiceTest markBlocked NoSuchMethod，别的会话改签名没同步测试，后被 fdbc6f7e 清死方法）→ 测试 fail → **package 的 jar 打包 goal 不执行 → jar 停在旧版（时间戳暴露）**。构建 jar 必用 **`-Dmaven.test.skip=true`**（跳编译+执行，强制 package 成功）。**部署前必验 jar 时间戳 + `unzip -l|grep 改动类` + `javap -c|grep 新方法` 证改动真进 jar**，别信 exit=0。
2. **master 是多会话并发写线，HEAD 秒级跳动**——一晚 acbbc006→f225efa4→17af333e→684a749b→fdbc6f7e→c739625e。deploy 脚本从当前 HEAD 构建，**ship 前必 `git log <我的commit>..HEAD` + `git diff --stat -- <我的模块>` 逐个 vet 新 commit 没碰我要部署的模块**（多是并行 deadcode-audit 的 docs commit，但必须证）。merged 判定对 local master（领先 origin 几十 commit 时）。
3. **admin 部署路径** = `/newworld/newworld-admin/deploys/admin-YYYYMMDD-<sha>.jar` + `current.jar` symlink（保 5 版）；web = `/opt/newworld/newworld-web.jar`。两者不同！SSH 用户 ubuntu + passwordless sudo，dir 属 newworld:newworld → scp /tmp 再 sudo mv+chown。重启后**轮询 health 200 + journalctl 无 ERROR + 池任务 init 日志**证真就绪（systemd active≠Spring 就绪）。
4. **web.log 本地仅 ~3h retention**——跨夜窗口（00:00-01:00）明早就 rotate 没了（假0陷阱）。要明早分析必**当夜锁窗**：等窗口跑完（01:05）后台 tar 抓 gz。**坑：waiter 只抓了 web.log.*.gz、漏了未 rotate 的 live web.log（丢 00:45-01:05）→ 下次必连 live web.log 一起 cp**。log $time_local 是 HKT（服务器 TZ=HK）。
5. **Monitor/哨兵 end-message 别写死**——我的复发哨兵收尾串硬编码「无复发」，但它实际 00:28 抓到了 busy=103 复发 → 误导。收尾串必须基于真实 BAD 计数输出。
6. **gawk 解析大 gz 逐分钟**：`match($0,/\/2026:00:([0-9][0-9]):/,m)` 取分钟 + `match($0,/urt="([0-9.]+)"/,u)` 取 urt，只输出 per-minute 汇总（小输出）。

关联 [[project_perf_rca_zerodowntime_2026_06_16]] [[feedback_local_build_deploy_no_push_pitfalls]]。

> ⚠️ 2026-07-10 布局统一后路径已变：三模块统一 `/opt/newworld/newworld-<mod>/deploys/current.jar`，回滚脚本在 `/opt/newworld/bin/rollback-backend.sh`。本档正文里的老路径按当时事实保留。见 [[reference_jar_symlink_vs_inplace_overwrite]]。

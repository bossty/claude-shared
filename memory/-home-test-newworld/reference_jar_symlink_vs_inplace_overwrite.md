---
name: reference_jar_symlink_vs_inplace_overwrite
description: 部署 jar 必用 symlink 切换而非覆盖实文件——install/cp -f 原地覆盖同一 inode，与运行中 JVM 的 mmap 懒加载竞争；附迁移验证的三个 harness 坑
metadata: 
  node_type: memory
  type: reference
  originSessionId: ab8d52d5-5178-4a38-979e-b2212f87f341
---

**`install` 与 `cp -f` 都是原地覆盖同一 inode**（`O_TRUNC` 写入，2026-07-10 实测 inode 不变），不是新建+rename。覆盖运行中的 jar 到 `systemctl restart` 生效之间，老 JVM 若触发尚未加载的类，会从内容已被改写的 inode 读 → `ClassFormatError`/`NoClassDefFoundError`。**部署 jar 一律 `install` 到新文件名 + `ln -sfn current.jar` 原子切换**（老 jar inode 完好，无竞争窗口），回滚也是切 symlink。

2026-07-10 web 6 节点已从实文件模型迁到 `/opt/newworld/newworld-web/deploys/current.jar`；admin/data 在 `/newworld/newworld-<mod>/deploys/`（阶段 2 待归一到 `/opt`）。见 `docs/sprint/2026-07-10-jar-layout-unification/`。

**验证 harness 三坑**（都会伪装成"迁移失败"）：
1. `for` 循环里跑 `ssh host 'bash -s' <<HEREDOC`：ssh 吃掉循环 stdin，第二次迭代起远端收到空脚本、输出丢失、退出码乱。→ 脚本落文件，`ssh host 'sudo bash -s' < file` 逐台调用。
2. 远端脚本 `set -e` + `curl` 抢跑：`:18080` actuator 比 `:7777` 晚起，固定 `sleep` 后 curl 失败（退出码 7）直接杀掉整个脚本，验证 echo 从未执行——**看起来像迁移失败，实际早已成功**。→ 轮询等 health + `curl ... || true`。
3. `journalctl | grep -c ERROR` 判据必须限定窗口起点，否则把 SIGTERM 瞬间噪声算进来。

**EU 节点重启必现数百条 `RedisException: Connection closed`**（`SnackService` 曝光写）：EU 跨洋写 CA master Redis，SIGTERM 时在途 `stats-async` 被切断；CA 写同区 Redis 不积压故为 0。**低峰重启为 0 是时段运气，不是流程更优**——别拿它当"常规部署无此问题"的证据。零 5xx（nginx 同区 backup failover 兜住），代价是丢曝光统计。根因是 `stats-async` 线程池 shutdown 不排干，见 [[project_branch_lifecycle_gates_2026_07_09]] 同批 backlog。

关联：[[reference_deadcode_audit_sop]]（删 bak 前全引用面 grep）、[[feedback_gate_redgreen_and_failsafe_direction]]（脚本判据必变异验证）。

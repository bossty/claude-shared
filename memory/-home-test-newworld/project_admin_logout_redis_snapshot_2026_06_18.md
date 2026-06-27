---
name: project_admin_logout_redis_snapshot_2026_06_18
description: "管理后台\"几分钟掉线\"根因=parseToken吞Redis超时→401误踢+Dragonfly小核盒*/5快照spike;修fail-open+快照降*/30;附CA读写同在.128/lag非秒数等架构实证"
metadata: 
  node_type: memory
  type: project
  originSessionId: ee515738-d606-4a5d-acde-66a1b408c3c1
---

# 管理后台"几分钟掉线" RCA + 修复 (2026-06-18)

**症状**：admin 后台几分钟就掉线重登;owner 记得"1 小时过期"。**真相=误踢,与过期无关**。token 真实有效期 **2h**(`jwt.expiration=7200000`,实测运行 jar 内 `application-prod.yml` + 无任何 env/systemd 覆盖)。

## 根因链(已实证)
1. 前端 `frontend-admin/src/utils/request.js` 拦截器:**任何** `code===401` 或 HTTP 401 → `localStorage.removeItem('admin_token')` + 跳 `/login`。
2. 后端只有 `LoginInterceptor:preHandle` → `AdminUserServiceImpl.parseToken` 返 empty 才对**有效 token** 出 401(权限不足是 403,前端不踢)。
3. `parseToken` 旧代码有**吞一切异常的 catch**(`return Optional.empty()`),其中唯一 Redis 依赖是 `isTokenBlacklisted`(黑名单 `hasKey`)。
4. CA Redis(Dragonfly **ca-redis-master .128**,2 vCPU/r6i.large)`snapshot_cron=*/5`→**每 5 分钟全量快照**,在 8.8M keys / ~12k ops/s 下 CPU/IO 争用 spike,把 Lettuce 3s 命令超时击穿(`RedisCommandTimeoutException: Command timed out after 3 second(s)`)。
5. spike 时 `hasKey` 超时抛异常 → 被静默 catch → empty → 401 → 前端清 token。**Redis 基础设施抖动被翻译成"登录失效"**。铁证:超时时间戳精确对齐 5min 快照节拍。请求线程的这次失败**不留日志**(静默 catch),所以 journal 里看到的超时来自不吞异常的 scheduler SCAN 路径。

## 修复
- **① parseToken fail-open**(commit `9c18197d`,+76/-8,2 files,**本地未 push**——origin 落后 20+ 其他 sprint commit,push 会夹带):拆两段——JWT 签名/过期失败仍返 empty(真 401);黑名单 Redis 查询抛异常→**fail-open 放行 + WARN 日志**(黑名单仅登出吊销用,尽力而为,infra 抖动不该踢在线管理员)。加 `@Slf4j`。新增 4 个 parseToken 单测含 fail-open,`AdminUserServiceImplTest` 12/12。已部署 ca-admin(本地 build `-Dmaven.test.skip=true`→scp→切 `current.jar` symlink→保留5版→重启;actuator :18080 UP)。
- **② snapshot `*/5`→`*/30`**,**.128 与 EU slave .184 两台都改**(runtime `CONFIG SET snapshot_cron` + systemd unit ExecStart,**均未重启**,各留 `.bak-pre-30min`)。
- **效果实测**(改后 33min 窗口覆盖 15:00/15:30):超时 4 次全落新快照点 `15:0x`/`15:3x`,频率降 6×;`黑名单查询失败` WARN=0(0 用户被踢);无 auth 回归。

## durable 教训(跨 sprint 复用)
- **吊销/黑名单类 Redis 查询必 fail-open**:基础设施抖动 ≠ 凭证无效;吞一切的 catch-all 把 blip 变 auth failure 且无日志极难排查(同 [[reference_api_encryption_lcp_backcompat]] 的 silent catch 反模式)。本地校验(JWT 签名/过期)与远程依赖(黑名单)分层 try。
- **Dragonfly 小核盒(2 vCPU)`snapshot_cron` 太密(*/5)**在高 ops/s+大 keyspace 下周期性击穿客户端命令超时。诊断金标=**超时时间戳 vs snapshot cron 节拍对齐**;降频是结构性治本,提客户端超时只是创可贴。
- **主库 `INFO replication` 的 `slave0 lag` 字段(Dragonfly)非秒数**,会上下波动误导(实测 601~1097 跳动)。判从库 staleness 用 `master_last_io_seconds_ago`(实测 0)+ **写主读从往返实测**(实测亚秒,sentinel 第1轮就到)。EU lag 是虚惊。
- **CA 读写同在 master .128**:`ca-web-01` 实测 `REDIS_HOST==REDIS_REPLICA_HOST=172.34.1.128`,CA 无独立只读副本(读写分离在 CA 是空操作);只 EU web 读本地 .184、EU 写跨洋回 .128。→ **重启 EU redis CA 无感,只有重启 .128 才波及 CA 全服务**(读+写都在 .128)+ EU 从库重握手。
- **.128 运行进程 replicaof 漂移**:PID 启动 9.6d 带 stale `--replicaof 172.31.19.174:6379`(已退役 HK 老 master),但运行时已 `REPLICAOF NO ONE` 提升为 master(`role:master` 无 `master_host`)=无害;systemd unit 已干净(无 replicaof + cron */30)=**重启安全**。owner 决定运行进程对齐**留计划维护窗**,不为对齐裸重启生产 Redis 主。
- **EU Redis 盒 SSH** 用 `~/.ssh/nw_poc` key + user ubuntu(非 aws_region key);dragonfly `--bind=172.33.3.184` 故本机 redis-cli 必带 `-h`,无 -t flag。
- 副带发现(独立 backlog,与本 sprint 无关):`CloudflareApiService` **DoH TXT 记录更新失败** ~10次/33min + CF `PUT zones/*/dns_records status=400`,DNS 更新在报错,待单独查。

关联:[[reference_terminal_ca_infra_eip_nat_n9e]](终态 CA 基建)、[[project_perf_rca_zerodowntime_2026_06_16]](.128 脉冲/N+1)、[[feedback_perf_rca_deploy_gotchas_2026_06_16]](-Dmaven.test.skip 本地 build 部署坑)。

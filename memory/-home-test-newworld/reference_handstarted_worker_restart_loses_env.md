---
name: reference_handstarted_worker_restart_loses_env
description: 手敲启动的 java worker（无 launch 脚本/无 systemd）重启时照抄 ps 命令行 = 必丢环境变量 → 回落到 application.yml 里早已退役的默认值；worker 仍 health 200「UP」但业务必败，是静默陷阱
metadata:
  type: reference
---

**BuyVM 上的爬虫 worker 不走 systemd**（手动 `java -jar` + `setsid nohup`）。DB/Redis 真值靠**环境变量**注入（`/etc/newworld/best.env` 等，root:600）。

**坑（2026-07-14 BL-68 实事故，我自己踩的）**：重启 worker 时从 `ps aux` 抄命令行，**只抄到 `java -jar ... --spring.profiles.active=prod ...`，抄不到环境变量**（environ 不在 cmdline 里）。用干净的 ssh session 起它 → env 全丢 → Spring 回落到 `application.yml` 的默认值 = **早已退役的 `10.0.0.40` 旧 VLAN 地址** → Redis `Unable to connect to 10.0.0.40:6379` + `WRONGPASS` + `CannotGetJdbcConnectionException`。

**为什么是静默陷阱（最恶劣的一点）**：
- worker **仍然 health 200 `{"status":"UP"}`**（actuator 不检 Redis/DB 连通性）
- HTTP 端点**正常响应**、返回结构化业务 JSON
- 只是**采集必然失败**（`movieFailed=1`，零入库）
→ 极易误判成「源站问题 / 我的代码改动有 bug」，实际是自己重启时丢了 env。我为此白查了两轮。

**判别**：worker 日志里出现 `10.0.0.40`（或任何早已退役的地址）= 100% 是 env 丢失，不是网络问题。真值一定来自 env 文件而非默认值。

**铁律**：
1. **重启这类 worker 一律用 launch 脚本，禁止手敲/照抄 ps 命令行。** madou/cableav 早有 `launch-madou.sh`/`launch-cableav.sh`；best 原先没有 → 2026-07-14 已补 `/home/test/launch-best.sh`（buyvm-data），固化：`set -a; eval "$(sudo cat /etc/newworld/best.env)"; set +a` + cwd=/home/test + 端口错开 + 显式 PID kill。
2. **杀 worker 禁 `pkill -f "<含本脚本命令行的串>"`** —— 会匹配到自己（同族坑见 [[reference_autossh_sidecar_tunnel_pkill_gotcha]]）。用 `pgrep -f "java.*<jar>"` + 显式 PID。
3. **改任何 worker 前先确认它的 env 来源**（`sudo cat /proc/<PID>/environ | tr '\0' '\n'` —— 注意 `sudo tr < /proc/...` 会失败：重定向由无权限的当前 shell 执行，必须 `sudo cat | tr`）。

**姊妹坑（同批发现）**：buyvm best worker 的 logback **长期写不进日志** —— `/home/test/logs/data/all.log` 属 `root:root`（某次以 root 跑 worker 留下），test 用户写不进 → worker 一直**盲跑、零日志**（BL-65 真采 40 部片时亦然）。症状是 logback 报 `Permission denied` 但服务照常起。→ 排查任何"没有日志"的服务，先查日志文件属主，别假设日志存在。

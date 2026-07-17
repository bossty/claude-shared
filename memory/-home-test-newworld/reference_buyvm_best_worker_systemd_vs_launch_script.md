---
name: reference_buyvm_best_worker_systemd_vs_launch_script
description: buyvm-data 的 best worker 由 systemd unit 管（另两台是 launch 脚本），双管理会打架并产生「假 READY」；三台日志在三个不同路径，极易误判 worker 没在跑
metadata:
  type: reference
---

BL-70（2026-07-15）部署途中挖出，**BL-68 交接档从未记载**，白查两轮。

## 双管理打架 + 假 READY

`newworld-data-best.service` **只有 buyvm-data 有**（buyvm-web-01 / buyvm-db 是 `inactive`/无）：

```
WorkingDirectory=/home/test/best-run
ExecStart=/usr/bin/java -Xmx2g -jar /newworld/newworld-data/deploys/newworld-data-best-current.jar \
          --spring.profiles.active=prod --app.scheduling.enabled=false \
          --server.port=9997 --management.server.port=19997
Restart=on-failure
```

跑 `launch-best.sh` 会发生：
1. 它 kill 掉 systemd 管的 java → systemd `Restart=on-failure` **5s 后自动拉起**（走 `current.jar` symlink，所以会拿到新 jar）
2. `launch-best.sh` 自己 `setsid nohup java` 启的那个 → **9997 已被 systemd 那个占** → 启动失败、把 `boot.log` 覆盖成一句「端口占用」
3. 但 launch 的 readiness 探针 curl `:19997/health` **探到的是 systemd 起的那个** → **报假 READY**（结果侥幸正确，过程全错）

### ⚠️ 2026-07-16 我曾在此写过一节「假 READY 更深根因」——**已自我推翻，全文作废**

原文断言：「`/health` 恒返 200 → **所有 `launch-*.sh` 的 readiness 探针无条件恒绿** → 这才是假 READY 的真根因，上面第 3 条只说对一半」。

**这是错的。** `launch-best.sh:58` 三台实测原文：
```bash
code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 http://127.0.0.1:19997/actuator/health ...)
[ "$code" = "200" ] && { echo "  READY ..."; exit 0; }
```
**探的一直是 `/actuator/health`、判据 HTTP 200，完全正确**（文件 mtime 07-15 00:09，早于 BL-70 采集启动）。上面第 3 条的原解释（探针探到了 systemd 起的那个实例、它确实 UP）**本来就完整正确**，不需要"补"。

**我怎么错的（这才是本节唯一值钱的东西）**：`:19998/health` 返 200 是我亲手实测的真事实；但「launch 脚本探 `/health`」是我**从 BL-70 交接档里那句「探针 curl `:19997/health`」直接采信、从未 `cat` 过脚本真身**——而交接档那句话本身就写错了。真事实 + 未验证的转述 = 一个不存在的"根因"，还被我写进 memory/BACKLOG、并据此说服 Owner 授权改共享模块 `newworld-common` + 部署。**同一个会话里我刚写完 [[reference_handoff_source_structure_claim_must_verify]]（交接档结论必抓真页面证伪），转头就犯**。→ 铁律强化：**引用交接档里的任何「某脚本/某配置怎么写」时，必须当场 `cat`/`grep` 那个文件本身；文档写的路径/端点/参数一律不可信。**

**站得住的事实（订正后）**：
- `/health` 及任意未映射路径，Spring 侧确曾恒返 HTTP 200（404 只在 body）——真。修法 `@ResponseStatus(HttpStatus.NOT_FOUND)` 已合 master `e79831b11` 并部署 ca-admin。
- **修后实测：主端口 `:9999/health`→真 404 ✓；但管理端口 `:18080/health` 仍 200**（childManagementContext 不受主上下文 `@RestControllerAdvice` 管）。**故此修并未消灭"管理端口上的假绿"**，而探针恰恰都在管理端口——所幸它们本来就探对了端点，无实害。
- **唯一真实的假绿实例 = `scripts/deploy-web.sh:174`**（探 `${WEB_PORT}/actuator/health` = `:7777/actuator/health`，而 actuator 只绑 `:18080` → 未映射 → 靠 200-包-404 假绿）。已修为 `${MGMT_PORT}`（同 commit）。**不是 launch-*.sh。**

**仍然成立的铁律**：BuyVM worker 健康只认 **管理端口 + `/actuator/health` + body 含 `"status":"UP"`**；禁用 `/health`、禁只看 HTTP 状态码（管理端口至今仍会假 200）。同源坑见 [[reference_actuator_port_18080]]。

**判进程数别用 `pgrep -fc "<flag>"`**：命令行里含该 flag 字符串的 shell/ssh 会自匹配，恒多算 1（实测报 2 实为 1）。用 `ps -eo cmd | grep "[j]ava -jar" | grep -c "<flag>"`。姊妹坑 = `pkill -f` 自匹配杀自己（[[reference_autossh_sidecar_tunnel_pkill_gotcha]]）。

**重启姿势**：buyvm-data 用 `sudo systemctl restart newworld-data-best`；web-01/db 用 `bash /home/test/launch-best.sh`。

## 三个日志路径（最坑）

| 机器 | 管理方式 | 真实日志 |
|---|---|---|
| buyvm-data | systemd（cwd=`/home/test/best-run`） | **`/home/test/best-run/logs/data/crawler.log`** |
| web-01 / db | launch 脚本（cwd=`/home/test`） | `/home/test/logs/data/boot.log` + `crawler.log` |
| — | ExecStart 的 `--logging.file.name` | `/var/log/newworld-data-best.log` ← **被项目 logback-spring.xml 覆盖，是死文件** |

logback 写的是**相对路径** `./logs/data/`，所以**日志位置由进程 cwd 决定** → 换个启动方式日志就换地方。

## 不靠日志判 worker 是否在干活（本次救场判据）

`sudo ss -tnp | grep :9997` 看 curl→9997 是否 **ESTAB** + `ps -o time,%cpu` 看 CPU 在涨 + `/proc/<pid>/task | wc -l` 看线程数。

姊妹坑：[[reference_handstarted_worker_restart_loses_env]]（手敲启动丢 env → 假 UP 真失败）。
同一条主线：**best worker 的「看起来在跑」有至少三种假象**（假 UP / 假 READY / 日志在别处）。

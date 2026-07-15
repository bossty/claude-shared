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

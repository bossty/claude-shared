---
name: reference_autossh_sidecar_tunnel_pkill_gotcha
description: 跨机房永久边车连通=ca-admin autossh systemd 隧道范式(受限key permitopen)+切换时 pkill -f 会自匹配杀掉自己的远端 shell
metadata:
  type: reference
---

# 跨机房边车永久隧道（autossh systemd）+ pkill -f 自匹配坑

BL-51 supjav 边车（buyvm-data）↔ ca-admin 永久连通实证。跨机房（AWS CA ↔ BuyVM）边车常驻连通标准做法。

## autossh systemd 隧道范式（可复用）
- ca-admin 生成专用 key（`ssh-keygen -t ed25519 -N ""`），**只授权到目标机、限端口转发**：目标机 authorized_keys 前缀 `permitopen="127.0.0.1:8770",no-pty,no-X11-forwarding,no-agent-forwarding <pubkey>`（该 key 只能转 8770，不能开 shell）。
- systemd 单元关键项：`autossh -M 0 -N -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes -o StrictHostKeyChecking=accept-new -i <key> -L 127.0.0.1:8770:127.0.0.1:8770 test@<目标IP>`，`Environment=AUTOSSH_GATETIME=0`，`Restart=always`。
- 断线重连实测：杀底层 ssh → tunnel FAIL → autossh 15s 内自动重连恢复。`-M 0` = 不用监控端口，靠 ServerAlive 探活。

## ★ pkill -f 自匹配杀掉自己的远端 shell（Exit 255 根因）
切换边车时 `ssh host 'pkill -f "Xvfb :99"'` —— `pkill -f` 匹配**整条 cmdline**，而运行这条命令的**远端 bash `-c '...pkill -f "Xvfb :99"...'` 自身 cmdline 就含 "Xvfb :99"** → pkill 把自己的父 shell 一起杀 → SSH 会话 `Exit 255`、命令半途中断。
- **修法**：杀进程用**显式 PID**（`kill 2089923`）或按**精确进程名**（`pkill -x Xvfb`，`-x` 匹配 comm 不匹配含参数的本 shell），禁用 `pkill -f "<出现在你命令行里的字符串>"`。
- 同类：任何 `pkill -f app_repo.py` 若命令行含 `app_repo.py` 也会自匹配。与 [[feedback_bash_timeout_does_not_kill_stray_processes]] 的野进程族相邻但根因不同（这是自杀、那是不杀）。

## systemd 边车切换顺序（避端口/display 冲突）
装单元 + daemon-reload → 停旧手起进程（显式 PID）+ 清 `/tmp/.X99-lock`+`/tmp/.X11-unix/X99` → `enable --now` xvfb 先、fetcher 后（Requires 会带起）→ 验 health + resolve 冒烟。僵尸 `[Xvfb] <defunct>` 无害（会被回收，不占 display）。

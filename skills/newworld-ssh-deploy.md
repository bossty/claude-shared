---
name: newworld-ssh-deploy
description: SSH 部署 heredoc 一律用 <<'QUOTED'（单引号包裹 sentinel）避免本地 shell 提前 expand 变量；远端 nginx.conf / systemctl 失败不能以 ssh exit code = 0 误判成功。Triggers on ssh, heredoc, ssh 部署, ssh 命令, 远端 expand, sed 占位符, sudo bash -s, REMOTE quoted, ssh expansion.
---

# Newworld SSH 部署 heredoc 铁律（2026-04-21 事故硬化）

## 触发场景
- 写 SSH 远端执行脚本（部署 / 配置同步 / 证书签发 / openresty reload）
- 远端用 sed / envsubst / cat heredoc 渲染配置文件
- 涉及变量替换 `$VAR` / `$(date)` / `$X`

## 铁律

### 1. heredoc 必须 quoted sentinel
**`<<'QUOTED'`（单引号包裹 sentinel）= 所有变量在远端才 expand。**

### 错（本地 shell 先 expand，$VAR 可能空值）
```bash
ssh usca-1 sudo bash -s <<REMOTE
  . /etc/newworld/secrets.env
  sed -e "s|{{ X }}|$X|g" file.j2 > out.conf
REMOTE
```
本地的 `$X` 在 ssh 发送前就被 expand — 但本地没这个变量！远端拿到 `s|{{ X }}||g`（空值），破坏 conf。

### 对（quoted 'REMOTE'）
```bash
ssh usca-1 sudo bash -s <<'REMOTE'
  . /etc/newworld/secrets.env
  sed -e "s|{{ X }}|$X|g" file.j2 > out.conf
REMOTE
```

或整个命令用单引号传给 ssh：
```bash
ssh usca-1 'sudo bash -c "source /etc/newworld/secrets.env && sed -e \"s|{{ X }}|\$X|g\" ..."'
```

### 2. 明确变量来源
除非你明确要在本地 expand 变量（如 `$(date)` 时间戳），那也要清楚哪些变量来自本地、哪些来自远端。

### 3. ssh exit code = 0 不等于部署成功
SSH 失败后必须检查 nginx.conf / systemctl status，不能以为 `ssh exit code = 0` 就万事大吉。

### 4. 部署前验证渲染产物
远端 `cat` / `head` 渲染后的配置文件，确认占位符都被替换、没有空值。

## 违反后果
按 **3.25** 级别处理。本地 shell 提前 expand 把空值渲染进生产 nginx.conf → `nginx -t` 失败 / systemctl failed → 10~30 秒 openresty 挂掉影响线上流量。

## 事故案例
commit `a870a0fc`（2026-04-21）v3.3 Lua SNI 部署到 usca-2 / aws-s 时触发。

## 源
- CLAUDE.md L554-L585

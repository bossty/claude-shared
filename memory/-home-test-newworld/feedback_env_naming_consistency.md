---
name: env 命名 nginx.conf vs secrets.env 必须严格同名
description: lua nginx.conf os.getenv("X") 与 secrets.env X=... 不一致会变空字符串静默降级，没有任何编译期检查；新增 env var 必须三方对齐
type: feedback
originSessionId: fe398321-ee74-4942-9f53-cfbb4ac5e1d8
---
OpenResty `os.getenv("X")` 找不到时返回 nil → `or ""` fallback 成空字符串，**Redis subscribe 时 NOAUTH 但被 lua 当成正常路径**，导致功能静默降级（pubsub 失效 → cache 不刷新 → 脏数据），没有 startup 报错。

**Why**：2026-05-02 web origin（aws-web-01/02）`web.nginx.conf:77` 写 `os.getenv("REDIS_PWD")`，secrets.env 实际是 `REDIS_PASSWORD=` → s_channel_agent.lua subscribe 永久 NOAUTH 累计 54 万行 error.log 噪音 + cache 退化到每请求直查 Redis（性能下降 + 30s 脏数据窗口）。修复：commit fec6e99a 改 nginx.conf 对齐 secrets.env。Edge VPS（aws-s/usca-*）当时已经是 `REDIS_PASSWORD`，origin 是唯一遗漏。

**How to apply**：
1. 新增 env var 时**必须同步检查三方**：（a）OpenResty nginx.conf `os.getenv("X")`（b）`/etc/newworld/secrets.env` 文件（c）systemd unit `EnvironmentFile=/etc/newworld/secrets.env` 和 `Environment=X=...`
2. 检查命令：`grep -rn 'os.getenv\|EnvironmentFile\|Environment=' openresty/ /etc/newworld/secrets.env /etc/systemd/system/newworld-*.service.d/`
3. 推荐 sprint：补 git pre-commit hook 或 CI lint，对比 nginx.conf 里 `os.getenv("X")` 的所有 X 与 secrets.env 文件 key 是否一一存在
4. 不要相信"它好像运行正常"——降级路径不会 startup 报错，必须主动 grep error.log 找 NOAUTH / auth 关键字

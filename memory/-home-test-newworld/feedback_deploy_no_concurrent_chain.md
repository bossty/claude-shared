---
name: 部署脚本不要混合 & 后台和 && 串联
description: 2026-04-14 web-02 dist 被破坏的事故教训
type: feedback
originSessionId: a1281538-3ef1-45f9-abfb-2b6348aec877
---
部署 SSH 命令时禁止在一行 bash 里同时用 `&` 后台 + `&&` 串联依赖。

**Why:** 2026-04-14 部署 SVG 时写了 `... && ssh switch &  ssh switch &  wait`，bash 控制流让 web-02 的 mv dist.new 在 tar 解压完成前执行，dist 和 dist.new 都被删，线上 30 秒不可用，靠 `cp -r dist.backup dist` 救回。

**How to apply:** 部署改用纯顺序（一次一台），慢 4 秒但永不出事。或者用 `&` + `wait` 但不要在 `&` 后再嵌套 `&&` 依赖链。

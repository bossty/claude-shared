---
name: OpenResty Lua require 链失败 = 进程级 500 雪崩
description: 部署 lua 模块缺文件会让顶层 require 失败被缓存"loop or previous error"，所有后续 require 同模块都 500 直到 reload。新 sprint 新增 lua 模块必须全 VPS 同步部署再 reload。
type: feedback
originSessionId: fe398321-ee74-4942-9f53-cfbb4ac5e1d8
---
部署新 lua 模块时，require 链上**任何一个文件缺失**都会让顶层 require 失败，且 Lua 会在该 worker 缓存"loop or previous error loading module 'X'"哨兵——所有后续 `require("X")` 都会 500，直到 reload openresty 让新 worker 重新加载。

**Why**：2026-05-02 hotfix-3 事故：W4-S02 sprint commit 634e3d4 引入 host_channel.lua + retry_token.lua，但 cp 到 aws-s 时漏掉这两个文件 → `short_redirect.lua:184 require "host_channel"` 失败 → aws-s 100% 500 直到 15:28:18 有人手动 cp + reload 自愈。usca-1/usca-2 当时也漏部署但有 v1 fallback 兜底 302。

**How to apply**：
1. 新 sprint 引入 lua 模块时，**部署清单必须列全所有 require 链文件 × 所有 VPS**（aws-s / usca-1 / usca-2 / aws-web-01 / aws-web-02 共 5 台 OpenResty）
2. cp 完文件**才** reload，不要"先 reload 看看"
3. 部署后 grep error.log `loop or previous error` 是 sentinel 信号，立刻 cp 缺失文件 + reload
4. 多 IP DNS 轮询的 S 域名某节点出问题，先 DNS 摘节点（5min 止血），再修文件，最后回填 DNS（见 reference_dns_drain_refill.md）
5. 提议 sprint：写 lua 模块 md5 一致性检查（git 仓库 vs 5 台 VPS），发 n9e 告警

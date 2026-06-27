---
name: feedback_repo_nginx_conf_stale_upstream
description: "repo 的 openresty nginx.conf 是 node-managed 不可整份 scp;曾存 HK 死 upstream,部署覆盖致 Empty reply"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 9532d6aa-c746-4dc8-9e64-aaed3bb1448b
---

2026-06-15 beacon #2 部署近失:repo `openresty/web/openresty/nginx/conf/nginx.conf` 的 `upstream nw_web` 存的是 **HK 退役时代死 upstream**(`172.31.27.120/121:7777`,无 `127.0.0.1`),而各 region 节点实跑的是本地 `127.0.0.1:7777`(节点上是 `nginx.conf.usw2` 之类的本地版)。Gate5 为加 batch location **整份 scp 覆盖**了节点 → OpenResty 接受连接但 upstream 全死 → **Empty reply**。Gate6 真链路验证(curl :80 /api 真发)抓出,从节点实跑配置还原 + 合入改动修复,并清 repo 地雷(commit e66f3c53 改回 127.0.0.1 primary+HK backup)。

**Why**:各 web 节点的 nginx.conf 是**节点本地管理**(region 各异),repo 那份是 HK 单源时代遗留,早已与生产漂移。整份 scp = 用陈旧配置覆盖正确的本地配置。

**How to apply**:
- 改 openresty 配置**只 patch 具体 location/upstream 行,禁整份 scp 覆盖**节点 nginx.conf;或先从节点拉实跑配置为基再改。
- 部署 openresty 后**必跑 Gate6 真链路**:`curl :80 /api/...` 真发看 200(非 actuator/首页假绿)——这是抓 upstream/guard 失效的唯一可靠手段(关联 web 重建 tar 漏 guard.lua 致 /api 404 教训 [[project_phase_c_execution_2026_06_11]])。
- repo 里凡带具体 IP 的配置(upstream/backend host)在大迁移后都疑似地雷,部署前 grep `172.31`(HK 退役段)核对。

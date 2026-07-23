---
name: newworld-openresty-deploy
description: OpenResty 改 .conf 后必查主 nginx.conf 真 include；access_by_lua 引入新 require 必须确认 lualib 已装；reload 后 3 min 必查 [error]/[emerg]=0 + 真请求 smoke。nginx -t PASS + reload 成功 ≠ 上线安全。Triggers on openresty, nginx.conf, include, lua-resty, reload smoke, configtest, ssl_certificate_by_lua, lua_shared_dict, access_by_lua, init_worker_by_lua.
---

> **执行机制**：靠判断力（reload smoke 方法论）

# Newworld OpenResty 配置/依赖部署铁律（2026-04-25 Wave Stats v4 事故硬化）

## 触发场景
- 修改 `/usr/local/openresty/nginx/conf/*.conf` / `nginx.conf` / lua 模块
- 新增 `lua_shared_dict` / `init_worker_by_lua_block` / `access_by_lua` / `ssl_certificate_by_lua` 指令
- 在 lua 中引入新的 `require "resty.foo"` 模块

## 铁律

### 1. cp .conf 后必须确认主 nginx.conf 真 include
```bash
ssh <host> 'sudo grep -E "include.*foo\\.conf" /usr/local/openresty/nginx/conf/nginx.conf'
# 命中才算生效；0 命中 = 该 cp 上来的文件未挂载（= 部署失败要修挂载，**不等于"可删"**，见下方 ⚠️）
```
**事故**：β1 cp `nginx-web.conf` 到 conf/ 但主 nginx.conf 未 include → 所有 `lua_shared_dict / init_worker_by_lua / access_by_lua / proxy_set_header X-NW-*` 全部死代码 → 归因从未真跑过。

**⚠️「未被 include」≠「死文件可删」（2026-05-16 近失误教训）**：一个 `.conf` 没被主 nginx.conf include，是**中性状态**，可能是 ① 部署漏挂（β1 bug，要修挂载）；② **deferred 部署候选**——`nginx-web.conf` 实为 v5.1-B/V6 待部署版（含 hmac_secret_agent），被 ~30 个 runbook 引用，差点被当"死副本"误删。**删 conf 文件前必须**：`grep -rn "<文件名>" /home/test/newworld`（**scripts + docs/runbooks 全查**，不只看本 skill 标签或行 diff）确认引用面 + Owner 确认该方案是否废弃。**根因防御**：deferred 配置变更别留半成品文件漂在 live 文件旁（`nginx-web.conf` vs `web.nginx.conf` 漂移数周无人能分辨权威）——要么显式命名/移子目录，要么留分支。2026-05-16 已把 `conf/` 重组为 `web/ data/ edge/ _test/` role 子目录 + ROLE marker 强校验根除歧义。

### 2. access_by_lua 新 require 前必须确认 lualib 已装
```bash
ssh <host> 'sudo find /usr/local/openresty -name "foo*.lua"'
```
**关键**：`nginx -t` **不验** access_by_lua 运行期 require，必须真发请求 smoke 才能暴露。
**事故**：β1 部署新 `short_redirect.lua` (`require "resty.http"`) 后 nginx -t PASS + reload 成功，但 access_by_lua 运行期 require 炸 → **6 min 生产 500**。

### 3. reload 后 3 min 必跑 error/emerg = 0
```bash
ssh <host> 'sudo journalctl -u openresty --since "3 min ago" | grep -cE "\[error\]|\[emerg\]"'
# = 0 才算健康；> 0 立即回滚 bak
```

### 4. 部署 runbook 必含"本地真请求 smoke"
单机 reload 后用 `curl -sI http://127.0.0.1/ | head -3` 看 200，404/500 立即回滚。
**`nginx -t PASS + reload 成功` 不等于"上线安全"。**

### 5. location 优先级陷阱（2026-04-29 P8-CORS 沉淀）
nginx location 匹配优先级（高 → 低）：
1. `=` 精确匹配
2. `^~` 前缀匹配（命中后**不再**尝试 regex）
3. `~` / `~*` regex（按文件出现顺序）
4. 普通前缀

**陷阱**：当存在 `location ~* \.(js|css|woff|...)$ { ... }` 一类 regex location 时，普通前缀 `location /assets/ { add_header ... }` **不会**生效——regex 抢占，header 不下发。
**解法**：想给 `/assets/` 或 `/lib/` 等路径加专属 header（如 ACAO）必须用 `^~` 强制前缀优先级：
```nginx
location ^~ /assets/ {
    add_header Access-Control-Allow-Origin "*" always;
    ...
}
```
**事故**：P8-CORS 第一版用 `location /assets/` 写 ACAO，curl 测试发现头部消失，被下方 `\.(js|css)$` regex 抢走；改为 `^~` 后立即生效。

### 6. config-as-code 流程（2026-04-29 治本 / 2026-05-17 改 per-role 树 + rsync）
**所有** OpenResty 配置改动**必须先编辑 git**，再部署到 server。

`openresty/` 是 **per-role 完整目录树** —— 每个 `<role>/openresty/nginx/{conf,lua}/` 镜像节点的 `/usr/local/openresty/nginx/`。`role ∈ web/admin/edge`：

| 仓库目录 | 部署到 |
|----------|--------|
| `openresty/web/openresty/nginx/{conf,lua}/` | ca-web-01/02/03/04 + eu-web-01/02 |
| `openresty/admin/openresty/nginx/{conf,lua}/` | ca-admin |
| `openresty/edge/openresty/nginx/lua/`（+ `edge/*.j2`）| aws-s / usca-1 / usca-2 |

**部署用脚本**：`/newworld/scripts/deploy-openresty.sh <host> <role>` —— **`rsync --delete` 声明式同步** conf/+lua/（节点多余文件自动清，无 role→模块映射逻辑）+ 备份 tar + `nginx -t` + **restart**（lua 改动 reload 不重 require，必须 restart）+ smoke。edge 只同步 lua/，nginx.conf 走 `.j2` 渲染（`prep-edge-vps.sh`）。
> 声明式优于过程式：role 定义 = 目录内容，孤儿清理 = `rsync --delete` 自带。早期硬编码模块清单 + 闭包脚本（`deploy-openresty-lua.sh`）已废弃删除，见 memory `feedback_declarative_over_procedural`。

**禁止直接 SSH 编辑** `/usr/local/openresty/nginx/`，除非生产紧急止血——事后必须立即拉回对应 `openresty/<role>/` 目录 + commit，否则下次 deploy（`rsync --delete`）或 reboot 即丢配置。

**事故**：P8-CORS 改动直接 SSH 改三台 server，未进 git，server reboot 即失效；2026-04-29 治本回填全套 conf + 部署脚本。

### 7. proxy_pass 到 upstream 必须显式 proxy_set_header Host（2026-05-16 /health 事故）
nginx `proxy_pass http://<upstream>;` 到**命名 upstream** 时，若该 location 没写 `proxy_set_header Host`，nginx 默认把发给后端的 `Host` 头设成 **upstream 块的名字**（不是 `$host`）。本项目 upstream 名 `nw_web` 含下划线 `_`，现代 Tomcat 严格按 RFC 解析 Host，下划线直接抛 `IllegalArgumentException: The character [_] is never valid in a domain name` → 该请求被拒。
**铁律**：每个 `proxy_pass` 到后端的 location **必须显式** `proxy_set_header Host $host;`（或 `$http_host`），不能靠默认值。新增 proxy location 时，把同级可用 location（如 `/api/`）的整套 `proxy_set_header` 完整抄过来，禁止只抄一半。
**事故**：2026-05-16 22:32，`location = /health`（admin `WebHealthCheckTask` 5min 定时探测用）`proxy_pass http://nw_web;` 漏 `proxy_set_header Host` → 探针请求被 Tomcat 拒 → admin 误判两台 web 全挂 + 17bot 🟡 告警 + "tunnel 故障切换"文案。同文件 `/api/` location 有此行，故真实用户流量全程无恙。修复 commit `6225975c`（git `web.nginx.conf`）+ 两台 server 紧急热修 + reload。
**防御**：upstream 名尽量避免下划线（用 `-` 或纯字母）；但根因是必须显式 set Host。`nginx -t` 不会报这个——它语法合法，只在运行期被后端拒。

### 8. 节点清理/审计必须扫全树 + 分类穷举，不能只扫单个子目录（2026-05-16 教训）
OpenResty 节点的 cruft 散布多处，清理/审计必须扫 `/usr/local/openresty/nginx/` **整树**，不能只扫 `conf/`：
- `conf/nginx.conf.*` —— 时间戳备份（`.bak-*` / `.bak.*` / `.pre-*.bak` / `.wave15-c.bak`）
- `lua/*.bak* / *.p7-broken.*` —— lua 模块备份
- `nginx/lua.bak.<ts>/` —— 整个 lua 目录的备份副本（whole-dir）
- `ssl/*.bak.*` —— per-domain 证书备份目录
- **该节点不需要的 lua（角色错配）** —— 不是备份、是孤儿 .lua（实证：aws-web-01 装了 `sni_loader`/`cert_pull_agent`/`edge_ops_api` 等纯 edge 模块）
**实证**：2026-05-16 首次 edge 清理只扫 `conf/nginx.conf.*.bak`、漏了后 4 类，Owner 当场抓"我看到一堆 bak 和该节点不需要的 lua"。
**How**：① 备份用 `find /usr/local/openresty/nginx -name '*.bak*' -o -name '*.p7-broken.*'` 扫全树；② 孤儿 lua 用「nginx.conf require 闭包（含 `_by_lua_block` 内 require + 仓库 lua 依赖图 + 服务器 lua require 三路交叉）+ 同角色节点比对」定位，**删前 `openresty -t` 验证配置仍 PASS**（PASS = 实证该文件未被加载）；③ 每类各台保留 1 个最新备份作回滚点即可。

### 9. live nginx 加载路径 vs repo nginx.conf 长期漂移，禁 ops sed 直改 live 作为常规手段（2026-05-21 anti-adblock sprint Phase 4b 教训）

OpenResty 实际加载的 config 路径可能与仓库 `openresty/<role>/openresty/nginx/conf/nginx.conf` **完全无关联**（既非 symlink 也非 include）。anti-adblock sprint Phase 4b 发现：P1.2 grace location 已 commit 到 repo `/newworld/openresty/web/openresty/nginx/conf/nginx.conf`，但 OpenResty 实际加载 `/usr/local/openresty/nginx/conf/nginx.conf`（独立文件）。ops-phase4b 不得不用 `sed` 直改 live config + 备份 `.bak-phase4b-*`（3 台各一份），仓库变更**未生效**直到 sed 写入 live。

**铁律**：
- **部署前 ops 必跑** `ssh <host> "sudo nginx -T 2>&1 | head -3 | grep 'configuration file'"` 确认 live 加载路径
- live path **必须等于** repo `openresty/<role>/openresty/nginx/conf/nginx.conf`（或 symlink 到，或 include 自），否则 sprint 内必须同步修复（不做"下次处理"）
- **禁 ops sed 直改 live 作为常规手段**：仅紧急止血允许，事后 24h 内必拉回 repo + commit（参考第 6 节"禁止直接 SSH 编辑"已有铁律，本条强化"漂移检测"前置）
- nginx 变更 sprint 的部署 runbook 必含步骤："`nginx -T` 实证 repo 路径 = live 路径"

**实证**：anti-adblock sprint ops-senior-phase4b 状态档"关键发现"段；3 台备份文件 `.bak-phase4b-*` 在 live FS。Phase 5 closure 蓝军 reviewer-phase5 揪 KI-3 仍待下个 sprint 同步。

## 违反后果
按 **3.25** 级别。

## 事故案例
- Wave Stats v4 β1-rollout / β1-rollout-retry 两轮（2026-04-24），见 `docs/design/wave_stats_v4_sprint_closure.md` §3.1 / §3.2。
- anti-adblock sprint Phase 4b live vs repo 漂移（2026-05-21），ops-phase4b sed 直改 live + 备份 `.bak-phase4b-*`。

## 源
- CLAUDE.md L670-L693

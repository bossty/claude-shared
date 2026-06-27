---
name: 2026-04-21 Phase 0 S 域 Go-Live 完成情况
description: S/P/A v3.2.4 Phase 0 冷切换上线：DNS 切换 + v3 pick-p 链路打通 + Phase 0.5 遗留项
type: project
originSessionId: 93fa30d6-8acf-448f-9897-96d44dbb2453
---

**Why**: 2026-04-21 Phase 0 cold cutover。5 S 域 (swiftgroup26.cc / swiftscope.cc / moonland26.cc / mintlab26.cc / peak-rank.cc) 从 P tunnel CNAME 切到 edge VPS (usca-1/usca-2/aws-s) × 3 源 × v4+v6 = 30 record。v3.2.4 标准 /r/ Z15c v3 pick-p 链路**已打通**（Redis-free）。

**How to apply**: 
- 用户点击短链 /r/<code> → edge VPS SSL 终止 → Lua access_by_lua_block → v3 pick-p RPC (adm.17.rip) → 302 redirect 到 P 域 (如 corenest26.top/mindbase474.top)
- 非短链 / 路径透传 17.rip (CF proxy 橙云) → aws-web SPA
- dns-failover-agent 在 aws-monitor 活跃，30 record 自动维护
- E2E 实测：5 S 域 × /r/abc = 15 tests 全 302，192~620ms

**关键凭证位置**：
- aws-monitor:/etc/newworld/secrets.env — CF_TOKEN_P/S + DB/REDIS/EDGE_OPS_SECRET/TG_BRIDGE_URL，newworld:newworld 0600
- aws-monitor:/etc/newworld/s-domains.json — 5 域 × 3 源 × (v4+v6) = 30 record 配置
- aws-monitor:/root/dns-backup-20260421-054505/ — 5 CNAME 删除前备份（回滚用）
- 3 edge VPS:/etc/newworld/secrets.env — 有 CF_TOKEN_P/S + EDGE_OPS_SECRET
- admin: EDGE_OPS_SECRET 存 system_config 表（configService.getValue）

**5 S 域 CF zone_id**（P 账号）：
- swiftgroup26.cc: cf71217277d753e208b7c32a60632ca6
- swiftscope.cc:   b97f050987b33cad678618e3bd4d3127
- moonland26.cc:   9b9e2d79217d0ead35cc9abda01c24a9
- mintlab26.cc:    fe2e59c0db2e8d803d1123d337a8cf01
- peak-rank.cc:    be81575e7ec20178d975a515d4cac1b4

**Edge VPS 真实 IP**：
- usca-1: 67.230.182.105 / 2607:8700:360:b168::2
- usca-2: 67.230.161.24  / 2607:8700:5500:2032::2
- aws-s:  95.40.168.207  / 2406:da1e:981:5d1:5ac7:6ad0:d41e:fade

**admin tunnel 域名是 adm.17.rip（不是 admin.17.rip）**：
- cloudflared-admin.service active on aws-data，Tunnel ID: 831edb84-3f74-4c03-8d37-8743a9645c8d
- adm.17.rip 已在 CF P 账号配好（orange cloud proxy），CF_TOKEN_P 可管
- admin API 认证 header: **X-Internal-Secret: $EDGE_OPS_SECRET**（不是 X-Edge-Ops-Secret）
- 源码默认值修正 commit 62289088：`or "https://admin.17.rip"` → `or "https://adm.17.rip"`

**edge VPS openresty 环境变量注入方式**（踩坑记录）：
- 原生 systemd `EnvironmentFile=/etc/newworld/secrets.env` 配置 `(ignore_errors=yes)` 显示已加载，**但 nginx master 进程 env 读不到**（原因未深挖，疑似 fork 时丢失）
- Workaround: /etc/systemd/system/openresty.service.d/env-wrapper.conf override ExecStart 用 bash wrapper：
  ```
  ExecStart=/bin/bash -c 'set -a; . /etc/newworld/secrets.env; export ADMIN_BASE_URL=https://adm.17.rip; exec /usr/local/openresty/nginx/sbin/nginx -g "daemon on; master_process on;"'
  ```
- 这个 drop-in 已在 3 edge VPS 落地，未入 git（运维侧）

**v3 pick-p 链路改造**（commit 62289088）：
- short_redirect.lua 跳过 `is_s_domain()` + `get_channel_for_host()`（都走 Redis，edge → aws-db 172.31.27.200 跨公网连不通，15s timeout 拖死）
- edge VPS nginx server_name 已严格绑 S 域，能进入 location /r/ 的必然是 S 域，不需额外 Redis 校验
- `channel = channel or ""` 允许无 channel 走 admin 全局池（符合代码注释契约）
- location `= /r/` → `/r/`（exact 改前缀匹配，/r/<code> 才命中）

**CF SSL mode 关键修复**（2026-04-21 06:58 UTC）：
- 症状：itdog 拨测 /r/abc 显示"5 跳"，某些地区 DNS 缓存旧 CNAME (proxied=true) 命中 CF anycast IP → CF 返回 `server: cloudflare` + 301 `location=self URL` → 死循环
- 根因：5 S 域 CF zone 原 SSL mode=`flexible`，当 zone 存在但无 proxy target（A record 灰云）时，flexible 默认兜底是 "301 self"；用 HTTPS 回源时这个 loop 消失
- 修复：API PATCH /zones/{id}/settings/ssl → `{"value":"strict"}` × 5 zones 全部成功
- 验证：curl --resolve $d:443:<CF_anycast_IP> /r/abc → HTTP/2 302 到 P 域（无 loop），与 curl 直连 edge IP 路径一致
- 经验：SSL=flexible 对"DNS 缓存残留命中 CF anycast" 的客户端会 loop；改为 strict 让 CF 真正 HTTPS 回源 edge（灰云 A record 也能当 origin）

**2026-04-21 v3.3 Owner 补充决策**：
- 证书**只用 LE**（不做多 CA failover，简化运维，LE 50/周限速走 SAN 合并规避）
- **P 推广主域也会更换**（推翻"永固"假设）：因百度统计主域乱填可行，P 域 rotation 无百度侧手工
- **CN2 / aws-s 的 IP 也会更换**：edge VPS 物理资源可能退租/切换，`dns-failover-agent` 源 IP 不能硬绑 `/etc/newworld/s-domains.json`，应从 DB `domain` 表（category='edge_ip'）读
- 影响：v3.3 §3.2 "P/A 主域永不换" 改为 "P 主域可 rotation，但更换时 channel_code 不变、前端 SPA 路由表要同步"
- 影响：dns-failover-agent v2 需重构为"DB drive"模式（读 domain + promotion_channel_domain 动态生成 30+ DNS record）

**Phase 0.5 遗留项**：
- ⏸ click_reporter 401 warn（edge → admin /api/v1/internal/ops/click-report 埋点，header 可能不是 X-Internal-Secret）
- ⏸ short_redirect timeout 15s → 500ms（理论上已通过 bypass Redis 路径解决，但 rpc_pick_p 里的 timeout 值需再 audit）
- ⏸ prep-edge-vps.sh 补漏：lua 模块部署 + opm get pintsized/lua-resty-http + /__s_health 80 port + openresty env-wrapper drop-in
- ⏸ cloudflared client 可选（若要 edge 直连 aws-web 而非经 CF proxy 双跳，可压 RTT 100~200ms）
- ⏸ systemd EnvironmentFile 机制根因（为什么没传给 nginx master）未查清，用 bash wrapper 绕过

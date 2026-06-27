---
name: project-nginx-error-audit-2026-05-22
description: 2026-05-22 双台 nginx error.log 排查 sprint —— 4 类错误家族 6 commit 合击；owner 5 次揪头发反诘推翻 5 次诊断；6 新教训
metadata: 
  node_type: memory
  type: project
  originSessionId: 81da18c1-0060-4b96-992a-9e14b0add5b3
---

# 5/22 双台 nginx error.log 排查 sprint 全景

## 触发
Owner 让"排查 web 服务器 nginx error 看看发生了什么"。

## 数据起点（部署前 baseline，5/22 16-21 时段）
- `/assets/cdn-failover.js` 404: **33606/h 双台合计**（dominant 头号）
- `/q/static/q05/<hash>.js` × 5: ~14k/h
- `/<32-hex-hash>/<id>.js` (R2 cover/thumb/preview): ~3000-7400/h
- guard.lua rate-limit: **8547/5min（99.7% CF edge IP 误杀）**

## 6 commit 合击

| commit | scope | 修法 | 数据 |
|---|---|---|---|
| `8b7366a2` | frontend `_minimalFallbackConfigs` 加 protocol | 修 fallback 输出裸 hostname 致 probe 拼相对路径 | (含在 owner 接手 2dc023c4 链路) |
| `fc04bf58` | test drift | owner `2dc023c4` PROBE_PATH `/cdn-cgi/trace` 后 mock 没同步 | 19/19 PASS |
| `a2bdf171` | 5 处同目录 `./X.js` dynamic import → static | vite 不 chunk 化同目录 + .js 后缀的 dynamic import，保留字面量致 `/assets/X.js` 404 | cdn-failover.js 404: 33k/h → **0** |
| `d5f33031` | `SK.EDGE_CONFIG: '_sc1' → '_sc2'` schema bump | 5/21 anti-adblock sprint 新增 R_AD/adUrl 字段但未 bump cache key 版本号，老 cache schema 缺 adUrl 致 state.ad 空 | q05 404: 230/min → 92/min (-60%) |
| `7e4771cb` | cdnImage/cdnPreview 空 base 返本地 placeholder SVG（cover/thumb/preview 3 张） | minimal fallback 路径下 R_IMG=origin/空时图打源站；业界共识本地占位托底 | 32hex 404 -48%~78%；placeholder 0 404 served 200 |
| `2d83363c` | guard.lua web rate-limit 暂取消（A 止血） | CF 注入 `Cf-Connecting-Ip = 2a06:98c0:3600::103`（CF 自己 edge IP），同 POP 全球流量共享单一限流桶 → 99.7% 误杀 | rate-limit: 1700/min → **0/30s** |

## owner 5 次揪头发反诘（**Why 这是宝**）

每次 owner 一句质疑都推翻我一次诊断：

1. **"修 setting 更直接吗？"** → 实证 DB R_VID/R_IMG/R_PRV/R_AD 200/200 全 https，确认根因在 fallback 路径而非 split 漏 protocol
2. **"setting API 失败？那数据都拿不到了，怎么走的？"** → 揪出 init() 5 条路径（cachedEdge / cachedConfig / fresh / catch降级 / minimal fallback），minimal fallback 路径**不调 initFailover**，真凶是 cachedEdge schema 缺 adUrl 的 7d 传播
3. **"R_AD 不是早就有了吗？"** → git log -S 实证 R_AD commit `77f14d1e` 是 5/21（**1 天前**），不是早就有；锁定 5/15-5/20 用户 7d cache schema 缺口
4. **"属于兼容修法？后续要改回来的？"** → 推翻 A 方案 schema 字段存在性 check 是死代码 hack；改 B 方案 bump cache key 版本号（`_sc1→_sc2` 既有命名设计就是为 bump 准备）
5. **"正常逻辑应该不打源站，对吧？"** → 引出业界最佳实践调研（Cloudinary default_image / Azure tier-fallback / shadcn safe-image），落实 placeholder β 方案

**How to apply**：未来 owner 任何"是不是"/"那为什么"/"你查过吗"反诘必先 fact-check 再答；蓝军独立复核胜过 groupthink。

## 6 条新教训

### 1. vite 同目录 `./X.js` dynamic import 字面量保留 bug
**Why**：vite chunk 化机制对**同目录 + .js 后缀**的 dynamic import 失败保留字面量，跨目录 `../utils/X.js` 才 chunk 化。`monitor.js:382 await import('./cdn-failover.js')` 漏过 newworld-vite-dynamic-import skill 测试覆盖（`lazy-import-catch.test.js:40` regex `\.{1,2}\/utils\/cdn-failover\.js` 缺 `utils/` 前缀的 case）。
**How to apply**：新增 dynamic import 必检查是否同目录 + .js 后缀；优先 static import；改 [[reference-vite-chunk-rules]] skill。

### 2. cache schema 演进必 bump key 版本号，禁字段存在性检查 hack
**Why**：anti-adblock 5/21 sprint 给 cdnConfig 加 R_AD/adUrl 字段但未 bump `SK.EDGE_CONFIG`，老 cache schema 残留 7d 致 q05 404 雪崩。"字段存在性 check" (`if cachedEdge.adUrl !== undefined`) 是兼容 hack（cache 全过期后变死代码，下次再加字段又叠一条）。
**How to apply**：cache 常量值含版本号（如 `'_sc1'`），schema break 时 bump（`_sc2/_sc3`），所有老 cache 自然 miss + cold start。schema 演进的清洁抓手。

### 3. CDN 域池空时绝不让源站当 fallback
**Why**：业界共识（Cloudinary default_image / Azure CDN 4-tier / shadcn safe-image）：CDN 失败用本地静态占位图托底。newworld `_minimalFallbackConfigs` 把 R_IMG/R_PRV/R_VID 设成 origin 是反业界推荐，源站本无图致 404 雪崩 + 浪费源站带宽 + 污染日志。
**How to apply**：cdnImage/cdnPreview 空 base 返 `/images/placeholders/placeholder-{cover,thumb,preview}.svg`（dist 内静态 < 1KB）；cdnVideo/cdnAd 空 base 返 ''（视频/广告不显假货）。

### 4. CF 可能注入 Cf-Connecting-Ip = CF 自己 edge IP
**Why**：5/22 实测 host=bytebase26.top (S 域) 的请求里 `Cf-Connecting-Ip: 2a06:98c0:3600::103`（CF IPv6 `2a06:98c0::/29` 范围）。可能 CF 健康检查 / Worker / Page Rules 等 CF 内部链路触发的回源里 CF-Connecting-IP 填的是 CF edge IP 而非用户 IP。同 POP 全球流量共享一个限流桶 → 99.7% 误杀。
**How to apply**：guard.lua 必加 CF IPv6/IPv4 range 白名单跳过 rate-limit（[[reference-cf-public-ip-ranges]]）；仅对 CF range 之外的 IP 限流；保留真攻击防护。

### 5. owner 转述/印象需独立 fact-check
**Why**：5 次反诘中 4 次 owner 印象与实证不符（"R_AD 早就有了" / "fallback 输出 origin 应该 OK" 等），owner 也是给线索而非定论；蓝军独立 git log -S / grep / tcpdump 实证才能定真相。
**How to apply**：owner 提的事实先用工具实证（git log/grep/curl），事实证据 ≥ 印象；蓝军复核胜过 groupthink。

### 6. lua 模块改动必 systemctl restart 不能 reload（已有 skill 增量验证）
**Why**：5/22 第 6 次部署 guard.lua 修法走 `/newworld/scripts/deploy-openresty.sh` 自动 rsync + nginx -t + systemctl restart + smoke。init_by_lua_block 缓存铁律（stats-audit W7 教训）落实 OK。
**How to apply**：`init_by_lua_block { require "X" }` 模式必 restart；现有 [[newworld-openresty-deploy]] skill + deploy-openresty.sh 已固化。

## 当前状态（22:55）
- 6 commit 全部 push + 部署完成
- A 模式 rate-limit 全禁，**观察期开始** → owner 决定 B 时机（CF range 白名单恢复）
- 32hex 404 等用户老 SPA 24h 自然刷新自愈
- placeholder β 修法验证 0 404（dist 含字面量 + svg 200 双台）

## B 时机预案
满足任一可启动 B：① 24h 无异常；② 真 attack spike；③ 定位 `2a06:98c0:3600::103` 具体 CF 链路（健康检查/Worker/Page Rule）。
B 修法：guard.lua 顶部加 CF IPv6 (`2a06:98c0::/29` / `2400:cb00::/32` / `2606:4700::/32` / `2803:f800::/32` / `2405:b500::/32` / `2405:8100::/32` / `2c0f:f248::/32`) + IPv4 段白名单跳过 rate-limit。

---

## 5/23 后续：trap-driven 真凶定位 + 8 commit 增量

### 新错误家族 + 真凶链
5/22 23:28 owner 反馈 q05 暴涨 + /assets/cache + /assets/aes：
- `/assets/cache` 4895/min
- `/assets/aes` 258/min
- `/assets/doh-client` 同源

referer 实证 = dist chunk `qvzf4jpd.js`（主 entry），但 src 全集 grep `/assets/cache` 字面量 0 命中。

**owner 拒绝 "中国国产浏览器加速 SDK" hypothesis**（猜测无实证）→ 派 trap pipeline 拿真相：
1. nginx 端 `log_format trap_fmt` 记 Sec-Fetch-Dest/Mode/Site + Sec-Purpose + Purpose + X-Moz → 实证 `dest=empty mode=cors site=same-origin purp=- moz=- purpose=-` = **fetch() 调用 + 非 prefetch**
2. JS-side window.fetch wrap → 被 module 绕过 0 数据上报
3. PerformanceObserver `type: 'resource'` 抓 initiatorType → 浏览器底层 instrumented，不被绕过
4. nginx `location = /_nw_diag/stk` 接 `<img>.src=` GET ping 记 `$arg_s` 含 stack（手机无 DevTools 兜底）

**真凶定位**：sw-bridge.js:301/308/309 三处**同目录 + 无后缀** dynamic import：
- `await import('./cache')` → 404 `/assets/cache`
- `await import('./aes')` → 404 `/assets/aes`
- `await import('./doh-client')` → 404 `/assets/doh-client`

同 a2bdf171 commit 同源 bug，但**前次 regex `\.{1,2}/utils/X\.js` 只覆盖含 .js 后缀**，漏 3 处无后缀。

### 新增 commit 链
- `a34ab1bd` **真凶修法**：sw-bridge.js 3 处无后缀 dynamic→static
- `caf794da` / `6e8cbb73` / `25d18cf9` / `bma9th0to` / `f7e1502b` 等：trap pipeline 部署 + 清理（已删）

### 3 条新教训

#### 7. vite chunk 化 dynamic import 失败的**完整规则**
**Why**：实证 vite 对 dynamic import 字面量 path 的 chunk 化行为有 case-by-case 差异：
- 跨目录 `'../utils/X.js'` ✅ chunk 化成功
- 同目录 + .js 后缀 `'./X.js'` ❌ 保留字面量（a2bdf171 commit 修 5 处）
- **同目录 + 无后缀 `'./X'`** ❌ 保留字面量（a34ab1bd commit 补修 3 处）
- 但实测 dist 上 `./cache` / `./doh-client` chunk 化成功 / `./aes` 失败，**case-by-case 不可预测**

**How to apply**：① 一律 static import（最稳，无 vite 行为不确定性）；② grep 必同时覆盖**含后缀 + 无后缀** 两种 regex `import\(\s*['"]\.{1,2}/[a-zA-Z][a-zA-Z0-9_-]*(\.js)?['"]`；③ 增量到 [[newworld-vite-dynamic-import]] skill。

#### 8. owner mindset：禁 nginx return 204/200 静音兜底 4xx
**Why**：5/23 trap 部署期间 nginx `location = /assets/cache { return 200 ... }`，但 owner 反对"nginx 不要返回 204/200，会隐藏问题导致无法发现"。日志透明原则 > 短期清噪音收益 —— 长期看真 bug regression 必须**让 error.log 自然 404 暴露**才能监控。

**How to apply**：① 临时诊断 trap 用完即清死代码（参考 a34ab1bd → f7e1502b 流程）；② 永久兜底必修对根因（修 src dynamic import）而非 nginx return 200；③ 4xx 暴露是 feature 非 bug，配合 N9E alert 监控 regression。

#### 9. trap-driven 诊断 pipeline 标准做法（手机无 DevTools 场景）
**Why**：owner 拒绝猜测，要实质证据；用户在手机访问没 DevTools 看 sessionStorage 不能直接拿 stack。**多层 trap fallback**：
- Layer 1 (nginx-side fingerprint header)：实证 fetch() 类型 + Sec-Fetch-* 标准 header（无任何 JS 执行依赖）
- Layer 2 (JS window.fetch wrap)：拿 stack（被 module 绕过时降级 0 数据 → 触发 Layer 3）
- Layer 3 (PerformanceObserver 'resource')：浏览器底层 W3C 标准 API 抓 `initiatorType`，**不被任何 module 绕过**
- Layer 4 (`<img>.src=` GET ping)：手机无 DevTools 兜底，stack 上报到 nginx-side `log_format` 含 `$arg_s` 直接定位

**How to apply**：未来 silent failure 类排查必走 4 层 trap pipeline；trap 死代码清理走独立 revert commit，避免污染生产配置。

---

## 5/23 后续：monitor.js R2 probe + 2 新教训

### 现象
owner 反馈 console 红色 404：`1tOP27my.js:2 HEAD https://he6t6.stream-lesson.com/__nw_cf_probe__ 404`

**根因**：monitor.js:388 `probeCfMeta()` setTimeout 5s 后 fetch R_IMG host `/__nw_cf_probe__` 拿 cf-ray + cf-ipcountry。R2 bucket 无此 key → 红色 404 console（功能 OK 因 `response.headers` 不受 status 影响，仅 UX 噪音）。

**修法 commit `024fd854`**：path 切 `/cdn-cgi/trace`（CF 内置每 zone 永远 200，仅接 GET），method HEAD → GET。同前次 cdn-failover 2dc023c4 同模式，零运维 + 跨池统一。

### 2 条新教训

#### 10. dist deploy `cp dist/assets/*` 老 chunk 残留 = 已 mount SPA 用户跑老逻辑
**Why**：`/newworld/scripts/deploy-frontend.sh` `cp dist/assets/* dist.new/assets/`（防 CF 边缘缓存老 HTML 引用 hash chunk 404 兼容设计）保留**所有老 chunk**到新 dist。已 mount SPA 用户内存 module 仍引用老 chunk URL（如 `1tOP27my.js`），即便修法已 ship 也仍跑老逻辑直到用户硬刷新 / SPA reload。owner 自己 tab 看到 404 = 浏览器内存里老 module。
**How to apply**：① 部署后 verify 必查**新主 entry chunk**（`grep 'src=.*\.js' dist/index.html | head -1`）而非旧 hash chunk；② owner / qa 反映"还在 404"先确认是否硬刷新；③ 24h 自愈窗口（用户自然 reload / SPA navigate triggers _m8）；④ deploy 脚本设计意图保留老 chunk 不可改，副作用接受。

#### 11. vite 主 entry chunk 名 content-hash 会随 src 改而变
**Why**：实证 dist/index.html 引用的 `<script type="module" src=...>` 在 5/23 多次 deploy 中：
- f7e1502b 后 = `/assets/qvzf4jpd.js`
- 024fd854 后 = `/assets/BE264yGT.js`
**不能凭印象**说"主 entry 是 qvzf4jpd.js"做 verify—— 必须每次 deploy 后从 dist/index.html 实际读出最新主 entry chunk 名再 grep 验证修法。
**How to apply**：verify 修法生效必先 `ssh host "grep -oE 'src=\"/assets/[^\"]+\\.js\"' /newworld/frontend-web/dist/index.html | head -1"` 拿真主 entry，再 grep 该 chunk 验证字面量；老 chunk 含 deprecated 字面量是 cp 残留设计意图，不当 bug。

---

## 5/23 续 2：edge nginx error.log sprint — 80.5k/h 噪音清理

### 4 错误家族实证 + 修法
1. **click_reporter 401 = 80k/h** (aws-s 47k + usca-1 15k + usca-2 18k)：Z15c sprint 4/20 commit `21ee4ce7` edge lua 写好上报契约，**期待 admin Z15b/后续补 `/api/v1/analytics/s-click` endpoint** —— git history admin 全集 0 命中 = **从未实现**。1 个月静默 dust。
2. **sni_loader fail boldpoint395+peak-rank 170/h**：5/21 commit 72951a07 release() 自动清 DNS 之前 13 分钟释放的 2 域 DNS 漏清。
3. `lua tcp socket read timed out` 200/h：admin RPC 300ms 偏严 noise，by design fallback。
4. `SSL_read decryption failed` 79/h：客户端弱网 spec 行为，无需修。

### commit 链
- `e79f7904` refactor(edge/click-reporter): 删 short_redirect.lua 4 处 async_emit + click_reporter.lua 109 行整文件 -113 lines
- CF API 24 records DELETE（boldpoint395 + peak-rank 各 12 records，CAA 保留）—— 无 commit（CF 配置层）

### 2 条新教训

#### 13. S 域 status vs DNS 一致性反向审计（release() 兜底）
**Why**：5/21 commit 72951a07 给 release() 加自动清 DNS 是 **forward 修法**，但**不修存量**（漏清窗口的释放域）。channel 表 channel-15 直接 DELETE 让 promotion_channel_domain 孤儿 binding（JOIN 需 LEFT JOIN 才全），status 漂移 standby 但 DNS 仍配 → 老链接用户 180/h 仍访问 → edge sni_loader fail → 用户 TLS error。
**How to apply**：① 周期性 systematic 审计：SQL `SELECT * FROM domain WHERE category='S' AND status='standby'` × CF API `dns_records?type=A,AAAA,CNAME` 对账，发现 records>0 即漏；② DELETE 漏的 A/AAAA/CNAME 保 CAA（cert 不吊销，复活可复用 cert_blob 现有 cert）；③ 老链接用户改看 NXDOMAIN 比 TLS error 体验明确；④ 未来可加 admin scheduled task 自动跑（每周 cron），作 release() 反向兜底。owner 业务规则验证："除了绑 channel 的 S 域，都应 standby" 100% 一致。

#### 14. 前后端契约 dust（lua 写契约期待 admin 后续补）一月未补审计
**Why**：Z15c sprint click_reporter.lua 文件头明确写"⚠️ 当前 admin 未实现 s-click，Z15b 或后续 P7 补齐；Lua 端写好契约，admin 收到即存"。**前置 lua 契约 + 期待 admin 后续补** 是常见跨 sprint 设计 pattern，但**没有 follow-up 机制** = 一月没补 = 80k/h 401 静默 dust。fire-and-forget + ngx.log.WARN 静默不告警，**没人发现**。
**How to apply**：① 跨 sprint 前后端契约前置必加 **N9E 告警**（401/404 → metric → alert，1 周内 >1k/h 触发 owner check）；② code 端 ngx.log.WARN "non-ok status: N" 升级到 console.error 等价（写 shared_dict counter + actuator/prometheus 让 categraf 抓）；③ 跨 sprint 待补 endpoint 必 add to 项目 backlog tracker（不只 inline comment "Z15b 后续补"）；④ sprint closure 必 grep `client lua` 调 `not_yet_implemented_admin_endpoint` 残留契约。

#### 15. edge → admin 跨 CF tunnel RPC timeout 必 ≥ READ_TIMEOUT（v3.2.3 硬约束 500ms）
**Why**：edge VPS (usca/aws-s) 跨 CF tunnel + 跨网络（CN/US POP → aws-data 香港）adm.17.rip 平均 RTT 40ms 但 P99 偶 >300ms。`short_redirect.lua:311` 原 `RPC_CONNECT_TIMEOUT=300ms / RPC_SEND_TIMEOUT=300ms` 严过 `READ_TIMEOUT=500ms`（硬约束）→ TCP/TLS handshake 阶段超时 → 触发 fallback chain `live snapshot → last known good pool` → edge 1h 101 次 `lua tcp socket read timed out`。修法 commit `c80f2a6` (300→500ms) 后 5min 实测 100% 归零。
**How to apply**：① 跨 tunnel/跨网络 RPC CONNECT/SEND timeout 至少 500ms（与 READ 一致）；② 严过 READ 没意义只增 fallback 触发率；③ READ_TIMEOUT 500ms 是 v3.2.3 硬约束不动；④ admin RPC 5 阶段降级 by design 工作 OK，但 fallback 触发频次≠good = 优化触发条件让 happy path 更稳。

#### 16. nginx 1.25+ `listen ssl http2` deprecated 必拆 `listen ssl` + `http2 on`
**Why**：openresty/1.29.2.3 起 `listen 443 ssl http2;` deprecation warning（不报错但 reload/start log 大量 warn 污染日志）。新形式 server block 内一次性 `http2 on;` directive。edge `nginx.conf:190-191` 实测 deprecated warning，commit `7b18fe51` 修。
**How to apply**：① 模板 `*.j2` 全 grep `listen .*ssl.*http2` 替换为 `listen 443 ssl;` + 加 `http2 on;`（同 server block 内一次）；② 已渲染 prod nginx.conf 走 SSH `sed -i 's| ssl http2 default_server;| ssl default_server;|g; /^        listen \[::\]:443 ssl default_server;$/a\        http2 on;'` 紧急回填（CLAUDE.md edge "紧急止血除外，事后必须回填 git"）；③ nginx -t verify + restart + `curl -w '%{http_version}'` 确认 HTTP/2 仍工作（避免 deprecation 推 fallback 1.1）；④ 注意：deprecation 不影响 HTTP/2 实际工作（curl http=2 verify），仅 log 噪音。

#### 18. admin actuator/prometheus 在 management port 18080，业务 8888 不暴露（5/23 Y2 教训）
**Why**：Spring Boot 配置 `management.server.port=18080` 把 actuator endpoint 隔到内部 management port，业务 8888 直接 GET `/actuator/prometheus` 返 `{"code":404}` 误以为 actuator 没装/挂了。实际 actuator/prometheus 真路径 = `http://127.0.0.1:18080/actuator/prometheus`（categraf scrape 也走 18080）。`ss -tlnp` 看到 admin java 同时 LISTEN `*:8888`（业务）+ `[::ffff:127.0.0.1]:18080`（management 仅 localhost）即真实拓扑。data 模块同模式 `*:9999` 业务 + `127.0.0.1:19999` management。
**How to apply**：① 任何 admin/data actuator endpoint 排查必先 `ss -tlnp | grep java` 看 java 真实 LISTEN port 集合（业务 + management 两端口），不假设 actuator 在业务端口；② curl 验证 metric 用 `127.0.0.1:18080/actuator/prometheus`（admin）/ `127.0.0.1:19999/actuator/prometheus`（data）；③ N9E categraf scrape config / dashboard datasource queries 都引 management port，对外业务请求隔离；④ 远程访问需 SSH 隧道（management 仅 listen 127.0.0.1）；⑤ 新业务模块加 management 拆 port 是标准 SOP（actuator 不混 prod 业务流量 + 防越权访问内部 metric）。

#### 19. admin pick-p Timer histogram 实证证伪"admin 慢"假说（5/23 Y2 教训）
**Why**：5/23 sprint rpc_pick_p timeout α 后剩 20/h 时，无法判断真凶是 admin 慢 vs 跨 tunnel 网络抖动。加 `Timer.builder("nw_pick_p_duration_seconds").publishPercentiles(0.5,0.95,0.99).publishPercentileHistogram().register(meterRegistry)` 30min 后实证：total 7814 calls / mean 7.67ms / max 61.94ms / fail 0 — **admin 处理 max 远 << 500ms timeout** = admin 永不会触发 edge timeout，**edge 48 timeout/30min 100% 是跨 CF tunnel 网络抖动尾巴**，admin 端无优化空间。Y1 keepalive pool 20→50 边际优化前后噪音级（baseline 20/h → Y1 后 21/h）说明问题不在 keepalive miss。
**How to apply**：① 任何"X 慢导致 timeout"假说先加 X 端 Timer histogram 实证（mean/max/P99 三件套）—— 不实测拍真相，瞎调 timeout/pool 是 vibe-driven；② Micrometer Timer.builder 用 `.publishPercentileHistogram()` 暴露 bucket，prometheus-side `histogram_quantile(0.99, rate(nw_pick_p_duration_seconds_bucket[5m]))` 算真 P99，不必客户端估算；③ Spring Boot Timer lazy register（第一次 record 才出现在 actuator/prometheus），部署后必触发 ≥1 次真调用再 verify；④ `recordCallable` / `try/finally + record()` 模式都 OK，多 return 点用 try/finally 包外层 + helper method 最干净；⑤ Counter（success/fail）+ Timer（duration）配合用 — Counter 看 rate，Timer 看 latency 分布；⑥ 业务边界服务（pick-p / sign-cert / push 等）跨网络调用都该有 Timer histogram 兜底，问题来时直接看真值不靠瞎猜。

#### 17. sni_loader NEG check 必在 shared_dict lookup + root_host fallback 之后（v3.3.5）
**Why**：5/23 实证 active S 域子域（`gg001.apexcorp26.com` 790-1092/h / `lt001.swiftgroup26.cc` 145-249/h）持续 neg_hit，baseline 1h aws-s=11 + usca-1=935 + usca-2=1341 = **2287/h**。诊断链：cert_pull_agent 真正常（`pull_once total=5 loaded=5 OK`），但 sni_loader 原顺序 NEG check（line 329-334 `ssl_neg:get("NEG:"..host)`）在 `certs:get(host)` 之前 → cert_pull_agent 异步拉到 root cert 前，60s 窗口已写 NEG → cert 拉到后子域访问仍走 NEG hit → TLS error → 用户访问续命 NEG TTL 形成雪球。修法 commit `657102f9` 顺序调换：`certs:get(host)` → root_host fallback → NEG check → lazy_load_from_disk。T+5min post-reload 3 edge 全 0 neg_hit / **-100%** / lazy_load_failed 0（无新失败路径）。
**How to apply**：① **shared_dict + NEG 协作铁律：lookup 优先于 NEG**，NEG 只在 lookup 全 miss 后兜底防 DoS；② 副作用 0：真乱 SNI（root 也不在 shared_dict）仍走 NEG + 60s TTL DoS 防护不变；③ 推广模式：所有"先 lookup 再 NEG/cache miss handling"的设计 review 必须验证 NEG check 不能拦截 lookup（同源 cache penetration prevention，DoS 防护是兜底不是头检）；④ owner Q "为什么 warn 级别"答：warn 级别合理（真 bug 信号应留 alert），不应降级 INFO 静音 — 修法在顶层设计调换顺序而非改 log level；⑤ 异步 cert push + 短 TTL NEG 的组合（lazy_load 失败写 NEG 60s）有 race window，必须 cert 命中后立即停 NEG 拦截（不能等 NEG 自然过期）。

#### 20. CF Early Hints 缓存独立于 200 响应 Cache-Control（5/23 outfit 字体警告教训）
**Why**：5/23 owner 报 `outfit-600/800.woff2 preloaded but not used` console 警告。3 commit 串联修：(debcd374) 删 HTML `<link rel=preload>` + @font-face dust（commit 183b12ac logo CSS→SVG path 后字体变 dust）→ owner incognito 仍报；(7f7561e9) 删 `/etc/openresty/nginx.conf:178` `add_header Link "</fonts/outfit-600.woff2>; rel=preload..."` —— 5/20 sprint 准备 CF Early Hints 加的 header，但字体 dust 后没同步清；deploy-openresty.sh aws-web-01/02 + restart + curl 验证 origin 200 不再带 Link header，但 **`HTTP/2 103` Early Hints + `link: outfit-600/800` 仍存在** → 真凶第三层 CF 边缘 Early Hints cache 独立缓存；CF API `POST /zones/{zone_id}/purge_cache` `{purge_everything:true}` 后 T+5s curl 实证 103 消失，真机 chrome-devtools incognito + ignoreCache **0 console warn + 0 outfit font fetch** 闭环。
**How to apply**：① CF zone 启用 Early Hints 后**两套独立缓存** = HTML body cache（看 Cache-Control / cf-cache-status）vs Early Hints cache（看 HTTP/2 103 + Link header）；② 改 origin Link header 后 **必须 CF purge** 才让边缘 Early Hints 缓存归零，不会自然过期到用户端；③ 抓 Early Hints 真凶的 curl 命令：`curl -s -D - https://X/ -o /dev/null --http2 | grep -iE "^(HTTP|link)"` —— 若返 `HTTP/2 103` + `link: ...`，是 CF Early Hints 在发；④ 全局规则：任何 nginx `add_header Link` / 后端 103 中间响应 一旦改动必同步 CF purge zone；⑤ owner 端 console 看到的 console.warn 决定权在浏览器 + 缓存层综合作用，源站改 ≠ owner 端立即生效。详见 [[reference_cf_early_hints_cache]]。

#### 21. owner 端 incognito 仍报错 ≠ 服务端修干净（5/23 真机实证金标）
**Why**：5/23 outfit 警告 sprint 第二轮：我 `curl https://17.rip/` 拿 HTML 0 outfit 命中 + dist 0 outfit 命中 = 自认为修法生效。owner 用真机 incognito + clear site data 仍报警告，反诘 "还在 这么简单都处理不好？"。chrome-devtools-mcp incognito + ignoreCache + isolatedContext **真机实证**：DOM 0 outfit preload + network 仍 fetch outfit → 单 curl 验证盲点。**抓手**：`window.performance.getEntriesByType('resource').filter(e => e.name.includes('xxx'))[0].initiatorType` —— 返 `early-hints` 才锁死真凶是 HTTP/2 103 不是 DOM。
**How to apply**：① owner 反诘"还在" → 立即跑真机 chrome-devtools-mcp 不依赖 curl（curl 看 200 body 看不到边缘 cache / SW / Early Hints / extension 注入）；② `initiatorType` 是定位"DOM 不可见但仍 fetch"资源的颗粒度抓手，5 类映射：early-hints / link / css / script / xmlhttprequest|fetch；③ DOM `querySelectorAll('link[rel=preload]')` 显示 0 处 + network 仍命中该资源 → 100% 是 Early Hints 或 JS 动态注入后立刻删；④ 真机验证三件套：incognito context（无 SW、无 cookie、无 cache）+ `ignoreCache:true` + 真随机 `?_bust=ts` query 防 CF edge cache；⑤ owner mindset：服务端 curl 干净 ≠ owner 端 0 命中，差异 = 中间层（CF / SW / 浏览器 disk cache / extension）问题，必逐层排查。

#### 22. add_header Link 这类"为未来 X 准备"的 header 没同步资源清理 = dust（5/23 outfit 教训）
**Why**：commit `5/20 anti-adblock sprint` 加 nginx `location = /index.html` `add_header Link "</fonts/outfit-600.woff2>; rel=preload..."` 准备 CF Early Hints 加速首屏。代码层正确（CF 行为有数据支持），但**忽略了同 sprint 后续 logo→SVG 改动会让 outfit 变 dust**。3/22 commit 183b12ac logo 改 SVG 时清了 CSS 文字 logo 样式，但 nginx Early Hints header **没同步审计**，独立漂在 dev/prod 一月多无人发现，直到 owner 5/23 看 console 才暴露。
**How to apply**：① 任何"为 future 优化 X 准备"的 nginx/CF/SW header 必绑 sentinel — 在源码内放注释 `# WHEN <feature 死/迁移> RE-AUDIT THIS`，未来改资源时 grep 出来；② 删/迁资源（字体/图标/JS module）必跑全栈 grep（HTML/CSS/Vue/nginx-conf/sw-precache/CF 规则），不能只 grep src/；③ 5/22-23 sprint 18-22 课「源站删了不立即生效」反复 5 次出现（同源同型）：lua require chain / cache schema bump / CF Early Hints / SW precache / cdn-failover — 任何**中间层有 cache 的资源被引用**都该上 deploy 后立即 purge / restart / clients.claim 主动失效；④ nginx 配置 review 必看 `add_header Link|Preload|Strict-Transport-Security` 这种"被 CF / 浏览器二次解读"的 header，影响面超 HTTP/200 body。

#### 23. activateDomain ↔ release() 对称设计 — 状态转换 pair 必互为镜像（5/24 commit `72c9077e`）
**Why**：owner 5/24 揪头发 A 池 active=18 vs target=20，cron 每 10min 崩 `core-sync.link` CF API 81053 "An A/AAAA/CNAME record with that host already exists" → `CfPermanentException` → maintainPool 整段 break，永久卡死。根因：5/21 commit `72951a07` 给 release() 加自动清 CF DNS 是 forward 修法，但 activateDomain 配对的"添加前清"漏写 → standby 域携带历史 stale CF 记录（前次 active 漏清 / 历史手动加）→ addWebDnsRecords 81053 → 链路死循环。修法 commit `72c9077e`：activateDomain `// ⓪` 步插入 `cloudflareApiService.deleteAllDnsRecordsExceptCaa()` 调用，与 release() 完全对称（release 删 → activate 必先清同 set 再 add）。CAA 保留不吊销 cert。try-catch 不阻塞 add，失败 log.warn 让 add 继续尝试。167 tests 0F0E PASS，1 cron tick A active 18→20 自愈。
**How to apply**：① **状态转换 pair 必互为镜像**：任何 `release/delete/teardown` 流程清除 set X，对应的 `activate/create/setup` 流程必先 `clear X` 再 add；② **CF 81053 处理优先 fix at source**（idempotent 清除）而非"看是否 stale 内容相同判 success"hack（更复杂且案例少）；③ **state-transition idempotency 是分布式系统铁律** — 任何 standby→active 路径都该假设 standby 携带 stale state（DNS / WAF / cert / cache），活化前必先 clean slate；④ activateStandbyDomains 内 `ORDER BY id` → 旧 standby 优先 → 旧域常携 stale 痕迹 → 概率失败更高（5/23 release() 自动清后新生成的 standby 比 ≥4 周老 standby 干净）。

#### 24. CF WAF rule expression 4000 字符硬限 + `lower() contains` 单子句解超限（5/24 commit `fe478523`）
**Why**：owner 5/24 报 CF WAF rule expression **4063/4000 字符超限** → 新激活 A/P 域（owner 改 DOMAIN_POOL_PROMO_TARGET=15 / 手动 PUT core-sync.link 等）syncWafRefererWhitelist update rule **CF reject** → R_IMG/R_VID/R_PRV 5 个 B 类 CDN zone WAF 校验 referer 拦截 → 用户访问真域看不显图。根因：旧设计 `buildRefererExpression` 给每域**写双子句**：① `http.referer contains "<domain>"`（case-sensitive 子串） + ② `http.referer wildcard "https://*.<domain>/*"`（case-insensitive 整串）= 字符翻倍，41 域必超 4000。蓝军 CF 官方 wirefilter docs fact-check：contains 子串匹配语义**已包含 apex + 所有 wildcard 子域**（`"domain.com"` 在 `"https://sub.domain.com/path"` 内即子串），wildcard 子句"看似精确"实为冗余。修法用 `lower(http.referer) contains "<lower_domain>"` 单子句 = case-insensitive 子串匹配 — 4063→**2087 字符（-49%）**。CF API GET assetlibs.com WAF rule 实证 `expr_len=2087 / action=block / contains_lower=True / contains_wildcard=False` ✅。
**How to apply**：① CF WAF rule expression **4000 字符硬限**（Free/Pro/Ent 同；docs 没明示但实测 reject）必加 length guard `>3800 软告警 + Telegram`；② 不要堆 OR 子句（每域 2-3 子句字符炸），优先 transformation function 简化（**lower / strip_www / url_decode 链 contains**）—— CF wirefilter `lower(String) : String` 与 contains 类型兼容，**`lower(http.referer) contains "<lower_domain>"` 是 case-insensitive 子串匹配 SOP**；③ contains 子串语义天然覆盖 apex + 所有 wildcard 子域，不需要单独 wildcard 子句；④ 长期超 100+ 域规模 → 改 CF List API（rule 引用 list，~200 字符 rule + list ref），newworld 当前 41 域 lower() 单子句解了。

#### 25. 蓝军 fact-check 官方 docs 推翻直觉 — CF 操作符 case sensitivity 不同（5/24 蓝军教训）
**Why**：我第一次判断"wildcard 子句对 happy case 完全冗余" 被 owner 揪头发 "wildcard 和 @ 应该都需要在白名单内才行 对吧"。蓝军 fetch CF 官方 wirefilter docs 实证：`contains` **case-sensitive** ("All string operators are case-sensitive unless explicitly stated") + `wildcard` **case-insensitive** ("whole-string + * 元字符")。原 wildcard 子句是 case-insensitive 兜底（防真用户大小写不规范 referer），删它损失 case 覆盖 — 不能"看似冗余就删"。最终方案 `lower(http.referer) contains` 既解超限又保 case 兜底（lower 把 referer 全转小写再 contains 已小写化的 domain）。
**How to apply**：① CF wirefilter 4 操作符 case 行为不同：`contains/eq/matches` case-sensitive；`wildcard/strict wildcard` case-insensitive — 看似等价表达式实际语义差很大；② owner 揪头发"对吗" = 真问，必蓝军 fetch 官方 docs 实证不能凭直觉答；③ 5/22-23 sprint 多次"未来材料/直觉判断"反复被 owner 揪头发推翻（同源 5/15 W3 教训 LSP report hallucination / 5/22 R_AD owner 印象错），fact-check 是金标；④ 简化方案前必 fact-check 真实语义是否等价，**不能因表达式短了就以为正确**。



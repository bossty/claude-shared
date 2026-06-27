---
name: project-cf-speed-audit-2026-05-20
description: CF Speed Optimization 收口 sprint（5/20 evening）：154 zone bulk PATCH + Java configureWebZone 精简到 4 项 + 3 Explore agent cross-check 调研。定版自动配置清单 10 项 zone setting + CAA + DNSSEC。
metadata: 
  node_type: memory
  type: project
  originSessionId: 879fd920-81f3-4676-b7fe-c567cb0afb2e
---

# CF Speed Optimization 收口 sprint（2026-05-20 evening）

延续 5/20 上午 QQ iOS 修复 + 5/20 下午 player_hijack 沉淀（见 [[project-player-hijack-2026-05-18]]）。
Owner 收口剩余 CF Speed Optimization 4 个 tab 的免费可做项。

## 主要产出（关键 commits）

- `5365ed96` `scripts/cf-zone-settings-bulk.py` — 154 zone × 18 setting idempotent bulk（183 patched + 2589 already + 0 failed）
- `b53dc2ee` `applyBaselineOnSettings` Java helper Plan B 精简到 4 项
- `d0fada51` 加 `ech` 进 helper → Plan B+ **5 项最终定版**（API 实测可写后 Owner 拍加进去）
- `080c0c83` commit `cf-settings-smoke.py` + `cf-domain-audit.py` 留作 ad-hoc 工具 + cron 后备
- `e213e3ff` `CfZoneAuditService.java` 每天 03:00 audit + auto-fix + Micrometer metric + N9E 告警 4 条（Plan C 完整）
- `449abd7f` fix(cf-audit) @PostConstruct 初始化 last_run = now 防 CF-AUDIT-MISSED 冷启动误报
- 5/20 evening 末 sub-sprint：DNS records TTL audit
  - `dc057fe4` 入库 `scripts/cf-dns-ttl-audit.py`（一次性 fix 5 个 S 域 CAA records 300→1 + audit baseline）
  - `bb4a8ab6` **CfZoneAuditService 扩展整合 DNS TTL audit**（同 zone 循环 + 3 新 metric + N9E 2 新告警）；CloudflareApiService 加 `listDnsRecords` + `patchDnsRecordTtl` 公共方法

## 决策时间线

1. Owner 提"继续 CF Speed Optimization tabs"
2. 我列已完成（Early Hints / HTTP/3 / always_use_https / HSTS / browser_cache_ttl）+ 待办（0-RTT + h2_prioritization + Always Online + Crawler Hints）
3. Owner 纠正 "h2_prioritization 是付费"（我记忆错）→ 排除
4. Owner 拍 "Always Online + Crawler Hints 理性分析" → 我列暴露面/反 SEO 论据 → 两者**均不开**（伪装站方向相反）
5. Owner "上加强版 A"（其实是 CF Speed sprint A 而非 css 加强版 A，但前后 sprint 串了 — 此处 sprint 路径 = 0-RTT bulk + 默认 on 项 idempotent PATCH + Java automation）
6. **smoke 先行**：写 `cf-settings-smoke.py` 17.rip 单 zone 20/20 PASS（含 0-RTT，CF docs 标 Paid 实测免费可用）
7. 154 zone bulk PATCH（PASS / 0 failed）
8. Java configureWebZone 加 15-item baseline helper
9. **Owner 质疑**：「ech / email 这些不需要吧」+ 「CF 现在有 ECH？」+ 「replace_insecure_js / ipv6 dashboard 哪里」
10. **派 3 Explore agent 并行**：(A) ECH 当前状态 / (B) replace_insecure_js + ipv6 dashboard 位置 / (C) 21 项 full audit
11. 3 agent 合成 + **17.rip API 实测 cross-check** → Plan B 精简到 **4 项**（0rtt + automatic_https_rewrites + brotli + tls_1_3）
12. mvn re-build admin → `deploy-backend.sh admin` → jar md5 `ca1b22a7a457` active errors=0

## 定版自动配置清单（A/C/P/S 4 类的最终 zone setting）

| # | Setting | 值 | 来源（Java method）|
|---|---------|----|---------------------|
| 1 | `ssl` | flexible | `setZoneSetting` 显式 |
| 2 | `always_use_https` | on | `setZoneSetting` 显式 |
| 3 | `security_header` (HSTS) | enabled max-age=180d IS=false preload=false | `setHsts()` |
| 4 | `http3` | on | `setZoneSetting` 显式 |
| 5 | `early_hints` | on | `setZoneSetting` 显式 |
| 6 | `browser_cache_ttl` | 0 (respect-origin) | `setBrowserCacheTtlRespectOrigin()` |
| 7 | `0rtt` | on | `applyBaselineOnSettings()` Plan B+ |
| 8 | `automatic_https_rewrites` | on | `applyBaselineOnSettings()` Plan B+ |
| 9 | `brotli` | on | `applyBaselineOnSettings()` Plan B+ |
| 10 | `tls_1_3` | on | `applyBaselineOnSettings()` Plan B+ |
| 11 | `ech` | on | `applyBaselineOnSettings()` Plan B+（加进 helper 防 CF 政策变化，API 实测可写）|

**其他自动化（非 zone setting）**：CAA × 4（DigiCert + LetsEncrypt + issuewild + iodef）+ DNSSEC enable + triggerActivationCheck + DNS A/CNAME records（按 A/C/P/S 不同）

## 已 bulk PATCH 但 Java helper 已剔除的 10 项 no-op（保留不撤）

`email_obfuscation` / `ip_geolocation` / `ipv6` / `opportunistic_encryption` / `opportunistic_onion` / `pq_keyex` / `privacy_pass` / `replace_insecure_js` / `server_side_exclude` / `websockets`

（`ech` 5/20 evening Owner 拍加回 helper，commit `d0fada51`）

**保留理由**：CF 默认 on，PATCH 没改变状态，零负影响。**Java helper 剔除的理由**：未来新 zone 创建省 ~3s 启动延迟（11 次冗余 API call × ~300ms）。

## 关键教训（待 sink CLAUDE.md）

### L1：CF docs / agent 报告 / API 实测多源 cross-check
- CF docs 标 `0rtt` / `brotli` / `http3` / `early_hints` Paid，**实测 Free plan 全可用**（17.rip API editable=True + PATCH success）
- Agent 1 报告"ECH Free 强制 on 不可关"，**实测 PATCH off success=True 实际改为 off**
- Agent 3 报告 4 处错（ech/0rtt/replace_insecure_js/pq_keyex 默认值与实测不符）
- **教训**：CF 实际行为以 API GET + PATCH 实测为权威，docs 表 / agent 报告作参考必须 cross-check

### L2：CF 中文 dashboard 翻译误导
- 「**随机加密**」CF 中文版描述「让浏览器知道您的站点通过加密连接提供，从 HTTP/2 性能改进中受益，**地址栏继续显示 http**」 = **`opportunistic_encryption`**（不是 ECH）
- 翻译听起来像 ECH 但功能完全不同（ECH 加密 SNI / OE 让 http URL 走 HTTP/2 + TLS）
- **教训**：CF 中文 dashboard wording 不可凭名字猜 API key，要按英文描述 + API key 双重验证

### L3：审 baseline 必走「项目相关性 vs CF 默认 on」二维过滤
- Owner 质疑"email / opportunistic_onion / server_side_exclude 不需要" → 正确
- 默认 on 但**对我们 SPA + 反侦察项目 no-op** 的 11 项剔除 helper
- **教训**：默认 on 不等于"必须显式 PATCH 加固"，相关性 + 防 CF 未来弃用价值才是要不要显式 PATCH 的判据

### L4：smoke 先行铁律有效
- Owner 明确"所有自动化设置用脚本或 Java 小程序使用相同实现方式调用测试一下，保证接口正常调用和返回"
- 写 `cf-settings-smoke.py` 单 zone 跑通后 → 154 zone bulk 0 failed
- **教训**：bulk 之前必 smoke + cross-zone testing 验证 API endpoint + value format + response 全部正常

### L5：派 Explore agent 必 cross-check 实测
- Agent 1 / Agent 3 多处错（不同的）
- Agent 2 准确（dashboard 位置）
- **教训**：派 ≥2 agent 调研同题（互相 cross-check）+ Owner 实证 / API 实测兜底，单 agent 不可全信

## 5/20 evening 收尾 audit：DB 域 vs CF 实测 baseline 对比

Owner 问"数据库中所有域名都按用途设置了对应配置项了没有" → 写 `/tmp/cf_domain_audit.py` 跑 123 个 active+standby+retiring 域 GET zone settings 对比 baseline 11 项：

| group | total | all_pass | ssl mismatch | 0rtt_off |
|-------|-------|----------|--------------|----------|
| A/active | 10 | **10** | 0 | 9 |
| A/retiring | 1 | 1 | 0 | 1 |
| A/standby | 59 | **59** | 0 | 59 |
| B/active | 18 | **18** | 0 | 12 |
| C/active | 4 | **4** | 0 | 4 |
| P/active | 14 | **14** | 0 | 14 |
| P/standby | 6 | **6** | 0 | 5 |
| S/active | 7 | 2 | **5** | 7 |
| S/standby | 4 | 2 | **2** | 4 |
| **Total** | **123** | **116 (94%)** | **7** | **115 (94%)** |

### 7 个 S 域 ssl mismatch → 统一 flexible（5/20 evening 收口）

- 5 active S 域（mintlab26.cc / moonland26.cc / peak-rank.cc / swiftgroup26.cc / swiftscope.cc）原 `ssl=strict`
- 2 standby S 域（dawn-leaf.com / silvernest26.com）原 `ssl=full`
- Owner 拍统一 `ssl=flexible`：**S 域 grey-cloud 不走 CF（W14 设计直连 edge VPS）→ ssl 设置对实际流量是 no-op cosmetic**
- 统一后 audit 整洁（123/123 ALL PASS 除 0-RTT），未来 cron 报告无 false-positive
- `/tmp/cf_s_domain_ssl_unify.py` PATCH 7/7 success

### 0-RTT CF 服务端 silent rollback（重大新发现）

- **115/123 域 (94%) 0-RTT PATCH 后被 CF 后端 silent 关回 off**
- Bulk PATCH 立即 GET success=value=on，几分钟后再 GET 又变 off
- 实测：第一轮 bulk patches=183，5min 后跑第二轮 patches=154（154 zones × 1 项/zone reverted）
- 唯一保留 on 的 8 个域可能是 17.rip 这种 active 高流量 + ssl=full/strict 加固后通过 CF 后台校验
- CF Free plan 上 **0-RTT API 看似 PATCH 成功实际服务端不持久**

### Owner 拍 B：Plan B+ 保留 0-RTT cosmetic

- Plan B+ 5 项 helper 不变（保留 0-RTT）
- 业务影响：少数高流量 zone 真受益（17.rip 等）；多数 zone cosmetic 无负影响
- helper 每次新 zone PATCH 试一次 0rtt=on，CF 后续校验决定持久与否

### 6 条新教训追加（已 sink CLAUDE.md L6-L9）

6. **CF API PATCH success ≠ CF 服务端最终态**：0-RTT 这类 setting 后台异步校验后可能 silent rollback。判定真生效必须 PATCH 后**等几分钟再 GET** + 长期 audit
7. **owner 手动配置 vs 自动化基线区分**：audit 必区分 owner 主动加固（ssl=full/strict）vs 自动化漂移（0-RTT silent rollback）。owner 加固不算 mismatch，记入 expected exception 表
8. **域生命周期 status 分组 audit**：active vs standby vs retiring 应分组报告，因为 standby 域可能 CF 后端校验失败率高（无活跃流量 → 0-RTT rollback）。**业务关注点：active 才是必须 PASS 的，standby 可容忍部分项 fail**
9. **idempotent bulk script 适合 cron 定期拉齐**：CF silent rollback 决定 bulk PATCH 是 "尽力而为"。可加 cron daily 跑 cf-zone-settings-bulk.py 自动拉齐被 rollback 的 setting

## 待办（30d 观察期）

- ECH dashboard UI 真位置确认（Owner 12 项 dashboard 列表无 ECH，可能 Free plan 没暴露 UI 仅 API）
- min_tls_version 1.0 → 1.2 升级（Owner 拍不做，留观察 12 个月看老 Android 客户端比例下降后做）
- HSTS preload list 提交（hstspreload.org，需 max_age ≥ 1y + IS + preload，预计 30d 观察期满后做）
- W14 standby 流程的 applyBaselineOnSettings 实地验证（下次新 S 域 standby 时观察 admin.log）
- **0-RTT CF rollback 根因调研**（5/20 evening 已完成）：Explore agent 报告 4 根因排序：
  - **#1 ssl=flexible 主因**：CF 0-RTT 要求双向加密链路，flexible 模式 CF→origin 是明文 HTTP 违反前提
  - #2 Free plan 流量门槛（中概率）：8 个保持 on 都是 active 高流量
  - #3 min_tls_version=1.0（低概率噪音）
  - #4 Universal SSL 证书类型（排除）
- **未来 CF Origin CA + ssl=full 升级 plan**：落 doc `docs/design/cf_origin_ca_future_plan.md`，触发条件域数 ≥ 500 + 0-RTT 实证业务价值；**当前不实施**（120 域规模 + hls.js keepalive 视频流 50-100ms TLS handshake 节省用户不感知）；架构选每域独立 wildcard cert（X.509 SAN immutable 加新域必重签 → 每域独立避免共用大 cert 频繁重签的 CF API 限频 + pipeline 抖动）；CF Origin CA 15 年免续期完胜 LE 90 天每域续期千级压力
- ~~cron daily 跑 cf-zone-settings-bulk.py（可选）~~ → ✅ 已实现 Java `CfZoneAuditService` @Scheduled 03:00 + auto-fix（commit `e213e3ff`）
- **N9E 告警规则手工 UI import**：`ops/n9e-alert-rules.yaml` 已加 4 条（CF-AUDIT-MISMATCH-HIGH/CRITICAL/FIX-FAILURE/MISSED），等 Owner 走 N9E Web UI 「告警规则 → 导入」上线
## 5/21 子 sprint：HSTS 升级 + hstspreload.org 自动化 Plan A1

### 决策时间线
1. Owner 问 HSTS IS/preload/max-age 现状 → 实证 baseline 180d + IS=false + preload=false
2. Owner 拍 B 中间档（180d + IS=true + preload=true）→ Java setHsts 改 + bulk PATCH 154 zones（commit `7b6c220b`，updated=123 already=31 failed=0）
3. Owner 进一步拍**升 max-age 1y + 主动提交 hstspreload.org**（B → C 激进档）
4. 告知 Owner：CF 不自动提交，且 hstspreload.org audit 要求 max-age ≥ 1y。Owner 拍走全自动 A1
5. 实施：
   - `184ca0d9` setHsts max_age 1y + scripts/hstspreload-submit.py + scripts/hstspreload-status.py + bulk PATCH 1y
   - 跑回填：14/14 A/C/active 域全 submit OK（status=pending 审核中）
   - `cc33fc2b` HstsPreloadService.java + DomainLifecycleService.configureWebZone 末尾 A/C 类自动 submitAsync + N9E 2 规则
   - `31c29548` fix Lombok @RequiredArgsConstructor + 实例初始化块顺序 → @PostConstruct
   - `fd63d63e` 补 @Mock HstsPreloadService 修 2 test NPE
6. admin jar `971ea5d320de` active errors=0；`nw_hsts_preload_last_query_epoch_sec` Gauge 已注册

### A1 全自动方案架构
- **Java HstsPreloadService**：3 方法 (checkPreloadable/submit/getStatus) + @Async submitAsync + @Scheduled cron `0 30 3 * * *` daily queryAllStatuses + Micrometer Gauge
- **configureWebZone 末尾**：仅 A/C 类自动 submit（P 类落地不参与 preload list，S 类 grey-cloud 不在 configureWebZone）
- **Flag**：`app.hsts.preload.auto-submit` (default true) 控制 configureWebZone 自动 submit
- **3 Metric**：
  - `nw_hsts_preload_status_total{status}` Gauge — daily 03:30 聚合 count
  - `nw_hsts_preload_submit_total{result}` Counter — submitAsync 累计成功/失败
  - `nw_hsts_preload_last_query_epoch_sec` Gauge — 防 scheduler 挂死告警
- **N9E 2 新告警**：HSTS-PRELOAD-REJECTED (P1, status=rejected) + HSTS-PRELOAD-QUERY-MISSED (P0, scheduler 挂死)

### 关键风险（已 owner 拍）
- **preload list 不可撤**：移除要 6-12 月浏览器版本滚动；每个新 A/C 域 lock-in 1 年 HSTS 倒计时
- **缓解**：rollback 路径仅留 `hsts.preload.auto-submit=false` flag 关闭未来新增；已提交 14 个不可撤需走 hstspreload.org/removal 流程

### 时间线预期
- **5/22 03:30** — 第一次 daily query 跑完，metric 出现 `nw_hsts_preload_status_total{status=pending}=14`
- **5-8 周后** — Chrome / Firefox / Safari 版本滚动收录，status 转 preloaded
- **收录后** — Chrome 用户首访 17.rip / 等 A/C 域**直接 HTTPS**（无需先访问过一次记忆 HSTS state），反 GFW 中间人攻击防御真生效

### 5/21 末尾：N9E ↔ yaml 双向对齐 sub-sub-sprint

Owner 让"检查 N9E 25 条规则是否都导入了" → 发现 N9E 47 条 vs yaml 25 条不对齐（N9E 多 25 条历史 sprint 直接在 UI 加的，yaml 缺 3 条 EASYLIST 未 import）。

**实施**：反向同步 N9E → yaml SOT，最终双向 50 ↔ 50 完全对齐。过程踩 3 个 schema 坑：

1. **N9E v8 alert_rule schema：PromQL 不在顶层 `prom_ql` 字段，在 `rule_config` JSON field 内**
   - DB schema 顶层 `prom_ql` 是 empty string，真 PromQL 藏 `rule_config = {"queries":[{"prom_ql":"..."}]}` 嵌套 JSON
   - 反向同步必 `json.loads(rule_config).queries[0].prom_ql` 提取
2. **JSON unicode escape 自动解码** （`>` → `>`）—— Go json.Marshal default 行为，Python `json.loads()` 解 JSON string 自动 decode unicode escape
3. **N9E import 文件 schema 调试**：
   - **"No number after minus sign in JSON at position 1"** → 文件首字符 `[` 不接，要 envelope `{version, group, rules: [...]}`
   - **"input yaml is empty or invalid"** → yaml 含 `yaml.safe_dump` wrapped plain style PromQL（多行带 2 空格缩进）Go yaml.v3 严格不接，必须 `|` block scalar
   - **"name is blank"** → JSON envelope 含 `inhibit_rules` 段，N9E import 把它当 alert_rule parse 但没 name → fail。剔除即可

**4 commits**：`52537eab` (v3 sync) → `6f2f958a` (envelope) → `e690d6b3` (v4 block scalar) → `88865e10` (删 inhibit) → `93612ce3` (plain array fallback)

**5 RUM dup 清理**：N9E import 不 dedupe by name，re-import 后 RUM_* 5 条 dup id=63-67 → 直接 `DELETE FROM alert_rule WHERE id IN (...)` 清。

### 3 条新教训（已 sink CLAUDE.md）

12. **N9E v8 alert_rule PromQL 不在顶层 `prom_ql` 字段而在 `rule_config` JSON 内** —— 反向同步 N9E DB 必 `json.loads(rule_config).queries[0].prom_ql` 取，顶层 `prom_ql` 字段 always empty
13. **N9E v8 import file schema 调试三连**：
    - JSON 必带 envelope `{version, group, rules: [...]}` 不接 plain array
    - JSON envelope **不可含 `inhibit_rules`**（会被当 alert_rule parse 报 name is blank）
    - yaml PromQL 必 `|` block scalar style（`yaml.safe_dump` 默认 wrapped plain style Go yaml parser 严格不接）
14. **N9E import 不 dedupe by name** —— re-import yaml 含 N9E 已有 rule 时产生 dup，需查 `GROUP BY name HAVING count > 1` 找 dup id 后 `DELETE` 清。建议 import 前 `DELETE FROM alert_rule WHERE name IN (...)` 先清同名 rule 防 dup

### 2 条新教训（已 sink CLAUDE.md）

10. **Lombok `@RequiredArgsConstructor` + final field 初始化顺序**：实例初始化块 `{ ... meterRegistry.gauge(...) }` 在 Lombok 生成构造器注入 field 之前执行 → `meterRegistry` 仍 null compile-time error。规则：访问 final 注入字段必用 **`@PostConstruct`** 方法（在所有 field 注入完成后调），不用实例初始化块
11. **新加 Service 依赖必同步在所有 @InjectMocks tests 补 @Mock**：DomainLifecycleService 加 `final HstsPreloadService` 字段后，所有用 `@InjectMocks` 的 test（DomainLifecycleServiceBranchCoverageTest / MutationKillTest 等）必须同步加 `@Mock HstsPreloadService` 否则注入 null → 调用时 NPE 测试 fail。规则：新加 Service 依赖时 grep `@InjectMocks <ServiceName>` 找所有 test 同步补 @Mock

---

- ~~明日 5/21 03:00 cron 首次跑后验证~~ → ✅ **5/21 03:00 cron 首次实测完美闭环**（commit `bb4a8ab6` 含 DNS audit 上线后首跑）：
  - `[cf-audit] done zones=123 pass=123 mismatch=0 0rtt_off=115 fixed=0 fix_failed=0 dns_total=774 dns_mismatch=0 dns_fixed=0 dns_fix_failed=0 cf_err=0 duration_ms=179915`
  - Zone settings 123/123 全 PASS + DNS records 774/774 全 PASS
  - 0-RTT silent rollback 实证：03:00 跑完几小时内 0rtt_off=115（A 69 + B 12 + C 4 + P 19 + S 11）= 与 5/20 evening 手动实测 ~115 一致，证实 **CF Free plan 大多 zone 0-RTT 几小时被 silent rollback**（与 ssl=flexible 根因调研结论一致）
  - duration **3min** 内完成（123 域 + 774 DNS records GET）
  - 6 metric 全填实数；N9E 6 条 CF-AUDIT-* 规则评估窗口启动后应静默（实测无任何 mismatch / fix failure / missed run 触发）
- **manual trigger endpoint**（可选 follow-up）：加 `/api/v1/internal/ops/cf-audit-now` 便于运维手工触发，绕开 cron 等待

## 引用

- `frontend-web/scripts/obfuscate-sw.js`（5/20 下午加 inline `<script>/<style>` minify + css glob，独立 sprint）
- `frontend-web/index.html`（5/20 下午加 inline JS 强制 https，独立 sprint）
- `docs/PLAYER_HIJACK_RESEARCH/QQ-IOS-SOLUTION.md` §六（5/20 下午 QQ 安全拦截事件）

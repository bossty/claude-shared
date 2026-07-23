---
name: newworld-cf-cache-ops
description: CF 缓存运维三铁律：①验证必用 GET（curl -s -o /dev/null -D -）——HEAD（curl -I）永远返 cf-cache-status DYNAMIC + no age 会误判没缓存（2026-05-22 ad-image-encrypt 浪费 3 个方向教训）；②多 zone wildcard 子域 URL purge 前必做 DNS 预验证、按 zone 分组（V5 5/7 教训）；③CF 默认遵守 origin Cache-Control 会缓存 404——4xx/5xx no-store 防线按域组分工：A/C/P 唯一防线是 nginx map + add_header always（CF 侧 cache rules 已被 syncCacheRules 主动清空，「双层防御」旧表述已过期），B 域 R2 唯一防线是 configureCdnZoneCache 的 status_code_ttl 400-599=-1（2026-05-01 plyr.js 404 sticky 24h 事故）。Triggers on cf-cache-status, DYNAMIC, CF cache verify, 验证 CF 缓存, cache HIT MISS, curl -I, purge, purge_everything, 多 zone purge, wildcard 子域, CF 缓存清理, zone purge 失败, CF 缓存 404, 404 sticky, no-store, Cache-Control map, nw_lib_cache_control, nw_assets_cache_control, add_header always, 双层防御, syncCacheRules, configureCdnZoneCache, status_code_ttl, stale-while-revalidate, version.js 缓存.
---

> **执行机制**：靠判断力（CF 缓存验证必用 GET 等方法论）

# Newworld cf-cache-ops（2026-07-03 由 newworld-cf-cache-verify + newworld-cf-purge-multi-zone 合并而成）

---

> ⬇️ **以下并入自 `newworld-cf-cache-verify`（2026-07-03 skill 合并，原档已删；触发词已并入本 skill description）**


# newworld CF cache 验证铁律

## 核心 lesson（2026-05-22 ad-image-encrypt sprint 实证）

**`curl -I` (HEAD) 永远 DYNAMIC，不代表 CF 没缓存。**

CF 默认对 HEAD 请求不命中 cache（且不存 cache），所以即便 GET 已经在边缘 HIT 4319s，HEAD 还是返 `cf-cache-status: DYNAMIC` + 缺 `age` header。曾误判 CF 配置坏了 → 折腾 Cache Rule / Origin headers / Cache Reserve 三个错方向。

## 正确验证方法

```bash
# ❌ 错的（永远 DYNAMIC，会误判）
curl -sI "https://cdn.example.com/path/file.js" | grep -i cf-cache-status

# ✅ 对的（GET 看真实 cache 状态）
curl -s -o /dev/null -D - "https://cdn.example.com/path/file.js" \
  | grep -iE 'cf-cache-status|^age:'
```

期望输出：
```
cf-cache-status: HIT
age: 4319
```

## 触发场景

任何下面对话 → 立即用 GET 验证，禁用 HEAD：

- "为什么 CF 没缓存"
- "cf-cache-status 是 DYNAMIC"
- "Cache Rule 配了但不命中"
- "明明 cache-control immutable 还是回源"

## 边界

- `purge` 验证 / DNS 存在性验证（见 `newworld-cf-purge-multi-zone` skill）用 HEAD 没问题
- 单纯调 cache 状态必须用 GET
- 浏览器 Network panel 看到的 cf-cache-status 是首次 GET 响应里的，**disk cache replay 时也会复用同 header**，所以浏览器看 HIT 不代表当前服务器 HIT — 强刷 Cmd+Shift+R 才能拿真实当前状态

---

> ⬇️ **以下并入自 `newworld-cf-purge-multi-zone`（2026-07-03 skill 合并，原档已删；触发词已并入本 skill description）**


# CF 多 zone purge 铁律

> V5 反爬铁律 sub-sprint（2026-05-07）真踩坑沉淀。

## 核心铁律

**多 zone 之间 wildcard 子域配置不对称时，URL purge 必须先 DNS 预验证子域存在；否则一律走 `purge_everything` per zone。**

CF API 对"不存在的 URL"返回 `success: true`，但实际什么也没刷。CF API success ≠ 缓存真清。

---

## 2026-05-07 真踩坑案例

### 背景
ad bucket 50 域 stale CT 缓存（image/avif）需要 CF purge —— 上轮 V5 反爬规范改 ContentType 为 `application/javascript`，但 CDN edge 仍 HIT 旧 image/avif。

### 反例（错误做法）
P7 按 `24 hash × 5 zones` 拼接 URL 调 CF `purge_cache` API：

```
https://ux1a.<zoneA>.com/<hash>.gif
https://ux1b.<zoneA>.com/<hash>.gif   <-- 假设 5 zones 都有 ux1a/b/c/d/e
https://ux1c.<zoneA>.com/<hash>.gif
... × 5 zones
```

### 故障现象
- CF API 5/5 zones 全 `success: true`
- 但 Playwright 实测 EWR edge 仍 `cf-cache-status: HIT`，`age: 180076`（50 小时老）
- Owner 50h 后还看到 image/avif stale cache

### 真根因
- DB `ad.image_url` 只存 hash，P7 拼接 URL 时假设每 zone 都有 `ux1a/b/c/d/e` wildcard 子域
- 实际只有 `ux1a` 在 assetlibs.com 上配置，其他 4 zones 这些子域**根本不存在**
- CF 收到不存在 URL 不报错（API spec 不校验子域存在性），返 success 但无任何缓存命中
- 多 zone 之间 wildcard 子域配置不对称 = URL purge 静默失效

### 解决方案
切 B 方案 `purge_everything` per zone（5 zones 各发 1 次），5/5 success，Playwright 复测 `cf-cache-status: MISS` → 彻底解决。

---

## 正确做法

### 选项 A — URL purge 前 DNS 预验证（精确但复杂）
URL purge 前对每个子域先 `dig` 或 HEAD：

```bash
# DNS 预验证
for zone in <zone1> <zone2> ...; do
  for sub in ux1a ux1b ux1c ux1d ux1e; do
    dig +short "${sub}.${zone}" @1.1.1.1 || echo "MISSING: ${sub}.${zone}"
  done
done

# 或 HEAD 真实存在性
curl -I "https://ux1b.${zone}/<hash>.gif"
# 200 / 304 → 存在；404 → 存在但缓存 miss；DNS error → 子域不存在，跳过 purge
```

仅对 dig/HEAD 通过的 URL 发 purge。

### 选项 B — purge_everything per zone（推荐 / sledgehammer 但安全）
多 zone wildcard 子域不对称时，直接走每 zone `purge_everything`：

```bash
# secrets.env 取 CF_TOKEN_S
for zone_id in <zoneA_id> <zoneB_id> ...; do
  curl -X POST "https://api.cloudflare.com/client/v4/zones/${zone_id}/purge_cache" \
    -H "Authorization: Bearer ${CF_TOKEN}" \
    -H "Content-Type: application/json" \
    --data '{"purge_everything":true}'
done
```

**代价**：该 zone 全量缓存清空，下一波请求回源压力短时上升（对 R2 静态资源回源便宜，可接受）。
**收益**：无视子域配置不对称，100% 真清。

---

## CF Pro plan 限制

| 方式 | Free / Pro / Biz | Enterprise |
|---|---|---|
| URL purge | 30 URL/req | 30 URL/req |
| Hostname purge | ❌ | ✅ |
| Tag purge | ❌ | ✅ |
| Prefix purge | ❌ | ✅ |
| `purge_everything` per zone | ✅ | ✅ |

> Newworld 当前 Pro plan，prefix / tag / hostname purge 都不可用。多 zone 大批量精确 purge 唯一选项是 URL purge（受子域对称性约束）或 `purge_everything`。

---

## 决策树

```
要 purge 缓存
├── 单 zone + 少量 URL（<30）+ 子域确定存在
│   └── URL purge ✓
├── 多 zone + wildcard 子域对称（DNS dig 全通过）
│   └── URL purge per zone ✓（注意 30 URL/req 限制，分批）
├── 多 zone + wildcard 子域不对称（或不确定）
│   └── purge_everything per zone ✓（V5 5/7 案例）
└── 跨 zone 大量精确 URL + Enterprise plan
    └── prefix purge ✓
```

---

## 部署 checklist（CF purge 前）

1. **确认 zone 列表**：`secrets.env` 中 CF zone ID 是否齐全
2. **确认子域对称性**：对每 zone 跑 `dig <wildcard_sub>.<zone>` 拿真相
3. **如有不对称**：直接走 `purge_everything` per zone，别浪费时间拼 URL
4. **purge 后必须真验证**：Playwright 或 curl `-I` 复测 `cf-cache-status: MISS / EXPIRED`，**不信 CF API success**
5. **复测节点选远端 edge**：EWR / NRT 别只测 HKG（HKG 离回源近，可能没缓存）

---

> ⬇️ **以下并入自 `docs/CF_CACHE_RULES_2026_05.md`（2026-07-21 BL-111 文档治理：现行知识转入本 skill，原档已删——事故时间线属时点叙事，经 `docs/TOMBSTONES.md` 索引的 git 历史可取回。并入时已按 2026-07-21 代码真值订正：原档「双层防御」表述已过期）**


# 4xx/5xx 禁被 CF 边缘缓存的防线（防「CF 缓存 404 sticky」事故类）

## 反直觉核心事实

**CF 默认会缓存 404。** CF 默认 Cache Level=Standard 遵守 origin 的 Cache-Control——origin 对 4xx 也吐 long-cache（如 `max-age=604800, s-maxage=86400`），CF 边缘就把 404 缓存 s-maxage 那么久。2026-05-01 实事故：部署临时删了 `/lib/plyr.js` → origin 404 + long-cache header → CF 缓存该 404 达 24h → 回滚恢复文件后 origin 已 200，CF 仍 sticky serving 404，播放页全员白屏。

## 现行防线分工（以代码为真值；原档「双层防御纵深」已过期）

| 域组 | 唯一防线 | 实现 |
|------|----------|------|
| A/C/P（用户访问域，经 OpenResty） | **nginx origin 层** | `$nw_*_cache_control` map + `add_header ... always`，4xx/5xx → `no-store`，CF 遵守 origin 即不缓存 |
| B（R2 CDN 资源域，不经 nginx） | **CF ruleset 层** | `CloudflareApiService#configureCdnZoneCache`：respect_origin + `status_code_ttl` 2xx=1yr / 400-599=-1（no-store）+ browser_ttl 7d + Smart Tiered Cache |

- **A/C/P 的 CF 侧 cache rules 已被主动清空**：`CloudflareApiService#syncCacheRules` 现行行为 = 对 zone 的 `http_request_cache_settings` ruleset PUT **空 rules 数组**（保留 ruleset 本身防 id 漂移），完全依赖 origin Cache-Control。2026-05-01 撤销原 P8-Tau catch-all 的原因：CF cache_settings 与 origin 不一致会有不可预测行为 + 曾把 `/api/*` 响应缓存出「响应时间戳无效」事故。测试断言 rules 必须为空数组（`CloudflareApiServiceTest`）。**排查 A/C/P 缓存问题时别去 CF dashboard 找 cache rule——空是正常态；发现非空 rule 才是异常**（可能被人手工加过，评估后清掉对齐 syncCacheRules）。
- 由此 A/C/P 的 4xx no-store 防线是**单层**（仅 nginx），改坏了没有第二层兜底——nginx 侧相关改动必须改后立即验证（见下）。

## nginx origin 层机制（改动时必知）

- 4 个 map 放 `http {}` 块内、`server {}` 块外：`$nw_static_cache_control`（默认 `max-age=604800, s-maxage=86400`）、`$nw_assets_cache_control`（默认 `max-age=31536000, immutable`，hash URL 专用）、`$nw_lib_cache_control`（默认同 static）、`$nw_version_cache_control`（`/version.js` 专用）；四者 `~^4` / `~^5` 分支一律 → `"no-store"`。
- **`add_header Cache-Control $nw_xxx_cache_control always` 的 `always` 是 load-bearing**：不带 always 时 nginx 仅对 200/204/301/302/304 输出 add_header，4xx/5xx 直接不吐 header → 防线归零。改这些行时禁顺手删 always。
- `/version.js` 特例（2026-06-06 firstscreen-edge）：2xx = `max-age=60, stale-while-revalidate=86400`（CF 过期后即时吐 stale + 后台异步 revalidate，用户阻塞 RTT≈0）；**禁把 s-maxage 加回该 map**——CF 官方：s-maxage 与 SWR 同用会 disable SWR。
- **web 与 admin 两份 conf 是同款 map，改一处必同步另一处**：`openresty/web/openresty/nginx/conf/nginx.conf` + `openresty/admin/openresty/nginx/conf/nginx.conf`（历史上正是多份 conf 漂移造成过防线缺口）。改后上线走 `newworld-openresty-deploy`（真 include / reload 后查 [error] / smoke）。
- 已知边界（有意设计勿"修"）：429 也被一刀切 no-store（若将来需要 429 短缓存，在 map 加 `429 "public, max-age=60";`）；301/302 走 map default 分支 long-cache（降回源 QPS，期望行为）。

## 改动后验证（沿用本 skill 铁律①：GET 不是 HEAD）

```bash
# 1) 不存在的 path → 404 + no-store（CF 不得缓存）
curl -s -o /dev/null -D - "https://<A域>/lib/__test_404__.js" | grep -iE '^HTTP|cache-control|cf-cache-status'
#   期望：404 + cache-control: no-store；cf-cache-status 不得出现 HIT
# 2) 真实 200 资源 → long-cache 正常，二次 GET 应 HIT
curl -s -o /dev/null -D - "https://<A域>/lib/<真实文件>.js" | grep -iE '^HTTP|cache-control|cf-cache-status|^age:'
#   期望：200 + public, max-age=...；复测 cf-cache-status: HIT
```

---

## 关联 skill

- `newworld-secrets` — CF token 取值（`secrets.env` 的 `CF_TOKEN_S` / `system_config.CF_TOKEN_S`）
- `newworld-deploy-runbook` — 部署后 CF purge 是否要做的判断点（部署前必查四项，2026-07-23 由 checklist 并入）
- `newworld-thirdparty-api` — CF API 必查官方文档
- `newworld-openresty-deploy` — nginx conf 改动的上线/验证流程

## 关联 docs

- ~~`docs/V5_SPRINT_RETRO.md` §3 T5（5/7 真踩坑详细复盘）~~（原档已随 2026-07-21 BL-111 文档治理删除，经 git 历史取回，索引见 `docs/TOMBSTONES.md`）
- `docs/media/IMG_PROCESSING_STANDARD_v5.md` §11（sentinel + ContentType 反爬规范）
- `docs/infra/CACHE_ARCHITECTURE.md`（多层缓存总图）

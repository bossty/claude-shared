---
name: newworld-cf-purge-multi-zone
description: CF 多 zone purge 铁律（V5 sprint 5/7 教训）
triggers:
  - CF cache purge
  - cloudflare purge_cache
  - 多 zone 缓存
  - URL purge
  - purge_everything
---

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

## 关联 skill

- `newworld-secrets` — CF token 取值（`secrets.env` 的 `CF_TOKEN_S` / `system_config.CF_TOKEN_S`）
- `newworld-deploy-checklist` — 部署后 CF purge 是否要做的判断点
- `newworld-thirdparty-api` — CF API 必查官方文档

## 关联 docs

- `docs/V5_SPRINT_RETRO.md` §3 T5（5/7 真踩坑详细复盘）
- `docs/IMG_PROCESSING_STANDARD_v5.md` §11（sentinel + ContentType 反爬规范）

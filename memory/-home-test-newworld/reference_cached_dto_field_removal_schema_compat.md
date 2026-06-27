---
name: reference_cached_dto_field_removal_schema_compat
description: 删/改被Redis缓存的DTO字段=高风险schema兼容坑;旧缓存JSON带已删字段→新类Jackson FAIL_ON_UNKNOWN反序列化炸;配套清缓存or版本化缓存键
metadata:
  type: reference
---

删/改**被 Redis 缓存的 DTO** 字段是高风险变更——旧缓存里存的是旧 schema 的 JSON，新类反序列化会炸。`newworld-deploy-checklist`「高风险 schema」必须覆盖这条。

## 事故（2026-06-18 snack imageUrl 退役）
退役 `SnackVO.imageUrl` 字段（[[reference_snack_adslot_render_unify]]）后，backend 6 节点滚动部署完，**EU 两台报错风暴**（eu-01 近 30s 仍 436 条、类型 = imageUrl/SnackVO），**广告全炸**（用户报"广告无法显示"）。

**根因**：Redis 缓存键 `web:snack:slot:<slug>`（`@Cacheable(cacheNames="web", key="'snack:slot:'+#slug")`，缓存 `SnackSlotWithSnacksVO`）存着**旧的带 `imageUrl` 的 JSON**；新 SnackVO 类无 imageUrl 字段，Jackson 默认 `FAIL_ON_UNKNOWN_PROPERTIES` →
`SerializationException: Could not read JSON: Unrecognized field "imageUrl" (SnackVO), not marked as ignorable`（错误消息 `not marked as ignorable` = 类没开 ignoreUnknown 的提示）。

**为何只 EU 炸**：CA 先部署，cache-miss 把新格式写回 `.128` master 自愈（err=0）；EU Redis `.184`（replica）还存旧缓存、命中即炸。读写分离：写 master(.128)/读 replica(.184)；DEL .128 会复制到 .184（参 [[project_phase0_redis_geo_deploy_2026_06_04]]）。

**诊断关键 = 看错误类型不只计数**：起初以为是 EU 重启瞬态（CA 零错，命中 [[project_mysql_qps_reduction_2026_06_17]]「EU 重启瞬态≠回归」），但 grep 错误**类型**发现 imageUrl/SnackVO + 近 30s 仍在生成 → 是真回归非瞬态。两条铁律（同 jar CA 是否也错 / 错误是否持续）要配「错误类型分析」一起用。

**止血**：清 `.128` master 的 `web:snack:slot:*` + `web:snack:slotmeta:*`（各 19）→ 复制 EU .184 → curl 触发重建新格式 → EU 0 错、广告恢复。

## 诊断 + 止血操作序列（runbook，可复用）

### 诊断（确认是缓存 schema 兼容炸，非重启瞬态）
```bash
# ① 各节点近 90s ERROR 计数：某区非零 + CA 零 → 先疑重启瞬态（别停在这）
ssh <node> "sudo journalctl -u newworld-web --since '90 sec ago' | grep -cE 'ERROR|Exception'"
# ② 决定性：看错误【类型】不只计数。top 是业务类/字段名(SnackVO/imageUrl) 而非纯 Lettuce STOPPED → 真回归
ssh <node> "sudo journalctl -u newworld-web --since '3 min ago' | grep -oE 'SnackVO|imageUrl|LettuceConnectionFactory|Unrecognized' | sort | uniq -c | sort -rn"
# ③ 近 15s 是否【仍在生成】：持续=真回归 / 归零=瞬态
ssh <node> "sudo journalctl -u newworld-web --since '15 sec ago' | grep -cE 'ERROR|Exception'"
# ④ 拉真实异常消息定根因
ssh <node> "sudo journalctl -u newworld-web --since '2 min ago' | grep -iE 'Unrecognized|InvalidClass|deserial' | head -2"
#   → 'Unrecognized field \"X\" (class Y), not marked as ignorable' = 缓存 schema 兼容炸
```

### 止血（清旧缓存键强制重建新格式）
```bash
# ① 取 Redis 写主 host/pw（⚠️ 禁 < 重定向，shell 先开文件→Permission denied）
ssh <web-node> 'PID=$(pgrep -f "newworld-web.*jar"|head -1);
  RH=$(sudo cat /proc/$PID/environ|tr "\0" "\n"|grep "^REDIS_HOST="|cut -d= -f2-);
  RPW=$(sudo cat /proc/$PID/environ|tr "\0" "\n"|grep "^REDIS_PASSWORD="|cut -d= -f2-);
  RC="redis-cli -h $RH -p 6379 -a $RPW --no-auth-warning";
  # ② SCAN 确认键格式（cacheName "web" → 键前缀 web: 单冒号）
  $RC --scan --pattern "*snack:slot*" | head;
  # ③ DEL 受影响键（写主 .128，自动复制到 replica .184；分批 -n50 防超长）
  $RC --scan --pattern "web:snack:slot:*"     | xargs -r -n50 $RC DEL;
  $RC --scan --pattern "web:snack:slotmeta:*" | xargs -r -n50 $RC DEL;
  # ④ curl 触发重建
  for s in g01 g02 z01 p01 p05; do curl -s -o /dev/null -w "$s=%{http_code} " http://127.0.0.1:7777/api/v1/snack/$s; done'
```

### 验证（全节点无残留）
```bash
# 各 web 节点：snack JSON 无旧字段 + 近 2min 0 错
for h in ca-web-01..04 eu-web-01..02; do ssh $h 'curl -s http://127.0.0.1:7777/api/v1/snack/g01 | grep -c "\"imageUrl\""'; done   # 全 0
# Redis 缓存值无残留旧字段：scan 键逐个 GET grep 旧字段名 = 0
```
> 实证收尾（2026-06-18）：6 节点 snack JSON imageUrl=0、SnackVO 错=0、Redis 15 键含 imageUrl 值=0。

## How to apply（删/改缓存 DTO 字段时）
配套动作三选一（按 Owner anti-silent 偏好排序）：
1. **缓存键带 schema 版本**（推荐，治本无静默）：`web:snack:slot:v2:<slug>`，改字段 bump `v2→v3` → 旧键自然成孤儿不命中（不是反序列化它、是根本不读）→ 保持严格反序列化、零静默、无需手动清。代价=维护版本常量。
2. **部署后清旧缓存键**：DEL `web:snack:slot:*` 等强制重建。保严格但靠记性（这次就是漏了被咬）。
3. **DTO 加 `@JsonIgnoreProperties(ignoreUnknown=true)`**：旧 JSON 多余字段静默跳过。**仅限内部缓存 DTO**（生产方=消费方=同一类，唯一未知字段来源是版本偏移=良性）；**外部输入 DTO（API 请求体/跨服务）禁加**=会掩盖契约漂移/拼错字段增排查难度。**禁全局** `spring.jackson...fail-on-unknown-properties=false`（一刀切所有 DTO 变宽松）。

**pre-deploy 检查**：改任何 DTO 字段，先 grep 它是否被 `@Cacheable`/`redisTemplate` 缓存；是 → 上面配套动作必做，别只想着代码改对。

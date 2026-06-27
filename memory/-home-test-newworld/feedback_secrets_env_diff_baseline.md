---
name: secrets-env-3-diff
description: cutover/RESET 类 sprint 重建 secrets.env 易漏基础设施类 env var，导致下游业务静默降级；改动必 diff 3 个最近 .bak 对账
metadata: 
  node_type: memory
  type: feedback
  originSessionId: e64cccd6-8800-4ac5-ac22-fff43a7b0395
---

# secrets.env 重建漏 env 静默降级 (2026-05-29 实证)

## 事故复盘

- **5/27 cutover sprint** RESET 重建 `/etc/newworld/secrets.env`，**实际漏 11 个 env**（初查只看到 2 个 HLS，cron 入库异常后 `comm -23 bak current` 揪出 9 个：
  - `HLS_FALLBACK_PROXY_HOST=209.141.48.177` + `HLS_FALLBACK_PROXY_PORT=3128`
  - `APP_CRAWLER_JAVXX_ENABLED` `CF_TOKEN_S`
  - `CRAWLER_BEEG_HARD_CAP_PER_RUN` `CRAWLER_JABLE_HARD_CAP_PER_RUN` `CRAWLER_JAVXX_HARD_CAP_PER_RUN` `HANIME_HARD_CAP_PER_RUN` ← cap 全失，default=10 → beeg 实际入 10/h 而非 1/h
  - `FFMPEG_PREVIEW_TIMEOUT_SEC` `FLARESOLVERR_URL` ← hanime1 CF Turnstile 无 FlareSolverr 走不通，failedPages=1
  - `INTERNAL_API_SECRET`
- 业务后果：
  - `HlsDownloadService` 默认 `@Value("${hls.fallback-proxy.host:}")` 拿到空 → 禁用 BuyVM proxy fallback
  - 直连 m3u8 源站，aws-data HK IP 被反爬 403
  - hourly cron 全栈停采 — 24h 仅入库 1 部 (jable 5/28 21:01)，**100+ 部 / day 业务量降到 0**
  - newworld-data service `is-active=active`（systemd 正常），监控不告警

## RCA 真凶链

```
5/27 cutover → secrets.env 重建漏 env →
  HlsDownloadService 接到默认空 String →
  禁用 proxy fallback (静默逻辑分支) →
  直连源站 → CN/HK IP 403 →
  cron 全栈停采 24h+ → owner 5/29 04:00 发现
```

## 修法（fact-driven）

```bash
# 1. fact-check env 是否真在 service process（不能信 systemd active）
ssh aws-data 'PID=$(pgrep -f "newworld-data.*jar"); sudo cat /proc/$PID/environ | tr "\0" "\n" | grep -E "HLS|PROXY|209.141"'

# 2. 与 3 个最近备份 diff 找漏项
ssh aws-data 'for bak in /etc/newworld/secrets.env.bak.*; do
  diff <(sudo cut -d= -f1 /etc/newworld/secrets.env | sort) \
       <(sudo cut -d= -f1 "$bak" | sort) | head
done'

# 3. 补回缺失 env + restart
echo "X=Y" | sudo tee -a /etc/newworld/secrets.env
sudo systemctl restart newworld-data
```

## 铁律 sink

### 1. cutover/RESET 类 sprint 重建 secrets.env 必跟备份对账

```bash
# 重建后立即跑这个对账脚本
for bak in /etc/newworld/secrets.env.bak.*; do
  echo "--- diff vs $bak ---"
  comm -23 <(sudo cut -d= -f1 "$bak" | sort -u) \
           <(sudo cut -d= -f1 /etc/newworld/secrets.env | sort -u)
done
# 输出 = 备份有但当前缺的 env，逐一确认是"真废弃"还是"漏带"
```

### 2. systemd active ≠ env 配置正确

`systemctl is-active = active` 只代表进程在跑，不代表所有 `@Value(${...})` 拿到正确值。`@Value` 默认值兜底（如 `:`)会让漏 env 静默降级为"功能 disabled"。

**verify env 真注入 java 进程**：
```bash
sudo cat /proc/$(pgrep -f your-app.jar)/environ | tr "\0" "\n" | grep -E "YOUR_ENV"
```

### 3. 全栈业务停采类事故，RCA 第一步看 secrets.env diff

- 不要先看 source 代码 / 反爬 / 网络 — 先 fact-check **env 配置完整性**
- newworld 现有 backup `secrets.env.bak.*` 多份（cableav-525 / cutover.* / cutover2.* 等）
- diff 备份是 1 分钟成本，找到漏项是 99% 概率快路径

### 4. 关键基础设施类 env 清单（重建必含）

| 类型 | env 关键字 | 漏会导致 |
|------|-----------|----------|
| DB | `DB_PASSWORD` `DB_HOST` | service 起不来 (Spring 报错明显) |
| Redis | `REDIS_PASSWORD` `REDIS_HOST` | cache 全炸 (明显) |
| Proxy | `HLS_FALLBACK_PROXY_*` `OPENAI_RELAY_*` | **静默降级**（业务停但 service active）← 危险 |
| R2 | `R2_ACCESS_KEY` `R2_SECRET_KEY` | 入库静默失败（log warn 不抛） |
| LLM | `OPENAI_API_KEY` `DEEPL_API_KEYS` | 翻译降级（log warn） |
| 反爬 | `FLARESOLVERR_URL` `INTERNAL_API_SECRET` | 爬虫静默降级 |

**Proxy/LLM/反爬 类是隐性炸弹** — 缺时不报错但功能停，监控必须看业务 KPI（入库率）而非 service 状态。

## 关联

- 与 `[[feedback_env_naming_consistency]]` 同根但不同维度：前者关注**命名同步**（lua/yml/env 三方一致），本文关注**重建对账**（diff 历史备份找漏项）。
- 与 `[[reference_n9e_alert_pipeline]]` 关联：建议加 N9E 业务 KPI 告警 `nw_cron_movie_insert_rate < 5/h` → 30min 触发 telegram，可早 23h 发现本次事故。

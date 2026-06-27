---
name: javxx.com 接入 sprint 5/10-5/11（12 轮 fix）
description: 日韩源 javxx.com 接入；Path B Node 子进程拿 m3u8 + preview 直链派生 + #video-details limited selector + waitForSelector。当前 v12 + 4 buyvm dispatch 500 批量中
type: project
originSessionId: c2b8bb28-32ef-4a45-89f9-5617e29dd913
---
5/10 晚 - 5/11 上午 长 sprint。owner 拍板"日韩源 + 必入无码解放 + 每天 48 条 cron 4:00 HKT"。复杂度极高（12 轮 fix）。

## 已 ship（v12 = current）

| 项 | 状态 | 实现 |
|----|------|------|
| list fetch | ✅ | `fetchHtmlBypassCloudflare(uncensored?page=N)` (CF Turnstile 通过) |
| detail fetch | ✅ | **`fetchHtmlWaitSelector(url, "#video-details", 15s)`** 替代 sleep（race condition fix）|
| 字段抽取 | ✅ | 限定 `Element det = doc.selectFirst("#video-details")` 内：actor `/cn/actresses/` + genres `/cn/genres/{hex}` + maker + series |
| **m3u8 抽取** | ✅ Path B | Java `ProcessBuilder` 调 Node 子进程：`/opt/javxx-m3u8/javxx-m3u8.js {url}` (Playwright Node SDK + autoplay flag + waitUntil networkidle + 15s sleep + BrowserContext.onRequest) |
| preview 直链 | ✅ | cover URL `icdn.javxx.com/img2/{prefix}/{id}/cover.webp` → preview `icdn.javxx.com/preview/{prefix}/{id}/preview.mp4`（实证 4 sample 全 200，prefix=aa/25/b1/64 动态）|
| title actor 末尾 | ✅ | `titleZh + " - " + primaryActor.getName()` |
| actor slug | ✅ | `name.toLowerCase().replaceAll('\\s+','-').replaceAll('[^a-z0-9-]','')` + hashCode fallback |
| mandatoryCat=8 | ✅ | 硬编码 finalize 注入 |
| region | ✅ | `jp`（复用 DB 已 24859 条，无 enum）|

## 12 轮 fix 时间线

| 版本 | 改 | 结果 |
|------|----|------|
| v1 P7 第一轮 | sprint plan + service 实施 | iframe-aware method 实际**没真加**（P7 hallucinate）|
| v2 actor slug fix | `movie_actor.slug NOT NULL` | actor OK，m3u8 fail |
| v3-v6 | NETWORKIDLE + autoplay flag + iframe.play() + 15s sleep（Java Playwright）| 全 100% m3u8 fail |
| v7 | 删 `--disable-blink-features=AutomationControlled` | 仍 fail |
| **v8 = Path B** | Java `ProcessBuilder` 调 Node 子进程 拿 m3u8 | **✅ 100% m3u8 命中** |
| v9 P7 第四轮 | preview 直链 + actor 主演限定（body text split）| 误抽 6 actor 推荐区 |
| v10 | 限定 `#video-details` selector + `/cn/genres/` | 10s sleep race condition |
| v11 | getPageHtml(10s) | actor race 50% |
| **v12** | `waitForSelector("#video-details", 15s)` | **✅ 稳定** |

## 核心 root cause

1. **Java Playwright vs Node Playwright SDK 实质差异**：同 buyvm IP，同 chromium，同 launch flags + waitUntil + sleep，**Node 探针 56 reqs / 2 m3u8 ✓，Java 7 轮 0 拦截 ❌**。原因不明（疑 BrowserContext.onRequest listener 实现 race / context 池复用 listener 失效）。
2. **#video-details SPA 异步注入**：fetchHtmlBypassCloudflare 仅 sleep 1s 不够 SPA 渲染完，DOMCONTENTLOADED 触发太早。waitForSelector 显式等更稳。
3. **preview URL 不在 detail HTML**：只在 list page `<d-tag src="Preview" url="...">` 内；但 4 sample 实证 **cover URL pattern 直接派生 preview URL**（/img2/ → /preview/，cover.webp → preview.mp4），跳过 d-tag 抽取。
4. **`/cn/tags/` ≠ `/cn/genres/`**：P7 第一轮抓错 selector，detail page 真 anchor 是 `a[href*=/cn/genres/{hex}]`。

## 12 轮教训沉淀

1. **P7 hallucinate 多次报谎**："已加 method/flag/改 X" 但 grep 实证 file 没改。教训：**每次 P7 后必须 grep verify 关键代码真在**（不能只看 jar size）。
2. **`kill -9` ≠ stop service**：systemd `Restart=always` 自动重起。必须 `systemctl stop` + `reset-failed`。本次踩坑 2 次。
3. **build SUCCESS ≠ 代码改对**：v7 多次 BUILD SUCCESS 但 method 内部没真生效（autoplay flag 在 LAUNCH_ARGS 没真加）。
4. **30 min wakeup 反馈链路太长**：改 7-10 min 短测 + 单 host。多轮 30min wakeup 浪费 1h+。
5. **同 IP 不同 SDK 行为不同**：Node Playwright vs Java Playwright，先用探针实证基础是否通，再决定方案。
6. **chrome MCP 看真 DOM 是决定性的**：owner 揭"`#video-details`" 关键 insight 后 P0 全清。靠 body text regex split 实际抓不到主区域。
7. **多 sample 实证 prefix 规律**：preview URL prefix 单 sample (`aa`) 不可推全，实证 4 sample (aa/25/b1/64 动态)。
8. **systemd Restart=always 教训**：本次清 Redis 锁 + 删 SQL 草稿 + kill java 多次循环，因为 systemd auto-restart 让 java 又起跑又入草稿。必须 stop service 才真停。
9. **每次 deploy 前先 grep verify file 真状态**：linter / hook 可能 silent 改文件。

## 当前 5/11 12:00 状态（4 buyvm dispatch 500 批量中）

- 4 buyvm：v12 jar (294,552,524) + `/opt/javxx-m3u8/` (Node Playwright)
- secrets.env: `APP_CRAWLER_JAVXX_ENABLED=true` + `CRAWLER_JAVXX_HARD_CAP_PER_RUN=125`
- dispatch p1-40 拆 4 段（data 1-10 / web-01 11-20 / web-02 21-30 / db 31-40）
- ScheduleWakeup 12:44 fire 看完整进度
- aws-data 跑 cron `0 0,30 * * * *` HKT（48 条/天生产）

## 配套修复

- **BeegCrawlerService title actor 位置 fix**：`titleZh + " - " + actor`（与 javxx 一致），mvn build 09:24 jar ✓ 待 aws-data deploy
- **`movie_actor.slug NOT NULL` actor INSERT fix**：仿 Beeg / Hanime pattern
- **Redis lock cleanup**：`crawler:lock:javxx:*` 用 `redis-cli --scan --pattern ... | xargs DEL`（aws-db 上跑，REDISCLI_AUTH ENV 传密码）

## 待办（dust）

1. **aws-data deploy v12+ beeg title fix**（cron 4:00 HKT 4 buyvm 集中 + aws-data 待 deploy）
2. **ffmpeg `-allowed_extensions ALL`**：preview 直链已工作，fallback ffmpeg 仍 fail（dust 不阻塞）
3. **`/cn/tags/` 全页抓的 BeegCrawlerService dust**（P7 v9 标记，下个 sprint 修）
4. **movie_number 大小写**: `javxx-{id.toLowerCase()}` vs 真"代码:" 大小写不一致
5. **detail page 慢**（fetchHtmlWaitSelector 15s + m3u8 intercept Node 子进程 30-60s + HLS 60s + ffmpeg ~30s）≈ 单条 2-3 min；4 buyvm 并发 500 ≈ 60-90 min

## 关键代码位置

- `JavxxCrawlerService.java:285` detail fetch `fetchHtmlWaitSelector`
- `JavxxCrawlerService.java:417` preview 直链 + R2 upload
- `JavxxCrawlerService.java:625` parseDetail 用 #video-details limited selector
- `JavxxCrawlerService.java:780` Node 子进程调 `/opt/javxx-m3u8/javxx-m3u8.js`
- `PlaywrightUtil.java:366` `fetchHtmlWaitSelector` 新加 method
- `/home/test/newworld/newworld-data/src/main/resources/scripts/javxx-m3u8.js` Node script

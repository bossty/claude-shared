---
name: P9 5/10 sprint：hanime1 0-tag 三层 fix + beeg 接入 + tmp cleanup 根因
description: 5/10 周日凌晨 P9 sprint：诊断 hanime1 6 channel 0 tag/cat（OPENAI relay 阻断 + source_tag_mapping 缺 + mandatory 缺）+ beeg HLS 全 fail 根因（host + protocol-relative + tmp cleanup bug）。今晚 ship + 明天 dust。
type: project
originSessionId: c2b8bb28-32ef-4a45-89f9-5617e29dd913
---
5/9 23:55 - 5/10 12:00 长 sprint。owner 反复"先想清楚再做，不要返工"教练 P9 节奏。

## 真根因发现链（按发生顺序）

### 1. hanime1 6 channel 0 tag/cat（5/9 21:47-23:30 入库）
- chrome MCP 实证 P7 selector OK（命中 9 真 tag）
- `source_tag_mapping` 表里**没有 hanime1_xxx**（仅 hqporner/jable/avjiali/hanime/beeg 等 12 source）→ `preMapSourceTags` 返 emptySet
- `LlmContentAnalysisService.java:216` endpoint 优先 `System.getenv("OPENAI_ENDPOINT")` → 否则 system_config → 否则 default
- `system_config.OPENAI_ENDPOINT = https://209.141.48.177/v1/chat/completions`（buyvm-data nginx relay）
- buyvm-web-01/02/db 调 buyvm-data:443 防火墙阻塞 → 30s timeout × 5 retry → ca=null
- LLM fail + seed 空 + mandatory 空 → 0 cat 0 tag

### 2. 三层 fix（hanime1）
- **方案 2**：4 台 buyvm `/etc/newworld/secrets.env` 加 `OPENAI_ENDPOINT=https://api.openai.com/v1/chat/completions` 直连（buyvm 在 luxembourg/US，不被 GFW）
  - aws-data 不动（HK 区被封必须 relay）
  - 实证：4 台 `/proc/<pid>/environ` 真传 ENV，post-restart `OpenAI API 超时` count = 0
- **mandatoryCategoryNames**：UPDATE 8 hanime1 channel `xvideos_channel_config.mandatory_category_names`
  - libang/paomian/motion (anime) → "动漫里番"(id=16)
  - 25d/2d/3dcg/aigen/mmd (3d) → "3D动画"(id=17)
  - **关键**：`XvideosChannelConfigService.parseCsv` 用逗号 split + `ConcurrentHashMap` lazy load → **jar 重启清 cache 后 lazy-load 新值才生效**
- **raw fallback**：`AbstractXvideosChannelCrawler.finalizeMovieWithDispatch` 加第 4 参 `List<String> rawSourceTagsForFallback`，加 opencc4j 1.7.0 dep
  - meta.tagSlugs（繁体）→ `ZhConverterUtil.toSimple()` 简体 → `movieTagMapper.findByName(simple)` 命中才入（不自动建新 tag 防污染）
  - 守卫 `if (mergedTagIds.isEmpty() && rawSourceTagsForFallback != null)`
- 实证：25d 361 条 + 2d 311 条满血 avg_tag 5.10/5.27 / avg_cat 2.01/1.97 / cat_id=17 100% 注入

### 3. beeg 接入 4 重 fix
BeegCrawlerService（5/8 已存在 1347 行 + BeegCrawlerController 5/4）+ 5/10 P7 加 BeegScheduledCrawlTask cron 4:00 HKT。
- **HLS_BASE host bug**: `https://video.beeg.com/` 5/10 全局 403（CDN 路由变更/buyvm IP 封）→ 改 `https://video.externulls.com/`（dispatcher，302→ahcdn.com 200）
- **master parse protocol-relative bug**: master m3u8 内 variant URL 是 `//ipXXX.ahcdn.com/...` 协议相对，原 code `line.startsWith("/") ? line.substring(1) : line` 处理错 → 拼出 `https://video.externulls.com//ipXXX...` 双 slash 404。fix：`if line.startsWith("//") → "https:" + line; else if line.startsWith("/") → line.substring(1); else → line`
- **caller 拼接**: 3 处 `String m3u8Url = HLS_BASE + qp.url` → 加 `qp.url.startsWith("http") ? qp.url : (HLS_BASE + qp.url)` 守卫
- **mandatoryCat=8 + mandatoryTag=598**：BeegCrawlerService.finalize 不继承 abstract，独立加硬编码注入（"无码解放" cat / "欧美" tag）
- **raw fallback**：BeegCrawlerService.finalize 加同 hanime1 模式 raw fallback（meta.tagSlugs → opencc → findByName）

### 4. /tmp cleanup 根因（owner 直觉揭真相）
buyvm-data /tmp **51 GB**（79G 盘 97% 满），主因 `/tmp/hanime1-mp4-{movieId}-{rand}/` 累积（每条几百 MB-2.6 GB）。

**`AbstractXvideosChannelCrawler.java:1815` 真 bug**：
```java
return ... success ...;        // ← success 路径不清理 tmpRoot！
} catch (Exception e) {
    if (tmpRoot != null) deleteDirQuiet(tmpRoot);  // 仅 catch 块清理
}
```
注释错认 "/tmp 是 tmpfs OS 自动回收"——实际 `/dev/vda1` 持久盘。

**Avjiali 是金标 cleanup**（`AvjialiCrawlerService.java:1223 finally { deleteDirQuiet(tmpRoot); }`）。owner 记忆"jable 已做"实指 Avjiali（jable 主 service 不存在，只有 JableCategoryCrawler/RecommendationCrawler）。

fix：abstract 改 `} finally { if (tmpRoot != null) deleteDirQuiet(tmpRoot); }` + 4 台 cron `/etc/cron.d/newworld-tmp-cleanup` 每小时清 1h+ 老 hanime1-mp4-/beeg-/avjiali-。

### 5. disk full 致 jar deploy 损坏（侧根因）
buyvm-data /tmp 100% → scp 失败 → cp 拷贝 264MB 不完整 jar → systemd Auto-restart loop `Invalid or corrupt jarfile`。Lesson: deploy 前 `df -h` 预 check + scp 后 verify size 等于 local。

## 4 台 buyvm 部署状态（11:46 cleanup-fix jar）

| host | 跑 channel | disk | OPENAI ENV | 状态 |
|------|-----------|------|-----------|------|
| buyvm-data | beeg + 历史 paomian/motion | 30% | api.openai.com 直连 | ✅ |
| buyvm-web-01 | hanime1_25d/2d 重 dispatch + redispatch（17 NULL backfill） | 10% | 同上 | ✅ |
| buyvm-web-02 | hanime1_aigen | 6% | 同上 | ✅ |
| buyvm-db | hanime1_mmd | 9% | 同上 | ✅ |

## 关键 schema/数据点

- movie_category id=8 "无码解放" / id=16 "动漫里番" / id=17 "3D动画"
- movie_tag id=598 "欧美"
- xvideos_channel_config 表的 mandatory_category_names = varchar(512) **逗号分隔**
- BeegScheduledCrawlTask cron `0 0 4 * * *` HKT (avoid 03:00 hanime1 撞)
- secrets.env 加 `APP_CRAWLER_BEEG_ENABLED=true` + `CRAWLER_BEEG_HARD_CAP_PER_RUN=20`

## ⚠️ 未闭环 dust（明天 sprint）

1. **beeg HLS 偶发 fail（50%）**：URL/host fix 已对，剩可能 token race / ahcdn 限流 / segment fail；查具体 stack 看 m3u8 vs ts fail
2. **hanime1 paomian/motion/aigen/mmd 4 channel 0 入库**：journal 显示 dispatch done + 1410+ keyword，但 movie 表 0 留。可能合理 < 5min skip 或 cleanup → DELETE 链路。需追查
3. **hanime1_2d 重现 1 NULL preview**：17 删+重爬后 buyvm-web-01 又出 1 条 NULL，buyvm-web-01 disk 10% 不紧张，root 待查（ffmpeg 偶发？hanime1.me 特殊编码？）
4. **deploys/ 老 jar 累积**：buyvm-data 4/20-23:59 一个 286MB jar 还在 + 5/10 多个新 jar，应加 deploy script 保留 N=3 + 自动删旧
5. **scp 健壮性**：deploy 前 `df -h` 预 check + scp 后 size verify + restart 前 `unzip -l current.jar` 验完整性

## 教训沉淀（写入 newworld-deploy-* skill 候选）

1. **/tmp 是真盘（/dev/vda1），不是 tmpfs**——爬虫所有临时文件必须显式 finally cleanup
2. **success path 必须有 finally cleanup**——catch 块只覆盖异常路径
3. **scp 大 jar 前 verify disk 空间** + scp 后 verify size 等于 local
4. **BeegCrawlerService 独立 service 不继承 abstract**——hardcode mandatory cat=8 / tag=598 + 自实现 raw fallback；不要假设跨 service 共享 finalize
5. **chrome MCP 测 200 OK 的 URL，buyvm 跑也可能 fail**（CDN session token / IP 限流）；浏览器有 cookie + signed redirect，curl 没有
6. **owner 业务直觉抽样揭实施盲区**：今晚至少 3 次靠 owner 质问发现盲点（"无预览视频部分出现" / "爬虫临时文件没清" / "jable 已做"指 Avjiali）

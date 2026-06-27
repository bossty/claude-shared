---
name: 2026-04-17 preview 抽帧整治（进行中，用 tmux 恢复）
description: 当日架构改造 sprint 中途暂停清场；下次进 session 按状态图恢复
type: project
originSessionId: f4505e91-c990-4d2b-9f8a-0e74e2ca4ce8
---
# 2026-04-17 清场节点（tmux 恢复用）

## 当前已达成（已提交 master）

- ✅ preview 两阶段 ffmpeg 修复（commit b5f32e / P7-FfmpegPreviewEmpty），5 台部署
- ✅ data BuyVM 装 ffmpeg 5.1.8
- ✅ R2UploadService `@PostConstruct verifyFfmpeg`（fail-fast）
- ✅ CoverUploadResult 契约（12 处 crawler 使用，thumb 失败降级 cover）
- ✅ 5 CDN zone 加 status_code_ttl：2xx=1yr / 4xx-5xx=-1（no-store）— 防 CF 缓存 404
- ✅ `configureCdnZoneCache` 代码同步（新购 CDN 域自动同款 rule）
- ✅ MovieCacheRefreshListener 补清 8 类 key + MetadataCacheRefreshListener 加 actor
- ✅ DB `OPENAI_ENDPOINT` = `https://api.openai.com/v1/chat/completions`（aws-data LLM 恢复）
- ✅ system_config `P_INT=180000`（前端 3min 轮询）
- ✅ admin /api/v1/admin/batch-observability 面板
- ✅ admin MovieList preview dialog `<video muted loop playsinline>` + explicit play()
- ✅ porcore 16 条 thumb backfill（drift=0）
- ✅ 修一次 unknown 4 条 → jable

## 清场时数据快照（aws-db）

```
jable         24292 (存量)
hanime        262   (今日 bulk 恢复采)
pornhub       246
xvgay         206
xvtrans       200
porcore       20
7mm-amateur   18
总日增 ~650 部
```

## 未完成任务（tmux 恢复后重开）

### 任务 A — 架构改造：ffmpeg 从本地明文 ts 抽帧（P7-LocalFramePreview 中断）
- **Why**：当前 FfmpegPreviewService 读源站 m3u8 二次下载，user 想改成读本地已下的明文 ts
- **要改**：
  1. FfmpegPreviewService 加 `buildFromLocalTs(List<String> paths, int movieId, double durationSec)`
  2. 4 crawler (Hanime/XvGay/XvTrans/Porcore) 调用点改用本地 ts 列表（VideoDownloadService.VideoDownloadResult.segments()[].localPath）
  3. 保留 `buildAndUpload(m3u8Url, id, referer)` 不动（backfill 仍用）
- **时序**：HLS 下载完 → 本地 ts 还在 → 抽帧 → 上传 → 清理本地
- **部署**：aws-data + 4 BuyVM

### 任务 B — Backfill 538 部历史 preview（P7-Backfill 中断）
- **Why**：2026-04-17 14:21 前的 hanime/xvgay/xvtrans/porcore 都是 dup-frame 假抽帧版本
- **怎么做**：新加 endpoint 读 DB → 对每部构造 R2 m3u8 URL（`https://yx4v.assetlibs.com/f0583267be0c0ceeb69f3f3ecd9684fc/playlist_{id}.m3u8` + Referer 17.rip）→ 调 buildAndUpload → 覆盖 R2 preview
- **已实测**：R2 m3u8 + AES key + 相对 ts path ffmpeg 全链路工作（f001-f004.jpg 真帧）
- **关键陷阱**：**每次覆盖 R2 必须 CF purge 5 zone**（CF edge 会 sticky 老 11376B 版本 —— 55584 案例实证）
- **预计**：538 部 × 60s/部 并发 3 = 3h

### 任务 C — bulk 恢复采集（已手动停在清场时）
- 目标：hanime/pornhub 2000，xvgay/xvtrans 1000，porcore 2000
- 脚本：4 BuyVM 上 `/tmp/bulk_simple.sh` + `/tmp/bulk_xvxx.sh` 还在
- 启动命令（A 架构改造完后）：
  ```
  ssh web-01 "nohup bash /tmp/bulk_simple.sh hanime 2000 6 120 > /tmp/bulk_hanime.nohup 2>&1 &"
  ssh db    "nohup bash /tmp/bulk_simple.sh pornhub 2000 4 100 > /tmp/bulk_pornhub.nohup 2>&1 &"
  ssh data  "nohup bash /tmp/bulk_simple.sh porcore 2000 6 100 > /tmp/bulk_porcore.nohup 2>&1 &"
  ssh web-02 "nohup bash /tmp/bulk_xvxx.sh xvgay 1000 ... &"
  ssh web-02 "nohup bash /tmp/bulk_xvxx.sh xvtrans 1000 ... &"
  ```

## 恢复顺序（推荐）

1. tmux attach → `claude --resume`（恢复 context）
2. 派 P7-LocalFramePreview 重做任务 A（1.5h）
3. PASS 后恢复 bulk（任务 C）
4. 并行派 P7-Backfill 重做任务 B（3h，加 CF purge 逻辑）
5. 总计 ~15h 达 2000/源

## 技术债（延后处理）

- 4 BuyVM `/etc/hosts` 缺 hostname → sudo warnings
- `__region_trans__` 合成 tag 死代码
- data 模块 test-compile 历史债（-Dmaven.test.skip=true）
- 7mm 403 反爬已通过 Playwright fetchHtmlBypassCloudflare 绕过（commit）但尚未大规模回归
- N_POOL 前端域 A/C/P 账户尚未加 status_code_ttl（可选优化）

## CF 缓存 sticky 关键认知（必记）

**CF edge 会缓存 200 响应 1 年**（我们 cache rule 设计）。
- R2 对象覆盖后 CDN 仍 serve 旧内容（直到 purge 或 TTL 到）
- 所以 crawler / backfill **每次 R2 写入后**必须 call CF purge API（5 zone）
- token: `CF_API_TOKEN_B`（system_config 有）
- 5 zones: b5fa48c..., 2c5632d..., 7dc5167..., 9908f83..., 3bd96c1...

## 已确认的事实

- 新采集 ffmpeg 两阶段走 source m3u8 也能抽真帧（56368 证明 YAVG 1.0-215.3）
- R2 m3u8 + AES-128 key ffmpeg 全链路支持（实测 55516 4 张 JPG 不同大小）
- 本地 ts 是**明文**（HlsDownloadService.processEncryption 已解密源站加密后存 local）

---

## 2026-04-18 UPDATE — Montage 方案替代抽帧（待执行）

### 用户判定

抽帧方案（fps=32/D + 4fps 8s 输出）**视觉是幻灯片不是流畅视频**（帧间隔 D/32 秒太大）。
改为业界标准 **B 方案 3 段 montage**：从视频 20% 截 2s + 50% 截 3s + 75% 截 2s → concat 7s 连续片段。

### Phase 1（当前）

P7-MontagePreview agent 做 1 部 hanime 样品 → 上传临时 test path → user 亲验。

### Phase 2（user PASS 后触发）— 一个不漏

| 源 | 当前部数 | 重做 |
|---|---|---|
| hanime | 2113 | ✅ 全量 |
| xvgay | 1025 | ✅ 全量 |
| xvtrans | 468 | ✅ 全量 |
| porcore | 20 | ✅ 全量 |
| jable / 7mm / pornhub | 26363 | ❌ 源站 native，不改 |

**合计 3626 部需重做**。判定 SQL：
```sql
SELECT id, source FROM movie 
WHERE source IN ('hanime','xvgay','xvtrans','porcore') 
  AND preview_video IS NOT NULL AND status=1;
```

执行：
1. 改 FfmpegPreviewService 加 buildMontagePreview 方法
2. 改 4 crawler 调用点（替 buildAndUpload / buildFromLocalTs）
3. 部署 5 台（aws-data + 4 BuyVM）
4. 复用 P7-Backfill v2 框架（tmux + state.json + CF purge 每批 20 个）
5. 并发 2-3，预计 **20h 全跑完**

### 约束（延续）

- aws-data 禁触发 crawler endpoint
- 每次覆盖 R2 立即 CF purge 5 zone（WS3P 域）
- 不改 jable / 7mm / pornhub 代码
- 批量跑期间 4 BuyVM bulk 不恢复（已停）

### 不漏的保证

批量跑完**再扫一遍 DB**：source IN (4源) AND preview_video IS NOT NULL 每条都应是 montage 版。最好加一个 preview_method 字段区分 'montage' / 'extract' / 'native' 方便审计。

### 用户原话（2026-04-18）

> 老方案制作的要重制，安排进测试完毕之后的计划， 别忘了

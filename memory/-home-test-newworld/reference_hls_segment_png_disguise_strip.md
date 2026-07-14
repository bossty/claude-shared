---
name: reference_hls_segment_png_disguise_strip
description: HLS 段内嵌 PNG 伪装前缀剥除——定位必须走 PNG chunk 结构到 IEND 后再扫 TS 周期同步，纯 offset-0 周期扫描会被「真起点−188」同相位诱饵 0x47 误命中少剥 188B
metadata:
  type: reference
---

# 段内嵌 PNG 伪装前缀剥除（BL-58）

**场景**：supjav 等源的 HLS 段明文 = `PNG 头 + 0xFF 填充 + 真 MPEG-TS`。我方 `HlsDownloadService`
入库时 AES 解密后**原样重加密上传**、未剥前缀 → 播放器解密后仍带前缀。hls.js TSDemuxer 容忍小前缀
（1×1 stub PNG ~95B，扫过找到 0x47）、**不容忍大前缀**（500×500 真封面 806B + 135B 填充 = 941B，
扫描窗口越界）→ `bufferAppended=0` 零帧不可播。判据=段 PNG 前缀尺寸（18 部穷举 5 坏全 500×500 /
13 好全 1×1，5/5 相关）。修=入库重加密前剥前缀使明文首字节即 0x47，任意前缀尺寸行为统一。

## 核心坑：定位 TS 起点不能从 offset 0 纯周期扫描（审代码红绿证出的真缺陷）

初版实现「从 offset 0 找首个连续 4×188 周期均为 0x47 的偏移」**有系统性误判**：
- 「真 TS 起点 −188」这个位置的后 3 个 188 周期探针，正好落在真 TS 的同步字节上；只要该位置本身
  碰巧是 0x47 即整体命中 → 少剥 188 字节、头部残留一个垃圾包、仍不可播。
- PNG 的 IDAT 是压缩数据、字节近似均匀 → 该位置是 0x47 的概率约 **1/256/段**；一部片近千段 → **几乎
  必然有若干段被误判**。伪起点与真流**同相位**，**加大探针包数也排除不掉**。
- 脚本复现：941B 前缀 + IDAT 内种一个「真起点−188」的 0x47 → 纯周期扫描判 753（少剥 188），
  正确应判 941。

**正解**：按 PNG chunk 结构（`4B 大端长度 + 4B 类型 + 数据 + 4B CRC` 逐块前进，**不是**搜 `IEND`
字面量——IDAT 压缩数据可能撞出同样 4 字节）走到 IEND chunk 结束偏移，从那里起扫周期同步。观测填充仅
135B（< 188，两样本一致）→ 唯一的同相位诱饵偏移必落在 PNG 内部，锚定 IEND 结尾即**确定性排除**；
填充区（实测 0xFF 为主、不含 0x47）内误命中需连撞 4 个 0x47（~1e-8）可忽略。

**fail-safe 方向**：无 PNG 签名（干净 TS / 他源 / 他型伪装）、chunk 结构走不通、填充区无周期同步
→ 一律原样返回不截断不抛异常（宁可维持现状不可播，也不静默损坏原本可播的段）。对非 supjav 源零影响。

代码：`HlsDownloadService.stripDisguisePrefix` + `pngStructureEnd`（`newworld-data`）。

## 存量返工手法（R2 原地 backfill，不重爬源站）

段重加密用**全局固定 key**（`VideoConstants.HLS_ENCRYPTION_KEY`）+ **段序号派生 IV**
（`generateIV(null, index)`，index=m3u8 列表顺序）→ 可直接读 R2 现存段解密-剥-重加密，不必碰源站。
- `HlsDownloadService.restripEncryptedSegment(encrypted, segmentIndex)`：解密→剥→重加密，无前缀返
  null（幂等信号）。**segmentIndex 必须取 m3u8 真实顺序**，否则 IV 错位解密得垃圾。
- `R2UploadService.restripMovieSegments(movieId)`：读 `playlist_<movieId>.m3u8` 保序解析
  (EXTINF,段名) → 逐段 restrip → 剥掉的以**新混淆名**（`sha256(movieId_i_nanoTime).ts`）putObject
  → 重写 m3u8（EXTINF 保留）。**新段名 = 新 URL 天然绕开 CF immutable 边缘 stale**
  （见 [[reference_cf_immutable_stale_id_reuse]]），只需 purge 5 个 m3u8 URL。
- **不删旧段**（切换前可回退、切换后变孤儿交 BL-54）；**幂等**（重跑干净段全返 null、m3u8 不变）。
- 入口 `POST /crawler/supjav/restrip-segments?movieIds=A,B`（≤50，受 supjav gate）。

## 为何一直潜伏

BL-51 金标「118238 真出片 16/16 封面 PASS」只验封面+preview（preview 从规整后 clean.ts 生成、
能播），**从未验正片 HLS 真实播放** → 见 [[feedback_goldset_must_play_real_video]]。

## 终态（2026-07-13 收口）

- **入库修复已合 master `add9cb61d`**（防未来 supjav 新采片再出此问题），backfill 能力(`restripMovieSegments`)保留。
- **存量 5 部坏片(118488/485/277/489/500)Owner 拍板物理删除**（`DELETE /api/v1/course/{id}` 级联 DB+R2），非 backfill。
- **backfill 其实技术成功**（R2 真值+CF 各域规范 URL 传播后均新段可播）——但 Owner 选删除更干净。
- **防复活**：Owner 停用 supjav 定时采集（ca-admin `data.env APP_CRAWLER_SUPJAV_ENABLED=false`+重启；供参考=supjav 去重键 movie_number，物理删后不停采会被重新入库）。

## 本会话运维教训（跨场景可复用）

1. **CF purge 是异步的**：purge API 返 success 后边缘 PoP 需**几分钟**才真失效，purge 完**立刻验证会拿到旧缓存**（本会话 agent 首次复验 5 部全假 FAIL 的根因，白跑一轮诊断）。验证前等几分钟，或判据用「规范 URL 段名 == cache-buster(`?cb=`) 段名」而非 cf-cache-status。
2. **m3u8 实际 CF TTL=604800(7天)**，非代码 `CACHE_CTRL_M3U8_5M=300`（CF Cache Rule override origin，见 HTML 壳 sprint）；**改 R2 上 m3u8 内容后必须 purge**，否则旧 m3u8 存活 7 天、指向旧段。段是 1 年 immutable，换新段名才能绕（见 [[reference_cf_immutable_stale_id_reuse]]）。
3. **data 服务(9999)对不存在路由也返 200**（有 catch-all，类似 admin Spring Security）；判 bean 是否装配看 `actuator/beans` 或启动日志(该 bean 有无初始化日志)，**不能看 HTTP 状态码**。
4. purge 全量脚本：5 部 × 50 个 R_VID 域(5 品牌 zone×10 子域)=250 URL，按 zone 分批(CF ≤30/请求)，`nw-cf B POST /zones/<zid>/purge_cache '{"files":[...]}'`。

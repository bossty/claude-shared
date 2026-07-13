---
name: reference_thumbnail_grid_seek_remux_mp4
description: 长视频抽等距帧(缩略图网格/contact sheet/预览montage)必先remux成MP4再keyframe seek——对concat demuxer/裸TS做-ss是顺序解码到N秒(非关键帧跳转)、长片靠后帧慢到超时
metadata:
  type: reference
---

**抽等距帧的 seek 陷阱（2026-07-12 supjav ContactSheet 实证，绕了 3 次弯才定位）**：对 **concat demuxer（`-f concat -i filelist`）或裸 MPEG-TS** 做 `-ss <t>`（放 -i 前的 input-seek）**不是关键帧跳转，是"顺序解码到第 N 秒"**。短片无感，**4000s 长片靠后的 seek（如 t=3720s）慢到超 90s 被 kill** → 退化封面（4核 ca-admin 实测 16 帧只成 4~11 张）。

**根治=先 remux 成真 MP4 容器再 seek**（业界标准，`ffmpegthumbnailer`/`vcsi`/`mtn` 内部同款）：
1. 阶段0：`ffmpeg -f concat -i filelist -c copy -movflags +faststart temp_full.mp4`（零重编码、纯顺序 I/O，510MB 几十秒）。
2. 阶段1：对 `temp_full.mp4` 做 N 次 `-ss -i`——MP4 有 moov 关键帧索引 → **O(log n) 亚秒 seek**，不管视频多长。

**实证效果**：ContactSheet 改 remux 后 ca-admin 封面 4/11→**16/16**、峰值 load 17→**0.96**、秒级完成。本项目 `FfmpegPreviewService.extractMontage8x1sFromLocalTs` 早有此 fix（注释写明「temp_full.mp4 是真 MP4，-ss 是 keyframe seek，不管多长 O(log n)」），ContactSheetService 补齐（commit 见 supjav 分支 merge `573a3c43f`）。

**另一条路（不推荐长片）**：单趟 `-vf "select='not(mod(n,K))',tile=4x4"`——零 seek 但要**整片解码一遍**（4000s 解 ~10 万帧留 16），长片更慢更费 CPU。短片才用。

**配套诊断铁律**：媒体时长必 **ffprobe 真实产物**（`-show_entries format=duration`），别信 m3u8 段 EXTINF（伪装源常灌水，supjav 802段和=4000s；也别拿部分测试 fixture 的时长外推——本会话正因把 50 段 fixture 的 250s 误当全片，先修错了 dur 无效 no-op 才发现真时长是 4000s）。相关：[[reference_crawler_dryrun_id_collision_mock_llm]]。小核生产盒(4核 ca-admin)上并发跑 ffmpeg 还需限并发到核数(防超订抖死)+注意其他 @Scheduled 采集抢 CPU。

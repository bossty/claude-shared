---
name: feedback_goldset_must_play_real_video
description: 视频源接入金标验证必须真点正片播放,不能只验封面+preview——否则正片不可播缺陷会潜伏
metadata:
  type: feedback
---

视频源（supjav/javxx/beeg…）接入的「金标出片验证」**必须包含正片在真实浏览器的实际播放**（hls.js 真解码出画面：`video.videoWidth>0` + `buffered` 增长 + `currentTime` 前进），不能只验封面网格 + preview 预览片就宣告 PASS。

**Why**：BL-51 supjav 生产启用金标记「118238 真出片 16/16 封面 + preview h264 PASS」，但 preview 是从 ffmpeg 规整后的 clean.ts 生成、能播，**正片 HLS 段从未真点播放**。结果 supjav 正片播放缺陷（部分片段带 500×500 PNG 前缀超出 hls.js demuxer 容忍→零帧，见 BL-58）潜伏到 2026-07-13 Owner 真点最新片才暴露，全 18 部里 5 部不可播。封面/preview 走的是「本地明文 ts→规整→抽帧/转码」链路，正片走的是「源站加密段→原样重加密上传→播放器解密 demux」链路，**两条链路的失败模式完全不同**：封面 PASS 完全不能代表正片可播。

**How to apply**：
- 金标 SOP 加一条硬哨兵：真出片后用真实浏览器（agent-browser + E2E cookie `__e2e=7rip` 旁路探针门，前台 /lessons/:id）**真点正片播放**，等 6-8s 断言 `videoWidth>0` 且 `buffered` 有增长。零帧（vw0/buffered 空）= 金标 FAIL,不看封面 PASS。
- 判据用「站点真实播放器」的 video 元素状态,不用自己 `new Hls()` 默认配置探测——默认配置缺站点那套 loader/config,会把能播的片也误判成坏（本次 play-repro 首轮就栽在这、把金标 118238 误判系统性坏）。
- 数据层快速预判段可播性:AES 解密段后看首字节,PNG magic（`8950 4e47`）前缀 = 伪装容器;`ffprobe -f mpegts` 强制解析能否解出 h264+aac 判段是否含真视频;前缀 PNG 尺寸 1×1(95B) 多数 hls.js 能容忍、500×500(806B) 拆包错位。但数据层只能预判、**不能替代真实浏览器 ground truth**。
- 关联 [[reference_zerodowntime_peak_validation_3source]]（三源金标验证法,应把「正片真点播放」纳入源验证）、BL-58（supjav 正片 500×500 前缀不可播）、[[reference_thumbnail_grid_seek_remux_mp4]]（封面/preview 抽帧链路,与正片链路不同）。

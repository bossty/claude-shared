---
name: reference_webkit_native_rss_video_leak_probe
description: 诊断 iOS Safari「卡死/杀页」类问题——JS heap 平 ≠ 没泄漏，必测 WebKit 进程 RSS；video unmount/remount churn 原生层泄漏（WebKit Bug
metadata: 
  node_type: memory
  type: reference
  originSessionId: 54236e30-dbdb-47b2-a9be-9e37a422af85
---

诊断移动端 feed「切 tab/深翻卡死」时（2026-05-30 feed-freeze-rca sprint）：桌面 Chromium + JS `performance.memory` 测不出真凶，因为 **iOS 原生 media 内存（VideoToolbox session / MediaPlayer / decode buffer）不进 JS heap**，JS heap 全程平 20-27MB 完全掩盖原生层单调泄漏。

**复现手法（Linux 上逼近 iOS 的唯一代理）**：playwright `webkit`（非 chromium）launch → 反复 churn（切 tab/深翻，每次 unmount 一窗口 `<video>` 再 remount）→ 用 `ps -eo rss,comm | grep WebKitWebProcess` 抓 **WebKit 渲染进程 OS 级 RSS**（含原生 media buffer）。三路对照隔离：
- NO-VIDEO（previewVideo 空、0 个 video 元素）：RSS churn#30 即 plateau 封顶（warmup 有界、非泄漏）
- VIDEO-only（禁 AVIF）：RSS 单调 +156MB 一路不 settle ← 纯 video 路径泄漏
- VIDEO+AVIF：climb 斜率与 video-only 相同 → 证伪 AVIF 是泄漏源

**真凶（WebKit #216820 官方实锤，webkit-expert 翻 bugzilla 一手文本）**：bug 原文 "removing video elements does NOT release native MediaPlayer，iOS+macOS 都中，至今 NEW，workaround=src=null before removing，否则 threads keep increasing & crashes Safari"。`useActivePreview.remove(cardId)` 只在 `activeId===cardId` 时 deactivate（释放 1 个），其余 unmount 的 `<video>` detach 后 WebKit 原生层不释放，反复 churn 累积撞 iPhone ~2GB jetsam → 杀页=卡死（Chromium 激进回收所以桌面不复现）。旁证 AWS Chime #771 / livekit #1432 / Apple Forums 704372。

**修法（=#216820 官方 workaround 精确实现）**：FeedCard `onUnmounted` 显式 `el.pause(); el.removeAttribute('src'); el.src=''; el.load()` —— 必须清 src（property+attribute 双清）+ load() 走 HTML abort 流程才释放 native player，光 removeAttribute / 光 v-if 卸 DOM 都不够。每个 video 都释放，不只 manager activeId。Linux WebKitGTK 无 VideoToolbox/jetsam → A/B 边际，**必须 iOS 真机验收**。

**两机制+权重**：①16 video 同时挂载硬限（iOS 第 17 黑屏，即时型，Tumult 多源 + react-native-video #1938「unmount 才解 pause 不解」）—— 实测 mounted 封顶 60 但 withSrc≤4≪16，仅当「空 video 也占槽」才主因（未证实：「m_player lazy 不占槽」是推断非证据，需 iOS 真机渲 20 空 `<video preload=none>` 看第 17+ 黑屏裁决）；②native MediaPlayer 泄漏（累积型，owner「多轮切才卡」更像此）= 主因。修法都做：主②release + 辅①超视口 v-if 不渲染 video。owner iOS 版本还定 content-visibility:auto 是否 no-op（Safari18/iOS18 才支持，≤17 失效 → 离屏卡片不省解码，更需辅①）。

**harness 复用**：`frontend-web/public/_rcatest/`（harness.html 直接 import 真 HomeFeed/FeedCard + fetch shim 返合成 feed + 真 ffmpeg MP4/AVIF；webkit-rss.mjs / rss-noavif.mjs / rss-novideo.mjs 三隔离 probe）。探针挡 playwright（CLAUDE.md 已记），故用 standalone harness 绕过，非真 app。相关 [[project_player_hijack_2026_05_18]]（同样 iOS WebKit 专属、桌面测不出需真机）。

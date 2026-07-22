---
name: reference_media_stream_attribution_needs_frame_ownership
description: 抓源站视频流必须做 frame 归属判定，只按 URL 关键词宽松匹配会把页面广告小组件的直播流误认成正片，进而凭空捏造出整套加密破解工作量
metadata:
  type: reference
---

2026-07-12 supjav 接入实事故：交接档的核心前提「supjav 正片走 MOUFLON/pdkey 加密、需写 v2 解扰器」**完全错误**。

**真相**：MOUFLON / pdkey / saawsedge 整套加密根本不是 supjav 的视频流，而是页面上一个 `creative.mayzaent.com/widgets` 凸轮广告小组件的直播流量。supjav 真实正片（默认 TV server）**纯明文、零加密、含 720p+ 多清晰度**。

**误判成因**：POC 用**宽松 URL 关键词匹配**收集网络请求、**没做 frame 归属**，把广告 iframe 的流量算进了"视频流"。

**三条独立证据的取证姿势（可复用）**：
1. 完整跟走真实视频链并 grep 加密标记：`turbovidhls → cdn3.turboviplay.com → gN.turbosplayer.com/file/<token>/master.m3u8 → 207 个 lh3.googleusercontent.com 段`，全程 `EXT-X-KEY` / `EXT-X-MOUFLON` grep 命中 0。
2. 直接看疑似加密源的 media 段本体是不是明文（saawsedge 段是明文 `.mp4`，无 `MOUFLON:URI` 密文）。
3. **frame 归属 + 时序**：saawsedge 请求全部归属广告 widget frame（235 次），且**在点开真播放器 iframe 之前就已在跑** → 与视频播放无因果。

**后果的量级**：整项 MOUFLON v2 解扰器（约 0.5 天 + 红绿双验 + fMP4 反混淆路径改造）被凭空立项；"只有 240p、画质不达标"的结论也是广告流的属性，差点据此毙掉整个源。

**铁律**：
- 判"某资源属于哪条业务链"的最小充分证据 = **frame/发起方归属 + 与用户操作的时序关系**，URL 子串只能当线索不能当判据（同族教训 [[reference_bare_substring_gate_needs_success_evidence_backstop]]）。
- 交接档写死的"技术前提"必须先自己抓一次真页面证伪再排期，别直接按它估工作量（[[reference_handoff_source_structure_claim_must_verify]]）。
- 顺带留档的真风险点：正片段落在图片 CDN（`lh3.googleusercontent.com` / `p16-*.tiktokcdn.com`，随片而变，受各 CDN 限速配额影响），`turbosplayer /file/<token>/master.m3u8` 是**几分钟即失效的短命 token** → 必须实时走完跳板链拿到 m3u8 就立刻下载消费，禁缓存该 URL。

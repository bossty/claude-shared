---
name: cableav-hls-bigvideo-failfast
description: cableav 大视频下不动的分层诊断法 + HLS 超时 fail-fast「限单部不限整档」的边界
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 3e6b0318-9157-4777-b86a-35bd2c0bb0d5
---

cableav 源 `picc.sex8sex855` 对单 IP **限并发**（2026-05-17 实测：单连接 1.4MB/s 健康，10 路并发抓切片仅 ~5 路拿到带宽、其余 SocketTimeout 拖到近 0；容忍线 ~5）+ 中国**晚高峰 21:00-23:00+ 整体拥塞**。两者叠加会让 900+ 切片大视频在 HLS 30min 下载上限内下不完 → 整部回滚。

修法（已 ship）：① `crawler.hls-concurrent-downloads` 10→4（`43d59ed9`，避开限并发线）；② HLS 整段下载撞 30min 上限 → fail-fast 不重试（`e3396556`，同 `HlsDownloadService` 既有 fMP4 fail-fast 模式）。

**Why:**
- 诊断教训：爬虫源"下不动"先别断言"源站降级"。必须 `curl` 实测**分层**——单段（健康?）vs 并发多段（被掐?）vs 不同时段（晚高峰?）。本次三测才定根因是"限并发 + 拥塞"、非源站挂；早先两次凭日志措辞猜都猜错。
- HLS 下载有 3 层超时语义易混：per-slice retry（3× 指数退避）、per-attempt 30min 上限（`awaitTermination`）、断点续传（retry 跳过已下切片）。30min 上限超时 ≠ 瞬时错，源站慢/挂时再试 2 个 30min 多半仍超 → 白占 cron 槽 90min。
- **fail-fast 限的是「单部」不是「整档 run」**：cableav cron `cap=1`，0 成功时一部接一部试到有 1 部成。烂源夜 fail-fast 让单部 90min→30min、churn 更快，但整档仍可能跑 2-3h（实证 00:00 档 2h41 试 6 部、第 6 部 164 切片小视频成功才收口）。整档会自收口、不无限空转。

**How to apply:**
- 源"下不动"先 `curl` 分层实测（单段/并发/时段），不靠日志措辞猜根因。
- 下载并发数按"源站单 IP 容忍线"定，不是越高越快（10 反被掐）。
- 真要给烂源整档兜底（免占数小时 cron 槽），需另加「单 run 总时长上限」——本次未做，owner 选了 per-movie fail-fast。
- `pool=2` 调度隔离始终有效：cableav 空转不拖累其余 4 源（[[project_cron_polish_5_13_5_14_sprint]]）。

相关：[[reference_deploy_backend_no_pull]]

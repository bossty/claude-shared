---
name: feedback-verify-not-recall
description: 引用易变的根因/机制/SOT 时一律回原文核，不凭记忆复述——记忆会出错，实证不会
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 64b5f5d1-9590-4971-9f5b-8d2e351a83eb
---

引用快速演变的事实（根因机制、SOT 结论、被多次纠正的归因）时，**一律回原文（banner/CORRECTION/最新 SOT 行号）核对，绝不凭记忆或转述复述**。

**Why**：2026-06-08 nw-region-p1 sprint，我就同一个 571ms 根因连踩三次"凭记忆/陈旧文本当真相"：
1. 引 `DATA-ARCH.md:11/24` 原文报"571ms 已修"，漏看同档 CORRECTION 已推翻它；
2. 改引 DATA-ARCH CORRECTION 机制后，被 RCA 中途版"replica 慢查询"带偏；
3. 给蓝军的 FYI **消息**把机制方向说反——把"被 lead 自纠作废的中途版(replica 慢查询)"当成"最新真相"，而最终 banner 定论是"搜索路径同步跨洋 Redis 写"。
关键对比：同一轮里我**凭记忆写的消息出错**，但**锚 banner 行号写的 doc 没错**。机制在两份文档间翻了四次（cache-miss→跨洋写→replica慢查询→回到跨洋写），doc 因锚行号而零错。

**How to apply**：
- 机制/根因/SOT 归因落笔前，先 `sed`/grep 读权威源原文那几行，再写。
- 设计/方案**锚现象不锚机制**（如"571ms 存在 + 命中率未知"），对上游机制翻案天然免疫——见 [[project_fullcut_5xx_rca_2026_06_06]] 的诊断铁律。
- 多文档冲突时认"最新 SOT banner / CORRECTION 段"为唯一真相，旧原文仅存证；引用前确认没漏看顶部推翻横幅。
- 分层编辑后必扫响应段/小结段（grep 旧断言字符串），防"改主体没清残句"自相矛盾。
- **状态汇报里的数字/标识符（测试数、grep 计数、marker/注解名、文件名）一律贴新跑/新 grep 的输出，不凭脑子复述**：2026-06-08 同 sprint 又犯——给团队的消息报"23/23"(实 24)、"marker 统一 @MasterReadAllowed"(实读闸是 @RegionReadAllowed，且两 marker 有意分开)；代码全对，错的是消息。蓝军逐行 trace 抓出（claim-vs-实代码是其必查项）。落笔前 `bash test`/`grep -c` 跑一遍贴结果。
- **浏览器/E2E 验证前必先核"跑的是不是我的代码"**：2026-06-08 nw-region-p1 实施期，chrome-devtools 默认连的 :5566 dev server 跑的是**另一个 git worktree（snack-rename）的旧码**——控制台仍刷旧日志、`fetch('/src/utils/X.js')` 实测 `_myNewSymbol=false`。差点拿旧树证据盖章（会得出"我的 fix 没生效"的假结论）。防线：验证前先 `fetch` 服务端转换后的源码断言我的新符号在；或 `ls -la /proc/$(lsof -ti :PORT)/cwd` 看 server 的 worktree；不对就从 canonical tree 起新端口 server 再验，验完 kill。多 worktree 仓库（`.claude/worktrees/*`）尤其易踩。
- **"是不是我引入的 regression"用 git stash A/B 对照实验判，不靠猜**：2026-06-08 三个 teammate 都怀疑我 #10 改动致 2 测超时。我 stash 掉我的改动跑 baseline——同 2 测**照样红同时序**=证伪。配 `grep "await.*<埋点>"`=0 证明结构上不阻塞。结论：陈旧测试（PROBE_TIMEOUT 2000→5000 后 fake-timer advance 没跟着改）非我 regression。改相邻文件被怀疑很合理，但**实验证伪 > 接受归咎**。
- **多引擎截图防 relabel：查引擎指纹**。蓝军验我"双引擎"4 截图时不数张数，查像素格式：Chromium 出 **RGB**、Playwright WebKit 出 **RGBA**——格式差异坐实 WebKit 那 2 张是真 WebKit 非 relabel 的 Chromium。我贴"双引擎"证据时也该自带这种不可伪造的指纹。

---
name: reference_absence_claims_need_two_independent_probes
description: 「不存在/没做/未发生」类结论必须两种独立判据交叉验证再下断言；find -newermt 撞 cp -p 保留 mtime 必然漏检；查证前先回读原始记载而非凭记忆定位路径
metadata:
  type: reference
---

**否定性结论（"备份不存在"／"没有调用方"／"该信号从未出现"）是最容易说错、且代价最大的一类断言**——它天然无法用单一判据证实，只能靠"我没找到"，而"没找到"恰恰是判据盲区最常见的表现形式。

## 2026-07-20 实事故（GFW P0 边车部署）

部署前核备份，我报出「备份不存在、agent 声称做了但实际没做」，并据此在给 Owner 的消息里指控 subagent 工作不实、把交接档那行判为虚构。**全错。** 备份一直好好躺在档里写明的路径下。

两个判据同时有盲区，且我一个都没交叉验证：

1. **路径凭记忆**：交接档写的是 `/opt/aliyun-probe-runner/backups/`，我去 `ls` 的是 `/home/ubuntu/backups/`（记混了「暂存新文件」的目录）。**回读原始记载只要一次 grep，我却先信了脑子里的印象。**
2. **兜底 find 判据结构性漏检**：`find ... -name "server.js*" -newermt "2026-07-20"`。备份是 `cp -p` 做的，**`-p` 保留原文件 mtime（Jul 16）**，所以无论备份在不在，这条 find 都永远找不到它。判据与被查对象的生成方式直接冲突，属于必然漏检而非概率漏检。

代价：向 Owner 发出了错误指控，污染了对 subagent 可信度的判断（当时还被我归纳成"今天第二次 agent 声称≠实况"这种成规律的错误叙事）。

## 铁律

- **任何 absence 断言，落笔前必须有第二条独立判据**：换路径查、换工具查（`ls` vs `find` vs `sudo find /` vs 服务端日志）、或直接问"如果它存在，应该还有什么伴随证据"（备份存在 → 备份目录该有历史批次；实测确有 3 个 0714 批次，一眼就能证伪我的结论）。
- **文件时间判据前先问「这文件是怎么生成的」**：`cp -p` / `rsync -a` / `tar -p` / `install -p` 全部保留 mtime，`-newermt`、`find -mtime`、`ls -lt` 排序在它们面前一律失效。判存在性用路径与内容（`sha256sum`），别用时间。
- **查证坐标先回读原始记载，禁凭记忆定位**（同族 [[feedback_verify_not_recall]]）；记混"暂存目录"与"备份目录"这类近义路径是高发项。
- **把单次异常升格成"规律"前先停一拍**：我当时已有一次真实的 agent 误报，于是把第二次（其实是我自己的误判）顺手归进同一叙事。**叙事惯性会让人跳过验证。**

## 同族

- [[reference_bare_substring_gate_needs_success_evidence_backstop]] —— 同日同型：判据本身写得没有兜底，导致误命中/漏命中。那条讲"匹配即丢弃"需成功证据兜底，本条讲"没匹配到即判不存在"需第二判据兜底，是一枚硬币的两面。
- [[reference_signal_onset_is_collector_birth_not_phenomenon]] —— "整月 0"不是现象不存在，是采集器还没建；同样是把"没观测到"误读成"不存在"。
- [[feedback_no_handwritten_numbers_from_tools]] / [[feedback_verify_not_recall]]

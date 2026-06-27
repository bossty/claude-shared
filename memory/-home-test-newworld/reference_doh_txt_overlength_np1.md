---
name: reference_doh_txt_overlength_np1
description: DoH池TXT超CF单条~2048上限→np1多记录分片修复;静默写失败致4天陈旧池;前端多段解析
metadata: 
  node_type: memory
  type: reference
  originSessionId: c26c2e1f-72a4-463f-8370-aeecffd81acf
---

DoH 域名池（加密 base64 的域名列表）写进 B 类域 apex TXT。**CF 单条 TXT 实用上限 ~2048 字符**。

**T4 — 4 天陈旧池的诊断（2026-06-18 实测）**：154 个 active A 域 → pool 加密后 base64 ~5400 字符，**远超 CF 单条上限** → 旧单条写触发 CF `83011 record size limit exceeded`，被 `updateDohTxtRecord` 的 catch **静默吞掉** → TXT 卡在上次成功写入 ~4 天不更新（实证法：新 np1 version 时间戳 vs 旧记录时间戳差 3.9 天）。同时老前端也解析不了：超 255B 被 CF 拆成 9 段 `"seg1" "seg2"`，老 `replace(/^"|"$/g,'')` 只剥外引号留内层 `" "` → base64 烂。**CN DoH 发现双重坏（解析 + 陈旧写）**。教训：CF 单 TXT ~2048；DNS 写失败必升级告警禁静默 catch；查陈旧用 version 时间戳。

**T5 — np1 多记录协议 + 四护栏**：每条 content = `np1|<version>|<seq>|<total>:<base64chunk>`，chunk ≤1800B；version=sync 毫秒数全域同代。
- ①**撕裂读/写序**：先 cfPost **新 version 全部分片** → 全成功**再** prune（删 `np1| 且 version!=新` + 旧单条 `^\d{10,}:`）。**禁先删后写**（中途失败旧完整集存活，前端回退）。
- ②**前端 tryAssembleNp1**：按 version 降序、跳不完整集、取首个完整（total 齐全 + seq 0..n-1）、seq 排序拼 base64 → 解密（version 当 timestamp）。
- ③**孤儿清理**：过滤 `type=TXT && content.startsWith("np1|")`，**绝不碰 apex CNAME / SPF**（见 [[reference_doh_domain_apex_cname_hstspreload]]，apex CNAME 是 hstspreload load-bearing 禁删）。
- ④**CF apex flattened-CNAME + N 条 TXT 共存**：canary 实证可共存，**三家 DoH provider（Ali/CF/Google）全返回所有 N 条**。
- 解析 `parseTxtData`：提取所有 `"..."` 段拼接（兼容 CF/Ali 引号多段 + Google 裸串）。
- provider 策略：阿里优先=三家**并行** + 阿里优先窗口（非串行兜底）；CN 浏览器 DoH 唯一 CORS+可达=阿里（腾讯/华为无 CORS）。

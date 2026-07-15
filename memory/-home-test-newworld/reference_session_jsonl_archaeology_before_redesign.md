---
name: reference_session_jsonl_archaeology_before_redesign
description: 交接档说「方案随 context 蒸发/丢失」必先去会话 jsonl 考古再重做——subagent 返回的设计正文只被口头复述一句就等于没写，但它完好躺在磁盘上
metadata:
  type: reference
---

**结论：任何档里写「方案正文已随 context 蒸发 / 已丢失 / 需重新设计」，先去本地 session jsonl 考古，禁直接重新设计。**

2026-07-14 实例（madou BL-60/BL-61）：SESSION-STATE 与 BACKLOG 都白纸黑字写「方案正文已随上会话 context 蒸发，需重新设计」。实际一次 grep 就翻案——两份**完整**设计（封面视觉分析全案 + 厂牌前缀映射实证调查）原封不动躺在
`~/.claude/projects/-home-test-newworld/80f2f903-*.jsonl` 里。重新设计的成本（含重新抓站实证 200+ 条目、9 张封面交叉验证）远高于考古的 ~4 分钟。

## 根因：subagent 返回的正文，主线程只口头复述一句 = 等于没写
上会话两个 subagent 在后台返回完整设计，主线程当时正忙于 push 冲突 + Owner 的清库指令，在对话里提了一句「厂牌番号+水印识别方案（BL-60）」就转场了，**从未整段落档**。下一会话读档只看到条目名，就误判成「从没写过」。
→ **铁律：subagent 返回的设计/调查正文必须当场整段写进 sprint 档**（不是摘要一行、不是口头复述）。它在 jsonl 里活着，但没人会想到去 jsonl 找。

## 考古方法（可直接抄）
1. 会话记录在 `~/.claude/projects/-home-test-newworld/*.jsonl` 与 `~/.claude-work/projects/.../*.jsonl`（**双账户，两个目录都要扫**，见 [[reference_claude_config_dir]]）。
2. 先用 `grep -c` 按关键词给全部 jsonl 打分定位候选文件（文件名是 sessionId，无语义；按 mtime + 命中数锁定）。
3. 再派 subagent 用 python 逐行解析 JSONL 抽 text、按关键词捞命中消息 + 前后各 1-2 条上下文，**只回结论**（文件 2-4MB，禁灌主线程 context）。
4. 区分 `user`（Owner 原话，最有价值，能还原被误传的意图）vs `assistant`。subagent 的返回在 task-notification 里。
5. 禁 `cut -c/-b` 切中文再喂 `rev`（非法 UTF-8 → 死循环野进程，见 [[feedback_bash_timeout_does_not_kill_stray_processes]]）。

## 附带收获：考古能翻出被误传的 Owner 意图
同次考古发现，上会话 subagent 的实证结论（madou footer「91制片厂/果冻传媒」**不是**从属关系，是站内 WordPress 分类无规律搭车混挂）**与 Owner 当时的猜测相反，且从未汇报给 Owner**。若不考古直接按「档里的说法」重做，会把一个已被证伪的假设当前提。
→ 同源教训 [[reference_handoff_source_structure_claim_must_verify]]（交接档结论必证伪）。

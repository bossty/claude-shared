---
name: reference_skill_verification_redgreen_v3
description: skill 验证方法规格 v3 — RED-GREEN 教训 + 偷自 SkillOpt 的 held-out 验证门控；下次验证 skill 是否真有效时直接用,别重蹈我 3 次过度论断
metadata:
  type: reference
---

验证"某条 skill 是否真改变 agent 行为/真有效"的可复用方法规格。源：2026-06-27 toolchain sprint 的 RED-GREEN v1+v2（我栽 3 次）+ 偷自 `microsoft/SkillOpt`（MIT，arXiv 2605.23904）的 held-out 门控。**下次做 skill 验证直接照这个，别再用裸 binary rubric。**

## 何时用 / 不用
- **用**：被验 skill 是"行为型/可写自动化判分的"（如生成代码、用 GET 不用 HEAD、commit 不夹带）→ 有正确性信号可门控。
- **不用**：B 桶"领域参考事实型"（IP 拓扑/CF 怪癖/deploy runbook/账号架构）——**没有可打分的 held-out 任务，门控无从谈起**，这类靠读码/事实核验，不靠 RED-GREEN。（这也正是 SkillOpt 产品对我们不适用的同一原因：训练单元要带正确性信号。）

## 方法规格（v3）
1. **held-out 验证门控（偷自 SkillOpt，核心修法）**：候选 skill 改动**必须在一组"留出"真任务上严格提分才采纳**，不是"看着更好/judge 说 OK"就采。门控分数下降/持平=拒绝。这道门正是我 v1/v2 缺的——没它我把"看着生效"夸成 PROVEN。
2. **场景必须埋雷-hard**：陷阱埋进多约束真实任务（模拟注意力被占）+ 加 review-loop（planted violation 让 agent 当蓝军 catch，测 enforcement）。单规则孤立题=太易，RED 不犯错你分不清"模型已毕业"还是"题太水"（v1 教训）。
3. **rubric 必须编码真实正确模式,禁 binary"无脑禁X"**：对"有界取舍型"skill（如有界 vs 无界同步），binary 违规判据会假阳性（我把 GREEN 的有界安全和 RED 的无界 bug 一锅判违规）。rubric 要分得清"对的做法"和"错的做法",不是"出现 X 就违规"。
4. **必持久化 RED/GREEN agent 原始输出当证据**：没留逐字输出就不能称"实测证明"（我只留散文转述,被独立审揪"零捕获输出"）。
5. **bounded 编辑 + rejected buffer + review-then-adopt（偷自 SkillOpt）**：一次只动一处可回滚单元;被拒的改动记下来别重试;改动 staged 给 Owner 采纳（承 skill 降级走 Owner 铁律）。
6. **汇报匹配证据强度 + 高风险结论上独立审**：没门控过就别说 PROVEN,说"sound/suggestive/load-bearing";区分"读码 sound"与"被验证度量到"。作者自查有系统盲点（我自纠 2 次仍留 1 个,独立审兜底）。

## SkillOpt 裁决（防重复论证）
`microsoft/SkillOpt` = 把 skill 当可训练文档 + held-out 门控优化（rollout→reflect→bounded edit→gate）。**steal-idea 不 adopt**：产品要"带正确性信号的 benchmark 任务",我们 corpus 多是不可打分的领域参考;其 +19~24 点是公开 task-benchmark 数字,不迁移到我们;且 optimizer 发 LLM 调用 + Sleep 收割 transcript(含内网IP/GFW)=数据外发面,承 copy-not-install。**只偷 held-out 门控这一条思想（即本规格 #1）。**

关联 [[feedback_verify_not_recall]] [[feedback_cross_component_key_format_align]]；全文 `docs/sprint/_archive/2026-06-27-toolchain-realignment/P-redgreen-skill-verification.md`。

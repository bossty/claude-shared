---
name: reference_doc_vouching_for_doc_is_not_evidence
description: 「X 档说 Y 档仍有效」只是线索不是证据——被引用方自己常已过期；文档治理/合并判定必须直接核第三方文档与代码
metadata:
  type: reference
---

BL-118 文档合并治理实事故：**两项合并判定的错误来源完全相同——都采信了「另一份文档对第三方文档的判定」，而没去核第三方文档本身。两次实测都发现被引用方早已过期。**

**实例一**：`IMG_PROCESSING_STANDARD_v5` §1 写「ad 维持 per-slot YAML（见 v3 §7）」，据此上一轮判定「v3 §7 是唯一权威、必须先整段搬走才能删 v3」。实测 v3 §7 描述的 `etc/ad-slot-spec.yml` / `AdSlotSpecService` **全仓零实体**，现实是 `etc/snack-slot-spec.yml` + `SnackSlotSpecService`、11 槽单尺寸（v45 收敛）。v3 §7 是从未收敛成现状的早期方案。**放大信号**：v3 的 frontmatter `covers:` 早被人改成指向 snack-slot-spec，正文 §7 却没跟着改——**档头与正文自相矛盾正是误判的来源**。

**实例二**：`EDGE_VPS_RUNBOOK` §8 附录 B 把 `CN2_VPS_RUNBOOK` §5 判为「保留」，据此上一轮判定 CN2 三节仍 active、不能删。实测 §5 换机流程的 50/50 灰度依赖 `dns-failover-agent`（2026-06-17 `82ed438ac` 永久退役），引用的 `bootstrap/cn2.sh`、`scripts/bootstrap-aws-s.sh` 全仓无实体。

**铁律**：合并/删除判定中，「另一份文档说它仍有效」只能当**线索**触发核查，不能当**证据**支撑结论。证据必须是代码/生产实查——类与文件是否存在、配置真值、生产库实查。同理，一份文档的**档头与正文若互相矛盾**，两者都不可信，必须回源码定论。

姊妹教训：[[reference_bare_substring_gate_needs_success_evidence_backstop]]（判据需成功证据兜底）、[[reference_negative_control_must_match_probe_semantics]]（负对照口径必须与被测判据一致）。同批还有「读文件头陈旧注释不读常量定义，把 Owner 拍板的 30s 改回被推翻的 300s」——**权威性排序：常量定义 > 代码注释；生产库实查 > 任何文档；Owner 拍板记录 > 早期设计档**。

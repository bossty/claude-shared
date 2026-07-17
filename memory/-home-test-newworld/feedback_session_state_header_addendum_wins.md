---
name: session-state-header-addendum-wins
description: 读 SESSION-STATE/交接档必先消化档头追加——追加常整段推翻正文旧节，按旧节开工会把已证伪方向当主线推荐给 Owner
metadata:
  type: feedback
---

SESSION-STATE 的惯例是**新会话结论以「档头追加」形式插入、正文旧节不删**（常明写「下方 X 节以本追加为准」）。读档时若只扫「未决/下一步」正文节就开工，会把**已被追加推翻的结论**当现状。

**Why**：2026-07-16 实事故（BL-72）——档头 07-15 第二会话追加已明写「主线排查完成、结论翻案：504 是 CF 记账伪影，Argo/LB 派发层假设被推翻」，我仍按正文旧「未决」节把「攻 CF Argo 派发层」推荐为唯一优先级并落档（commit `92b020c25`），Owner 据此授权开工，一轮后才靠 BACKLOG 交叉核对翻案、追加订正 commit `9a382e6a4`。错误方向多烧一轮授权 + 两次落档。

**How to apply**：
1. 读任何 SESSION-STATE/交接档：先通读全部档头追加（blockquote/加粗段），再读正文；正文与追加冲突处**一律以时间最新的追加为准**。
2. 引用某档结论去做推荐/落档前，与 `docs/BACKLOG.md` 对应 BL 条目交叉核对一次（BACKLOG grooming 常已吸收最新翻案）——两源不一致即停下先考据。
3. 自己写追加订正时，尽量顺手把被推翻的正文旧节就地打删除线或加「已被 X 追加推翻」标注（本次事故根因之一是旧节干净完整、毫无失效痕迹）。

相关：[[reference_handoff_source_structure_claim_must_verify]]（交接档结论必验证）、[[reference_cf_504_unk_protocol_accounting_artifact]]（本次涉及的 BL-72 判别法）。

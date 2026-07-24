---
name: feedback-docs-must-match-implementation-zero-tolerance
description: Owner 07-23 铁律：后续开发零容忍「读到与当前实现不符的文档」导致思路错误；跨模块联动分析必须全面
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 847861dd-4d2f-4b8a-891e-93b1a8d888eb
  modified: 2026-07-23T13:19:49.980Z
---

Owner 2026-07-23 指令（BL-111/144 复盘后）：不管采取何种目录结构/文档形式/整理方式，**后续开发一次也不能再出现「读到与当前实现不相符的文档」导致思路错误、效率低下**；且多功能/多模块有逻辑关联联动时，分析必须全面、不许漏联动面。

**Why:** docs 曾达 1363 份 md、日均 ~10 个 commit 在修「文档说谎」（BL-144 立项实测）；散文档天然会漂移，靠「写完文档」不能防，只有机制+读档协议双重才能防。散文 memory 为最后手段之所以仍写本条：这是 Owner 行为协议指令，覆盖所有读档场景，无法收敛为单个 hook（机制化本身是 BL-144 阶段④的任务）。

**How to apply:**
1. **读档信任层级（决策前强制）**：生产真值/代码（git、DB、systemd 实查）> `docs/generated/`（生成物）> 带 covers+闸门的 durable 档 > 无 frontmatter 散文（只当线索、禁当依据）。任何将影响实现决策的易变事实，必须回代码/生产核对后才可用（与 [[feedback_verify_not_recall]]、[[reference_doc_vouching_for_doc_is_not_evidence]] 同源，本条升级为零容忍）。
2. **读到与实现不符的文档时**：当场修正或删除+墓碑（禁「先用着」），并按 [[newworld-incident-outputs]] 三选一登记产出。
3. **跨模块联动分析**：以 LSP find-references + 静态依赖实查为准，禁只凭 CHANGE_IMPACT_MATRIX 等散文矩阵推断影响面；散文矩阵只做 checklist 起点。
4. 存量散文假话的系统性清算走 BL-120/121/122；防再发机制化走 BL-144 阶段④——两者未收官前，第 1 条信任层级是唯一防线，执行不得打折。

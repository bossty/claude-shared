---
name: feedback_cross_component_key_format_align
description: "隔离worktree多agent写读同一Redis key/JSON契约必漂(省份带不带后缀/数组vs对象);lead二查必逐件核对齐+蓝军专扫+真存储端到端验,防功能上线即死的假绿"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 019a2513-f7cc-4759-ad55-7522771891e2
---

**铁律**:多 agent 在隔离 worktree 各写一件(互相看不见对方代码)时,**任何"一侧写、另一侧读"的共享契约(Redis key 格式 / JSON 结构 / 字段名)必然漂移**,且单件测试全绿掩盖它——因为每件只测自己那侧,写读不在同一测试里碰头。

**2026-06-23 GFW S入口实证(2 个真 BLOCKER,蓝军才抓出,单件测试全绿)**:
1. **省份格式**:写侧 AliyunProbeClient 剥"省/市"后缀写 `reach:grid:d:telecom:广东`,读侧 pick-p/reachHint 用 IspDetector 的 `广东省` 读 → HGET **永不命中** → penalty 恒 0、reachHint 永空 → **reach-aware 整功能上线即零效果**。各件单测都绿(写侧测自己写的、读侧 stub 自己的 key)。
2. **reachHint 形状**:W3c 生产 `{deadRoots,wildcardOk,ver}` 对象,W3e 消费按 `[{domain,reach}]` 数组 → 运行时静默 no-op。

**How to apply**:
1. **设计阶段在 COMMON 钉死契约**还不够——agent 仍会各自实现到自己理解的形状。
2. **lead 二查必逐件核对齐**:把"写侧产出格式"与"读侧消费格式"并排比(grep 两侧真代码的 key 构造/字段名/JSON 结构),不信"两件都 testOk"。
3. **加写读对齐专项测试**:`canonical(读侧输入) == canonical(写侧输入)`、写一条读一条用同一 key 断言命中(把写读放进同一测试碰头)。本轮修法=抽 `IspProvinceNormalizer.reachGridProvince()` 单一 canonical,写侧+所有读侧全过它(剥后缀,无论源带不带"省"都收敛同 key)。
4. **蓝军 review 专设"跨件契约对齐"维度**;部署前 runbook 必有**真存储端到端闸门**(写一条真数据→另一侧真读命中→功能真生效),否则 isolated-test-pass ≠ production-works(假绿)。

**Why**: 隔离是 worktree 并行的代价;契约漂移是系统性必然不是偶发。与 [[feedback_migration_external_dependency_audit]](迁移漏依赖)、[[project_region_hourly_guarantee_2026_06_15]](worktree 过期基线)、[[feedback_realtime_vs_accuracy]] 同属"分布式/隔离作业的接缝处最易出隐性 bug"。关联 [[project_gfw_s_entry_execapi_poc_2026_06_22]]。

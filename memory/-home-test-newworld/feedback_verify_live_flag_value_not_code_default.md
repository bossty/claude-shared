---
name: feedback_verify_live_flag_value_not_code_default
description: 声明部署「行为中性/flag off 零回归」前，必查生产 DB 里该 flag 的真值，不能信代码默认值
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 1c0cb80f-adb3-429d-b88b-1582724035c8
---

宣称一次部署「行为中性 / flag 默认关 / 零回归」时，**必须查生产 `system_config`（DB）里那个 flag 的 live 真值**，不能拿代码里的默认值（`@Value("...:false")` / schema default `'0'` / 注释「默认关」）当生产真值。

**Why**：2026-07-08 批 A（IspDetector 接 IPv6，受 `IPV6_LOOKUP_ENABLED` 门控）——A1 implementer 报「flag 默认关」、Fable 全分支终审验「默认 flag off 零回归」、lead 都**把代码默认值当成了生产真值**，宣称部署行为中性。实际该 flag **自 2026-04-14 就已被运维启用 =1**（system_config id=71，description 明写「上线 24h 观察后由运维启用」）。是 ops-senior 部署时查 DB 三源交叉才抓出来 → 「中性码→观测→单独激活」的分阶段计划落空，v6 解析在部署即 live（所幸方向为正、无 error）。**代码默认值 ≠ 生产真值**，尤其「灰度门」类 flag 常在上线后被运维翻开而代码默认仍写关。撞 [[feedback_verify_not_recall]] / [[feedback_verify_metric_source]] 同族。

**How to apply**：
1. 任何「部署后行为是否变化」取决于某 flag 时，部署前 `scripts/nw-toolbox/nw-mysql <host> newworld-web "SELECT config_key,config_value,update_time FROM system_config WHERE config_key='<FLAG>'"` 查 live 真值，以它为准写「中性/激活」结论。
2. 若代码把一个功能新接入某**已存在的 flag**，先查那个 flag 是否已被别的消费者启用 live——共用门时「翻 flag=false 回退」可能连带回退别的已 live 功能（批 A 的 `IPV6_LOOKUP_ENABLED` 与 `IpIntelligence` v6 路径共门，翻不得），真中性化需代码层独立门控。
3. 分阶段「部署中性→观测→激活」的前提是 flag 真的 off；flag 已 on 时该计划不成立，要么接受部署即激活、要么先加独立 gate。
4. implementer/reviewer 的「默认关」若来自读代码而非查 DB，lead 必补一次 DB 实证再拍「中性」。

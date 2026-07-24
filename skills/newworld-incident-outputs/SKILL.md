---
name: newworld-incident-outputs
description: 事故/教训收口时的产出形式铁律(BL-144 阶段④) — 产出必按优先序三选一:①hook/gate(结构性拦截)②测试/检查器(红绿可验)③删规则(病灶是规则本身陈旧);散文 memory 为最后手段,用时必须一行说明前三为何不适用;产出落地后 nw-rule-audit record 登记防住记录。Triggers on 事故收口, 教训固化, 固化铁律, 复盘产出, RCA 收尾, retro 提案, postmortem, 防再发, 三选一, 写 feedback memory, 新增 feedback, 新增铁律, lessons learned, 事故产出, incident output, 记住这个坑, 落 memory.
---

# 事故产出三选一(hook/测试/删规则),散文 memory 为最后手段

**适用时点**:事故/教训**收口期**(根因已明、要决定"怎么防再发"时)。根因分析期不适用(那是 systematic-debugging 的事)。

## 为什么

散文 memory 是**最弱的防再发形式**:靠下个会话恰好 recall + 恰好照做,无机器执行者。本项目 316 份 memory 的实测教训:高频违反项照样违反(会话常驻铁律清单的存在即证据)。结构性拦截 > 可验证检查 > 减少规则面 > 散文提醒。

## 三选一优先序

1. **hook / gate**(最优):把"不该发生"变成"发生不了"。落点=`.claude/scripts/*.py`(PreToolUse/SessionStart 等,12 个先例)或 `scripts/precommit-gate.sh`/`pre-push-gate.sh` 闸门。铁律:隔离行为测试 + fail-safe 方向(照 `feedback_gate_redgreen_and_failsafe_direction`、`feedback_hooks_privileged_infra_invariants`);新 hook 必单独证明真执行过(照 `reference_new_hook_needs_execution_proof`)。
2. **测试 / 检查器**:红绿可验的 `scripts/check-*.sh`、`scripts/__tests__/*`、selftest。适用于"拦不住但能检出"的病灶。
3. **删规则**:病灶是规则本身(陈旧/歧义/互相矛盾)→ 删或合并,走墓碑册;有争议删除 Owner 拍板(分级授权,见 `docs/process/WEEKLY_RETRO.md` §二)。

**散文 memory 兜底**:前三都不适用(纯判断力/一次性语境/机制成本远超风险)才写,且 memory 正文里必须有一行:"为何不做 hook/测试/删规则:<理由>"。无此行的新 feedback/reference 视为未过本铁律。

## 收尾动作(必做)

- 产出落地后登记防住记录:`scripts/nw-toolbox/nw-rule-audit record --id <相关规则> --date <日期> --note <一行事故引用>`(新建的 hook/检查器先跑 `nw-rule-audit init` 增量补条)。这是季度废弃审查判 keep 的核心证据。
- 走 skill/rule 形式的产出照 rule `skill-authoring` 四步同步。

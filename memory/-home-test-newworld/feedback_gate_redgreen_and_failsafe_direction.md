---
name: feedback_gate_redgreen_and_failsafe_direction
description: 闸门/守卫/告警上线必须造反例红绿双向实测 + 确认未知输入的失败方向是 fail-safe；纯读代码看不出静默失效。第5种失效模式=只守了链路的一部分，最后一跳（生成物有没有真重新生成）没人守
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 3befc815-5129-4718-9143-cfdb33c0abbd
---

**任何 gate / guard / alert 新增或改动，必须造反例双向实测，并确认「未知输入」的失败方向是 fail-safe。**

**Why**：守卫的失效是静默的——它不报错，只是不再守卫。2026-07-09 一次会话内同一模式命中三次，加上一个已知同族实例，四个全是「声称覆盖某类输入，实际匹配不到」，且**纯读代码一个都看不出来**：

1. `ci-local.sh` 缺 `backend-pl:*` 分支 → `pre-push-gate.sh` 分级生成该 scope 传入后命中零分支 → `exit 0` 静默放行。**改叶子后端模块（newworld-web/admin/data）的 push 曾零测试**。
2. `pre-push` 的 `bash -n` 只匹配 `scripts/*.sh` → `nw-toolbox/nw-cap` 等无后缀 bash 脚本从不过语法门（同目录 `nw-cf` 是 python3，故必须按 shebang 判不能按目录）。
3. memory 软守卫用 `rsync -a`（比 mtime，而 git checkout 会重写 mtime）+ 缺 `-l`（symlink 致 "skipping non-regular file" 混入 **stdout**）→ 恒真。**反方向失效：恒报警会被学会无视，等于没有守卫**。
4. 同族（监控域）：N9E `alert_rule.datasource_queries` 为 NULL → 规则永不 eval，告警挂着却从不触发（见 `newworld-monitoring-ops`）。

## 第 5 种失效模式（2026-07-22 BL-133 实测新增）：**只守了链路的一部分，最后一跳没人守**

前四种都是「判据匹配不到该匹配的输入」。第五种里每一道守卫都工作正常、判据也没错——**问题是链路有三跳，三道守卫全挤在第二跳，没人守最后一跳**：

```
真相源 claude-shared/skills/<name>.md
   ↓ ① sync-skills-to-plugin.sh
plugin 副本 claude-plugin/newworld/skills/<name>/SKILL.md   ← 三道 gate 全守这一跳
   ↓ ② install-user-skills.sh（四步流程的第 3 步）
加载副本 claude-shared/skills/<name>/SKILL.md   ← harness 真正读的，零守卫
```

后果：**「gate 全绿」与「实际加载的是旧铁律」可以长期并存**。2026-07-22 实测 7 份加载副本陈旧，其中 `newworld-cf-cache-ops` 缺整条铁律③（4xx/5xx 禁被 CF 边缘缓存，2026-05-01 plyr.js 404 sticky 24h 播放页全白屏事故）。而 `docs/CF_CACHE_RULES_2026_05.md` 正是以「知识点已转入该 skill」为由删除的——**知识转进了 plugin 副本，却从没装进加载副本**，墓碑上那句话在操作层面不成立。病因只是漏跑了第 3 步，而没有任何东西会告诉你漏了。

**判别法**：对「A 生成 B」的每一跳都问一句「**谁来证明 B 真的重新生成过**」。链路越长越要盯**最后一跳**——因为前面每跳都绿会给人整条链路健康的错觉。修法已落地：`skill-drift-check.js` 增加第三跳校验（排除清单从 `install-user-skills.sh` 单一来源解析，读不到则 fail-open 跳过），红绿双验：改陈旧→检出、删加载副本→检出、还原→绿。

> **同批我自己犯的错，比 bug 本身更值得记**：诊断时我认定「目录形式=真相源、扁平档是遗留」，据此删了 32 份真扁平真相源并反转了三个脚本——**而权威架构就写在 `.claude/rules/skill-authoring.md` 和 `install-user-skills.sh` 头部注释里，我动手前没读**。是文档漂移闸门（`NEW_SESSION_PROMPT.md` 的 `covers` 声明）把我拦下，我才读到那份文档、发现搞反了，全部回滚。**改任何「多副本 + 同步脚本」体系前，先把该体系自己的架构文档读完**——这类体系的副本关系不能靠看目录结构猜，因为生成物和真相源常常躺在同一个目录里（本例中扁平 `.md` 与 `<name>/SKILL.md` 就在同一个文件夹）。

## 附带：守卫只挂某个工具通道时，绕过路径靠自觉

同日实事故：主 checkout 的 `shared_checkout_edit_guard.py` 只挂 **Edit 工具**，我用 Bash `cp` 写产品代码**直接绕过**，直到下一条 Edit 被拦才暴露。**「守卫没拦住」≠「该操作被允许」**——存在绕过通道时，约束靠纪律不靠工具。设计守卫时也要问：这个约束有几条通道能到达，我挂住了几条。

**How to apply**：
1. **RED**：造一个本该被拦的输入，确认真被拦（退出码非 0 / 告警真发 / push 真失败）。例：往 `nw-cap` 塞 `if [ 1 -eq 1 ; then` 看是否 exit 1。
2. **GREEN**：造一个本该放行的输入，确认不误报。恒真的警报 = 噪声 = 等于没有守卫。
3. **画完整链路再数守卫**：把「真相源 → 中间产物 → 最终消费物」每一跳列出来，逐跳问「谁守这一跳」。最后一跳（消费物）最常被漏，而它才是唯一有实际后果的那一跳。
4. **查失败方向**：未知/意外输入必须 fail-safe（多跑 / 拦 / 报警），绝不 `exit 0`。修法示例：`ci-local.sh` 加 scope 白名单，未知 scope 一律升全量。
5. 「读了代码觉得对」不算验证；grep 也抓不到——这五个 bug 全靠造反例/画链路现形。

关联 [[reference_skill_verification_redgreen_v3]]（skill 触发的 RED-GREEN 门控是同一方法在另一个域）、[[feedback_verify_not_recall]]、[[feedback_memory_commit_discipline]]、[[feedback_hooks_privileged_infra_invariants]]（改 hook 须隔离行为测试）、[[reference_new_hook_needs_execution_proof]]（钩子加了要单独证明它真跑过——同族的「以为在守，其实没守」）、[[reference_doc_vouching_for_doc_is_not_evidence]]（墓碑声称「知识已转入 X」必须验证 X 真的被消费）。

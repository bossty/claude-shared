---
name: project_anti_adblock_phase2_negative_2026_07
description: anti-adblock Phase 2 收口不做的负结果——A/B 蜜罐证伪「国产浏览器拦我们广告」，真实威胁≈0；再有人提 anti-adblock 重活先走本条
metadata:
  type: project
---

**结论：anti-adblock Phase 2 整体收口不做，真实威胁 ≈ 0。** 2026-06-18 拍板；再有人提 anti-adblock（SSR 首屏注入 / class 随机化 / 软降级）重活，先读本条别重跑调研。

**为什么（决定性判据来源）**：Phase 2 原前提「夸克 90%/小米 76% 拦我们广告」被一个 +53 行的 A/B 蜜罐（`baseline.js` baitOurs vs 通用 bait）在写任何重活前证伪：
- 通用蜜罐 bait 含 EasyList 通用 class（`adsbox`/`pub_300x250`），测的是**「有没有装 adblocker」**；我们真 Snack 渲染用 `snack-hero`/`snack-corner-img`/`snack-tile-*` 自定义命名空间，**不在任何 EasyList**。
- 24h 全窗高 N 读数（覆盖峰窗，与早读 4h 一致无翻转）：跨所有大样本 UA（夸克 71826 / mobile_chrome 235316 / QQ 63043 / safari 65269），**我们 `snack-` 命名空间被拦率 ~0%**。adblocker 确实活跃（拦通用 bait 夸克 91%/chrome 8%）但不拦我们。
- vivo/pc_edge 通用与我们拦截绝对数相等（46=46 / 14=14）=极少数装通杀型拦截器的用户两蜜罐齐隐，~1% 噪声级，非命名空间被定向拦。
- 原 baseline「QQ snacks_hidden 41%」= 视口外/lazy 噪声（`offsetHeight===0` 判定），非拦截。

**四子项逐项判死**：P2.2-lite（class 随机化）零价值（我们 class 本就不被拦）；P2.1 SSR 不成立（渲染未被 class 拦）；P2.3 软降级 / P2.4 无触发（没有拦截要降级/防御）。

**留存在产的净产出（勿删）**：A/B 蜜罐保留在生产——`baseline.js` baitOurs + `bait_ours_*` 指标长期监控「我们命名空间是否被 EasyList 收录」；若未来 snack- 进拦截名单，bait_ours 拦率会涨自动预警（这才是正确 anti-adblock 信号，取代被污染的通用蜜罐）。告警/决策只看 bait_ours，通用 bait_blocked 仅作 adblocker 渗透率参考。

**方法论价值**：recon-first + measure-first——写 SSR/Vite plugin 重活前先用探针证伪前提，同 Redis 多活/MySQL 专项同款「先证伪前提再建重活」。本负结果与 [[reference_negative_control_must_match_probe_semantics]] 同根：探针语义（含通用 class）与被测判据（拦我们广告）不一致就量出假信号，必须换与判据逐字一致的对照蜜罐才拿到真零。相关：[[feedback_distribution_reflects_sample_not_phenomenon]]、skill `newworld-frontend-stealth`。

> 原 sprint 全文（含 LEAD-RECON/ARBITRATION/MEASURE-RESULT 读数表）已随 BL-146③ 删除，取回见 `docs/TOMBSTONES.md` BL146 行。

---
name: project_bl34_canary_deploy_2026_07_11
description: BL-34 前端错误上报 + BL-40 上生产（web×6 + 前端×6），金丝雀 SOP 首次真跑，暴露并修掉 SOP 三处真缺陷（含 fail 方向错的 PromQL 判据）
metadata: 
  node_type: memory
  type: project
  originSessionId: eda7ef50-950e-4d1c-9bb9-e14e4381e2c3
---

2026-07-11，Owner 授权（Gate A，走金丝雀）把 BL-34（前端错误上报治理）上生产，BL-40（web 本地 dev loopback region 误判拒启动修复，生产行为中性）搭顺风车。**`docs/CANARY_RUNBOOK.md`（BL-33）首次真实执行**。

## 部署事实

- 后端 web 6 节点 + 前端 web 6 节点；基线 tag `deployed/web` / `deployed/frontend-web` → **`62e18003`**；前端 `version.txt = e249b0e3`（6 台一致），`s.dat` 152B ×6。
- 6 台 jar md5 逐台实测**逐字节一致** `53841394ce2cf6706b7b026b5f9f6d31`。
- SOP 订正 + 部署结果落档 commit **`adea4ea0`**（已合 master）。全文 `docs/sprint/2026-07-10-solo-best-practices/DEPLOY-RESULT-2026-07-11.md`。
- 金丝雀 15min 判据全绿：ca-web-04 非 2xx **0%**（窗内只有 status=200 一个 series）/ QPS 101（对照组 532）/ `/settings` p99 9.5ms / journalctl ERROR 0。

## ★ 金丝雀 SOP 三处真缺陷（纸面推演看不出，首跑才暴露）

1. **观测 PromQL 用了不存在的 `application="web"` 标签** → 匹配不到任何 series，`nw-vm` 返 `(no result)`。**这是朝错误方向 fail 的判据**：空结果极易被读成「零错误、金丝雀健康」而放行。真实标签只有 `ident` / `instance` / `job="newworld-actuator"` / `status` / `uri`。已写进 SOP 铁律：**`(no result)` 必须先当「查询写错/采集断了」排查，不得当「无错误」放行**；判空前先用 `sum by(status)` 列真实 series 坐实。方向性教训归 [[feedback_gate_redgreen_and_failsafe_direction]]，标签核实归 [[feedback_verify_metric_source]]。
2. **对照组写 `ident!="ca-web-04"` 会把 ca-admin 算进基线**（另一个应用，401 是常态）→ 必须用 web 白名单 `ident=~"ca-web-0[1-4]|eu-web-0[1-2]"`。
3. 退化方案章节编号自相矛盾（标 §4 但 §4 已是观测节）→ 理顺为 §6。

## ★ ca-web-04 未接入任何 CF LB pool（一次性预检定论，已回写 SOP §0）

A 账号（`50cbd453…`）与 P/S 账号（`9a1d6632…`）下各只有 2 个 LB pool（`nw-dnsv106-ca`/`-eu`、`nw-lbedge-ca`/`-eu`），**每个 pool 只有一个区域级 tunnel 聚合 origin**（`origin-ca.dnsv106.com` / `origin-ca.lbedge.org`），CF 侧看不到单台 web 节点 → **SOP §2 的 CF 百分比降权是永久死路径**，金丝雀一律走 §6 退化方案（单节点先部署 + 观测，敞口 = CA 侧自然流量 1/4 ≈ web 总量 1/7）。查询：`nw-cf A GET /accounts/<id>/load_balancers/pools`（**path 必须带前导 `/`**，漏了返 10404 "No route for that URI"）。

## 共享 master 在观测窗内前移 —— 虚惊，但记住判法

金丝雀构建于 `d7007b79`，15min 观测期间**别会话往共享 checkout 推了 2 个 commit**，HEAD 被动前移，`--rest` 遂从 `62e18003` 构建 → 一度以为「铺出去的 jar ≠ 验过的 jar」破坏金丝雀不变量。**实测证伪**：两 sha diff 仅文档/memory、零代码，构建产物 md5 相同。**判法 = 比 jar md5 + `git diff --stat` 看有无代码文件，别只看 sha 不同就慌，也别只看 sha 相同就放心**。附带澄清：`deploy-web.sh` 的 `[rest-tag-check]` 比的是 **md5 而非 sha，是诚实的**——不是当初评审担心的「--rest 基线 tag 说谎」。

## 遗留

- BL-34 三个阈值（120 次/分限流、20 条/会话、5 分钟去重窗）待真实流量校准后收紧。
- 验证注入约 25 条合成 js_error 进 slot `202607111605`（有 TTL 自然过期），远小于组织噪声（26–64 条/5min）。
- 自我批评：commit `adea4ea0` 的 message 写「+120/-11 行」，实际 **+76/-11**（违反 [[feedback_no_handwritten_numbers_from_tools]] / commit 精确量化铁律）；共享 master 禁改写历史故未 amend，以 `git show --stat` 为准。**行数必须复制 `git diff --stat` 输出，禁手写估算。**

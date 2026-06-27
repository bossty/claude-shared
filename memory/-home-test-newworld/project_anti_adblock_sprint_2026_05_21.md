---
name: project-anti-adblock-sprint-2026-05-21
description: Anti-adblock sprint（2026-05-20 至 5/21）反广告拦截命名体系 + Q01-Q11 映射 + 18 类 UA + nginx grace + Phase 2 触发阈值；16+ agent 协作 ~150 commits / mvn 1723 + npm 550+60 全 PASS；3 条新铁律 sink。
metadata: 
  node_type: memory
  type: project
  originSessionId: 23504196-81a0-4136-a354-f57c75e336dc
---

# Anti-Adblock Sprint 2026-05-20 ~ 5/21

完整反拦截命名体系 + SDLC 流程教训。详细 sprint-report 在 `docs/sprint/2026-05-20-anti-adblock/sprint-report.md`。

## Sprint 概览

- **起止**：2026-05-20 PRD ~ 5/21 Phase 5 closure（含 P1.0 baseline 3 天观察期 5/21-5/24）
- **commit 范围**：`bb4a8ab6..3a91e6ac`（~150 commits，含 7 个 merge artifact + N9E datasource hotfix 3 commit）
- **agent 数**：pm-helper / 5 dev-senior / 5 qa-senior / 6 reviewer / 2 ops-senior / 1 memory-keeper = 16+
- **测试**：mvn 1723 / 0F/0E + npm 550（frontend-web）+ 60（frontend-admin）全 PASS

## 反拦截命名体系（核心交付）

### 前端组件 Q 代号映射

| 旧名 | Q 代号 | 业务 |
|---|---|---|
| AdBannerFull | Q01 | 横幅 |
| SidebarBanner | Q02 | 侧栏 |
| PrerollAd | Q03 | 视频前贴 |
| NativeAdCard | Q04 | 信息流 |
| CornerAd | Q05 | 角标 |
| PauseOverlay | Q06 | 暂停遮罩 |
| SplashAd | Q07 | 启动屏 |
| BrandCards | Q08 | 品牌卡 |
| PinnedSponsorBar | Q09 | 置顶赞助 |
| SponsorBar | Q10 | 赞助商栏 |
| HomeAdSlots | Q11 | 首页位 |

- 目录：`frontend-web/src/components/ad/` → `src/components/q/`
- class BEM：`q-hero` / `q-card` / `q-tag` / `q-placeholder` 等（替代 `ad-*` `banner-*` `sponsor-*`）
- data attr：`data-ad-id` → `data-q-id`
- "广告" 中文：全删（Owner 拍板无兜底）
- vite css.modules generateScopedName + VITE_BUILD_SALT
- vite chunk hash + strip-script-comments plugin

### 后端 API 路径

| 旧路径 | 新路径 | 模块 |
|---|---|---|
| `/api/v1/promotions/slots` | `/api/v1/q/list` | web |
| `/api/v1/promotions/slots/{slug}` | `/api/v1/q/{slug}` | web |
| `/api/v1/promotions/pinned` | `/api/v1/q/fixture` | web |
| `/api/v1/promotions/track` | `/api/v1/q/tally` | web |
| `/api/v1/promotion` | `/api/v1/q-admin` | admin（翻案纳入） |
| `/api/v1/promotion-slot` | `/api/v1/q-admin/slot` | admin |
| `/api/v1/admin/promotion-channel` | `/api/v1/q-admin/channel-lifecycle` | admin（第三轮蓝军揪 ChannelLifecycle） |
| `/api/v1/promotion-channel` | `/api/v1/q-admin/channel` | admin |
| `/api/v1/promotion-channel-domain` | `/api/v1/q-admin/channel-domain` | admin |

### nginx grace（30 天兜底）

- web nginx：4 个 grace location（`promotions/slots/{id}` / `slots` / `pinned` / `track`）
- admin nginx：5 个 grace location（`promotion-slot` / `promotion` / `admin/promotion-channel` / `promotion-channel-domain` / `promotion-channel`）
- 顺序敏感：长前缀 `promotion-slot/` 在短前缀 `promotion/` 之前（nginx `^~` 按声明顺序）
- 正则收紧：捕获组 `(.*)`改 `(/[A-Za-z0-9_/-]*)?` 防用户输入污染
- N9E legacy hit metric：nginx log_format `nw_legacy_grace` + categraf toml（aws-web + aws-data）

### BrowserUaResolver 18 类 UA

返回值 19 个（18 named + other）：
- 桌面：`pc_chrome / pc_safari / pc_firefox / pc_edge / pc_other`
- 移动主流：`mobile_chrome / mobile_safari`
- 国产浏览器：`mobile_uc`（UCBrowser）/ `mobile_qq`（MQQBrowser+X5）/ `mobile_quark`（Quark）/ `mobile_huawei`（HuaweiBrowser/HMSCore）/ `mobile_miui`（MiuiBrowser）/ `mobile_baidu`（baiduboxapp/BIDUBrowser）/ `mobile_sogou`（SogouMobileBrowser）/ `mobile_vivo`（VivoBrowser）/ `mobile_oppo`（HeyTapBrowser/OppoBrowser）
- 微信生态：`mobile_wechat`（MicroMessenger / Weixin / **miniProgram**）
- `other`

UA 解析配置：`map-underscore-to-camel-case: true` 让 `client_filter` 自动映射 `clientFilter`，无需 resultMap。

### DB schema 加列（v7_006 + v7_007）

- `ad_slot.display_name VARCHAR(64) NULL`：admin 中文展示名
- `ad_slot.component_code VARCHAR(8) NULL`：前端 Q 代号映射（P1.1 完成后另起 UPDATE 填）
- `ad_slot.client_filter JSON NULL`：允许投放的 UA 类型数组（NULL/[]=全开放，UA 字段 `JSON_CONTAINS` 过滤）
- `easylist_alert (id, source, matched_rule, asset_type, severity, alert_time)`：EasyList/cjxlist 监控匹配记录
- 部署 SQL：`ALGORITHM=INPLACE, LOCK=NONE` + rollback DROP COLUMN 注释
- `ad_slot.getClientFilter()` 兜底返回 `Collections.emptyList()`（防 NPE）

### EasyList/cjxlist 监控（5 源 daily 03:00）

- `EasyListWatchScheduler` @Scheduled cron `0 0 3 * * *`
- 5 源：easylist.txt / easyprivacy.txt（`easylist/easyprivacy/master`）/ uAssets filters / AdGuard Base（`filters.adtidy.org/extension/ublock/.../2_without_easylist.txt`）/ cjxlist
- GFW failover：jsDelivr CDN
- ||domain^ 规则边界解析（不是 contains，用 endsWith/equals）
- 告警分级：P/S/B 域 wildcard → BLOCKER；A/C 内容域 → CRITICAL；q-* class / Q[0-9]+ → MAJOR
- Micrometer counter `nw_easylist_alert_total`（蓝军第一轮揪虚报 BLOCKER 修过）

### N9E baseline dashboard（Prometheus pattern）

- DiagService 用 MeterRegistry counter `nw_diag_visibility_total{ua, metric}`（metric=`bait_total/bait_blocked/ads_total/ads_hidden`）
- actuator 端口 `:18080` + `management.endpoints.web.exposure.include=prometheus`
- categraf scrape config `ops/configs/categraf/input.prometheus.toml.tmpl`
- VictoriaMetric-local datasource id=1（N9E v8 MySQL `n9e_v8.datasource` 表实证唯一 datasource，**无 Redis datasource**——P1.0 dev 初版错用 Redis pattern，部署后才发现，hotfix 重构）
- dashboard JSON：`ops/n9e-baseline-dashboard.json` 用 PromQL（`sum(nw_diag_visibility_total{metric="bait_total"})` 等）

### 探针 E2E 旁路

- `frontend-web/src/main.js` baseline check 包 `if (!document.cookie.includes('__e2e=7rip'))` 避自动化污染数据（同 main.js 现有 stealth 探针 E2E 旁路）

## Phase 2 触发阈值（30 天观察期 backlog）

5/24 baseline 3 天数据出后 Owner 判定：
- 拦截率 > 20% 或 EasyList 已收录自家资产 → 启 Phase 2（SSR 把广告 HTML inline 到正文 DOM + Cloudflare Workers HTMLRewriter 边缘随机化 + Bait 元素 + CSP Trusted Types 防 WebView 注入）
- 拦截率 < 20% 且 EasyList 未收录 → Phase 2 推迟，进 L7 长尾监控

## SDLC 教训沉淀（已 sink，记录链接）

3 条新铁律已 sink：
- `~/.claude/skills/newworld-deploy-runbook.md` "多并行 worktree merge 后部署必含 Step0：mvn compile 主仓全模块验证"
- `~/.claude/skills/newworld-openresty-deploy.md` 第 9 节 "live nginx 加载路径 vs repo nginx.conf 长期漂移"
- `~/.claude/skills/newworld-multi-agent-coord.md` "并行 worktree scope creep 防范"

增量 patch 已 sink：
- `~/.claude/skills/newworld-commit-message-precision.md` "commit 后 git log -1 --stat 自验 + 扩展全角色 + qa 评估精确度新维度"
- `~/.claude/skills/newworld-sdlc-agent-team.md` WARN-12 "Controller 方法替换必逐端点 grep 自验"

CLAUDE.md Lessons Learned 加 5 条（anti-adblock 整体 / 测试代码硬编码日期 + mock 同步 / mid-sprint 翻案 recon / CSS custom property + N9E datasource 一致性）。

## 待办（30 天观察期 backlog）

| # | 项目 | 期限 | 责任 |
|---|---|---|---|
| 1 | N9E baseline dashboard 人工 UI import | 24h | Owner |
| 2 | P1.1 PC/Mobile × Chromium/WebKit 4 象限视觉验证 | 5/22-24 | Owner / qa |
| 3 | baseline.md 落档（3 天数据归档） | 5/24 | Owner |
| 4 | EasyListWatchScheduler 5/22 03:00 首次触发 + N9E 告警链路 e2e | 5/22 后 | ops |
| 5 | Phase 2 触发判定 | 5/24 后 | Owner |
| 6 | component_code SQL UPDATE 待 dev 提供 Q01..Q11 ↔ slot.slug 映射 | 5/24 前 | dev |
| 7 | live nginx vs repo 同步（KI-3） | 下 sprint | ops |
| 8 | nginx grace 撤除（30 天 metric ≈ 0） | ~6/21 | ops |

## 相关引用

- sprint-report: `docs/sprint/2026-05-20-anti-adblock/sprint-report.md`
- PRD: `docs/sprint/2026-05-20-anti-adblock/PRD.md`
- implementation-plan: `docs/sprint/2026-05-20-anti-adblock/implementation-plan.md`
- 调研报告：`docs/AD_BLOCK_BYPASS_RESEARCH_2026_05_20.md`
- agent 状态档：`docs/sprint/2026-05-20-anti-adblock/agents/*.md`（16 个）
- 配套 skill：[[newworld-commit-message-precision]] / [[newworld-multi-agent-coord]] / [[newworld-deploy-runbook]] / [[newworld-openresty-deploy]] / [[newworld-sdlc-agent-team]]

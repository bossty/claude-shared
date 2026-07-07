---
name: project-audit-deferred-batch1-swiper12-2026-07-06
description: 全项目审计 deferred 第一批：Phase1 收尾（B1 domain_health_log 外科定案+coverage untrack）合 b7a8c244 + swiper 11→12.2.0 清 critical CVE 合 a1e7f464（升14被否），fe-web 部署待搭车
metadata: 
  node_type: memory
  type: project
  originSessionId: bad9e248-e91e-4f20-b940-5c3872e06b28
---

全项目审计 deferred 修复第一批（2026-07-06，接 [[project_full_code_audit_closure_2026_07_04]] 与 07-06 SPRINT-CLOSURE）。

**已合 master 两批**：
1. `b7a8c244` Phase1 收尾：B1 domain_health_log 两套 schema 冲突外科定案（`sql/domain_pool_upgrade.sql` 废弃块注释留档，z7 版=权威）+ untrack frontend-web/coverage×34 + gitignore 补 admin 侧 dist.new/dist.backup/coverage。
2. `a1e7f464` swiper 11.2.10→12.2.0：清 critical 原型污染 CVE（GHSA 漏洞区间 6.5.1–12.1.1，12.2.0 已修）。**⚠️ 部署待搭车——fe-web 6 节点线上仍是 v11 构建，下次前端 web 部署自动带上（master 已含），部署后需线上四象限补验**。

**B1 关键实证（三源交叉，比审计 FINDINGS 更深一层）**：生产库 domain_health_log 是 ewma/wilson/cusum 版但 **0 行从未写入**；z7 版（action ENUM+VIEW）从未在生产执行（VIEW 不存在）；唯一写入方 scripts/domain_health_agent.py（写 z7 列集）在 ca-admin/edge 三台全休眠（Z14 已降级 sanity-only）。即：若未来恢复 Z7 agent，须先在生产按 z7 schema DROP 重建该空表。

**swiper 升 14 被否决的证据链（勿重蹈）**：v14（2026-06-26 发布）浏览器基线 Chrome/Edge 110+/Safari 16.4+，与 `.browserslistrc` ios>=12/android>=7 直接冲突，官方原话「需要旧浏览器支持就留在 v12」；v12→v14 本就零 API 变更，未来旧设备占比可忽略时再升。

**技术教训**：
- **vendor CSS 现代语法必验 dist 产物**：swiper v12 起 vendor CSS 带原生嵌套（`&`），vite/PostCSS 默认不展平，旧 WebView 静默丢规则且新版 Chromium 视觉验证完全看不出。修法=postcss.config.js 加 `postcss-nesting`；其 2024-02 edition 展开必产 `:is()`（Safari 14+ 才认），须再加 `@csstools/postcss-is-pseudo-class` 二段展平。验证断言=dist grep 裸 `&` 和 `:is(` 双零。
- **本地起 newworld-web 被 L0 fail-closed 拦**（dev profile 无 slave URL→塌缩→本机 IP 不在 127.0/16 被判 region 节点拒启）：绕法=`--spring.datasource.slave.url=jdbc:mysql://localhost:3306/...`（localhost 别名使 host 字符串≠127.0.0.1）+ `--spring.datasource.slave.username/password` + `--spring.datasource.slave.hikari.maximum-pool-size=10 --spring.datasource.slave.hikari.minimum-idle=2`（否则继承 master 未初始化 -1 报 minimumIdle 负数）。另需本机 redis-server 先 systemctl start。
- 无 X server 环境四象限验证：chrome-devtools/playwright MCP 均要 X；改用 frontend-web 自带 playwright@1.60（webkit-2287 已装）写 headless 脚本，Chromium+WebKit×PC/Mobile 与 v11 基线逐项对照。

**剩余 deferred（下批候选）**：上帝类拆分 B5/B6/B7(web优先)/B8/B9 + 前端 F6/F7/F4/F5；echarts 5→6、lodash；横切 B11/B15/B13-R2Config/B16-18；F1 Option 2 后端签名（大工程）；B22/B23 文档归档（99 active vs 21 archived，逐个 grep 禁 bulk）。B14 勿重踩（已 revert）。

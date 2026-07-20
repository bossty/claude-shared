---
name: project_toolchain_realignment_2026_06_27
description: 2026-06-27 工具链调研+双账户统一 sprint：建 ~/claude-shared git 真相源、13源取长补短、A/B 账户漂移止血
metadata: 
  node_type: memory
  type: project
  originSessionId: db5508e8-b38b-4064-957a-fc8f2119f138
---

2026-06-27 toolchain-realignment sprint（13 外部源取长补短 + 双账户工程化体系统一）。

## ★ 最关键 durable 事实：~/claude-shared 是 skill+memory 唯一真相源
- `~/claude-shared/`（本地 git，**无远端**，Owner 定单人开发风险可控）= skills(35) + memory(232 .md 并集) + scripts(治理) + plugin-manifest。
- 两账户已 **symlink** 到它：`~/.claude/skills` 与 `~/.claude-work/skills` → `~/claude-shared/skills`；两账户 `projects/-home-test-newworld/memory` → `~/claude-shared/memory/-home-test-newworld`。**改一处两账户同步**。原目录留 `.pre-symlink` 兜底。全备份 `~/.claude-backups/toolchain-20260627-211430`。
- 漂移根因（已止血）：A 曾 34skill/91memory、B 0skill/143memory，memory 近乎全裂脑（重叠<1%），已非破坏并集合并（零丢失实证）。
- 治理脚本：`scripts/skill-drift-check.js`（真相源↔repo plugin `claude-plugin/newworld` byte-compare，陈旧即红，替代人肉「home 改必同步 plugin」）+ `skill-lint.js`（description 体检）。**改 skill 后必跑 drift-check 回绿 + 同步 plugin + bump version**。

## 调研结论（13源，0个整包安装）
- 铁律：**copy-not-install**——禁 symlink 上游第三方 repo、禁第三方 hook 注入会话、禁 npx/curl|bash 安装器（SkillSpector 实测连扫自己+superpowers 都判 DO_NOT_INSTALL=二元裁决是噪声，价值在 issue 清单当 checklist）。
- 落地：新建 skill `newworld-audit-rigor`（双引证 finding+3类高漏报+attacker=victim+豁免纪律）；编辑 `multi-agent-coord`（蓝军只传 ARTIFACT+CONTRACT 不传 CLAIM+跨模型只读二审）；`commit-message-precision`（diff 可视化对照）。全文 `docs/sprint/_archive/2026-06-27-toolchain-realignment/`。

## 账户/plugin 状态
- A 补装 4 plugin：lua-lsp/playwright/skill-creator/claude-api（A 原缺；newworld plugin **不装**，软链已覆盖防双载）。
- B 的 newworld plugin（v0.1.0/32skill 陈旧子集）**已 disable**（软链给 B 最新35，消双载，可 enable 回滚）。
- repo plugin `claude-plugin/newworld` bump 0.1.6→**0.1.8**（35 skills，**已合 origin/master `b067900c`**；reconcile 过别会话的 0.1.7+dev-workflow 撞车）。

## staleness 退役（Owner 逐条审 + 实证）
- `cf-tunnel-edge-region-placement` §1/§2「US需俄勒冈+加州双region」结论被终态B推翻，加 superseded 横幅（方法论保留）。
- `deploy-runbook`：region US(俄勒冈)行标退役；**EU REDIS_REPLICA_HOST .248→172.33.3.184**（eu-web-01 /proc/environ 实证更正，旧值错）。

## 未完（Owner 节奏）
**已合 origin/master**（`b067900c` 双账户统一+plugin 0.1.8 + `d1c98ba8` README/一致性修复 + 独立审纠正）。S7 已做(2026-06-28):settings 拉平(~/claude-shared/settings/shared.json+scripts/sync-settings.{py,sh},两账户43 union权限+DISPLAY,私有偏好保留)+PUA hook两账户自门控(A3.1.0/B3.2.2)。剩 plugin**版本**对齐(chrome-devtools1.2↔1.4)、P4三战略项、A桶降级逐条审。★crossocean 教训：RED-GREEN 没度量到它，prod 模式 sound 但非 PROVEN（我判 3 次靠独立审兜底）。

## 2026-07-03 plugin 清理 + 远端 + 双账户全自动同步（推翻两项旧决策,Owner 拍板）
- **卸 4 plugin**（两账户）:code-review/code-simplifier（被内置 /review /code-review /simplify 能力级取代）、everything-claude-code、pua（hook 自门控后壳无用）;frontend-design Owner 定保留;释放~290MB;A 按铁律没跑 CLI 纯文件改。
- **远端**:GitHub 私有 `bossty/claude-shared`（remote=origin,**推翻 6-27"无远端"决策**）;backup cron 每日 sync+commit+push+镜像+快照,端到端已验。
- **★2026-07-09 Owner 订正:claude-shared 入 newworld 项目仓 = 有意设计（非技术债）**——诉求=换环境直接 `clone` 主 repo 即带全套 skill+memory,无需另建仓/额外基建;由 pre-commit 闸门0（`sync-claude-shared.sh`+`git add -A claude-shared`）自动镜像入库。原"禁进项目仓"三条理由重估:①分支切换真相源时间旅行——真相源物理在 home `~/claude-shared`（symlink 目标）、drift-check 读 home，repo 内仅镜像副本,切分支不动真相源,实际影响≈0;②auto-backup 污染 master commit diff——真实但轻微（仅 memory/skill 真更新时）,Owner 接受为备份代价;③**部署把 memory 带上生产节点——实测不成立**：deploy-web.sh 只 scp 单 jar、deploy-frontend.sh 只 tar dist.new,build-artifact-only 从不整 repo checkout 到生产，memory 到不了生产机（⚠️仅当将来改成整 repo 部署时此风险复活,届时需重评）。故入仓代价≈commit 噪声,换来跨环境导入便利,Owner 拍板成立。
- **双账户全自动同步四层**:①skills/memory=symlink 即时（原有）②**plugin/marketplace 装卸=`~/.claude/plugins` symlink→B 的 plugins**（B 物理主,A 原目录留 `.pre-symlink-20260703`,**推翻 6-27"plugin 实体不能 symlink"结论**——installPath 绝对路径经 symlink 照样解析）③MCP 全经 plugin/项目 .mcp.json（两账户零 user-scope MCP,**别用 `claude mcp add --scope user`**=落账户私有 .claude.json 同步不到）④settings 共享域=`scripts/sync-toolchain.py` 双向 harvest+apply,两账户 SessionStart hook+每日 cron 触发,下次开会话生效。
- 同步语义:已声明值账户优先（context-mode A关B开这类故意差异保留）、只补缺失 key、卸载经共享安装登记 prune 传播（登记读不到 fail-open）、model/effortLevel/hooks/通知类私有键永不同步;幂等,变更才写盘,bak 只留3份。
- ★坑:`settings/shared.json` 的 enabledPlugins 曾陈旧（还写着已卸插件=true）,不剔会被 sync 回灌——**动 plugin 后 shared.json 必须同步动**（现 sync-toolchain prune 自动兜）。

## 2026-07-03 第二批 13 源评估（copy-not-install 复验）
Owner 又抛 13 个 skill/plugin/mcp 源评估。规律同前：**0 装整包**。唯一取长=**alibaba/open-code-review** 的 Java 缺陷规则(NPE/线程安全/SQL注入/XSS，阿里大规模验证、Token 1/9)→ 已抄成新 skill `newworld-java-review` checklist(缝合已有 sql-safety/mybatis-plus-camel-mapping/multiregion-crossocean-hotpath/batch-oom/auth-revocation-failopen)。可借思路(不装)：addyosmani agent-skills「每 skill 内嵌反理性化借口→反驳表」、ponytail「写码前决策阶梯」、microsoft/SkillOpt「轨迹驱动+验证门控」系统优化 skill 触发率(backlog，日常 skill-creator 够)。明确无用：karpathy-skills(全重叠 CLAUDE.md/Owner 铁律)、taste-skill/impeccable/awesome-design-md(前端美学/distinctive UI，**反发现伪装场景要平庸不显眼=反效果**)、obsidian-skills(不用 Obsidian)、playwright-agent-cli(agent-browser 已占轻量浏览器 CLI 生态位)、headroom(上次已评，proxy/wrap 基础设施侵入大，维持不装)、mattpocock/skills(/grill-me 消歧 brainstorming 已覆盖)、skill-creator(已装)。**结论落此防第三次重复评估**。

关联 [[project_terminal_arch_B_single_california]] [[project_eu_redis_separation]] [[feedback_feature_branch_deploy_test_then_merge]]

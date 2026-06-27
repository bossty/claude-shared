---
name: project_cc_bestpractices_alignment
description: 2026-06-17 按 claude.com《large codebases best practices》对齐项目;6 commits 落地子目录 CLAUDE.md 分层+.lsp.json+claude-plugin 入仓;附 multi-agent 协作教训
metadata: 
  node_type: memory
  type: project
  originSessionId: 809750ae-eb58-4a24-b9ed-42e9ab00244c
---

2026-06-17 sprint：把项目对齐 https://claude.com/blog/how-claude-code-works-in-large-codebases。owner 反复强调"不停滞/任何增删改不排斥/团队完成后 lead 别停滞"。

**6 commits（master）**：`890894b6` 6 模块子目录 CLAUDE.md 分层(common/web/admin/data+frontend-web/admin,lean 18-24行,根档加指针) → `033245d3` `.lsp.json`+Java25 LSP 金标 → `cc95e8e7`/`6f2b4755` Vue hybrid 修复+探针 → `49040607` `claude-plugin/` 入仓 plugin(32 skills+6 agents+4 hooks,保留 home 版)。设计/差距/状态全文 `docs/sprint/2026-06-17-cc-bestpractices-alignment/PLAN.md`。

**博客 6 抓手全闭环**：CLAUDE.md 精简分层✅/子目录初始化✅/版本化排除(实证 .gitignore 已覆盖 node_modules/logs/web-sourcemaps/target,**未造冗余 .claudeignore**=避 scope creep)✅/LSP 符号级精度✅/Skills+Hooks 经 Plugin 分发✅/Subagent 拆探索与编辑✅。技术细节见 [[reference_cc_lsp_plugin_setup]]。

**lead 二查抓真 bug（队员/同行报告必独立复核,全程无走过场）**：① recon-admin 报 data"无@Scheduled"实 26 文件(SOP:断言"无X"必 grep src/ 全量非只看 pom.xml) ② admin 守卫实为 @ConditionalOnProperty 非 @Value ③ mvn -pl 缺 -am(clean 环境 resolve 失败) ④ plugin-builder hooks.json 漏顶层 "hooks" 包裹键(线上实证抓出) ⑤ plugin-guide 给的 event/handler hooks 格式是 inferred 错的(采信 lead 直读官方权威格式) ⑥ PLAN.md 悬空指针。**方法论**：同行/sub-agent"X 不存在/已验证"必自己 grep+线上实证;文档歧义用线上真实产物拍板;owner"不停滞"=队员完成 lead 立即接力二查不空等。

**待 owner 手动**：plugin 真加载是交互式 `/plugin marketplace add /home/test/newworld/claude-plugin` + `/plugin install newworld@newworld-marketplace`，agent 跑不了。

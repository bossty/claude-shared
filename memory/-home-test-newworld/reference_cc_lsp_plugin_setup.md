---
name: reference_cc_lsp_plugin_setup
description: "Claude Code LSP 配置(.lsp.json jdtls/TS/Vue hybrid)+plugin 打包(skills/hooks/agents 入仓)的权威结构与实证踩坑;死代码审计现可用 LSP find-references 替 grep :: 盲区"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 809750ae-eb58-4a24-b9ed-42e9ab00244c
---

2026-06-17 CC 最佳实践对齐 sprint 沉淀。权威结构来自官方 https://code.claude.com/docs/en/plugins-reference + 线上真实 plugin 实证。

## LSP（`.lsp.json` 仓库根，CC 原生工具，commit 033245d3/cc95e8e7）
- 三 server：`java→jdtls`（settings.java.import.maven.enabled + startupTimeout 120s）、`typescript→typescript-language-server --stdio`（.ts/.tsx/.js/.jsx/.mjs/.cjs）、`.vue` 也路由进 typescript server。
- **jdtls 在 Java25 实测 OK**：官方标 Java≤24 是文档保守，jdtls 跑 JDK25 多模块导入+find-references 无致命错（金标实证）。
- **Volar 3.0+ 删了 standalone/take-over 模式**：`.vue` 里 TS 符号 find-references **必走 hybrid**——`.vue` 路由进 `typescript-language-server` + initializationOptions 挂 `@vue/typescript-plugin`（bundled 在 @vue/language-server/node_modules，require.resolve 可解析）+ tsserver path。单跑 `vue-language-server` 对 .vue 做 find-ref = 0命中+timeout。取舍：换来 .vue TS 导航全通，放弃 Volar 模板/CSS 专属诊断（CC 单扩展名只能挂一个 server）。
- **本机 server 装在 `~/.local`**：npm global prefix=/usr root-owned 会 EACCES → `npm i -g --prefix /home/test/.local`。
- **金标验证法（死代码审计救场）**：挑只被 `Class::method` 方法引用的方法（grep `method(`=0 会判死），jdtls find-references 命中真引用。实证 `MenuKey::defaultForAdmin`(2命中)、`convertToListVO`(13命中=10::+3lambda)、TS `formatDuration`(14含跨文件进.vue)。可重放探针 `docs/sprint/2026-06-17-lsp-config/{lsp_probe.py,vue_hybrid_probe.py}`。**更新死代码审计 SOP：`::` 方法引用盲区现可用 LSP find-references 覆盖**（见 [[reference_deadcode_audit_sop]]）。

## Plugin 打包（commit 49040607）
- 结构：`<root>/.claude-plugin/plugin.json`（仅 `name` 必填,kebab-case）+ `skills/<name>/SKILL.md`（**单文件 .md 不行,必须目录形态**）+ `agents/*.md` + `hooks/hooks.json` + `scripts/*.py` + README。marketplace：`marketplace.json` {name,owner,plugins:[{name,source相对路径,description}]}。
- 🔴 **hooks.json 顶层必须有 `"hooks"` 包裹键**（线上 context-mode plugin 实证顶层=['description','hooks']）；命令用 `${CLAUDE_PLUGIN_ROOT}/scripts/X.py`。格式同 settings.json（matcher+hooks:[{type:command,command}]），**不是** event/handler/condition（那是 hallucinated）。
- plugin-shipped agent **不支持** hooks/mcpServers/permissionMode frontmatter。
- 本地加载：`/plugin marketplace add <localpath>` + `/plugin install <name>@<marketplace>`（交互式，agent 跑不了，需 owner 手动）。
- **去重安全**：plugin skills 自动命名空间化 `/<plugin>:<skill>`，~/.claude/skills home 版非命名空间化，并存不碰撞 → "入仓+保留 home" 安全，owner 本机不 enable plugin 即无双触发，plugin 供新机/他人分发。

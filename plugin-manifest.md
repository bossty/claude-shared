# plugin-manifest — 两账户 canonical plugin 集 + 版本（对齐基准）

> 来源：2026-06-27 实测两账户 `installed_plugins.json`。
> 用途：plugin 实体不能 symlink（install 路径含版本号 + 账户元数据），故用本清单 + `sync-plugins.sh` 在两账户分别装到一致版本。
> 对齐规则：**canonical = 两账户并集；版本冲突取较新**（dry-run diff 后再 sync，禁降级）。
> ⚠️ 实际 `/plugin install/update` 会改两账户活配置，**Owner-gated**，本清单只记基准。

## Canonical 集（并集 17 个）

| plugin@marketplace | A(.claude) | B(.claude-work) | canonical 版本 | 备注 |
|---|---|---|---|---|
| chrome-devtools-mcp@claude-plugins-official | ✓ 1.4.0 | ✓ 1.2.0 | **1.4.0** | 取新；A 较新 |
| pua@pua-skills | ✓ 3.1.0 | ✓ 3.2.2 | **3.2.2** | 取新；B 较新 |
| superpowers@claude-plugins-official | ✓ | ✓ | pin 最新已测 | 关 auto-update + DISABLE_TELEMETRY（矩阵主题 A） |
| context7@claude-plugins-official | ✓ | ✓ | — | 库文档 MCP |
| code-review@claude-plugins-official | ✓ | ✓ | — | |
| code-simplifier@claude-plugins-official | ✓ | ✓ | — | |
| context-mode@context-mode | ✓ | ✓ | — | 重命令降本 |
| everything-claude-code@everything-claude-code | ✓ | ✓ | — | |
| frontend-design@claude-plugins-official | ✓ | ✓ | — | |
| jdtls-lsp@claude-plugins-official | ✓ | ✓ | — | Java LSP |
| pyright-lsp@claude-plugins-official | ✓ | ✓ | — | Python LSP |
| typescript-lsp@claude-plugins-official | ✓ | ✓ | — | TS LSP |
| **newworld@newworld-marketplace** | ✗ **缺** | ✓ | 装 | ⚠️ A 竟没装自家 plugin（A 走裸 skills 目录，B 走 plugin） |
| **lua-lsp@claude-plugins-official** | ✗ **缺** | ✓ | 装 | ⚠️ openresty/lua 工作要用 |
| **playwright@claude-plugins-official** | ✗ **缺** | ✓ | 装 | 多步 E2E |
| **claude-api@anthropic-agent-skills** | ✗ 缺 | ✓ | 装 | Claude API 参考 |
| **skill-creator@claude-plugins-official** | ✗ 缺 | ✓ | 装 | 写 skill 辅助 |

## A 账户待补（5 个）
`newworld` / `lua-lsp` / `playwright` / `claude-api` / `skill-creator` —— B 是事实上更全的账户。

## 版本待对齐（2 个）
`chrome-devtools-mcp` A 1.4.0 ← B 升到 1.4.0；`pua` B 3.2.2 ← A 升到 3.2.2。

## 护栏（矩阵主题 A/F）
- 第三方 plugin 装前过 SkillSpector `--no-llm`（P0）。
- superpowers 等已装本体：pin 版本 + 关 auto-update + 设 `DISABLE_TELEMETRY`。
- newworld 自有 plugin 随 repo `claude-plugin/newworld` 分发，与真相源 `skills/` 用 `skill-drift-check.js` 对齐。

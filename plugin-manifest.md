# plugin-manifest — 两账户 canonical plugin 集 + 版本（对齐基准）

> 来源：2026-06-27 实测两账户 `installed_plugins.json`。
> 用途：plugin 实体不能 symlink（install 路径含版本号 + 账户元数据），故用本清单 + `sync-plugins.sh` 在两账户分别装到一致版本。
> 对齐规则：**canonical = 两账户并集；版本冲突取较新**（dry-run diff 后再 sync，禁降级）。
> ⚠️ 实际 `/plugin install/update` 会改两账户活配置，**Owner-gated**，本清单只记基准。

## Canonical 集（并集 13 个，2026-07-03 卸 4 后）

| plugin@marketplace | A(.claude) | B(.claude-work) | canonical 版本 | 备注 |
|---|---|---|---|---|
| chrome-devtools-mcp@claude-plugins-official | ✓ 1.4.0 | ✓ 1.2.0 | **1.4.0** | 取新；A 较新 |
| ~~pua@pua-skills~~ | 已卸 | 已卸 | — | 2026-07-03 卸载（hook 自门控后插件壳无用） |
| superpowers@claude-plugins-official | ✓ | ✓ | pin 最新已测 | 关 auto-update + DISABLE_TELEMETRY（矩阵主题 A） |
| context7@claude-plugins-official | ✓ | ✓ | — | 库文档 MCP |
| context-mode@context-mode | ✓ | ✓ | — | 重命令降本 |
| frontend-design@claude-plugins-official | ✓ | ✓ | — | Owner 定保留（2026-07-03） |
| jdtls-lsp@claude-plugins-official | ✓ | ✓ | — | Java LSP |
| pyright-lsp@claude-plugins-official | ✓ | ✓ | — | Python LSP |
| typescript-lsp@claude-plugins-official | ✓ | ✓ | — | TS LSP |
| **newworld@newworld-marketplace** | ✗ **缺** | ✓ | 装 | ⚠️ A 竟没装自家 plugin（A 走裸 skills 目录，B 走 plugin） |
| **lua-lsp@claude-plugins-official** | ✗ **缺** | ✓ | 装 | ⚠️ openresty/lua 工作要用 |
| **playwright@claude-plugins-official** | ✗ **缺** | ✓ | 装 | 多步 E2E |
| **claude-api@anthropic-agent-skills** | ✗ 缺 | ✓ | 装 | Claude API 参考 |
| **skill-creator@claude-plugins-official** | ✗ 缺 | ✓ | 装 | 写 skill 辅助 |

## A 账户待补
已于 2026-06-27 补齐 `lua-lsp`/`playwright`/`claude-api`/`skill-creator`；`newworld` **A 有意不装**（skills 软链已覆盖，防双载）。

## 版本待对齐
已于 2026-06-28 对齐（见下执行记录）；pua 已卸载不再适用。

## 护栏（矩阵主题 A/F）
- 第三方 plugin 装前过 SkillSpector `--no-llm`（P0）。
- superpowers 等已装本体：pin 版本 + 关 auto-update + 设 `DISABLE_TELEMETRY`。
- newworld 自有 plugin 随 repo `claude-plugin/newworld` 分发，与真相源 `skills/` 用 `skill-drift-check.js` 对齐。

## 卸载执行记录（2026-07-03，Owner 拍板）
- ✅ 两账户卸载 4 个：`code-review`（被内置 /review + /code-review 能力级取代）、`code-simplifier`（被内置 /simplify 取代，且 prompt 写死 JS 规范不适配 Java 仓库）、`everything-claude-code`（评估期杂货铺，MCP 子服务早已单独禁用）、`pua`（hook 自门控后插件壳无用）。
- 机制：B 用 `claude plugin uninstall`（user scope）+ 手清 project-scope 残留（/home/test 老会话装的）；A 按铁律**不跑 CLI**，直接改 settings.json + installed_plugins.json + 删 cache/data。释放 ~290MB。备份后缀 `.bak-uninstall-20260703-*`。
- ⚠️ 同步源 `settings/shared.json` 的 enabledPlugins 同步剔除（原值陈旧 code-review/code-simplifier/pua=true，不剔会被 sync-settings 回灌）。
- marketplace `everything-claude-code`/`pua-skills` 的 known_marketplaces 登记保留（重装通道，成本≈0）；要清:`claude plugin marketplace remove <name>`。
- `frontend-design` Owner 定保留。

## 版本对齐执行记录（2026-06-28）
- ✅ pua A 3.1.0→3.2.2（copy B 的 patched cache，A 白嫖 hook 自门控）；chrome-devtools B 1.2.0→1.4.0（copy A cache）。两账户磁盘已齐。
- context-mode 两账户磁盘本就 1.0.89（A installed_plugins 元数据误写 1.0.162+跨账户路径=预存坏数据，未触碰）。
- 机制：文件级 copy cache + 改 installed_plugins.json（不碰凭证/不用 CLAUDE_CONFIG_DIR claude）；次会话生效，B 待重登。claude-api SHA 差异=cosmetic 未对齐。

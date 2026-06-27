---
name: reference-lsp-toolchain
description: 4 LSP（jdtls/typescript/lua/pyright）已在本机装好；jdtls 用 wrapper 注入 Lombok javaagent（必要，否则 newworld 后端 28+ 假 log cannot be resolved 误报）
metadata: 
  node_type: memory
  type: reference
  originSessionId: cb1b5e5d-e9cf-4617-8867-6b7aea222012
---

# LSP Toolchain for newworld (installed 2026-05-15)

4 个 LSP plugin 都装在 `claude-plugins-official`，对应底层 binary 都在 `~/.local/`。可以直接用 `LSP` 工具调用 `hover` / `documentSymbol` / `goToDefinition` / `findReferences` 等操作 newworld 项目代码。

## 二进制位置

| LSP | 实际 binary | 安装方式 |
|---|---|---|
| jdtls | `~/.local/bin/jdtls` (**wrapper script**, 不是 symlink) | tarball 解压到 `~/.local/share/jdtls/` |
| typescript-language-server | `~/.local/bin/typescript-language-server` | `npm install -g --prefix ~/.local` |
| lua-language-server | `~/.local/bin/lua-language-server` → `~/.local/share/lua-language-server/bin/` | GitHub release tarball |
| pyright-langserver | `~/.local/bin/pyright-langserver` | `npm install -g --prefix ~/.local pyright` |

## ⚠️ jdtls 必须用 wrapper 注入 Lombok javaagent

newworld 后端 4 个模块（admin/web/data/common）几乎每个 class 都用 `@Slf4j` / `@Data` / `@RequiredArgsConstructor` / `@Getter` / `@Setter`。如果 jdtls 没启用 Lombok，会报海量假诊断：
- `log cannot be resolved`（@Slf4j 生成的 log 字段）
- `setAuthenticityScore undefined for type ChannelDailyReport`（@Setter 生成的 setter）
- `blank final field domainMapper may not have been initialized`（@RequiredArgsConstructor 生成的构造函数）

实测装 LSP 后**第一次开 java 文件 35+ 误报**，配 Lombok 后**全部消失**，剩下的诊断才是真信号。

**Wrapper 内容** `~/.local/bin/jdtls`（手写 bash 脚本，不是 symlink）：
```bash
#!/usr/bin/env bash
exec /home/test/.local/share/jdtls/bin/jdtls \
  --jvm-arg=-javaagent:/home/test/.local/share/lombok/lombok.jar \
  "$@"
```

Lombok jar 位置：`~/.local/share/lombok/lombok.jar`（从 https://projectlombok.org/downloads/lombok.jar 下载）

**Why：** marketplace 的 jdtls-lsp 插件 `lspServers.jdtls.command = "jdtls"` 无参数，没法直接传 `--jvm-arg`；改 marketplace 配置会被 plugin update 覆盖。Wrapper 是最干净的注入点。

## .luarc.json（OpenResty/LuaJIT 必配）

repo 根：`/home/test/newworld/.luarc.json`（已 commit 在 master，commit `00d999f4`）。声明 `runtime.version=LuaJIT` + `diagnostics.globals=[ngx, ndk, bit, jit]`，否则 lua-ls 按 vanilla Lua 5.4 解析 → `ngx.*` API 全报 `redundant-parameter` + `bit` 报 `undefined-global`。

**坑**：agent worktree 是从 git HEAD 切的，**不继承未 commit 的 .luarc.json**。所以 .luarc.json 必须先 commit，dev-senior worktree 才有正确 lua 诊断。教训来自本次 sprint：dev-senior 在 worktree 改 retry_token.lua 时 lua-ls 又冒出 bit/ngx 误报。

## 已暴露但未清的诊断（followup）

[[project_lsp_cleanup_5_15]] sprint 清了 unused import / unused local / unused field / raw type 共 56 行（6 commits），但故意**没动 deprecated method 迁移**：
- `@MockBean` → `@MockitoBean`（Spring Boot 3.4+，在 PrometheusEndpointIntegrationTest + 多个 test）
- `findActiveByChannelAndCategory(Integer, String)` 弃用（ChannelLifecycleServiceTest 6 处）
- `SDomainPoolService.markBlocked(int, String)` 弃用

这是工作量更大的 API 迁移，单开 sprint 处理。

## 快速验证 LSP 是否还在工作

```
mcp_LSP(operation: documentSymbol, filePath: newworld-web/src/main/java/.../HealthController.java, line: 1, character: 1)
```
返回 package + class + fields + methods 列表说明 jdtls 活着。其他 3 个 LSP 同理换路径。

## Vue gap

marketplace 没有 vue-lsp（volar），75 个 `.vue` 文件 typescript-lsp 只能部分解析 `<script>` 块。如果 vue 单文件智能感知重要，要等官方上 vue-lsp 或自己手装。短期 acceptable。

## vue-tsc：`lang="ts"` 是 .vue 文件强制 TS 模式的前提（E-sprint 5/16 教训）

`.vue` 文件若 `<script setup>` 没有 `lang="ts"`，vue-tsc 按 **JS 模式**处理——`import type` / 泛型 / 类型注解语法会触发 TS8006/TS8016 报错。要在 .vue 用 TS 类型声明（如 `import type { AdItem }` + `AdItem[]` prop 类型），**必须先把 `<script setup>` 改 `<script lang="ts" setup>`**。

⚠️ 加 `lang="ts"` 会让该文件进入 TS 严格检查，**可能暴露此前 JS 模式下被忽略的新错误**。LSP 清理改 .vue 文件前：先在 worktree 试跑 `npx vue-tsc --noEmit` 看加 lang="ts" 后的增量错误数，再决策。实证：E-sprint commit `32fcd79b`（BrandCards.vue / SponsorBar.vue 加 lang="ts" + import type 重排）。

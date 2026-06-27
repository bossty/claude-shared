---
name: feedback-heavy-cmd-ctx-routing
description: 重命令（大输出且只要结论）默认走 context-mode ctx 路由，不用裸 Bash
metadata: 
  node_type: memory
  type: feedback
  originSessionId: e78b8dd9-c86a-4112-9028-289062aadd6a
---

重命令（**大输出 + 只需要派生结论**的命令）默认走 context-mode 的 `ctx_batch_execute` / `ctx_execute` / `ctx_execute_file` / `ctx_search`，不用裸 Bash/Read 把原始字节灌进上下文。

**Why:** 2026-06-13 实测一条 `find+git log+find` 批命令产出 ~4MB / 30597 行原始输出；走 ctx 路由后只回 29.4 KB（99% 留 sandbox，约 137× 上下文杠杆）。裸 Bash 会整块吃掉约 100 万 token。context-mode 是软约束（hook 只提示不强制），省不省全看是否真用 ctx 工具。

**How to apply:**
- 走 ctx：日志分析、`git log` 全量、`find`/`wc`/`grep` 全仓扫描、API 大 JSON、大文件分析/提取——传 queries 一轮拿结论。
- 仍用 Bash：小固定输出（`git status`、`pwd`、`whoami`）+ 状态变更（git/mkdir/rm/mv/部署）。
- 文件写入永远用原生 Write/Edit（ctx_execute 的 sandbox FS 不落盘）。

context-mode 当前 v1.0.162（2026-06-13 升级 + 清残留 .mcp.json + 重启验证）。

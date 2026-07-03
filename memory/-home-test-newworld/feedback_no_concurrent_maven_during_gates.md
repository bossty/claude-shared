---
name: feedback-no-concurrent-maven-during-gates
description: pre-push/ci 门禁运行期间禁止在同一 worktree 并行跑 maven 或改源码——clean 会抽掉门禁测试的 classpath 致大片 NoClassDefFoundError 误判失败
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 8c1fcb79-0cfc-4ab7-83a2-3dc3a94850e3
---

pre-push 门禁（ci-local.sh 全量测试）后台运行期间，同一 worktree 内禁止任何并行 `mvn`（尤其 `clean`）和源码改动（merge/checkout 也算）。

**Why**：2026-07-03 C 组缓存统一 push 期间并行 `mvn clean package` 把 `newworld-common/target` 从门禁测试 classpath 底下抽掉 → admin 模块大片 `NoClassDefFoundError`（如 ConfigVersionRegistry）→ ci-local 误判失败拦下 push；并行期间打的 jar 也不可信。

**How to apply**：① push 想后台跑就把它当独占锁——期间只做纯读/写 docs/home 目录操作；② 判"真失败 vs 自伤污染"看两点：失败清一色 NoClassDefFound/资源缺失 + 时间戳与自己的 mvn 窗口重叠；③ 部署 jar 必须在无任何并行 maven 的窗口重建。相关 [[project-cache-unification-2026-07-03]]。

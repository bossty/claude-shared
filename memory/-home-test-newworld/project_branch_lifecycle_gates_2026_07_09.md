---
name: project_branch_lifecycle_gates_2026_07_09
description: 修 ci-local backend-pl 空转漏洞+合 master 慢门+分支全生命周期 SOP，分支 feature/branch-lifecycle-gates 待 Owner 授权合 master
metadata: 
  node_type: memory
  type: project
  originSessionId: 3befc815-5129-4718-9143-cfdb33c0abbd
---

2026-07-09 闸门审计（双 subagent：仓库拆解 + 业界调研）结论与落地。**已收口：Owner 授权后 re-merge 最新 master(2dd9e726，解 MEMORY.md 镜像冲突取活文件) → 重验(bash -n+四场景 decide-only) → `--no-ff` 合 master=`8ba9731b` 已推送；本地+远端分支与 worktree 均已清**（走了刚落档的 SOP 全流程含"master 动了重 merge 重验"）：

1. **真缺陷已修**：`pre-push-gate.sh:79` 对叶子后端模块生成 `backend-pl:<模块>` scope，但 `ci-local.sh` 无对应分支 → 只改 newworld-web/admin/data 的 push 零后端测试放行。修法 = ci-local.sh 补 `backend-pl:?*` 分支跑 `mvn -pl <模块> -am test` + scope 白名单（未知 scope fail-safe 升全量）。实测：reactor 3 项目 BUILD SUCCESS 1:06min（此前 0 秒空转）。
2. **合 master 慢门**：pre-push 检测目标 ref=refs/heads/master 且代码类改动 → 升全量。附带机械闭合「B 测完后 master 被抢先推进」竞态（non-ff 拒推→重 merge→慢门重测）。
3. **分支全生命周期 SOP** 落 `docs/process/BRANCH_LIFECYCLE.md`（七步：扫撞车→origin/master 切出→禁 rebase 只 merge→merge master 重测→Owner 授权→慢门→安全清理），CLAUDE.md 分支铁律段同步扩写。
4. **审计澄清**：pre-commit/pre-push 无真重复（分层干净，唯一跨层项 skill-drift 是有意双保险）；全量约 7 分钟在业界「<10 分钟直接全量」口径内，不上更细粒度选测（后端隐式耦合多，依赖图不可靠）。

**Why**: 闸门自身的 bug 静默放行是最危险的一类（绿灯≠跑过）；调研三来源 = Not-Rocket-Science Rule / Fowler 语义冲突 / TIA（martinfowler.com/articles/rise-test-impact-analysis.html）。
**How to apply**: 未来给 ci-local 加新 scope 必须同步改 scope 白名单 case（否则被 fail-safe 升全量，慢但不漏）；分支收尾清理照 [[reference_safe_branch_worktree_cleanup_protocol]]（本次已按此清干净）。

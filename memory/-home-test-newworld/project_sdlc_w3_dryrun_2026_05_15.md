---
name: project-sdlc-w3-dryrun-2026-05-15
description: SDLC Agent Team W3 dry-run sprint 2026-05-15-lsp-cleanup — Phase 1 软门首次有效拦截正面案例。pm-helper + reviewer + memory-keeper 5 senior + reviewer 全 subagent_type 真用至少 1 次
metadata: 
  node_type: memory
  type: project
  originSessionId: da3be312-2b73-46c3-95da-580bd268b069
---

SDLC Agent Team Approach A 三周建设的 Week 3 dry-run sprint，以 Owner 上一 session 的 LSP_LINT_CLEANUP_2026_05_15.md 当真业务材料跑批量 lint cleanup。

## 关键事件
- ✅ Phase 1 PRD: pm-helper agent **首次真用**（W2 是 prompt 注入 general-purpose 模拟），起 PRD candidate（3 OQ + 4 MEMORY 历史关联 + 风险矩阵）
- ✅ Phase 1 蓝军挑刺: reviewer agent **首次独立 spawn**，挑 6 条（1 BLOCKER + 4 MAJOR + 1 MINOR），100% 真 bug 率
- 🚨 **BLOCKER #1 揪 Owner 准备的 LSP doc 含 hallucinated 内容**：
  - `OpsController:104 promotionChannelMapper` 实际是 `IpIntelligence`（@Autowired(required=false)）
  - `Z15_HASH_FIELD_COUNT` 全库 grep 零结果（不存在）
  - A/C 类路径含不存在的 `crawler/` 子目录（实际 `service/` + `xvideos/`）
  - B 类 `totalBounce` 实际是 `totalBounceSessions`（有真实使用）
- ⛔ Phase 1 软门 1 未拍板，Owner 决定重跑 LSP 工具拿新清单 + 重拟 PRD
- ⏭️ Phase 3+4 deferred（dev-senior / qa-senior 未 spawn，无业务代码 commit）
- ✅ Phase 5 沉淀: memory-keeper agent **首次真用**，sprint-report.md candidate + 6 候选教训 + 自检"未直接动 skill/memory/CLAUDE.md"（spec §4.5 铁律实证）

## 真核心价值（即使 Phase 3 没跑）

**Phase 1 软门首次在真实 sprint 中有效拦截。** SDLC Agent Team 设计意图实证：pm-helper + reviewer + 软门 1 三件套能在错误进入代码层前止损。

如果没 SDLC Agent Team 跳过蓝军，Owner 直接给 LSP doc 让 dev-senior 跑：
- C 类 11 条 @Autowired 删除会误删 `IpIntelligence` / `promotionChannelMapper` 真存在的 bean → Spring 启动 BeanCreationException
- B 类 `totalBounce` 删除会误删 `totalBounceSessions` 实际使用的字段 → mvn 编译挂

成本效益：~$1 token cost 拦截一个有问题的 sprint，避免下游灾难。

## 6 候选教训（已 sink 5 条，#6 跳因 W2 已沉淀）

| # | 教训 | sink 路径 |
|---|------|----------|
| 1 | 输入材料也需 fact-check（pm-helper 必须 Grep 实代码抽样验证 ≥2 条/类） | CLAUDE.md Lessons Learned ✅ |
| 2 | C 类 unused @Autowired Grep SOP 必含 Java 反射模式（ReflectionTestUtils.setField + @InjectMocks） | newworld-sprint-closure-audit skill 加 §5 ✅ |
| 3 | PRD 验收涉工具链信号必含可执行命令 + @Autowired 删除验收必含 Spring 容器启动冒烟（W11） | pm-helper agent 5 铁律→7 铁律 ✅ |
| 4 | reviewer agent 加 Write 工具（限定 reviewer.md 状态档），否则挑刺仅存在 main session 转发记录 | reviewer agent frontmatter + body ✅ |
| 5 | W3 dry-run 价值实证：Phase 1 软门首次有效拦截正面案例 | 本 memory 文件 ✅ |
| 6 | subagent_type 注册需 reload-plugins（再实证） | W2 已沉淀，无需新 sink |

## token cost
- pm-helper: ~60k
- reviewer: ~80k
- memory-keeper: ~30k
- main session orchestration: ~20k
- 合计 ~190k tokens ≈ **~$1 USD**（claude-sonnet-4-6, input $3/MTok + output $15/MTok）

## sprint 产物
- `docs/sprint/_archive/2026-05-15-lsp-cleanup/PRD.md`（pm-helper 起）
- `docs/sprint/_archive/2026-05-15-lsp-cleanup/agents/pm-helper.md`（状态档）
- `docs/sprint/_archive/2026-05-15-lsp-cleanup/sprint-report.md`（memory-keeper Phase 5 candidate）
- `docs/sprint/_archive/2026-05-15-lsp-cleanup/agents/reviewer.md`：**未填**（reviewer 当时无 Write 工具，挑刺只在 main session 转发记录；本次教训 #4 已修扩 Write 权限）

## Owner 待办（sprint 未完成段）
1. **Owner action**: 重跑 LSP 工具链（jdtls/typescript-language-server/pyright/lua-language-server）拿当前 HEAD 真清单
2. 拿到新清单后另起 sprint resume LSP cleanup（pm-helper 二刷新 PRD → reviewer 二审 → dev-senior 跑 Phase 3）
3. 历史 lint commit C 类删除 `376347d4` 是否补跑 Java 反射 Grep 验证（基于本 sprint 蓝军 #3 风险）

## 关联

- spec `docs/superpowers/specs/2026-05-14-agent-team-sdlc-design.md` §11 W3 完成状态 blockquote 含本 dry-run 总结
- W3 plan `docs/superpowers/plans/2026-05-15-sdlc-agent-team-week3.md`
- Week 1+2: [[reference_lsp_toolchain]] LSP 工具链已装好（Owner 另一 session 完成）
- 上游 spec: §4.1 Phase 1 PRD + §4.5 Phase 5 沉淀
- 触发 skill: [[newworld-commit-message-precision]]（W2 沉淀的 dev 越权防范）+ [[newworld-sprint-closure-audit]]（本次新增 §5 Java 反射 Grep）

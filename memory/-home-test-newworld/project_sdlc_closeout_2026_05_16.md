---
name: project-sdlc-closeout-2026-05-16
description: SDLC Agent Team 收官 sprint — v1.0 生产就绪定稿 / 7 sprint 全归档 / newworld-sdlc-agent-team skill 落地；SDLC 项目收尾
metadata:
  node_type: memory
  type: project
  originSessionId: da3be312-2b73-46c3-95da-580bd268b069
---

SDLC Agent Team **收官/元 sprint** `2026-05-16-sdlc-closeout` —— pipeline 已走完 7 个 sprint 实战验证，本 sprint 做整体收尾。是 SDLC Agent Team 项目的终点。

## 三项交付（Owner 软门 1 全选）
- **D1 复盘 + spec 定稿**：`docs/sprint/_archive/2026-05-16-sdlc-closeout/RETROSPECTIVE.md`（7 sprint 复盘表）+ spec `docs/superpowers/specs/2026-05-14-agent-team-sdlc-design.md` 升 **v1.0 生产就绪**（顶部标记 + §4.1 步骤 2a 设计决策型 recon 子步骤 + §11 Week 批注完成态 + §17 实战总结 7 类教训）
- **D2 SOP skill**：`newworld-sdlc-agent-team` skill 已装 `~/.claude/skills/`（第 29 个 newworld skill；8 章节 + 快速起步清单 + 6 条反模式 WARN；关键词触发自动加载）—— 后续起 SDLC sprint 直接套此 skill
- **D3 脚手架归档**：7 个完成 sprint 目录 `git mv` 到 `docs/sprint/_archive/` + INDEX.md；保留 `_template`；清 32 个 stale worktree

## 流程
- pm-helper 三刷 PRD v1→v3 + reviewer 二轮 9 挑刺（round1 7 / round2 2）crossfire 闭环 reply_count 2/2
- Owner 软门 1：OQ-1=skill / OQ-2=git mv _archive / OQ-3=直接改 spec / OQ-4=只复盘前 7 / OQ-5=§4.1 子步骤 2a
- dev-senior 5 commit Phase 3（master HEAD `86e3f2dd`）；memory-keeper Phase 5 sprint-report + memory 路径失效清单
- 归档后 6 个 `project_sdlc_*` memory 共 9 处 `docs/sprint/<id>/` 路径已 main session 改为 `docs/sprint/_archive/<id>/`

## 教训 #1：蓝军「路径冲突」类误报须实路径核实，不凭逻辑推断
reviewer round1 #3：逻辑推断 `CLAUDE_CONFIG_DIR=~/.claude-work/` 会影响 skill 加载，判 OQ-1 路径 `~/.claude/skills/` 错。main session 实跑 Glob：28 个 newworld skill 全在 `~/.claude/skills/`，`~/.claude-work/skills/` 不存在 —— 误报。**两个机制名字相似（配置目录 vs skill 加载路径）不代表互相影响，读实目录才是 ground truth**。是 [[CLAUDE.md Lessons Learned]]「诊断冲突查实代码仲裁」+ [[feedback_agent_team_crossfire]]「crossfire 双向」的又一实例。

## 教训 #2：批量改动 AC 用 grep 命令不用静态数字（已 sink CLAUDE.md）
reviewer round1「5 文件 8 处」→ PRD v2 照抄 → round2 实测「6 文件 9 处」漏 1 文件。批量改动 AC 只写 grep 命令、执行时以实跑输出为准。已 sink [[CLAUDE.md Lessons Learned]]。

## 教训 #3：spec 多段落对同一流程描述须交叉一致
OQ-5 选 B（Phase 0 作为 Phase 1 子步骤）若只改 §17 教训段、不改 §4.1 操作流程，读者按 §4.1 操作永不执行 recon 子步骤 —— spec 内部脱节。dev-senior D1 实施时主动在 §4.1 步骤 2/3 间插入步骤 2a，避免脱节。规则：spec「选项 X 落地」需同步检查所有引用该流程的段落（§4.x 操作流 / §11 验证 / §17 教训）一次性改齐。

## 里程碑：SDLC Agent Team v1.0 收官
W3→LSP-2→E→F→BD→D 六连真业务 sprint + frontend-perf/lsp-cleanup 两 dry-run = **7 sprint 实战验证**，覆盖 dry-run / 纯删除 / 类型补全 / 行为相邻迁移 / 设计决策型（×2）五类改动，D-sprint 首次走完 Phase 4 真生产部署。pipeline 普适性确认，spec 升 v1.0。后续起 SDLC sprint 直接用 `newworld-sdlc-agent-team` skill，不必重学流程。

## 关联
- spec v1.0 `docs/superpowers/specs/2026-05-14-agent-team-sdlc-design.md`（定稿对象）
- 复盘 `docs/sprint/_archive/2026-05-16-sdlc-closeout/RETROSPECTIVE.md` + sprint 产物 `docs/sprint/_archive/2026-05-16-sdlc-closeout/`
- skill `~/.claude/skills/newworld-sdlc-agent-team.md`（D2 交付）
- 7 sprint memory（均已更新 `_archive/` 路径）：[[project_sdlc_w3_dryrun_2026_05_15]] / [[project_sdlc_lsp2_2026_05_16]] / [[project_sdlc_e_sprint_2026_05_16]] / [[project_sdlc_f_sprint_2026_05_16]] / [[project_sdlc_bd_sprint_2026_05_16]] / [[project_sdlc_d_sprint_2026_05_16]]
- 归档索引 `docs/sprint/_archive/INDEX.md`

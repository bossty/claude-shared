---
name: project_xvideos_best_onboarding_2026_07_14
description: BL-64(原BL-60/63) xvideos best榜接入+20类分类金标1353条,已合master 2aeca89a5;BL-65部署段已完成(migration+data jar+dry-run两轮PASS),挂dry-run待开真采;评测补强待排期
metadata:
  type: project
---

**BL-64（2026-07-14 收口，编号两迁：占坑 BL-60 被 madou 会话先推占用→改 BL-63 又被 pre-push 轻门会话先推占用→定格 BL-64）。已合 master `2aeca89a5`（--no-ff，慢门后端 2214 tests 0 failures + 前端 web 111/admin 30 测试文件全绿），BACKLOG 收口 `7e6089dca`，分支/worktree 已按 merged+pushed 双验清理。**

**BL-65 部署段已完成（2026-07-14 Owner 授权）**：migration 已跑（best 两行 mandatory→NULL 核对过，ledger `dbef15d26`）；data jar 部署 ca-admin `deploys/20260714-061232-5dd7fd370.jar`（jar 内 BestTask.class/dry-run-slugs/yyyy-MM 三探针 True，启动 0 ERROR）；data.env +2 键（`APP_CRAWLER_XVIDEOS_BEST_ENABLED=true`/`APP_CRAWLER_XVIDEOS_DRY_RUN_SLUGS=xvideos_best`，备份 bak-*-bestdryrun）；dry-run 端到端两轮 PASS（手动 crawl-monthly 27 部 skipped 零入库 + cron HKT 18:30 准点开火，movie 前哨 44513/118750 不变，DRY-RUN 逐条日志证 region 规则+LLM+forbid 管线真跑）。hanime is_uncensored 影响面查清=前台零消费、仅后台编辑框字段，无阻塞。**现挂 dry-run 态每小时空转，开真采=删 DRY_RUN_SLUGS 键+restart，待 Owner 拍板。**
详细状态：`docs/sprint/2026-07-13-xvideos-best-onboarding/SESSION-STATE.md`

## 前置已收口
region 金标分支 `fix/goldset-blockers`（21 commit，已上线一天但一直没合）**已合入 master `372db27c1`**（2201 tests 绿），分支/worktree 已清。

## best 榜「零入库」的真根因（四个叠加）
1. **代码层零调用** —— 两行 `xvideos_channel_config`（enabled=1）是**孤儿**，唯一驱动配置驱动渠道的 `Hanime1ScheduledCrawlTask` **硬编码** 8 个 hanime1 slug。补 `XvideosBestScheduledCrawlTask`（默认关）。
2. **`{date}` 格式** yyyy/MM（斜杠）→ 源站 **301**（buyvm 实测；横杠版 200/27 块）。且既有单测 fixture **把 bug 当成了期望值**（写死 `2026/04`）→ 测试一直绿、生产一直 301。
3. **★ mandatory 双通路** —— `finalizeMovieWithDispatch` 把渠道配置的 `mandatory_category_names` **无条件 merge、绕过 `applyCategoryForbids`**。best 配着「无码解放,国产剧情」→ 每部欧美/日本/3D 片都会被打上「国产剧情」。修法：抽 `ContentAnalysisService.forbiddenCategoryNames(region)` 纯静态函数两路共用。**实测破坏力：国产剧情 F1 A0(未修)0.206 → A(修复)1.000。**
4. **off-by-one**（蓝军逮到）—— `crawlByMonthRange` 循环传 0-based 但 `renderListUrl` 契约 1-based → best（0-indexed）3 页实际抓 `/0 /0 /1`（首页双抓、末页永不抓）。**与 {date} bug 在同一个函数里，我修一处时没通读其他参数流。**

## 分类金标（1353 条，data/goldset/）
8 月 best 语料 23111 部 → Tier A 复标600 + B 真随机400 + C 稀有类过采样353。三配置在**生产真实 gpt-4.1+prompt**（buyvm relay）上评测。

**关键结论**：
- 生产判 20 个分类的唯一输入是 `(region=xx) 标题` —— **源站 tags 一个都没喂**，且 prompt 里 20 类**零判据**。
- 喂 tags macro F1(16类) +0.05~0.07，属性类召回大涨（男友视角 0.30→0.59）。**但这是「一致性上界」非准确率增益**（真值与配置同源，见 [[reference_goldset_truth_config_same_source_circularity]]），且缺「判据入 prompt」对照 → **不能直接拍板采用**。
- **★★ 无码解放口径冲突**：Owner「凡无马赛克就打」与生产 prompt「cn/western 禁无码解放」**直接打架** → 修复后该类 F1 暴跌 0.757→0.057。光清渠道配置不够，需加 region mandatory + **捆绑删 prompt 冲突规则**。
- 「素人自拍」best 榜候选 8191 部但生产库只有 408 → **没打上，不是没采到**；男同/人妖/伪娘/中文字幕 = best 榜**结构性没有**（靠 xvgay/xvtrans 专用渠道）。

## 生产侧发现（未修，可另立 backlog）
**LLM 批量模式 100% 失效**：`response_format=json_object` 决定模型**返回不了数组**（顶层必须是 object），而 prompt 要求「多条返数组」→ 每批必然结果数不匹配 → **必然走逐条降级重试**。实测喂 10 条只回 1 条。净效果：每 10 条**白烧一次批量调用 + 15s sleep**。
另：LLM 会给同一部片同时打「角色剧情」+「直接开啪」（prompt 没写互斥）→ 这就是生产库 **1606 部自相矛盾**片的产生机制。

## Owner 6 项拍板结果（2026-07-14，全按推荐）
1 无码解放实现（region mandatory + 删 prompt 冲突规则）+ 5 `is_uncensored` 硬编码（western/cn→1、jp 按信号、anime/3d→0）**已实现合 master**（79 测试绿）；2 采用 B 暂缓（先补配置 D 四方对照+tag 真值视觉校准）/ 3 直接开啪硬规则 / 4 异源标注复检 / 6 B 上线 scope 限 best → **全部下阶段 = BL-65**。⚠ 第 5 项部署影响面：存量 hanime（anime/3d）片 is_uncensored 1→0，**部署前必查前端是否按该列筛选**。

## 教训
- **每完成一个可测单元立即 commit**：allowedMandatoryCategoryNames 重构 + 4 测试跑绿了却**悬在工作树没提交**，被蓝军逮到「跑绿的验的是工作树不是 commit」。
- **dry-run 这类「安全门」必须想清它管不到什么**：本次两个洞——① 全局 boolean 开关注在抽象基类 → 生产开它预演 best 会**静默关停 hanime1** 采集且监控不报警；② `cleanupIncompleteMovie` 在 dry-run 断点**之前**执行 → 「只读预演」会**删存量 R2+DB**。改按 slug 白名单 + 跳过 cleanup。
- **★ 占坑/改号只落在分支 = 等于没占**（本工作连撞两次号的根因）：BACKLOG 纪律 5 要求占坑「单独 commit + push」——push 的是 master 才对其他会话可见；上会话把 BL-60→BL-63 改号只 commit 在 feature 分支里，master 上无痕 → 轻门会话按 master 最大号又取了 BL-63。**编号变更与占坑同权重，必须走 docs 轻门直接推 master。**

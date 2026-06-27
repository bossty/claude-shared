---
name: reference_crossocean_read_methodology_2026_06_25
description: 跨洋读 sprint 沉淀的可复用方法论 — identity-based检测不可误报/tcpdump读写分类查premise/web部署baseline陷阱/三轮蓝军各抓真bug
metadata: 
  node_type: memory
  type: reference
  originSessionId: 6eecae1c-95e0-4231-a84e-4ccc79979b6c
---

来自 [[project_crossocean_read_guardrail_2026_06_25]] 的跨 sprint 可复用方法论:

- **"运行时 identity-based 检测不可能误报"是反驳"false positive"的硬逻辑**:L2 按【连接物理 host==跨洋 master】计数,一条 readOnly→slave 的读物理上走 slave 不会被计。dev 把 #4 movie_tag 标"false positive"(只查了 TagService 三方法全 readOnly),lead 用此逻辑驳回→查到真源在 common embedding 子系统(HighFreqTagLoader/EmbeddingTagRecall @PostConstruct 启动全表读)。**检测器报了就是真的,先找漏的 caller 别急着判误报**。

- **先 tcpdump 实证 premise 再决定要不要建护栏**(铁律"输入材料也需 fact-check"):阶段4 workflow 称 Redis 有跨洋读泄漏→tcpdump eu→CA Redis(.128:6379 明文 RESP)按命令分类(GET/MGET/ZRANGE=读 vs SET/INCRBY/HSET=写)→实测读到 master 仅 5(RYW),写数千 → **Redis 读路径已落本地 replica,零泄漏,省一整层重型 Lettuce 护栏**。同理诊断"是读还是写跨洋"用 performance_schema/tcpdump 按 SELECT vs INSERT 分类(MySQL 当初也是这样确认读漏)。

- **web 生产部署 baseline ≠ master ≠ 工作分支 HEAD**:prod web jar 从某个 commit build(无 git.properties,靠 `.bak-pre-<sha>` 命名 + `git diff` 内容比对定 baseline);本 sprint baseline=master 0337ac59(当时),但工作分支 gfw-breakthrough-arch 领先 +3560 行 GFW WIP——**从工作分支 HEAD build 会把未上线 WIP 上 prod**。建分支务必 off 实际 deployed baseline。6 节点全用 md5 比对确认 baseline 一致(防 stale region 节点)。

- **region 判定用 IP /16 子网法**(节点 region 不在 jar 配置、只在 systemd Description):比 master host /16 vs 本机所有非 loopback IPv4,无一匹配=跨洋 remote=region 节点。**drop-in 无关**(即使 SLAVE_URL 丢了也能判),这是堵"塌缩池"洞的根。

- **三轮蓝军各抓一个单轮会漏的真 bug**:① @Autowired MeterRegistry 字段时序→早期 dataSource bean 创建时 null→首条 master SQL afterQuery NPE 炸全站 DB(改方法参数根除);② CORS 改走 SettingsReadCache(5min TTL)使新域 staleness 60s→6min=用户可见 403 回归(缩 TTL 到 60s);③ dev 给 @PostConstruct 自调用方法加 readOnly 不生效(自调用旁路代理)。**生产高爆炸半径改 datasource 装配,蓝军 + 金标 canary(先 1 CA 验 proxy 不破查询+Hikari指标存活,再 1 EU 验 fail-closed 不误触+受控移除 SLAVE_URL 验真拒启动)缺一不可**。

- **git 多会话 master 集成**:master 被另会话 worktree(/home/test/nw-h2)checkout 时 `git branch -f master` 会 fatal 拒绝;正确=从那个 worktree 内 `git merge --ff-only`(其 working tree clean 时安全)。集成走【temp 分支 merge+全量 test 验过→才移 master】,先 `git tag archive/master-pre-*` 兜底。`git branch -d` 对 merge commit 过保守会拒,确认 master 已含则 -D。**删 temp 分支前别先删(我误删 integrate-xocean 致 merge commit 悬空,靠记着 SHA `git branch <name> <sha>` 救回)**。

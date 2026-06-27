---
name: W4-S02 hotfix-3（2026-05-02）部分闭环 + V5.1-B cutover 仍悬空
description: 5/2 4 个 S 域名 500 → DNS 摘 aws-s 止血 → 真根因 W4-S02 部署遗漏（require 链断）→ commit fec6e99a 修 origin REDIS_PWD env 名 → DNS 回填。但 W4-S02 完整 V5.1-B cutover（admin/web JAR + DB + frontend）仍未做
type: project
originSessionId: fe398321-ee74-4942-9f53-cfbb4ac5e1d8
---
2026-05-02 hotfix-3 5 个域名间歇 500 事故全程：

**根因**：W4-S02 sprint commit 634e3d4 部署不完整。两层问题：
1. host_channel.lua + retry_token.lua 没 cp 到 aws-s → require 链断 → 100% 500（DNS 三 IP 轮询 ~33% 用户中招）
2. origin web.nginx.conf 第 77 行 `REDIS_PWD` env 名错（应 `REDIS_PASSWORD`）→ s_channel_agent NOAUTH 累计 54 万行噪音 + cache pubsub 失效降级

**已闭环**：
- DNS 摘 aws-s + 回填（CF API 全程，rollback JSON 在 aws-data:/tmp/dns-rollback/）
- aws-s/usca-1/usca-2 三台 cp host_channel.lua + retry_token.lua 已就位（hotfix-3 自愈时手动 cp + reload）
- commit fec6e99a 改 web.nginx.conf REDIS_PWD → REDIS_PASSWORD，已 push，aws-web-01/02 已 reload，新 worker NOAUTH=0

**未做（V6/V7 sprint 决策）**：W4-S02 完整 V5.1-B cutover——admin 端 StatsHmacSecretInitTask + HmacSecretHolder + RetryTokenCodec + AnchorTargetController 未部署，DB 缺 STATS_HMAC_SECRET_V51 行，frontend dist 没 retry-cookie 字段，hmac_secret_agent.lua 未上 origin，nginx.conf 没 require。当前 v5.1-B retry-cookie HMAC 校验降级到 RESERVED bucket，功能不完整但不报错。

**Why**：commit message 自己说"部署: 不部署生产，B.3 cutover 一起"。今天清债选项 A 是清噪音 + 修一致性，没扩到 sprint cutover——cutover 决策属于 V6/V7 owner 拍板。

**How to apply**：
- 后续如果 owner 决定 V5.1-B cutover，参考 commit 634e3d4 + scripts/v51_b_cutover_smoke.sh + docs/recon/p9_task_prompt_v5_1_b_*.md
- 期间 retry-cookie 功能保持 RESERVED bucket 状态，monitor 不报警，可观察 60d
- 如果观察期 retry-cookie 用例确实需要，再单独派 sprint
- 另外两个低优 followup：（a）s_channel_agent.lua 加 ngx.worker.exiting() + 显式 close（覆盖 newworld-lua-redis-pubsub skill）（b）**纠正**：`openresty/conf/nginx-web.conf` **不是过时副本**，是 V5.1-B cutover 待部署版（含 hmac_secret_agent）；2026-05-02 commit 9ac05278 已修 REDIS_PWD typo 与 fec6e99a 对齐，避免 cutover 时漂移
- 5/2 自动化治理：commit e9f42807 加 `scripts/lint-env-names.sh` env 名一致性 lint（pre-commit + CI），抓出 nginx-web.conf typo（fec6e99a 漏修）

## 5/2 全程闭环（hotfix → 自动化治理 → V6/V7 audit → closure 反审计）

5/2 当天 P9 推进路径超出 hotfix 范围，演变为 V6/V7 sprint 状态复核 + closure 审计反审计 + 治理沉淀。

### 8 commits 总账
1. `fec6e99a` hotfix-3 修 origin REDIS_PWD（真根因 W4-S02 部署遗漏）
2. `e9f42807` feat(lint): env 名一致性检查（pre-commit + CI）
3. `9ac05278` fix: nginx-web.conf typo（lint 抓出 fec6e99a 漂移）
4. `71c7d0f1` feat(admin): health-check 一键挂起开关（**待部署**）
5. `86ebb08f` docs(stats-v7): closure saga + Outlook 段修订
6. `ae09c2ec` docs(claude): closure 残余虚报 + `newworld-sprint-closure-audit` skill（合并 commit）
7. `9d95d4df` 撤销 AnalyticsV5Metrics ⚠️ 错改（审计 P8 第 1 误判）
8. `5346648a` 撤销 F3 ⚠️ + §1 红字重写（审计 P8 第 2-3 误判）

### V7 closure 真实状态（反审计后修订）
- **真虚报 2 项**：C-2 Outlook 默认关 + HomeEmailBanner.vue 0 文件
- **审计 P8 自误判 3 项已修订**：saga 永久取消 / F3 后端 11/11 tests pass / AnalyticsV5Metrics 已迁
- **实质完工度 ≈ 80%+**，仅 C-2 启用 + HomeEmailBanner 实施待 owner 业务决策

### 沉淀产物
- 4 条 memory（saga / Lua require / env 名 / DNS 摘填）
- 1 个 skill：`newworld-sprint-closure-audit`（CLAUDE.md 一级 16 个）
- 1 个 lint 工具：`scripts/lint-env-names.sh`（防 env 名漂移再发）
- 1 个 admin endpoint：health-check 一键挂起（防 hotfix 期间污染域名健康度）

### 待派 backlog（按时序）
- **5/9** 派 P7 准备 _rp legacy 清理 PR（5/11 deadline，7 文件清单：RetryTokenCodec / HostChannelParser / IdentityContext / IdentityInterceptor / VisitorAliasWriter / lua/retry_token.lua / RetryTokenCodecTest）
- **owner 择时**：71c7d0f1 admin 部署（凌晨）+ V5.1-B 完整 cutover（连 V7 cutover 合并跑）
- **owner 业务**：C-2 Outlook plan E 启用 + HomeEmailBanner 实施
- **可选**：lua 模块 5 VPS md5 一致性 lint（防 require 链断雪崩重演）+ s_channel_agent.lua 加 ngx.worker.exiting 显式 close（旧 worker NOAUTH 拖尾洁癖）

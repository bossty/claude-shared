---
name: project-openai-relay-aws-us-2026-05-25
description: OpenAI relay 从 BuyVM-data 迁移到 AWS US (us-east-1) sprint 全程 — title 翻译挂的真凶 + 选型决策 + 实施 + 38 条 backfill + 教训
metadata: 
  node_type: memory
  type: project
  originSessionId: e64cccd6-8800-4ac5-ac22-fff43a7b0395
---

# OpenAI Relay AWS US 迁移 sprint（2026-05-25）

## 故障真凶（fact-check 实证链）

5/24 开始 aws-data 入库视频日文 title 不再翻译，CJK 比例 24h 71%（之前 ~30%）。

```
真凶链：
aws-data EIP/NAT 出口    BuyVM ufw 白名单
16.162.253.75 (5/24 前) ←─ ALLOW 16.162.253.75 ✅
                ↓ 漂移
18.167.41.192 (5/24 后) ←─ ALLOW 16.162.253.75 ❌ → DROP 静默丢包
                              ↓ timeout 30s × 5 retry 全失败
                          LlmContentAnalysisService fail-soft
                          → TextConvertService.toSimplified() 仅繁简
                          → 日文 raw title 留底（28/41 含 CJK）
```

**关键 fact-check（按 owner mindset 不凭印象）**：
- aws-data → 209.141.48.177:443 `nc -zv` = `connect timed out`（DROP 特征非 RST）
- BuyVM-data 本地 nginx 70 天 uptime 没崩（ssh `ss -tlnp` 实证）
- BuyVM ufw `sudo ufw status numbered` 实证 `[22] 443/tcp ALLOW IN 16.162.253.75` —— 老 aws-data IP
- aws-data 当前真出口 `curl ipify` = `18.167.41.192`（漂了）

**漂的是源端不是目的端** —— 这次教训跟之前那些"目的端 IP 漂"的诊断思路反向。

## 选型决策（揪头发 3 条路）

| 方案 | 工作量 | 治本度 | 漂移风险 |
|------|--------|--------|---------|
| A 救火 ufw allow 新 IP | 5 min | 治标 | 中（EIP 再漂再修） |
| **B AWS US relay (Owner 拍板)** | 4-6h | 治本 | 低（AWS EIP 锁死 + token 鉴权代 IP 白名单） |
| C Cloudflare Worker 反代 | 30min | 治本+提速 | 无 |

**Owner mindset 拍 B 的真意**："不依赖第三方 VM + EIP 不漂"——但要揪头发分清：
- 漂的是**源端 aws-data 出口 IP**，不是 relay 侧 IP
- 如果 B 方案仍走 IP 白名单 = 没解决漂的根因
- **真治本：token 鉴权代替 IP 白名单**，aws-data 出口 IP 漂也不影响

## 实施颗粒度（最终架构）

```
aws-data (HK)
  → POST https://3.222.179.128/v1/chat/completions
     headers: X-Relay-Secret + Authorization Bearer
  ↓ 公网（HK→US ~155ms RTT）
aws-proxy (us-east-1, EIP 3.222.179.128, t4g.small)
  ↓ nginx 反代 + token 校验 + 444 静默 drop
  → POST https://api.openai.com (US 出口不被地理封禁)
```

**关键事件时间线**：
- 16:00 Owner 拍板方案 B；console 开 EC2 / Allocate EIP
- 16:05 SSH 通；relay nginx 装 + 自签 cert + token 校验
- 16:10 内核 sysctl BBR + ulimit + nginx restart
- 16:15 N9E categraf arm64 装 + heartbeat
- 16:18 nginx logrotate daily/7d
- 16:20 Java 改代码：`RELAY_HOST_TRUST_BYPASS = "3.222.179.128"` + `CONFIG_KEY_RELAY_SECRET` + 两处 HttpRequest builder 加 X-Relay-Secret conditional header
- 16:25 mvn build + scp + system_config UPDATE OPENAI_ENDPOINT + INSERT OPENAI_RELAY_SECRET
- 16:28 启 newworld-data active；E2E smoke「美少女戦士」→「美少女战士」gpt-4o-mini 200
- 16:30 backfill id>69234 共 41 条 → ok 38 / fail 0 / skip 3

**关键 commits**：未 commit（实施期间，等 sprint 收尾一起 commit）

## OpenAI 用量实证（admin key 5/25 拿到）

```
近 30 天累计: $24.04
近 90 天累计: $64.52
近 365 天累计: $64.52  ← 4 月前无数据，账号 4/25 才开始用
```

**每日费用曲线印证 BuyVM 故障真凶**（5/8-5/25）：
- 04-25 ~ 05-04: $0.01-0.33/d 低活跃
- 05-07 ~ 05-11 高峰: $1.93 / **$6.29** / $3.05 / $1.96 / $2.52（对齐 javxx + cableav + hanime1 扩源 sprint）
- 05-12 ~ 23 稳态: $0.45-1.15/d
- **05-24 $0.26 / 05-25 $0.13** ↓↓ — 不是用量减少而是 OpenAI 调用根本没出去，与 nc timeout / journalctl timeout / ufw 白名单失效 形成**第 3 个独立信号源印证**故障真凶链

**揪头发**：余额 API（`/v1/dashboard/billing/credit_grants`）即使 admin key 也拿不到，只能 platform → Settings → Billing 浏览器看。OpenAI 没把 billing balance 开 admin scope。

## sprint 教训（沉淀候选）

1. **"EIP 不漂"要先揪头发漂的是源端还是目的端**：BuyVM relay 侧 nginx 70d 不崩、IP 没动；漂的是 aws-data 出口 NAT EIP。源端漂时 IP 白名单是脆弱方案，token 鉴权 + 444 drop 才是真治本。

2. **跨 region VPC peering 必先看 CIDR 冲突**：AWS 所有 region 默认 VPC 都给 `172.31.0.0/16`，跨 region peering 硬约束两端 CIDR 不重叠。要么新建非默认 VPC 用 `10.20.0.0/16`，要么放弃 peering 走 EIP 公网。本次走公网 + token 鉴权绕过这个坑。

3. **`nw-dev` IAM 只有 `ec2:DescribeVpcs` 不够开实例**：需要 `AmazonEC2FullAccess` + `AmazonVPCFullAccess`；本次走 Owner console 自开（Step 4 我接管 nginx/data 切量）。长期治理建议给 nw-dev 加 policy 让 CLI 闭环。

4. **OpenAI key 分两层 secret vs admin，secret 永远拿不到 usage/billing**：
   - `sk-proj-...` (secret) 调 model API
   - `sk-admin-...` (admin) 查 usage/billing/members
   - secret key 调 `/v1/organization/usage/completions` 返 403 `Missing scopes: api.usage.read`
   - 要在程序里查用量必须新建 admin key（最小权限只勾 `usage.read` + `models.read`）

5. **EC2 stop/start 升配 EIP 自动保留 + EBS 持久化全保留**：Owner 升 t4g.nano → t4g.small（升内存）过程中：nginx auto-start enable / cert + secret 文件 EBS 不丢 / EIP 不变。但 instance public DNS 会变（不影响 EIP）。验证抓手：`ssh aws-proxy` 通 + `nginx is-active`。

6. **AWS metadata IMDSv2 需 token，bash 一次性脚本里别裸取 metadata**：`curl http://169.254.169.254/latest/meta-data/public-ipv4` 在 IMDSv2 默认拒 → 返空 → 后续命令字符串拼接错（这次 cert SAN `IP:,DNS:...` 语法错）。硬编码 EIP 或先 PUT token 取 IMDSv2 session 再 GET。

7. **nginx default_server 加 `ssl_reject_handshake` 会干掉所有 SNI 包括自家**：`server_name _;` 在没 default_server 时优先级低，新加的 `ssl_reject_handshake` server 抢了 default_server 角色 → 所有 https 入站 TLS 层就 reject。解法：主 server 自己标 `default_server` 即可，不需要单独的 reject server；"非自家流量全拒"靠 token 校验 + `return 444` 闭环。

8. **"非自家流量全拒"用 444 静默 drop 而非 403**：扫描器看到 403 知道服务在 → 可暴破 token；444 close-without-response → 扫描器拿不到 fingerprint。配合 `limit_req_zone 60r/s` 防 token brute force。

9. **categraf arm64 binary 不能从 aws-data x86_64 scp**：必须按目标架构下 GitHub release（`categraf-v0.5.6-linux-arm64.tar.gz`）。配置目录 `/etc/categraf/` 可以跨架构 scp，需改 `hostname/region/dc`。

10. **MyBatis ORM 抽象层与 DB 真实列名分离**：`system_config` 表真实列 `config_key`/`config_value` 不是 `key`/`value`；service 层 `getValue(key)` 内部转 `config_key`。直接写 SQL 必先 `DESC` 看真列名，凭印象写 `WHERE \`key\`=...` 会报 `Unknown column 'key'`。

11. **同模型 backfill 复用 service prompt 颗粒度最小**：38 条 backfill 走独立 Python 脚本（非侵入主代码），prompt + model 完全 copy `LlmContentAnalysisService.translateTitle`（gpt-4.1 + 同 system prompt）。结果质量 ok=38/41，3 skip 是本身已中文。"backfill 不污染主代码"（5/25 广告图 sprint 沉淀的铁律）再次实证。

12. **OpenAI key 真值意外暴露在 agent context 教训**：`SELECT config_key, config_value FROM system_config WHERE config_key LIKE 'OPENAI%'` 把真 key 回显进 context。虽然 context 只存本会话不外泄，但 owner mindset 安全卫生角度建议 **rotate 一次**（platform.openai.com → API keys → revoke + create new + UPDATE system_config）。

## Backfill 三批闭环（v1+v2+v3）

| 批次 | 范围 | 跑 | ok | skip |
|------|------|---|----|------|
| v1 | id > 69234 含 CJK | 41 | 38 | 3 |
| v2 | 近 1 周亚洲源（含 hanime/jable/javxx）无汉字 | 12 | 10 | 2 |
| v3 | 5/24 22:07+ **全 source 除 cableav**（含 beeg western）| 17 | 16 | 1 |
| **累计** | - | **70** | **64** | **6 唯一 2** |

**Owner 反诘揪头发**：v2 前我凭印象排除 beeg/西方源认为"western 用户预期英文"——**错判**。owner 抛 5 个具体 id (69372/69364/69354/69353/69346) 实证 4/5 是 beeg —— **底层逻辑**：cron `ContentAnalysisService.detectLanguage("ASCII>70%")` 不区分 source，全 source 都该翻。修脚本 v3 去掉 source 排除 → beeg 15 全翻 + 总剩 2 条 LLM 合理 skip（IP 名 + 角色名）。

**Sprint α 告警链路 (5/25 20:30+)**：
- Java `LlmContentAnalysisService` 加 `MeterRegistry` + 2 Counter `nw_openai_llm_failed_total{phase=translate_title|analyze_batch}` + @PostConstruct 静态注册（commit `26169216`）
- categraf `input.prometheus.toml.tmpl` 修源：注释明说 data 19999 但 urls 漏配（≥1 月历史 bug），加第二个 `[[instances]]` job=newworld-data-actuator
- N9E alert_rule id=68 `OPENAI-LLM-FAIL` severity=1 prom_for_duration=180s rule_config `sum(increase(nw_openai_llm_failed_total[5m])) > 3` notify_rule_ids=[1] → ops-telegram chat -5238565076 "事件预警 - 17"
- Telegram bot 直推 message_id=20062 + Owner UI 双 verify N9E rule 真见

## Sprint α 回滚（5/25 21:30+ owner 揪头发反诘后撤 aws-proxy）

**owner 反诘**："aws-proxy 完全没有存在的必要了"——揪头发指出 sprint 顶层设计 over-engineered。

**3.25 自评真凶链**：
- 原 BuyVM 故障真凶 = aws-data 出口 EIP 漂（源端） + BuyVM ufw 白名单源 IP stale → 一行 `ufw allow from <new IP>` 即修
- 我推荐方案 B（AWS US relay）理由失实：
  - ❌ "不依赖第三方 VM"：BuyVM-data nginx 70d uptime 没崩，可靠性不是问题
  - ❌ "EIP 不漂"：漂的是 aws-data 源端，不是 BuyVM 目的端，AWS 实例同样会漂 NAT IP
  - ✅ "token 鉴权代 IP 白名单"：这条是真价值，但**用 BuyVM 也能做**（只需加 X-Relay-Secret nginx 配置）

**Sprint α 实际成果**：
- BuyVM-data 加 OpenAI relay nginx + 自签 cert + 444 静默 drop + token 校验（移植 aws-proxy 那套架构）
- ufw allow 18.167.41.192 → 443
- system_config OPENAI_ENDPOINT 改回 `https://209.141.48.177/v1/chat/completions`
- Java `RELAY_HOST_TRUST_BYPASS = "209.141.48.177"`
- E2E 真翻译「美少女戦士」→「美少女战士」200
- aws-proxy 终止 + EIP 释放（owner console），省 $6/月

**新增教训**：
13. **AWS datacenter IP (AWS / GCP / Azure) 被 CF / wowstream / hanime1 等反爬识别为 datacenter ASN 直接 IP 层 403**——不是 challenge 页面（FlareSolverr 解不掉），是 CF Bot Fight 内置规则。要绕 datacenter IP block 必须用**小厂家住宅 IP 池**（如 BuyVM ASN 30633 FranTech Solutions / DigitalOcean / Vultr 部分 range）。AWS us-east-1 (IAD POP) 实测 wowstream/hanime1 拒，BuyVM (LAS) 接受 (404=CF 穿过)。

14. **AWS region 默认 VPC 都是 172.31.0.0/16**——跨 region VPC peering 硬约束 CIDR 不重叠，无法建立。要么新建非默认 VPC 用 `10.20.0.0/16`，要么走 EIP 公网（这次走公网）。

15. **顶层设计决策 fact-check 失误教训**：sprint 推荐方案 B 时凭印象给"不依赖第三方 VM + EIP 不漂"两个失实理由，没揪头发真凶端（漂的是源端不是目的端）。owner 反诘后客观自评 over-engineered。规则：sprint 启动前 owner mindset"漂的是源还是目的"实测，"VM 稳定性"用 uptime 数据驱动，不凭印象。

16. **token 鉴权代 IP 白名单是真价值，与 relay 位置无关**——X-Relay-Secret 校验 + 444 静默 drop 在 BuyVM 同样可实现。这条是 sprint α 真正保留的设计资产。

## 待办 follow-up

1. ✋ BuyVM-data 上 nginx 反代 + ufw 209.141.48.177:443 规则可删（BuyVM-data 实例保留做爬虫/离线）
2. ✋ Owner 看一眼 platform.openai.com Usage / Billing → 一行字告诉我累计 / 余额
3. ✋ 可选：新建 admin key `OPENAI_ADMIN_KEY` 进 system_config → 加 cron 每天拉用量进 N9E
4. ✋ 翻译 fallback 链路（DeepL 作 title fallback / 多 region relay）—— 长期治理 sprint
5. ✋ sprint 收尾 commit（Java 改 + 脚本 + CLAUDE.md 更新一起）
6. ✋ Owner rotate OPENAI_API_KEY（安全卫生）

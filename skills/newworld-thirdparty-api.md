---
name: newworld-thirdparty-api
description: Cloudflare/NameSilo API 调用前必查最新官方文档，不得凭记忆或猜测编写 endpoint/参数。Triggers on cloudflare api, namesilo, 第三方 api, 端点, request format, dns api, domain api, api endpoint, cf api, 创建 dns 记录, create dns record, 注册域名, register domain, cf zone, cloudflare zone, api 文档, api docs, dns 记录, 域名 api.
---

> **执行机制**：靠判断力（第三方 API 必查官方文档；含 2026-05-21 0-RTT eventual-consistency 独有教训）

# Newworld 第三方 API 调用铁律

## 触发场景
本仓库 Java 代码或脚本中需调用 Cloudflare API（DNS / zone / cert / WAF / Tunnel）或 NameSilo API（域名注册 / DNS / contact）时。

## 铁律
1. **Cloudflare API**：调用前必须查阅最新官方文档 `https://developers.cloudflare.com/api/`，确认：
   - endpoint 路径（含 path params 顺序）
   - 请求方法（GET/POST/PATCH/PUT/DELETE）
   - 参数格式（body schema、query string、必填/可选）
   - 鉴权头（Bearer token / X-Auth-Email + X-Auth-Key）
2. **NameSilo API**：调用前必须查阅 `https://www.namesilo.com/api-reference` 中 **Available Operations** 列表，确认：
   - 操作名（如 `dnsListRecords` / `registerDomain` / `contactAdd`）
   - 参数名大小写（NameSilo 区分大小写）
3. **不得凭记忆 / LLM 训练数据 / 类比其它 API 写**——这两家 API schema 历史上有 v1→v4、operation 重命名、字段废弃等变更，错误调用会触发 4xx / 静默成功但行为异常。
4. **CF zone setting bulk PATCH 是 eventual consistency，不可一次跑完就信**（2026-05-21 0-RTT sprint 教训）：
   - PATCH `/zones/{id}/settings/{key}` 即时 GET 返新值，但 CF backend 持久化是异步的（数分钟到十几分钟）
   - 第一次 bulk 跑完立即 audit 可能看到大批 zone 仍是旧值（同账号大量并发 PATCH 时尤甚）
   - `modified_on` 字段对部分 setting（如 0rtt）一直返 `null`，**不能用它判定持久化**
   - 稳态确认必须：① 等 5-10 min ② 二次 bulk reaffirm ③ 跨账号分批跑（不要 154 zone 一起灌）
   - 实证：5/21 0-RTT 首跑后 A/B/C 账号几乎全 off（同账号 P+S 共享账号 100% on，看似 account-level 不可改 —— 误判）；二次 bulk + 等待 + audit 后 154/154 全 on 稳定
   - 同账号 zone 集合行为一致；独立账号要各自 reaffirm

## 检查清单
- [ ] PR / commit 含 CF/NameSilo 调用 → diff 注释处贴 doc URL（最新版）
- [ ] endpoint path / operation 名与 doc 一字不差
- [ ] 必填参数齐全（doc 标 required 的全在）
- [ ] 鉴权 header 来源是 secrets.env 注入（不硬编码）
- [ ] CF zone setting bulk PATCH 收尾必跑「等 5-10 min → 二次 bulk → audit 三次连续 stable」三步（idempotent 不等于即时持久化）

## 违反后果

- 凭记忆写 CF API endpoint → 4xx 报错或调到旧 v1 端点静默失败（CF 历史上有 v1→v4 迁移 + 字段废弃）
- NameSilo operation 大小写写错（`dnslistrecords` vs `dnsListRecords`）→ 接口返 `error 280 invalid operation`，DNS 记录未创建却日志看不到
- 鉴权头硬编码 → secrets 入 git 历史，按 secrets-management 铁律 3.25 级
- 漏贴 doc URL → 后续 reviewer 无法判断 endpoint 是否对齐当时 CF 文档版本，下次 schema 变更找不到 owner

## 源
- CLAUDE.md L7-L10

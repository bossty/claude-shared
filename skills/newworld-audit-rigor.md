---
name: newworld-audit-rigor
description: 代码审计 / 安全 review / 蓝军挑刺时的「严谨度」铁律 — finding 必须 intended-vs-implemented 双引证（文档铁律 + 代码 file:line）才成立、三类高漏报必查（SSRF·renderer-abuse / PII 流入 logs·traces·analytics / output-encoding≠input-validation）、attacker=victim 不报、豁免必"明确不报+工具证实再报"、证伪式反思过滤 pass。Triggers on 审计, audit, 安全 review, 蓝军, finding, SSRF, PII, output encoding, 误报, 漏报, 豁免, audit-suppressions, false positive, security review.
---

> **执行机制**：靠判断力（审计严谨度/漏报三类不可机制化）

# Newworld 审计严谨度铁律（2026-06-27 toolchain 调研吸收，源 phuryn/pm-skills + alibaba/open-code-review + mattpocock/skills）

> 配套 `docs/security/audit-suppressions.md`（审计前必读的抑制清单）+ `newworld-multi-agent-coord` 蓝军门禁 + `newworld-sprint-closure-audit` 抗虚报。本 skill 补的是**单条 finding 的成立判据 + 高漏报盲区 + 豁免纪律**，防"看似 bug 实误报"与"看似干净实漏报"两头翻车。

## 触发场景
- 代码审计 / 安全 review / 蓝军挑刺产出 finding 时
- 审 PR / sprint Phase 3 产物、写 audit-suppressions 条目时
- Owner 复核审计结论（真 bug / 误报 / 有意设计）时

## 铁律 1：finding 必须 intended-vs-implemented 双引证才成立（源 phuryn）

一条 finding 要被接受，必须同时给出**两端证据**：
- **intended（应该怎样）**：文档铁律 / 契约 / 注释 / schema 约束的 `文件:行号` 或原文引用
- **implemented（实际怎样）**：代码的 `文件:行号` 实证它偏离了 intended

**只有一端 = 不成立**：
- 只说"代码这样写不好" without 引用任何 intended 基准 → 是**口味**不是 finding，驳回
- 只说"文档要求 X" without 定位代码真违反 → 是**猜测**不是 finding，驳回

> 与既有 `feedback_verify_not_recall`/蓝军"文件:行号证据"同源，本条把它升级为**双锚**：现象锚（代码偏离）+ 标准锚（intended 出处）。两锚齐才算实锤。

## 铁律 2：三类高漏报盲区必查（源 phuryn high-miss classes，贴 newworld 上下文）

通用审计最常漏的三类，对 newworld 尤其致命，每次安全 review 必专门过一遍：

1. **SSRF / renderer 滥用**：能否诱导服务端去请求攻击者指定的内网/元数据地址？
   - newworld 高危面：OpenAI relay（buyvm-data nginx 443）、HLS 下载 tinyproxy/代理、爬虫 `fetchHtmlBypassCloudflare`/Playwright、S 入口 execapi 取 Host、任何 `ProcessBuilder`/`exec`/`URL.openConnection` 收用户可控输入。
   - 查：用户输入是否能进 URL host 段 / 重定向 follow / DNS rebinding；是否能打到 `169.254.169.254`(IMDS)、`172.31/172.33/172.34`(内网)、`127.0.0.1`。
2. **PII / 敏感信息流入 logs / traces / analytics**：不只看"返回给前端"，要看**写日志、写监控、写埋点、写 trace** 的旁路。
   - newworld 高危面：RUM/N9E 指标（by-pop 曾撑爆，见 `project_rum_cardinality_fix`）、web.log / access.log、stats 埋点、redirect_trace、前端错误监控。
   - 查：visitor_fingerprint / IP / token / 内网 IP / CF 账号 / secrets 是否被 log/metric/trace 捕获并落盘或外发（categraf/prometheus 出口）。
3. **output-encoding ≠ input-validation**：输入校验通过 ≠ 输出安全。要分别查**输出点**的转义。
   - 查：进 HTML/JS/SQL/Shell/Lua 的每个 sink 是否按 sink 类型转义（前端 v-html、Lua `ngx.say`、SQL 拼接 vs `#{}`、ProcessBuilder 参数）。input 白名单不代替 output 转义。

## 铁律 3：attacker = victim 不报（源 phuryn carve-out）

若攻击者能影响的只有**他自己的**资源 / 会话 / 数据（打不到别的租户、别的用户、服务端内部），则**不是漏洞**，不报：
- 用户只能 SSRF 到自己浏览器可达的地址、只能 XSS 自己的页面、只能改自己的 visitor_fingerprint → carve-out，不报。
- 但**跨租户 / 跨用户 / 触达服务端内网**就立刻升级为真 finding。
> 防止刷"理论漏洞"噪声淹没真问题——这是 audit-suppressions 的活判据，不是事后补登记。

## 铁律 4：豁免纪律（源 alibaba/open-code-review）

1. **"明确不报什么"前置**：审计开始前先声明本轮**明确不报的类别**（如已在 audit-suppressions 的、guard.lua 临时禁用相关的白名单空缺），写进产出抬头。防止反复重报已确认项（CLAUDE.md「审计时必须先读 audit-suppressions」的执行抓手）。
2. **用工具证实再报**：任何 finding 落笔前必有 `grep -rn` / `git log -S` / EXPLAIN / curl 实证命中，**实证行附在 finding 里**。不接受"我觉得这里可能"。误报根源 90% 是"依赖声明/印象而非工具实证"。
3. **证伪式反思过滤 pass**：出 finding 清单后，对每条反问一遍"我能否证明它**不**成立？"——能轻易证伪的（被某机制兜底了、被上游校验了、是有意设计）当场划掉，不进交付。pass 一遍再交 Owner，比让 Owner 逐条驳回省成本。

## 铁律 5：临时调试代码单 grep 清理（源 mattpocock [DEBUG-xxx]）

审计中如需临时加调试/探针代码，统一打标记 `[DEBUG-<sprint>]`（如 `[DEBUG-toolchain]`），收口前 `grep -rn '\[DEBUG-toolchain\]'` 一把清干净，杜绝调试代码遗留进 prod（与"删任何文件前必 grep 全仓引用面"同纪律方向）。

## 违反后果
- finding 单锚就报 / 无工具实证 → 误报，退回；蓝军单 phase 误报 ≥2 当过失指标
- 漏查三类高漏报盲区 → 安全 review 不合格，重审
- 该 carve-out 的理论漏洞硬报 → 噪声污染，扣信号

## 配套
- [[newworld-multi-agent-coord]] 蓝军门禁 + 证据传递纪律
- [[newworld-sprint-closure-audit]] 抗虚报
- [[newworld-commit-message-precision]] message vs diff 精确
- `docs/security/audit-suppressions.md` 抑制清单（审计前必读）

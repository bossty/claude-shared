---
name: admin-axios-response-unwrap
description: "admin frontend axios interceptor 对 ResponseEntity<DTO> raw POJO 直返 body（无 .data wrapper），调用方必用 `res?.data ?? res ?? {}` 双兜底"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: e70b4a45-2ab1-4fe9-840f-d033e3031a2e
---

admin 后台 frontend 调 `ResponseEntity<DTO>` 类型的后端 endpoint 时（W3b S6 起的 channel-lifecycle
/ bind-s-domain 等），调用方**必须用 `const data = res?.data ?? res ?? {}` 双兜底访问**，
不要直接写 `res.data.xxx`。

**Why**：`frontend-admin/src/utils/request.js` 响应拦截器（commit `c2dc9188` 2026-05-11 起）
对 raw POJO 返回（HTTP 2xx + 非加密 + 无 code 字段）**直接返回 res（body 本身）**，
不再保留 axios 默认的 `{data, status, headers, ...}` wrapper。所以：

- `Result<T>` 端点（code === 0 path）：`res = {code, message, data}` → `res.data` 是 payload ✓
- `ResponseEntity<DTO>` raw POJO 端点（@EncryptResponse 解密后）：`res = {channelId, jobId, ...}` →
  `res.data` 是 undefined ✗

**How to apply**：

1. 写 admin 前端新代码调后端时：
   - 看后端 controller 返回类型 —— `Result<T>` vs `ResponseEntity<T>`
   - 不确定就用双兜底 `res?.data ?? res ?? {}`（同 `ChannelList.vue:547` `bindFirstSDomain` 既有模式）
2. **单元测试 mock 用 `{data: {...}}`** 模拟 axios 原生形（兼容写法都通），但 production 拿到的可能
   是 raw body —— 测试通过 ≠ production 行为对，**改完必跑一次真实 happy path 验证**。
3. 复习类似 latent bug：W3b S6 起的 NewChannelDialog.vue handleSubmit / pollOnce 5 个月一直
   有 `res.data.jobId` 漏取 bug，单测 mock `{data:{}}` 一直绿，但生产用户每次"新增渠道"都报
   "后端未返回 jobId" —— 平时低频不暴露，5/21 加 channelCode 手填功能促使首次完整测试才发现。
   修法 commit `f1d8d6af`。

**同晚连环教训：channel-lifecycle namesilo_done 未翻位 latent bug（commit d6b5bb66）**
`ensureChannelProvisionJob` 初始置 4 flag 全 false，注释承认 "namesilo_done / cf_done 在
SDomainPoolService 翻位（未来 S5 接入）" deferred 缺口 ≥半年。cf_done 在 phase2 runDnsStep
被 markStepDoneSafe 救回，**namesilo_done 永远 0** → markJobDone WHERE 4-flag=true 永不匹配
→ status 停 pending → deriveCurrentStatus 返 "pending_ns" → 前端 TERMINAL_STATUSES 不含
→ UI 卡进度永不停。修法：channel-lifecycle 走 standby 池预留（域早期 NameSilo 注册批量买回），
namesilo step 结构上 N/A → ensureChannelProvisionJob `setNamesiloDone(true)`。

**latent bug 通用规律**（同一晚连撞 2 次实证）：
- "deferred 未来 S5 接入" 类 TODO 注释超过 1 个 sprint 没人补 → 已是永久缺口，应改成"立即用结构上等价的 true/false 兜底"或开 ticket 强制 owner
- 单测 mock 模拟 happy path 全绿不代表生产路径走通 —— 拦截器 unwrap / DB markJobDone WHERE 子句 / 后端 controller 返 raw POJO 等都是 mock 测不到的真实路径
- 改动这种功能时 dev 必须临时跑一次完整 happy path（创建 + 查状态 + 终态）—— 别只信单测绿
- 大版本部署后第一次有人完整走流程时容易暴露这类 dust（5/21 channelCode 手填功能 = 我们的促发点）

**反例**：

```js
// ❌ 这种写法 production 必爆
const res = await createChannel(payload)
const data = res.data || {}        // res.data undefined → data = {}
if (data.jobId == null) ...        // 永远 true → "后端未返回 jobId" 报错
```

```js
// ✓ 双兜底
const res = await createChannel(payload)
const data = res?.data ?? res ?? {}  // axios 原生 / 拦截器 unwrap / null 都 work
```

涉及类似改动时关联 [[s-domain-status-lifecycle]]、[[lsp-toolchain]]（验前端 await 类型对齐用）。

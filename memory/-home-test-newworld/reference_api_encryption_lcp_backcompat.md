---
name: reference_api_encryption_lcp_backcompat
description: 接口 @EncryptResponse 的性能真相(700ms糊涂账)+字段级vs整接口双轴否决+信封形状检测backcompat+WASM gate解耦原子
metadata: 
  node_type: memory
  type: reference
  originSessionId: ed36f894-57b3-4f1e-b7f5-2b5f59c3a13c
---

2026-06-14 P0-3 接口加密 RCA（node + 真实浏览器 chrome-devtools trace + 蓝军 crossfire）实证结论，供后续动接口加密复用。

**① 700ms 是查无实据的糊涂账**：commit e8135159 自述"删 9 首屏接口 @EncryptResponse 省 settings187+featured522ms LCP"——**全仓库零 profiling/trace**，只是 commit message 自述。真实浏览器实测：WASM compile 桌面0.9ms/手机6x throttle 12.5ms（一次性、并行、不阻塞首屏）；AES decrypt 149KB topics=0.19ms 亚毫秒。**真实 LCP 真凶=跨洋网络腿**（Load-delay 1785ms=81%，JS boot + 首屏 API 跨洋往返），**LCP 元素=封面 `<img>`(明文/CF HIT)，AES/WASM 不在 LCP 关键路径**。教训：性能决策必带 trace 实据，commit 自述 ROI 数不可信；"成本∝解密字节"是错前提（现代设备 decrypt 可忽略）。

**② 字段级 vs 整接口被双轴否决，选整接口**：(a) **LCP 轴**：两者差~1ms 淹没在网络腿，"字段级省78%"是省解密字节非 LCP；非首屏接口(topics/subjects)根本不在 LCP 路径，首屏(courses)compute 差~1ms。(b) **兼容轴(致命)**：见③。→ 统一**整接口信封级**恢复 @EncryptResponse。

**③ 信封形状检测=老前端 backcompat 根因**：前端 `fetch.js:12 if(result.encrypted===true)` 按**响应形状**(有无 `{encrypted:true,data:密文}` 信封)决定解密，**非按客户端版本/接口白名单**；e8135159 只改 probeGate.js+main.js、**没碰 fetch.js**、形状检测器自明文期前就在。→ **整接口信封加密对所有缓存老前端 100% 透明兼容、可裸部署、零分群出血**（这也是 e8135159 当初敢裸切明文没翻车的同一机制）。**⚠️ 字段级会破老前端**：响应仍 encrypted:false 但字段是密文字符串→形状检测见无信封→当明文渲染乱码裂。前端无字段级解密器。

**④ WASM gate 解耦必原子（BV3-1）**：`aes.js decrypt()` 同步函数、未就绪直接 throw 'WASM AES module not ready'、不调 ensureReady；原 main.js STEP3 `await bootstrapAes()` 串行 gate 其实是隐性安全机制(保证 fetch 前 WASM ready)。删它换 LCP 必同时把 `fetch.js` decrypt 前改 `await ensureReady()`，**两件原子一起改**，否则慢机首屏 API 早于 WASM ready→decrypt 同步 throw→首屏崩。本地浏览器 6x throttle smoke 实证解耦后 boot 零崩。

**⑤ BV5-1：decrypt 全调用面都要 await ensureReady（不止 fetch.js）**：修 BV3-1 时只改了 fetch.js，**漏了 `app-config.js decryptResponse()`**——同样同步 decrypt 无 await。`/settings`(=ConfigController `@RequestMapping("/api/v1/settings")` getFullConfig) 是最早 boot 调用，加密后 WASM 未就绪→decrypt throw→initConfigLayer catch→域池/CDN 丢→白屏。修=decryptResponse 改 async+await ensureReady，两处调用点(:228/:504)都加 await。**教训：修一处 WASM-gate 解密 race，必 grep 全部 decrypt/decryptResponse 调用面（fetch.js + app-config.js 两条独立路径），漏一条=白屏。** 已 2bc1efc8 修复+隧道打 canary 全栈实证加密 config 解密零白屏。

**⑥ 「所有接口都加密」≠字面全量（消费方约束）**：分前端消费(走 fetchWithTimestamp/decryptResponse 形状解密=可加密)vs**非前端消费(加了打挂消费方=必 EXCLUDE)**。EXCLUDE 三个点名：`/auth/gw-token`(SW raw fetch 无 WASM 解密器→加密挂网关JWT)、`/health`(N9E/categraf+LB健康检查→密文误报down摘节点)、`/internal/sync-seeds`(部署脚本带secret消费)；9 个 beacon 写入响应`{code:0}`加密无对象。**EXCLUDE 必落代码注释防被当漏洞重审(probeGate 式认知盲区)**。当年被撤 9 接口最终 **9/9 全加密闭环**(D 补 courses×5+topics+subjects，P0-3E 补 snack/list + settings)。已全量上线全 5 节点+真 prod 端到端零白屏。

属 [[project_detection_recon_2026_06_14]] sprint。

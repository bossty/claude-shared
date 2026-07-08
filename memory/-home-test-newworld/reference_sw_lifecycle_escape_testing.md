---
name: reference_sw_lifecycle_escape_testing
description: Service Worker 生命周期 + 前端逃生/域名失败转移的测试与实现铁律 —— SW 改动必真浏览器 e2e、SW 内存态不跨重启须 IDB 恢复、rollup 缺失导出只 warning、测试 harness 自身会骗人、老 headless SW 终止脆弱。改 public/sw.js / 逃生链 / 探针 / 域名池时必读。
metadata: 
  node_type: memory
  type: reference
  originSessionId: b9fd4d92-4512-483c-bb13-85d6f46690bd
---

2026-07-06/07 统一域名失败转移 P0（SW-primary 逃生）沉淀。**改 `public/sw.js` / 逃生链 / 探针 / 域名池 / 任何 SW fetch 拦截逻辑前必读。** 是 skill 候选（若未来 SW 改动高频，提升为 `newworld-sw-lifecycle-testing` skill，走 home→plugin 同步 + 红绿门）。

**1. SW 类改动必真浏览器 e2e，不能只 mock 单测**：本轮两个 BLOCKER（① 缓存命中路径 loadFullConfig 从缓存成功→degraded 永不置位→逃生零触发 ② SW 空闲终止后重启只重放 fetch 不重放 activate→domainPool 空）+ 时序 10s，**全是纯函数单测/mock 看不见、真浏览器 e2e 或代码+生命周期推导才现形**。`vi.mock('@/utils/migrate')` 整体替换会让"escapeTo 根本没实现"也测绿。真 e2e 用真 dnsmasq+真 TLS(SPKI pin)+真 iptables 注入死域，Chromium/WebKit 真驱动。

**2. SW module-global 不跨重启——只 `activate` 跑一次，任何 SW 内存态必须能从 IDB 按需恢复**：SW 被浏览器空闲终止后重启，只重放触发事件（fetch），**不重放 install/activate**。所以"在 activate 里 loadDomainPool() 填内存池"在"老用户回访"（SW 大概率已重启过）场景池是空的。正解=顶层 `const xReady = loadDomainPool().catch(()=>{})`（每次 SW 脚本 eval 都跑）+ 消费处 `await xReady`。对比 `apiGatewayUrl` 早有 COLD 硬编码种子防同款鸡生蛋，`apiDomains`/`promoDomains` 当年漏了。（handleApiRequest 有同款依赖，顶层 ready fix 顺带改善但未 await=残留 backlog。）

**3. 缺失具名导出在 rollup/vite 默认只是 warning（`vite build` 仍 exit 0）**：`import { notExist } from '...'` 只报 `MISSING_EXPORT` 警告、构建不失败。所以"跨模块具名导出契约破裂"整类 bug **本地 vitest（mock 掉解析）+ vite build（exit 0）都零信号，只在部署真 build 才炸**。契约门必**同时看 exit code + grep 输出 `is not exported by`/`MISSING_EXPORT`**（已落 `scripts/ci-local.sh run_fe_build_contract`，frontend-web pre-push 加此门 + `node --check public/sw.js`，因 public/ 被 vite 原样拷贝不解析）。

**4. 测试 harness 自己会骗人，先验证 harness 不能盲信第一次结果**：
- Playwright `ignoreHTTPSErrors:true` 会**吞证书错误**→ 验"no-cors 靠 TLS 证书校验挡假阳"这类断言会得**方向相反的假结论**（比不测更危险）。这类格必开独立 context 禁此项。
- 测试脚本里**同步 `execSync` 连调 sudo iptables 会阻塞 Node event loop**（本 sandbox 稳定 ~40s），把浏览器/CDP 通信饿死→探测 ERR_ABORTED。注入 iptables 要么预置在 CDP/导航窗口之前、要么异步非阻塞。
- iptables REJECT 用 `-I`（insert 链顶）非 `-A`（append 会被前置规则旁路→假阳"通过"）；用 packet counter 自证命中。DNS 污染模拟用 RFC5737(192.0.2.1)/127.0.0.2，**禁 0.0.0.0/127.0.0.1**（撞本机 leftover 服务=假阳）。

**5. 老 headless Chromium 在 SW 终止边缘路径脆弱**：CDP `ServiceWorker.stopWorker` 强制终止 SW 在 old headless 下会崩浏览器 context（连纯等自然空闲也崩）。SW lifecycle e2e 用 **xvfb-headful**（`xvfb-run -a` + `chromium.launch({headless:false})`）或 `--headless=new`。SW 逻辑不变量也可用 **Node `vm` 跑真实 sw.js 源码**在无 activate 的全新上下文验（业界 service-worker-mock 同款，非"退路"）。

**6. reach:grid 作排序先验非硬保证**：客户端 `/cdn-cgi/trace` no-cors 探测（仍走 TLS 证书校验，对 DNS 污染/SNI-RST/IP 黑洞三封锁无假阳）是最终裁判；服务端 reach 只排候选省探测 RTT。A 池 RUM 样本薄需 min-n 门。

相关：[[project_gfw_apool_rum_phase3_firetest_2026_07_02]]、SESSION-STATE `docs/sprint/2026-07-06-unified-domain-failover/`（CONSENSUS §8）、[[reference_frontend_deploy_checkout_npm_ci]]、[[feedback_e2e_real_browser]]、[[feedback_qa_safari_chrome_dual_engine]]。

---
name: project_cf_httpclient_split_b5_2026_07_06
description: B5 CloudflareApiService 上帝类拆分第一批已完成合 master 400d0db1a(2026-07-06,抽 CfHttpClient 传输层 2580→2114 行,行为逐字保持);后续批=7 资源域拆分未开工;含可复用的拆分范式与 3 个绕过点接口设计
metadata:
  type: project
---

CloudflareApiService 上帝类（原 2580 行 / 69 方法，7 类 CF 资源域 + 自建 HTTP 传输层耦合）拆分**第一批已完成并合 master `400d0db1a`**（2026-07-06，部署 ca-admin，admin 2148 测试全绿，蓝军 8 点全 REFUTED）。防未来会话误判「B5 未开工」重复立项或重跑设计：

- **已完成（批 1）**：抽出 `CfHttpClient`（admin service 包）传输层——HTTP 底座（HttpClient/超时 20s/requestBuilder）、重试（executeWithRetry/backoff/isTransientStatus）、动词 get/post/put/patch/delete、响应处理 handleResponse、认证错误检测、令牌失效告警（CURRENT_CF_ACCOUNT ThreadLocal）、指标分类 classifyOp、三个异常类迁为其 public 嵌套类。CloudflareApiService 2580→2114 行，行为逐字保持。
- **未开工（后续批）**：按资源域拆 WAF/DoH/DNS/Zone/Worker/R2/Tunnel 六七个 service，各自需单独 DESIGN；B6~B9 及其他审计 deferred 项同样未动。
- **可复用的拆分范式**：比照 B7/MovieService「只抽干净件、行为逐字保持」；**3 个原本绕过统一动词直连 httpClient 的调用点**（worker 多段上传、activation_check 无重试、deleteZone）不硬塞进动词，而是暴露窄口子 `apiBase()`/`requestBuilder()`/`sendOnce()`/`handleResponse()` 保持逐字行为——后续资源域拆分遇到绕过点照此办理。测试迁移用 ReflectionTestUtils 注入 + retrySleeper test seam 同款。
- 完整设计档原在 `docs/sprint/_archive/2026-07-06-b5-cf-http-client/DESIGN.md`，BL-111 删档后从 git 历史或 commit `400d0db1a` 找回。
- **BACKLOG 订正点**：BL-24 行写「上帝类拆分 B5-B9……未开工」与事实矛盾，应订正为「B5 批 1（CfHttpClient）已合 master 400d0db1a，B5 后续批与 B6-B9 未开工」。

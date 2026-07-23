---
name: newworld-java-pitfalls
description: Java/JVM/Maven 跨版本陷阱 — JDK 24+ HttpClient 默认拒设 Host/Content-Length/Connection/Upgrade restricted headers，需 systemd drop-in JAVA_TOOL_OPTIONS=-Djdk.httpclient.allowRestrictedHeaders=host；本地 JDK 17 测不出 → 必须 prod profile + 目标 JDK 真跑；AWS 服务器 mvn 不在 PATH，必须 export PATH=/opt/apache-maven-3.9.9/bin:$PATH。另：JDK HttpClient 无 per-client DNS override（`addressResolver` 不存在于 JDK 17/21/25，仅 JDK-8328286 提案；`localAddress` 只绑源地址；`InetAddressResolverProvider` SPI 是 JVM 全局不可接受）→ 保留 hostname+/etc/hosts 或换 OkHttp/Apache HC5。Triggers on httpclient, HttpRequest.Builder, restricted header, host header, content-length, jdk.httpclient.allowRestrictedHeaders, JAVA_TOOL_OPTIONS, systemd drop-in, picked up java tool options, mvn 找不到, mvn command not found, /opt/apache-maven, maven path, jdk 24, jdk 25, addressResolver, InetAddressResolver, InetAddressResolverProvider, per-client DNS, DNS override, SNI override, EdgeSyncService, /etc/hosts hostname 映射.
---

> **执行机制**：靠判断力（JDK 跨版本 restricted header 等陷阱）

# Newworld Java/Maven 跨版本陷阱铁律

## 触发场景
- 写 / 改 Java 代码用 `java.net.http.HttpClient` 设 Host / Content-Length / Connection / Upgrade header
- 部署后 Controller 抛 `IllegalArgumentException: restricted header name: Host`
- AWS 服务器手动跑 `mvn ...` 报 `command not found`

## 1. JDK HttpClient restricted header（2026-04-22 事故硬化）

**背景**：v3.3 Wave 7 `OpsController.probeSDomain()` 做 TLS SNI override（直连 IPv4 + `Host: hostname`），用 `HttpRequest.Builder.header("Host", host)`。**JDK 24+** 默认拒设这些 restricted headers，运行时 `IllegalArgumentException` → `/probe-s-domain` 返 `ok:false`，Wave 7 reverse probe 降级。修复走 systemd drop-in + `JAVA_TOOL_OPTIONS=-Djdk.httpclient.allowRestrictedHeaders=host`。

铁律：
1. **写 Java HttpClient 代码前**，Controller / Service 顶部注释列所有要 override 的 restricted header（Host / Content-Length / Connection / Upgrade 等）
2. **同一 commit 必须同步产出 systemd drop-in 配置片段**（`/etc/systemd/system/<service>.service.d/*.conf`）放 runbook 或 docs，不要到生产发现崩了才补
   ```ini
   [Service]
   Environment=JAVA_TOOL_OPTIONS=-Djdk.httpclient.allowRestrictedHeaders=host
   ```
3. **本地 dev 测试必须在 prod profile + 目标 JDK 版本下真跑请求**——本地 JDK 17 不会触发 restriction，会误以为 OK
4. **runbook 必校验 JVM 真 picked up flag**：
   ```bash
   ssh <host> 'sudo journalctl -u newworld-<svc> | grep "Picked up JAVA_TOOL_OPTIONS"'
   # 命中才算 drop-in 生效
   ```
5. **代码 review checklist**：grep `.header("Host",` / `.header("Content-Length",` / `.header("Connection",` → 立刻检查对应 systemd drop-in 是否就位

## 2. AWS 服务器 Maven PATH

**背景**：AWS 服务器 maven 装在 `/opt/apache-maven-3.9.9/bin`，**不在默认 PATH**。SSH session 直接 `mvn ...` 报 `command not found`。

铁律：
- 部署 / 手动构建命令前必加：
  ```bash
  export PATH=/opt/apache-maven-3.9.9/bin:$PATH
  ```
- 部署 runbook 的 `ssh aws-* '...'` 块内必含此 export（已嵌在 deploy-runbook skill 三模块 bash 块里）
- 服务器侧 `~/.bashrc` / `~/.profile` 不要随便加（多用户共享），交给 deploy 命令显式声明

## 3. JDK HttpClient 无 per-client DNS override（2026-04-21 EdgeSync TLS SNI 调研定论）

**背景**：想让某个 HTTPS 调用「TCP 连 IPv4 直连、TLS SNI / 证书验证仍用 hostname」（去掉对 `/etc/hosts` 的依赖）时，容易以为 JDK `HttpClient.Builder` 有 per-client DNS override。**没有。**

铁律：
1. **JDK 25 `java.net.http.HttpClient.Builder` 无 `addressResolver(...)` 方法**——网传「JDK 20+ `HttpClient.Builder.addressResolver()`」不成立，该 API 仅停在提案（[JDK-8328286](https://bugs.openjdk.org/browse/JDK-8328286)），JDK 17/21/25 均未实装。反射列方法清单只有 priority/version/proxy/executor/localAddress/sslContext/connectTimeout/... 。
2. **`localAddress` 是源地址绑定**（选出网 IP），**不是**目的地 DNS override——别指望它改解析目标。
3. **`InetAddressResolverProvider` SPI（JEP 418，JDK 18+）作用域是整个 JVM**——一旦注册，MySQL(HikariCP) / Redis(Lettuce) / CF API / acme.sh 所有 `InetAddress.getAllByName(...)` 全走它。为一个调用的 hostname→ipv4 映射打开全局 SPI = 把整服务 DNS 链路塞进一段自定义逻辑，风险面覆盖 DB/Redis/CF，**不可接受**。
4. **结论**：JDK HttpClient 做不了 per-client hostname→IP 定向而不牺牲证书验证。要么保留 hostname URL + 系统 DNS / `/etc/hosts` 兜底（现状，零回归），要么换 OkHttp / Apache HttpClient 5（都支持 per-client DNS override，但引新 Maven dep = P10 级架构决策）。`EdgeSyncService` 当前即走 hostname + `/etc/hosts`，未改代码。
5. **重启此方向的触发条件**：JDK 某版真装 `Builder.addressResolver(...)`、或 `/etc/hosts` 维护痛点 > 1 次/周、或项目接受 OkHttp/Apache HC 为 admin HTTP 标准。

## 检查清单
- [ ] 需 per-client DNS override 时先确认 JDK HttpClient 无此能力（无 `addressResolver`、`localAddress` 只绑源地址、SPI 是 JVM 全局），别假设存在
- [ ] HttpClient 改 restricted header 时同 commit 含 systemd drop-in
- [ ] drop-in 路径 `/etc/systemd/system/<service>.service.d/*.conf`
- [ ] 部署后 grep `Picked up JAVA_TOOL_OPTIONS` 验证 flag 生效
- [ ] AWS ssh 跑 mvn 前 `export PATH=/opt/apache-maven-3.9.9/bin:$PATH`
- [ ] 本地 dev 测 HttpClient 时切到目标 JDK 版本（24+）

## 违反后果
- HttpClient 抛 IllegalArgumentException 没 drop-in → 接口运行期挂，本地 JDK 17 测不出，生产降级（Wave 7 事故）
- drop-in 配了但没 reload daemon → flag 不生效，"修复"上线但症状不变
- AWS ssh 漏 export PATH → 部署 mvn command not found，部署链路断
- 上述任一项 = **3.25 级别**复盘（跨 JDK / 跨版本 API 约束未 enumerate 前置假设）

## 源
- CLAUDE.md L522-L536（JDK HttpClient restricted header）
- CLAUDE.md L116（Maven PATH，散落在架构原则段）
- §3 要点提炼自 `docs/recon/p7_edgesync_tls_sni_design.md`（P7-Wave5-B TLS SNI override 调研，2026-04-21；已删除留墓碑，`git show` 取回）

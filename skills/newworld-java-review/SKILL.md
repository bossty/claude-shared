---
name: newworld-java-review
description: Java/Spring Boot 后端审查 checklist（NPE/线程安全/SQL/资源/事务/安全）——写审 Java、PR 前、蓝军 Java 审逐条过；确定性规则优先 grep/LSP 静态扫，再人判。源 alibaba/open-code-review 取长(2026-07-03) + 缝合 newworld 既有铁律
triggers:
  - java review
  - 代码审查
  - PR 前
  - 蓝军审 java
  - NPE
  - 线程安全
  - newworld-web
  - newworld-admin
---

# newworld-java-review — Java 后端审查 checklist

**用法**：写/审 `newworld-web|admin|data|common` 的 Java、PR/合并前、蓝军 Java 审时逐节过 diff，命中即报 `file:line` + 严重度 + 修法（对齐 [[newworld-audit-rigor]] 双引证）。**能静态查的先 grep/LSP 扫，再人判**（阿里 open-code-review 的确定性管道思路：`${}` 注入、`static SimpleDateFormat` 这类无需推理）。

## 1. NPE / 空值
- 外部输入 / DB 查询结果 / `Map.get` / 三方 API·RPC 返回未判空直接解引用
- 链式调用中间返回 null（`a.getB().getC()`）
- 自动拆箱 NPE（`Integer→int`；DB null 列映射到基本类型字段）

## 2. 线程安全 / 并发（web 多实例 + 百万 DAU）
- 可变共享状态无同步：`static` 可变字段 / 单例内可变成员 / **`SimpleDateFormat`·`SdkClient` 复用**
- 非线程安全集合并发读写（`HashMap`/`ArrayList` 多线程）
- check-then-act 竞态（先查后写无锁/无原子）
- **分布式：本地锁/本地状态替代分布式锁**（web 多实例失效）→ [[newworld-multiregion-crossocean-hotpath]]

## 3. SQL / 持久层
- **PageHelper 分页缺 LIMIT 兜底** → [[newworld-sql-safety]]（DBA benchmark + LIMIT 铁律）
- 拼接 SQL 注入：`${}` vs `#{}`（静态可 grep）
- **下划线↔驼峰漏映射 = silent null** → [[newworld-mybatis-plus-camel-mapping]]
- N+1 / 循环内查库；大批量未分批 OOM → [[newworld-batch-oom]]

## 4. 事务 / 一致性
- **`@Transactional` 自调用失效**（同类内调用不走代理）→ `@Lazy` self 代理
- **热路径读漏 `@Transactional(readOnly)` / readOnly 内写 Redis** → [[newworld-multiregion-crossocean-hotpath]]
- 事务内跨洋/跨服务同步调用（放大延迟）→ `@Async` 离请求线程
- 异常吞没导致事务不回滚

## 5. 资源泄漏
- `Stream`/`Connection`/`InputStream` 未 try-with-resources
- 线程池 / `HttpClient` 每请求新建未复用

## 6. 安全
- XSS（未转义输出）；敏感信息（密码/token）进日志
- **鉴权路径 fail-open vs fail-closed 分层**：本地校验 fail-closed、远程吊销(Redis) fail-open；catch 吞 Redis 超时→静默 401 是 bug → [[newworld-auth-revocation-failopen]]

> 本 checklist 只做"逐条过"入口；每条的深度铁律在被链接的专项 skill 里，命中后 recall 对应项。

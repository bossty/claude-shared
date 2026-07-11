---
name: reference_spring_bean_instantiation_vs_import
description: 判定「某模块是否消费某配置键」不能只看谁 import 了那个类——Spring @ComponentScan 会实例化被扫到的所有 @Component，@Value 无默认值即启动失败。给 common 里的类去默认值前必查所有下游模块的扫描范围。
metadata: 
  node_type: memory
  type: reference
  originSessionId: c3cfb099-3899-4c4e-9d83-ba1ec13cbb2f
---

**Spring 实例化 ≠ 代码引用。** 一个类「全仓只有 A 模块 `import`」不代表只有 A 会创建它的 bean —— 只要 B 的 `@ComponentScan` 覆盖了它所在的包，B 启动时照样实例化，`@Value` 照样解析。

## 本项目的具体形状（2026-07-10 实证）

`JwtUtil` 在 `newworld-common`，全仓唯一 import 方是 `newworld-admin/…/AdminUserServiceImpl.java`。
但三个入口类的扫描范围都含 common：

- `newworld-web/…/WebApplication.java:16` → `@ComponentScan({"org.earth.newworld.web", "org.earth.newworld.common"})`
- `newworld-data/…/DataApplication.java:12` → 同构
- `newworld-admin/…/AdminApplication.java:12` → 同构

而 web / data 的 `application*.yml` **都没有 `jwt.secret` 占位符**。故把
`@Value("${jwt.secret:硬编码默认值}")` 朴素改成 `@Value("${jwt.secret}")`（fail-fast 的直觉改法）
会让 **6 台 web + data 启动即 `Could not resolve placeholder 'jwt.secret'`**。

交接档 `SECRETS-UNIFICATION-PLAN.md` §7 原本就写着「影响面仅 admin」——正是踩了这个推理跳跃。

## 正确做法

给 common 里 `@Component` 的类去掉 `@Value` 默认值前：

1. `grep -rn 'ComponentScan' */src/main/java/**/[A-Z]*Application.java` 看哪些模块会扫到它；
2. 对每个会扫到的模块，确认它的 yml/env **确实**提供该属性；
3. 若只有部分模块提供 → 加 `@ConditionalOnProperty(prefix="x", name="y")`，让不提供该属性的模块干脆不实例化该 bean。

## 决定性验证手段（别停在静态推理）

`ApplicationContextRunner` 测试**证明不了**全组件扫描下的行为（本项目 `ReplicaRedisConfigIntegrationTest`
就是 runner 而非 `@SpringBootTest(classes=WebApplication)`，因为后者无 DB 必崩）。

真起 jar 加 `--debug`，读 Spring 的 condition evaluation report：

```
java -jar newworld-web/target/newworld-web-*.jar --spring.profiles.active=dev --debug 2>&1 \
  | grep -A3 'JwtUtil'
# JwtUtil:
#    Did not match:
#       - @ConditionalOnProperty (jwt.secret) did not find property 'secret'
```

配套判据：`grep -c "Could not resolve placeholder 'jwt.secret'"` 必须为 0。

> 推论：`@Value` 无默认值时，只要 bean 被创建，**任何 profile 都会解析失败**。
> 所以「dev profile 下能正常启动」就等价于「该 bean 没被创建」——这让本地验证无需 prod profile，
> 不违反 [[feedback_local_admin]] / 禁连线上 DB 铁律。

与 [[reference_env_key_ownership_and_systemd_envfile]] 是同一族铁律的两面：那条讲「判模块是否读某键必追 @Value 所在模块」，
本条讲「@Value 所在模块 ≠ 唯一实例化它的模块」。

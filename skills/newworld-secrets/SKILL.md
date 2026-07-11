---
name: newworld-secrets
description: 生产凭证不入 git，application-prod.yml 用 ${XXX:changeme} 占位符，真值在 /etc/newworld/ 下按「共享/模块/节点」分层的 .env 文件，经 systemd EnvironmentFile 注入。判定某模块是否消费某 secret 必须追到 @Value/@ConfigurationProperties 所在模块，禁凭类名或键名推断。drop-in 覆盖 EnvironmentFile 必须先写空赋值重置（累加语义）。Triggers on 密码, secret, application-prod.yml, secrets.env, 凭证, ${XXX:changeme}, EnvironmentFile, 密钥占位符, hardcoded password, 密钥分层, admin.env, data.env, r2.env, node.env, drop-in, relaxed binding, JWT_SECRET, CF_TOKEN_S, ComponentScan, ConditionalOnProperty, Could not resolve placeholder, 去默认值, fail-fast 启动校验.
---

# Newworld 凭证管理铁律（2026-04-13 起；2026-07-10 三层拆分收口）

## 触发场景
- 修改 `application-prod.yml` / `application.yml`
- 新增任何密码、token、API key、签名密钥、AES key、JWT secret
- 在 Java 代码 / .yml / .properties / SQL seed 中看到看似硬编码的凭证
- 改 systemd unit 或 drop-in 的 `EnvironmentFile=`
- 判断"某个 secret 该不该发给某个模块"

## 铁律

1. **生产凭证不入 git**：`application-prod.yml` 中所有密码 / 密钥用 `${XXX:changeme}` 占位符。占位符默认值必须是 `changeme`，不要给"看起来正常"的默认值。
   > 历史反例（2026-07-10 已修）：`newworld-common/…/utils/JwtUtil.java:21` 曾写成
   > `@Value("${jwt.secret:newworld-jwt-secret-key-256bits}")` —— 默认值是一个**可用的真密钥字面量**，
   > 漏配时不 fail-fast，而是静默用公开在 git 里的密钥签名。现已改为无默认值 + `@PostConstruct` 校验
   > （prod 下哨兵值或短于 32 字节即拒绝启动）+ `@ConditionalOnProperty`（见铁律 5）。
   > 正例：`newworld-web/…/service/JwtTokenService.java:247` 缺密钥直接 `throw new IllegalStateException`。

2. **真值在 `/etc/newworld/` 下分层存放**（2026-07-10 起，8 实例已统一；`/opt/newworld/` 已废弃）：

   | 文件 | 内容 | 谁加载 |
   |---|---|---|
   | `secrets.env` | 跨模块共享键 | 全部 newworld-* 服务 |
   | `r2.env` | R2 对象存储凭证 | admin + data（web 不读） |
   | `web.env` / `admin.env` / `data.env` | 模块专属键 | 对应模块 |
   | `node.env` | 节点 / region 覆盖 | 有差异的节点（可选） |

   **最小权限原则**：一个模块的 `EnvironmentFile` 里不该出现它不读的密钥。拆分前 CA web 四台持有整份 admin secrets（含账号级 `CF_TOKEN_S`），web 一行都不读——任何一次在 web 节点上的常规排错都可能把它捞出来。

3. **权限一律 `0640 root:root`**：systemd 以 root 读 `EnvironmentFile`，JVM 无需直读该文件。别放宽，也别设成 `newworld:newworld 0600`（无意义且不一致）。

4. **drop-in 里覆盖 `EnvironmentFile=` 必须先写一行空赋值重置** —— systemd 的该指令是**累加**语义，不是替换：

   ```ini
   [Service]
   EnvironmentFile=                          # ← 缺此行则 base unit 的旧路径仍生效，新旧并存
   EnvironmentFile=/etc/newworld/secrets.env
   EnvironmentFile=-/etc/newworld/node.env   # `-` = 文件不存在时不报错
   ```

   顺序即优先级（后者覆盖前者）。改完必须 `systemctl daemon-reload` 并断言：
   `systemctl show <unit> -p EnvironmentFiles` 里**不含**任何旧路径。

5. **判定"某模块是否消费某 secret"，必须追到 `@Value` / `@ConfigurationProperties` 所在的模块**。禁止凭以下任一推断：
   - **凭类名**：web 里有 `JwtAuthFilter` / `JwtTokenService` 不代表 web 读 `jwt.secret`。它走的是 DB `system_config` 里的 `GW_JWT_SECRET`，与 `JwtUtil` 无关。`grep -rl "import.*JwtUtil"` 一查即知（唯一 import 方是 admin）。
   - **凭 yml 有无占位符**：Spring relaxed binding 会把 env `FOO_BAR_BAZ` 映射到属性 `foo.bar.baz`。**yml 里没有 `${}` 占位符的键依然可能生效**。例：`ANALYTICS_V4_WRITE_SHADOW_ENABLED` 在 web 的 yml 里查无此名，却被 `newworld-web/…/service/SiteStatsService.java:60` 的 `@Value("${analytics.v4.write-shadow-enabled:false}")` 真实读取。
   - 正确方法：yml 占位符扫一遍 + 全模块 `@Value("${...}")` / `@ConfigurationProperties(prefix=...)` 扫一遍，两边对账。

   ⚠️ **反过来也不成立：Spring 实例化 ≠ 代码引用**（2026-07-10 差点炸 6 台 web 的教训）。
   「全仓只有 admin `import JwtUtil`」不代表只有 admin 会创建该 bean —— `WebApplication.java:16` 与
   `DataApplication.java:12` 的 `@ComponentScan` 都含 `org.earth.newworld.common`，web/data 照样实例化它、
   照样解析它的 `@Value`。而 web/data 的 yml 均无 `jwt.secret` 占位符，故**把默认值朴素删掉做 fail-fast，
   会让 6 台 web + data 启动即 `Could not resolve placeholder`**。
   → 给 common 里的 `@Component` 去默认值前，必须 `grep -rn 'ComponentScan' */src/main/java/**/*Application.java`
     查全部下游扫描范围；只有部分模块提供该属性时，加 `@ConditionalOnProperty(prefix=…, name=…)` 让其余模块不实例化。
   → 决定性验证**不能**用 `ApplicationContextRunner`（证明不了全扫描行为）。真起 jar 加 `--debug` 读 condition
     evaluation report：期望 `JwtUtil: Did not match: @ConditionalOnProperty …`，且
     `grep -c "Could not resolve placeholder 'jwt.secret'"` 为 `0`。
     （`@Value` 无默认值时只要 bean 被创建，**任何 profile 都会解析失败** → dev profile 下能起来 = bean 没被创建，
     故本地验证无需 prod profile，不违反禁连线上 DB 铁律。）

6. **新增 secret 的标准动作**：
   - yml 加占位符 `${NEW_SECRET:changeme}`
   - 判定归属层（共享 / 模块 / 节点），加到**对应层**而非一律 `secrets.env`
   - 在所有部署该模块的服务器上同步
   - 禁止硬编码到 Java 常量或 .properties

7. **三档分类**（详见 `docs/SECURITY_POSTURE.md`）：强 secret（DB / R2 / JWT）/ 弱签名（探针 salt 一类）/ 探针 salt（可暴露但不能丢）。新 secret 必须分档。

## 检查清单

- [ ] `grep 'password:\|secret:\|key:'` in `application-prod.yml` → 全部 `${XXX:changeme}` 形式
- [ ] 新 secret 归到了正确的层，该模块之外的 unit 拿不到它
- [ ] 服务器 `/etc/newworld/*.env` 权限 = `0640 root:root`
- [ ] drop-in 若覆盖 `EnvironmentFile=`，第一行是空赋值重置
- [ ] `systemctl show <unit> -p EnvironmentFiles` 输出中无旧路径、可选层标 `ignore_errors=yes`
- [ ] 改 `EnvironmentFile` 后**不重启**即可完成路径迁移（仅启动时读取）；用
      `sudo cat /proc/$(systemctl show <unit> -p MainPID --value)/environ | tr '\0' '\n' | md5sum`
      前后对账证明零中断
- [ ] 新配置未经启动验证时，用 `systemd-run --collect --wait --pipe -p EnvironmentFile=… /usr/bin/env`
      无损预演，确认 systemd 能解析且键集正确

## 违反后果

凭证入 git、或被打进日志 / 会话记录 → **必须 rotate**（CF token revoke / DB 密码改 / R2 key 轮换），
不能"反正没人看到"打发。脱敏正则要按**完整键名**匹配：`s/(SECRET|TOKEN)=.*/…/` 挡不住 `CF_TOKEN_S=`
（`TOKEN` 后面还有 `_S`）——2026-07-10 实际因此泄露过一次账号级 CF token。

## 源
- CLAUDE.md L16-L21
- 配套文档 `docs/SECURITY_POSTURE.md`
- 三层拆分实施记录 `docs/sprint/2026-07-10-jar-layout-unification/SECRETS-UNIFICATION-PLAN.md`
